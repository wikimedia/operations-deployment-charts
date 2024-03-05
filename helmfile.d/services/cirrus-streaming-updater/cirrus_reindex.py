#!/usr/bin/python3
# Automates reindex and backfill operations for cirrus clusters
from argparse import ArgumentParser
from dataclasses import dataclass
from datetime import datetime
import json
import os
import shlex
import subprocess
import sys
from textwrap import dedent
import time
from typing import Dict, List, Mapping, Optional, Set


def expanddblist(name: str) -> List[str]:
    return subprocess.check_output(
        ['/usr/local/bin/expanddblist', name]
    ).decode('utf8').split('\n')


def arg_parser() -> ArgumentParser:
    parser = ArgumentParser(description="Cirrus reindexer")
    parser.add_argument('cirrus_cluster', choices=['eqiad', 'codfw', 'cloudelastic'])
    # Provide choices, as otherwise a backfill for an invalid wiki
    # wouldn't fail. It would simply backfill nothing.
    parser.add_argument('wiki', choices=expanddblist('all'), metavar='{dbname}')

    subparsers = parser.add_subparsers(dest="command", help="sub-commands")
    subparsers.required = True

    reindex = subparsers.add_parser("reindex", help="Reindex one wiki")

    backfill = subparsers.add_parser("backfill", help="Backfill one wiki")
    backfill.add_argument('start', type=datetime.fromisoformat)
    backfill.add_argument('end', type=datetime.fromisoformat)

    return parser


@dataclass
class Release:
    namespace: str
    cluster: str
    name: str


def kube_env(release: Release) -> Dict[str, str]:
    return {
        'K8S_CLUSTER': release.cluster,
        'KUBECONFIG': f'/etc/kubernetes/{release.namespace}-{release.cluster}.config',
    }


def debug_print_completed_process(result: subprocess.CompletedProcess) -> None:
    print('Args: ' + ' '.join(shlex.quote(x) for x in result.args))
    print(f'Return Code: {result.returncode}')
    if result.stdout is not None:
        print('--- stdout ---')
        print(result.stdout)
    if result.stderr is not None:
        print('--- stderr --')
        print(result.stderr)


def flink_status(release: Release) -> str:
    """Fetch the status of a flink release from kubernetes"""
    result = subprocess.run([
            'kubectl',
            'get',
            '--selector', f'release={release.name}',
            '-o', 'json',
            'flinkdeployment',
        ],
        capture_output=True,
        env=kube_env(release))

    if result.returncode != 0:
        debug_print_completed_process(result)
        raise Exception('kubectl invocation failed.')
    output = json.loads(result.stdout.decode('utf8'))
    if not output['items']:
        return 'NOT_DEPLOYED'
    if len(output['items']) > 1:
        raise ValueError(f"More than one flinkdeployment for {release}")
    item = output['items'][0]
    # afaik UNKNOWN can only happen very early in the deploy while it's initializing.
    return item['status']['jobStatus'].get('state', 'UNKNOWN')


def wait_for_flink_status(release: Release, allowed: Set[str]) -> str:
    print(f'Waiting for {release}...', end='', flush=True)
    while True:
        status = flink_status(release)
        if status in allowed:
            print('Done', flush=True)
            return status
        time.sleep(10)
        print('.', end='', flush=True)


def reindex(cirrus_cluster: str, wiki: str) -> bool:
    print(f'Starting reindex of {wiki} on the {cirrus_cluster} cluster')
    result = subprocess.run([
            '/usr/local/bin/mwscript',
            'extensions/CirrusSearch/maintenance/UpdateSearchIndexConfig.php',
            '--wiki', wiki,
            '--cluster', cirrus_cluster,
            '--reindexAndRemoveOk',
            '--indexIdentifier', 'now'
        ])
    return result.returncode == 0


