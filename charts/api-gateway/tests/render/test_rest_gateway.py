import unittest
from os import path
from subprocess import CalledProcessError

from .manifest import Manifest
from .chart import Chart
from .data import HelmData

TEST_DIR = path.dirname(__file__)
CHART_DIR = path.dirname( path.dirname( TEST_DIR ) )
FIXTURE_DIR = path.join(CHART_DIR, ".fixtures")

def dump(obj, path):
    """
    Helper for dumping the contents of a manifest, set or other structure into a yaml file.
    Can be temporarily added to a test to allow the generated manifest to be examined.
    """

    with open(path, "w", encoding="utf-8") as f:
        f.write(obj.dump())

class RestGatewayTest(unittest.TestCase):

    chart = None
    release = "gwtest"

    @classmethod
    def setUpClass(cls):
        cls.chart = Chart( CHART_DIR )

    def render(self, fixtures = None, options = None):
        files = []
        for f in fixtures or []:
            files.append( path.join( FIXTURE_DIR, f ) )

        try:
            return self.chart.render( self.release, files, options )
        except CalledProcessError as ex:
            raise Exception( "Helm failed to render the chart:\n" + ex.stdout + "\n" + ex.stderr ) from ex

    def test_restgw(self):
        manifests = self.render( [ "rest_routes.yaml" ] )

        # Deployment manifest
        deployment = manifests.find( { "kind": "Deployment" } )
        self.assert_deployment_common(deployment)

        # Envoy config
        cm = manifests.find( { "kind": "ConfigMap", "metadata.name": "api-gateway-gwtest-base-config" } )
        envoy_config = cm.get_decoded( ["data", "envoy.yaml"] ) # this also ensures tha the YAML is valid
        self.assert_envoy_config_common(envoy_config)

    def test_ratelimiter_enabled(self):
        manifests = self.render( [ "rest_routes.yaml", "ratelimiter_enabled.yaml" ] )

        # Deployment manifest
        deployment = manifests.find( { "kind": "Deployment" } )
        self.assert_deployment_common(deployment)
        self.assert_deployment_ratelimiter_enabled(deployment)

        # Envoy config
        cm = manifests.find( { "kind": "ConfigMap", "metadata.name": "api-gateway-gwtest-base-config" } )
        envoy_config = cm.get_decoded( ["data", "envoy.yaml"] ) # this also ensures tha the YAML is valid
        self.assert_envoy_config_common(envoy_config)
        self.assert_envoy_config_ratelimiter_enabled(envoy_config)

        # Ratelimit config
        cm = manifests.find( { "kind": "ConfigMap", "metadata.name": "api-gateway-gwtest-ratelimit-config" } )
        ratelimit_config = cm.get_decoded( ["data", "config.yaml"] ) # this also ensures tha the YAML is valid
        self.assert_ratelimit_config_valid(ratelimit_config)

        # Shadow mode
        data_path = [ "descriptors", { "value": "active-policy" },
                 "descriptors", { "value": "anon" },
                 "descriptors", { "key": "user_id" },
                 "descriptors", { "value": "HOUR" },
                 "shadow_mode" ]
        self.assertIsNone( ratelimit_config.get( data_path ) )

        data_path[1] = { "value": "shadow-policy" }
        self.assertTrue( ratelimit_config.get( data_path ) )

    def assert_deployment_common(self, deployment):
        #volumes
        self.assertIsNotNone( deployment.get("spec.template.spec.volumes.name=gwtest-base-config"), "gwtest-base-config" )

        # containers
        envoy_container = deployment.get("spec.template.spec.containers.name=api-gateway-gwtest")
        self.assertIsNotNone( envoy_container, "name=api-gateway-gwtest" )

        self.assertEqual( envoy_container.get("securityContext.allowPrivilegeEscalation"), False )
        self.assertIsNotNone( envoy_container.get("volumeMounts.name=gwtest-base-config"), "gwtest-base-config" )

    def assert_deployment_ratelimiter_enabled(self, deployment):
        #volumes
        self.assertIsNotNone( deployment.get("spec.template.spec.volumes.name=gwtest-nutcracker-config"), "gwtest-nutcracker-config" )
        self.assertIsNotNone( deployment.get("spec.template.spec.volumes.name=gwtest-ratelimit-config"), "gwtest-ratelimit-config" )

        # containers
        nutcracker_container = deployment.get("spec.template.spec.containers.name=gwtest-nutcracker")
        self.assertIsNotNone( nutcracker_container, "gwtest-nutcracker" )
        self.assertIsNotNone( nutcracker_container.get("volumeMounts.name=gwtest-nutcracker-config"), "gwtest-nutcracker-config" )

        ratelimit_container = deployment.get("spec.template.spec.containers.name=gwtest-ratelimit")
        self.assertIsNotNone( ratelimit_container, "gwtest-ratelimit" )
        self.assertIsNotNone( ratelimit_container.get("volumeMounts.name=gwtest-ratelimit-config"), "gwtest-ratelimit-config" )

    def assert_envoy_config_common(self, config):
        # clusters
        self.assertIsNotNone( config.get("static_resources.clusters.name=main_services_cluster") )

        self.assertEqual( config.get("static_resources.clusters.name=other_cluster.load_assignment.cluster_name"), "other_cluster" )
        self.assertIsNotNone( config.get("static_resources.clusters.name=other_cluster.transport_socket.typed_config.common_tls_context") )

        # listener
        listener = config.get("static_resources.listeners.name=listener_0") # brittle, name may change
        self.assertIsNotNone( listener, "listener_0" )
        self.assertEqual( listener.get("address.socket_address.protocol"), "TCP")

        # connection_manager
        connection_manager = listener.get(["filter_chains", 0, "filters", { "name": "envoy.filters.network.http_connection_manager"} ])
        self.assertIsNotNone( connection_manager, "http_connection_manager" )
        self.assertEqual( connection_manager.get("typed_config.access_log.name"), "envoy.file_access_log")
        self.assertIsNotNone( connection_manager.get("typed_config.internal_address_config"), "internal_address_config")
        self.assertIsNotNone( connection_manager.get("typed_config.local_reply_config"), "local_reply_config")

        # http filters
        self.assertIsNotNone( connection_manager.get(["typed_config", "http_filters", {"name": "envoy.health_check"}]), )
        self.assertIsNotNone( connection_manager.get(["typed_config", "http_filters", {"name": "envoy.filters.http.cors"}]), )
        self.assertIsNotNone( connection_manager.get(["typed_config", "http_filters", {"name": "envoy.filters.http.header_to_metadata"}]), )
        self.assertIsNotNone( connection_manager.get(["typed_config", "http_filters", {"name": "envoy.filters.http.router"}]), )

        # route_config
        vhost = connection_manager.get("typed_config.route_config.virtual_hosts.name=restgateway_vhost")
        self.assertIsNotNone( vhost, "restgateway_vhost")
        self.assertIsNotNone( vhost.get("routes.name=rest_gateway_root"), "rest_gateway_root")
        self.assertIsNotNone( vhost.get("routes.name=main_services_foo_bar"), "main_services_foo_bar")
        self.assertIsNotNone( vhost.get("routes.name=other_endpoints_dummy"), "other_endpoints_dummy")

    def assert_envoy_config_ratelimiter_enabled(self, config):
        # clusters
        self.assertIsNotNone( config.get("static_resources.clusters.name=rate_limit_cluster") )

        self.assertEqual( config.get("static_resources.clusters.name=rate_limit_cluster.load_assignment.cluster_name"), "rate_limit_cluster" )
        self.assertIsNotNone( config.get("static_resources.clusters.name=rate_limit_cluster.typed_extension_protocol_options") )

        # listener
        listener = config.get("static_resources.listeners.name=listener_0") # name may change
        self.assertIsNotNone( listener, "listener_0" )

        # connection_manager
        connection_manager = listener.get(["filter_chains", 0, "filters", { "name": "envoy.filters.network.http_connection_manager"} ])
        self.assertIsNotNone( connection_manager, "http_connection_manager" )

        # http filters
        self.assertIsNotNone( connection_manager.get(["typed_config", "http_filters", {"name": "envoy.filters.http.lua"}]), )
        self.assertIsNotNone( connection_manager.get(["typed_config", "http_filters", {"name": "envoy.filters.http.ratelimit"}]), )

        # route_config
        vhost = connection_manager.get("typed_config.route_config.virtual_hosts.name=restgateway_vhost")
        self.assertIsNotNone( vhost, "restgateway_vhost")
        self.assertIsNotNone( vhost.get("rate_limits"), "rate_limits")

        self.assertIsNotNone( vhost.get(["routes", {"name": "main_services_foo_bar"}, "metadata", "filter_metadata", "envoy.filters.http.lua", "wmf_ratelimit", "policy"]), "wmf_ratelimit.policy")

    def assert_ratelimit_config_valid(self, config):
        self.assertIsNotNone(config.get("domain"))
        self.assertIsNotNone(config.get("descriptors"))

        for d in config.get("descriptors"):
            self.assert_ratelimit_valid(d)

    def assert_ratelimit_valid(self, config):
        self.assertIsNotNone(config.get("key"))

        limit = config.get("rate_limit")
        if limit:
            self.assertIsNotNone(limit.get("unit"))
            self.assertIsNotNone(limit.get("requests_per_unit"))

        for d in config.get("descriptors", []):
            self.assert_ratelimit_valid(d)
