require 'rake'
require 'json'
require 'tmpdir'
require 'rake/tasklib'
require 'open3'
require 'yaml'
require 'readline'
require 'digest/md5'
require 'fileutils'
require 'open-uri'
require 'base64'
require 'pathname'

# Load local modules
require_relative '.rake_modules/scaffold'
require_relative '.rake_modules/monkeypatch'
require_relative '.rake_modules/utils'
require_relative '.rake_modules/tester/tester'
require_relative '.rake_modules/tester/asset'

HELMFILE_GLOB = 'helmfile.d/*services/**/helmfile.yaml'.freeze
CHARTS_GLOB = 'charts/**/Chart.yaml'.freeze
# Charts that contain CRDs need to provide a well known fixture (crds.yaml)
# that guaranteed proper rendering of the CRDs and will be used to create
# JSON schema (used by kubeconform to validate custom resources).
CDRS_GLOB = 'charts/**/.fixtures/crds.yaml'.freeze
ISTIOCTL_VERSION = 'istioctl-1.15.7'.freeze
JSON_SCHEMA = 'jsonschema/'.freeze
LISTENERS_FIXTURE = '.fixtures/service_proxy.yaml'.freeze

# This returns a base64-encoded value.
HIERADATA_BASE_URL = 'https://gerrit.wikimedia.org/r/plugins/gitiles/operations/puppet/+/refs/heads/production/hieradata'.freeze
DEPLOYMENT_SERVER_KUBERNETES_HIERA_URL = "#{HIERADATA_BASE_URL}/role/common/deployment_server/kubernetes.yaml?format=TEXT".freeze
LISTENERS_DEFINITIONS_URL = "#{HIERADATA_BASE_URL}/common/profile/services_proxy/envoy.yaml?format=TEXT".freeze
MARIADB_SECTION_PORTS_URL = "#{HIERADATA_BASE_URL}/common/profile/mariadb.yaml?format=TEXT".freeze
COMMON_HIERA_URL = "#{HIERADATA_BASE_URL}/common.yaml?format=TEXT".freeze
COMMON_KUBERNETES_HIERA_URL = "#{HIERADATA_BASE_URL}/common/kubernetes.yaml?format=TEXT".freeze

## RAKE TASKS

desc 'Checks dependencies'
task :check_dep do
  check_binary('helm')
  check_binary('helm3.11')
  check_binary('helmfile')
  check_binary('semver-cli')

  res, output = _exec('helm version --client --short')
  helm_version = output.split('.').first

  raise("Only helm v3 is supported. Installed helm version is #{helm_version}") if helm_version != 'v3'
end

# This is to ensure that all repos are available and up to date
desc 'Add and update all needed helm repositories'
task repo_update: :check_dep do
  # Hash of repository url (ensure no trailing backslash, don't ask) and repository name
  repositories = {
    'https://helm-charts.wikimedia.org/stable' => 'wmf-stable'
  }
  FileList.new(CHARTS_GLOB).each do |path_to_chart|
    chart_yaml = yaml_load_file(path_to_chart)
    dependencies = []
    # Dependencies are to be defined in Chart.yaml
    dependencies = chart_yaml['dependencies'] if chart_yaml['dependencies']

    next unless dependencies

    dependencies.each do |dep|
      next unless dep.has_key?('repository')

      unless dep['repository'].match(/^http/)
        raise("Only http(s) URLs supported for non-local helm dependencies (#{path_to_chart})")
      end

      url = dep['repository'].chomp('/')
      unless repositories.key?(url)
        # Use the md5 hash of the repository URL as name, it does not matter for dependency references
        repositories[url] = Digest::MD5.hexdigest(url)
      end
    end
  end

  repositories.each do |url, name|
    puts("Adding helm repo #{url} as #{name}")
    # --force-update does *not* force a repository update but forces the update of the URL if the repository already exists
    system("helm repo add --force-update #{name} #{url}")
  end
  system('helm repo update')
end

desc 'Create CRDs JSON schema (for kubeconform validation)'
task :json_schema do
  output_dir = File.join(JSON_SCHEMA, 'charts')
  if File.exist?(output_dir)
    Dir.glob(File.join(output_dir, '*.json')).each { |file| File.delete(file) }
  else
    Dir.mkdir(output_dir)
  end
  FileList.new(CDRS_GLOB).each do |fixture|
    chart_path = File.expand_path('..', File.dirname(fixture))
    chart_name = File.basename(chart_path)
    res, helm_out = _exec("helm template -f #{fixture} #{chart_path}")
    if !res
      puts helm_out.red
      raise("Error templating chart #{chart_name} for JSON schema")
    end
    res, convert_out = _exec("./openapi2jsonschema.py -o #{output_dir} -", helm_out)
    if !res
      puts convert_out.red
      raise("Error running openapi2jsonschema.py for chart #{chart_name}")
    end
  end