def helmfile(
    release: Release,
    *args,
    env: Mapping[str, str] = {},
    **kwargs
) -> subprocess.CompletedProcess:
    return subprocess.run(
        [
            '/usr/bin/helmfile',
            '--environment', release.cluster,
            '--selector', f'name={release.name}',
            '--state-values-set', 'backfill=true',
            *args
        ],
        cwd='/srv/deployment-charts/helmfile.d/services/cirrus-streaming-updater',
        env={
            'PATH': os.environ['PATH'],
            'HELM_CONFIG_HOME': os.environ['HELM_CONFIG_HOME'],
            'HELM_CACHE_HOME': os.environ['HELM_CACHE_HOME'],
            'HELM_DATA_HOME': os.environ['HELM_DATA_HOME'],
            **kube_env(release),
            **env,
        },
        **kwargs)


def require_backfill_not_deployed(release: Release) -> bool:
    # We could accept FINISHED or FAILED here, but if we are expecting
    # those statuses to result in a `helmfile destroy` then our deploy could
    # race with with destroy.
    initial_status = flink_status(release)
    if initial_status == 'NOT_DEPLOYED':
        return True

    print(dedent(f"""
        ERROR: backfill release is already deployed. Cannot backfill.
        Current status is: {initial_status}

        To wait for a still running backfill:

            kube_env {release.namespace} {release.cluster}
            kubectl get -o json --selector release={release.name} flinkdeployment | jq .items[0].status.jobStatus.state'

        To manually destroy the backfill:

            cd /srv/deployment/helmfile.d/services/cirrus-streaming-updater
            kube_env {release.namespace} {release.cluster}
            helmfile -i -e {release.cluster} --selector name={release.name} --state-values-set backfill=true destroy
    """))
    return False


def backfill(release: Release, wiki: str, start: datetime, end: datetime) -> bool:
    print(f'Starting backfill on {wiki} for {start.isoformat()} to {end.isoformat()}')
    if not require_backfill_not_deployed(release):
        return False

    # Format expected by java Instant.parse
    instant_fmt = '%Y-%m-%dT%H:%M:%SZ'
    start_instant = start.strftime(instant_fmt)
    end_instant = end.strftime(instant_fmt)
    app_config = 'app.config_files.app\\.config\\.yaml'
    result = helmfile(
        release,
        'apply',
        '--context', '5',
        '--set', f'{app_config}.kafka-source-start-time={start_instant}',
        '--set', f'{app_config}.kafka-source-end-time={end_instant}',
        '--set', f'{app_config}.wikis={wiki}')
    if result.returncode != 0:
        print('WARNING: Failed to apply backfill release')
        debug_print_completed_process(result)
        return False

    final_status = wait_for_flink_status(release, {'FAILED', 'FINISHED'})
    print(f'Final backfill status: {final_status}')

    result = helmfile(release, 'destroy')
    if result.returncode != 0:
        print('WARNING: Failed to destroy backfill release')
        debug_print_completed_process(result)
        return False

    return final_status == "FINISHED"


def main(
    command: str,
    cirrus_cluster: str,
    wiki: str,
    start: Optional[datetime] = None,
    end: Optional[datetime] = None,
):
    if cirrus_cluster == "cloudelastic":
        release = Release(
            "cirrus-streaming-updater",
            "eqiad",
            "consumer-cloudelastic-backfill")
    else:
        release = Release(
            "cirrus-streaming-updater",
            cirrus_cluster,
            "consumer-search-backfill")

    if not require_backfill_not_deployed(release):
        return 1

    if command == "reindex":
        start = datetime.now()
        success = reindex(cirrus_cluster, wiki)
        end = datetime.now()
        # If reindex fails we still need to backfill, it might
        # have worked on one index and failed the second.
        success &= backfill(release, wiki, start, end)

    elif command == "backfill":
        success = backfill(release, wiki, start, end)

    else:
        raise ValueError(f"Unknown command: {command}")

    return 0 if success else 1


if __name__ == "__main__":
    args = arg_parser().parse_args()
    sys.exit(main(**dict(vars(args))))