end

desc 'Runs helm lint on all charts'
task :lint do |_t, args|
  charts = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check_charts].invoke('lint', charts)
  Rake::Task[:check_charts].reenable
end

desc 'Runs helm template on all charts and validate the output with kubeconform'
task :validate_template do |_t, args|
  charts = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check_charts].invoke('validate', charts)
  Rake::Task[:check_charts].reenable
end

desc 'Runs helmfile lint on all service deployments'
task validate_deployments: :repo_update do |_, args|
  deployments = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check_deployments].invoke('lint', deployments)
  Rake::Task[:check_deployments].reenable
end

desc 'Validate the envoy configuration'
task validate_envoy_config: %i[check_dep refresh_fixtures] do
  puts 'Generating and verifying the envoy configuration...'
  begin
    sc = Scaffold.new('service', 'validate-envoy-config', '_scaffold/service/.presets/nodejs.yaml')
    sc.run
    # run helm template for a specific fixture that generates a service proxy and tls terminator
    command = "helm template --values .fixtures/validate_envoy_config.yaml --values #{LISTENERS_FIXTURE} charts/validate-envoy-config"
    res, out = _exec command
    unless res
      puts out.red
      raise('Failure generating the helm manifest')
    end
    # Extract the envoy configuration, write it to a file
    file_resources = {}
    begin
      error = 'Extracting envoy config from "helm template" output'
      config = ''
      YAML.load_stream(out) do |resource|
        next unless !resource.nil? \
          && resource['kind'] == 'ConfigMap' \
          && resource['metadata'] \
          && resource['metadata']['name'] \
          && resource['metadata']['name'].end_with?('envoy-config-volume')

        file_resources = resource['data']
        config = file_resources['envoy.yaml']
      end
    rescue StandardError => e
      puts error.red
      puts e
      raise('Failure reading the helm yaml template')
    end
    begin
      error = 'Parsing envoy.yaml'
      YAML.safe_load(config)
    rescue Psych::SyntaxError => e
      report_yaml_parse_error(command, error, config, e)
      raise('Failure parsing envoy YAML configuration')
    rescue StandardError => e
      puts error.red
      puts e
      raise('Generic failure interpreting envoy YAML configuration')
    end
  ensure
    FileUtils.rm_rf('charts/validate-envoy-config')
  end

  use_local_envoy = system('which envoy > /dev/null 2>&1') && File.writable?('/etc/envoy')
  if use_local_envoy
    dest = '/etc/envoy'
  else
    dest = '.tmp'
    # Now create a temp directory where we write the yaml file, then run docker to verify it works.
    FileUtils.mkdir dest, mode: 0o777
    at_exit { FileUtils.remove_entry dest }
  end
  file_resources.each do |fn, data|
    f = File.open "#{dest}/#{fn}", 'w'
    f.write data
    f.close
    # If we're copying the file into the container, it needs to be world-readable
    File.chmod 0o755, "#{dest}/#{fn}" unless use_local_envoy
  end

  FileUtils.cp_r('.fixtures/ssl/', "#{dest}/")

  if use_local_envoy
    # Some envoy options do require service-node and service-cluster to be set
    # and we do so in the entypoint of the procution images. Reproduce that here.
    envoy_args = "--service-node validate --service-cluster validate --mode validate"
    cmd = "envoy #{envoy_args} -c #{dest}/envoy.yaml"
  else
    envoy_image = "docker-registry.wikimedia.org/envoy:latest"
    # SERVICE_NAME will be used as value for the --service-cluster argument by the entrypoint
    envoy_envs = "-e SERVICE_NODE=validate -e SERVICE_NAME=validate"
    envoy_args = "--mode validate"
    path = File.realpath dest
    cmd = "docker run --pull always --rm -v #{path}:/etc/envoy #{envoy_envs} #{envoy_image} #{envoy_args}"
  end
  res, out = _exec cmd
  if !res
    puts out.red
    raise('Failure')
  else
    puts out.green
  end
end

# Scaffolding
desc 'Create a new chart'
task :scaffold do
  sextant = which("sextant")
  if sextant.nil?
    puts("Please install sextant: pip3 install sextant")
    return 1
  end
  puts("Please use sextant to create a chart: ")
  puts("#{sextant} create-chart -s _scaffold/<model> charts/<chart-name>")
end

desc 'Validate all scaffolding models'
task :test_scaffold, [:tests] => [:refresh_fixtures] do |_, args|
  sextant = which("sextant")
  if sextant.nil?
    puts("Please install sextant: pip3 install sextant")
    return 1
  end
  args = {} if args.nil?
  Rake::Task[:check].invoke('scaffold', args.fetch(:tests, nil), nil)
  Rake::Task[:check].reenable

end

desc 'Show diff introduced by the patch'
task helm_diffs: %i[refresh_fixtures] do |_t, args|
  charts = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check_charts].invoke('diff', charts)
  Rake::Task[:check_charts].reenable
end

desc 'Show diffs in deployments introduced by the patch'
task deployment_diffs: %i[check_dep repo_update refresh_fixtures] do |_, args|
  charts = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check_deployments].invoke('diff', charts)
  Rake::Task[:check_deployments].reenable
end

## RAKE TASKS admin_ng

desc 'Runs helmfile lint on admin_ng for all environments'
task admin_lint: %i[check_dep repo_update refresh_fixtures] do |_t, args|
  envs = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check].invoke('admin', 'lint', envs)
  Rake::Task[:check].reenable
end

desc 'Runs helmfile template on admin_ng for all environments and validate the output with kubeconform'
task admin_validate: %i[check_dep repo_update refresh_fixtures] do |_t, args|
  envs = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check].invoke('admin', 'validate', envs)
  Rake::Task[:check].reenable
end

desc 'Shows admin diff introduced by this patch'
task admin_diff: %i[check_dep repo_update refresh_fixtures] do |_t, args|
  envs = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check].invoke('admin', 'diff', envs)
  Rake::Task[:check].reenable
end

## RAKE TASKS custom_deploy

desc 'Validate istio configuration'
task :validate_istio_config do
  check_binary(ISTIOCTL_VERSION)
  FileList.new('custom_deploy.d/istio/*/config.yaml').each do |config|
    ok, out = _exec "#{ISTIOCTL_VERSION} validate -f #{config}"
    next if ok

    puts "Failed to verify istio config '#{config}':".red
    puts out
    raise('Failure')
  end
end

desc 'Run other tasks locally within the CI docker images'
task :run_locally, [:cmdargs] do |_t, args|
  check_docker
  # If ROOTLESS_PODMAN is set to 1, we will assume the user is using podman
  # TODO: maybe use the output of "docker version" to determine if we are using podman
  # and some trickery to detect rootless podman too?
  is_rootless_podman = (ENV['ROOTLESS_PODMAN'] == '1')
  cmdargs = if args.nil? || args.count.zero?
              ''
            else
              args[:cmdargs]
            end
  Dir.mktmpdir do |dir|
    puts "Copying and committing code to #{dir}"
    FileUtils.cp_r('.', dir)
    Dir.chdir dir do
      g = Git.open('.')
      # Change origin to anonymous https
      g.refresh_remote('origin', force = true)
      # Commit any outstanding file
      if g.diff('HEAD', '.').size != 0
        g.add(all: true)
        g.commit('running_diffs')
      end

      # In rootless podman, the root user is the current user
      # so we want to run as root!
      user = is_rootless_podman ? 0 : Process.uid

      puts 'Now running in docker'
      cmd = [
        'docker',
        'run',
        '--pull always',
        '--rm',
        "--user #{user}",
        "-v #{dir}:/src:rw",
        '-v /etc/passwd:/etc/passwd:ro',
        '-v /etc/group:/etc/group:ro',
        'docker-registry.wikimedia.org/releng/helm-linter:latest',
        cmdargs
      ].join(' ')
      puts cmd
      puts `#{cmd}`
    end
  end
end

desc 'Update global fixture (service-proxy listeners, deployment_server::general ...)'
task :refresh_fixtures do
  # Download the services proxy file from puppet.
  service_proxy = {}
  URI.open(LISTENERS_DEFINITIONS_URL) do |res|
    decoded = Base64.decode64(res.read)
    hiera = YAML.safe_load(decoded)
    # We don't really need an upstream to be accurate here.
    upstream_mock = {
      'ips' => ['127.0.0.1/32', '169.254.0.1/32'],
      'address' => 'mock.discovery.wmnet',
      'port' => 443,
      'encryption' => true,
    }
    # List of keys to keep in the listeners definition, assembles what we do in
    # modules/profile/manifests/kubernetes/deployment_server/global_config.pp
    listener_keys_to_keep = %w(port http_host timeout retry_policy xfp upstream split)
    data = hiera['profile::services_proxy::envoy::listeners'].map do |x|
      name = x['name']
      upstream = upstream_mock.dup
      if x['sets_sni'] == true
        upstream['sets_sni'] = true
      end
      if x['keepalive']
        upstream['keepalive'] = x['keepalive']
      end
      if x['tcp_keepalive']
        upstream['tcp_keepalive'] = x['tcp_keepalive']
      end
      x['upstream'] = upstream_mock

      if x['split']
        x['split']['address'] = x['split']['upstream']
        # Override ips, port and encryption with mock data
        x['split']['ips'] = ['127.0.0.2/32', '169.254.0.2/32']
        x['split']['port'] = 1443
        x['split']['encryption'] = true
      end

      # Filter keys and nil values to produce the same structure as global_config.pp
      y = x.filter do |key, value|
        listener_keys_to_keep.include?(key) && !value.nil?
      end

      [ name, y ]
    end.to_h

    File.open(LISTENERS_FIXTURE, 'w') do |out|
      service_proxy = { 'services_proxy' => data }
      YAML.dump(service_proxy, out)
    end
  end

  # Fetch mariadb section ports
  # puppet modules/profile/manifests/kubernetes/deployment_server/global_config.pp
  mariadb_sections = {}
  URI.open(MARIADB_SECTION_PORTS_URL) do |res|
    decoded = Base64.decode64(res.read)
    hiera = YAML.safe_load(decoded, aliases: true)
    mariadb_sections = { 'mariadb' => { 'section_ports' => hiera['profile::mariadb::section_ports'] } }
  end

  # Fetch hiera's common.yaml to extract lists of known clusters.
  common_clusters = {}
  URI.open(COMMON_HIERA_URL) do |res|
    decoded = Base64.decode64(res.read)
    hiera = YAML.safe_load(decoded)

    zookeeper_mock = ['1.2.3.4/32']
    zookeeper_clusters = {}
    hiera['zookeeper_clusters'].each_key do |cluster_name|
      zookeeper_clusters[cluster_name] = zookeeper_mock
    end
    common_clusters['zookeeper_clusters'] = zookeeper_clusters

    kafka_mock = ['1.2.3.4/32']
    kafka_brokers = {}
    hiera['kafka_clusters'].each_key do |cluster_name|
      kafka_brokers[cluster_name] = kafka_mock
    end
    common_clusters['kafka_brokers'] = kafka_brokers
  end

  # Read the kubernetes cluster information from hiera
  # merging defaults with cluster settings. Like modules/k8s/manifests/clusters.pp
  kubernetes_clusters = {}
  URI.open(COMMON_KUBERNETES_HIERA_URL) do |res|
    decoded = Base64.decode64(res.read)
    hiera = YAML.safe_load(decoded, aliases: true)
    defaults = hiera['kubernetes::clusters_defaults']
    hiera['kubernetes::clusters'].each do |group_name, clusters|
      clusters.each do |cluster_name, cluster_values|
        kubernetes_clusters[cluster_name] = deep_merge(cluster_values, defaults.dup)
        kubernetes_clusters[cluster_name]['cluster_group'] = group_name
        if cluster_values.has_key?('cluster_alias')
          kubernetes_clusters[cluster_values['cluster_alias']] = kubernetes_clusters[cluster_name]
        end
      end
    end
  end

  # Mock the data structure created for the external-services chart in
  # puppet modules/profile/manifests/kubernetes/deployment_server/global_config.pp
  external_services_definitions = {
    'external_services_definitions' => {
      'kafka' => {
        '_meta' => {
          'ports' => [
            {
              'name' => 'plaintext',
              'port' => 9092
            },
            {
              'name' => 'tls',
              'port' => 9093
            }
          ]
        },
        'instances' => {
          'main-eqiad' => [
            '1.2.3.4/32',
            'fe80::ffff:ffff:ffff:ffff/128',
          ],
          'main-codfw' => [
            '1.2.3.4/32',
            'fe80::ffff:ffff:ffff:ffff/128',
          ]
        }
      },
      'kerberos' => {
        '_meta' => {
          'ports' => [
            {
              'name' => 'ticket',
              'port' => 88,
              'protocol' => 'UDP'
            },
            {
              'name' => 'ticket-large',
              'port' => 88
            }
          ]
        },
        'instances' => {
          'kdc' => [
            '1.2.3.4',
            'fe80::ffff:ffff:ffff:ffff',
          ]
        }
      },
    }
  }

  # Fetch general settings for all environment, similar to
  # puppet modules/profile/manifests/kubernetes/deployment_server/global_config.pp
  URI.open(DEPLOYMENT_SERVER_KUBERNETES_HIERA_URL) do |res|
    decoded = Base64.decode64(res.read)
    hiera = YAML.safe_load(decoded, aliases: true)
    data = hiera['profile::kubernetes::deployment_server::general']

    write_env_fixtures = lambda do |env_name, cluster_values|
      File.open(".fixtures/general-#{env_name}.yaml", 'w') do |out|
        res = [
          data['default'],
          cluster_values,
          service_proxy,
          mariadb_sections,
          common_clusters,
          external_services_definitions,
          {'kubernetesVersion' => kubernetes_clusters[env_name]['version']}
        ].reduce { |acc, h| deep_merge(h, acc) }
        YAML.dump(res, out)
      end
    end

    data.each do |cluster_name, cluster_values|
      next if cluster_name == "default"
      write_env_fixtures.call(cluster_name, cluster_values)
      if cluster_name == 'staging-eqiad'
        write_env_fixtures.call('staging', cluster_values)
      end
    end
  end
end

task :check, [:kind, :tests, :assets] do |_, args|
  # This task is supposed to only be called by upstream ones
  # so it *has* args
  view = Tester.view args
  options = {}
  options[:assets] = args[:assets].split('/') unless args[:assets].nil?
  options[:tests] = args[:tests].split('/') unless args[:tests].nil?
  pattern = case args[:kind]
            when 'charts'
              CHARTS_GLOB
            when 'deployments'
              HELMFILE_GLOB
            when 'admin'
              'admin'
            when 'scaffold'
              'scaffold'
            end
  # Update JSON schema if validate (e.g. kubeconform) will be called
  if options[:tests].nil? || options[:tests].include?('validate')
    Rake::Task[:json_schema].invoke
  end
  tr = Tester.runner pattern, options
  tr.run
  puts view.render(tr)
  abort('validation failed') unless tr.failed.empty?
end

desc 'Run checks for all the charts.'
task :check_charts, %i[tests charts] => [:refresh_fixtures] do |_, args|
  args = {} if args.nil?
  Rake::Task[:check].invoke('charts', args.fetch(:tests, nil), args.fetch(:charts, nil))
  Rake::Task[:check].reenable
end

desc 'Run checks for all deployments.'
task :check_deployments, %i[tests deployments] => [:refresh_fixtures] do |_, args|
  args = {} if args.nil?
  Rake::Task[:repo_update].invoke
  Rake::Task[:refresh_fixtures].invoke
  Rake::Task[:check].invoke('deployments', args.fetch(:tests, nil), args.fetch(:deployments, nil))
  Rake::Task[:check].reenable
end

desc 'Run checks for the admin section'
task :check_admin, %i[tests envs] => [:repo_update, :refresh_fixtures] do |_, args|
  args = {} if args.nil?
  Rake::Task[:check].invoke('admin', args.fetch(:tests, nil), args.fetch(:envs, nil))
  Rake::Task[:check].reenable
end

def bump_chart_version(filename)
  content = File.read(filename)
  match = content.match(/^version: \d+\.\d+\.(\d+)$/)
  return unless match

  new_patch_version = (match[1].to_i + 1).to_s
  content.gsub!(/^(version: \d+\.\d+\.)\d+$/, "\\1#{new_patch_version}")
  File.write filename, content
end

desc 'Only checks the charts/deployments affected by our change'
task :check_change do
  g = Git.open('.')
  g.add_remote('origin', REPO_URL, fetch: true) unless g.remotes.map(&:name).include?('origin')
  # First refresh origin, to be sure we're comparing our code to
  # production's HEAD
  g.remote('origin').fetch
  changes = g.changed_files('origin/master')
  # Before doing anything else, we check if the ruby files are changed. If so, we run everything
  # as the impacted file is in CI
  if changes.values.flatten.filter{ |path| (path == 'Rakefile' || path.start_with?(".rake_modules"))}.empty?
    puts tasklist_from_changes(changes)
  else
    Rake::Task[:all].invoke
  end
end

def tasklist_from_changes(changes)
  tasks = {scaffold: false, charts: [], deployments: [], admin: false, envoy: true, istio: false}
  all_changes = changes.values.flatten

  # Scaffold is easy. Any file under _scaffold or modules changed?
  all_changes.each do |path|
    if path.start_with?('_scaffold/') || path.start_with?('modules')
      tasks[:scaffold] = true
      break
    end
  end

  # Walk the fs tree up from the change to find all charts this change is part of.
  # Charts may contain subcharts, if a subchart has changed we want to return that as well as it's parent.
  # The parent should have the subchart as dependency - but you never know.
  charts = []
  all_changes.filter { |p| p.start_with?('charts/') }.each do |p|
    Pathname.new(p).ascend do |v|
      pv = File.join(v, 'Chart.yaml')
      next unless File.exist?(pv)
      charts |= [v.basename.to_s]
    end
  end

  # Now let's find if any chart in our repo depends on the charts we've modified. We will need to test them as well.
  FileList.new(CHARTS_GLOB).each do |path_to_chart|
    chart_yaml = yaml_load_file(path_to_chart)
    chart_name = chart_yaml['name']
    dependencies = []
    # Dependencies are to be defined in Chart.yaml
    dependencies = chart_yaml['dependencies'] if chart_yaml['dependencies']

    next unless dependencies

    dependencies.each do |dep|
      next unless dep.key?('name')

      charts << chart_name if charts.include? dep['name']
    end
  end
  tasks[:charts] = charts.uniq

  # Now let's check deployments.
  # First let's find deployments that have been modified directly
  deps = all_changes.filter { |p| p.start_with?(%r{helmfile.d/.*services/}) && p.split('/').length > 2 }
  # Now check if any file in each service deployment directory links to a modified file
  deps.map{ |p| File.dirname(File.dirname(p)) }.uniq.each do |dir|
    FileList.new(dir + '/**/*').each do |path|
      if File.symlink?(path)
        # Get target path relative to the repository path (as thats what we got in all_changes)
        target = (Pathname.new(File.dirname(path)) + File.readlink(path)).to_s
        if deps.include?(target)
          # This deployment links to a modified file, add it to the array
          deps << path unless deps.include? path
        end
      end
    end
  end
  tasks[:deployments] = deps.map{ |p| p.split('/')[2] }.uniq

  # Find deployments that depend on a specific chart that changed
  FileList.new(HELMFILE_GLOB).each do |path_to_helmfile|
    # We load an helmfile asset, but do not intend to run it or collect fixtures
    # this is, unless someone adds a "nonexistent" deployment one day.
    asset = Tester::HelmfileAsset.new(path_to_helmfile, ['nonexistent'])
    next if tasks[:deployments].include?(asset.name)

    asset.collect_charts.each do |chart|
      next unless tasks[:charts].include?(chart)

      tasks[:deployments] << asset.name
    end
  end

  # Now let's check if any file was changed in helmfile.d/admin_ng
  all_changes.each do |changed_file|
    if changed_file.start_with?('helmfile.d/admin_ng')
      tasks[:admin] = true
      break
    end
  end

  # We also need to see if any chart used there is actually changed.
  unless tasks[:admin]
    asset = Tester::AdminAsset.new('helmfile.d/admin_ng/helmfile.yaml', ['nonexistent'])
    asset.collect_charts.each do |chart|
      if tasks[:charts].include?(chart)
        tasks[:admin] = true
        break
      end
    end
  end
  # validate_istio_config checks
  # anything under 'custom_deploy.d/istio/*/config.yaml'
  intersection = FileList.new('custom_deploy.d/istio/*/config.yaml') & all_changes
  tasks[:istio] = !intersection.empty?

  # TODO: also check heuristically for envoy
  Rake::Task[:test_scaffold].invoke if tasks[:scaffold]
  Rake::Task[:check_charts].invoke(nil, tasks[:charts].join('/')) unless tasks[:charts].empty?
  Rake::Task[:check_deployments].invoke(nil, tasks[:deployments].join('/')) unless tasks[:deployments].empty?
  Rake::Task[:check_admin].invoke if tasks[:admin]
  Rake::Task[:validate_envoy_config].invoke if tasks[:envoy]
  Rake::Task[:validate_istio_config].invoke if tasks[:istio]
end

# This is the old default
task all: %i[repo_update test_scaffold check_charts check_deployments check_admin validate_envoy_config validate_istio_config]
task default: %i[check_change]
