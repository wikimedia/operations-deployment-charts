#!/usr/bin/env python3

"""Generate a beta configuration for changeprop based on k8s.

This script generates a configuration file for changeprop based on the template
defined in the WMF deployment-charts repository. The values in values-beta.yaml
are used to override the defaults in the chart.

Helm generates many files for object types when using `helm template`, so we
parse the generated files for only the changeprop config itself.

"""

import argparse
import os
import subprocess

import yaml

CONFIGS = {
    "jobqueue": "values-beta-jobqueue.yaml",
    "changeprop": "values-beta-changeprop.yaml"
}

def parse_args() -> argparse.Namespace:
    """ Parse command line arguments """

    parser = argparse.ArgumentParser(
        description='Generate beta configuration for changeprop in Docker')
    parser.add_argument("helm_chart_path", action="store",
                        help="The path to the changeprop helm chart")
    parser.add_argument("service_name", action="store",
                        help="The service to generate configuration for",
                        choices=["changeprop", "jobqueue"])
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Verbose output")
    args = parser.parse_args()

    return args

def main():
    """ Generate the changeprop configuration file """

    args = parse_args()

    # when we dump our yaml out, this will unroll the anchors used in the
    # generated YAML. Puppet doesn't like literally interpreted anchors in
    # YAML, and PyYAML will mangle the anchor names into id001 etc as is. This
    # makes our config huge, but it's necessary for it to be loaded by puppet.
    yaml.Dumper.ignore_aliases = lambda *args : True

    helm_p = subprocess.Popen(["helm", "template", "-f", CONFIGS[args.service_name],
                               "--show-only", "templates/configmap.yaml", args.helm_chart_path],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = helm_p.communicate()

    if helm_p.returncode:
        print("helm failed:")
        print("stdout: {}".format(stdout))
        print("stderr: {}".format(stderr))
    elif args.verbose:
        print("helm stdout: {}".format(stdout))
        print("helm stderr: {}".format(stderr))

    # note - we load all here as helm puts multiple yaml documents in a
    # file
    configmap = yaml.load_all(stdout)
    for doc in configmap:
        if doc and "data" in doc:
            configdata = doc["data"]["config.yaml"]

    print(configdata)

if __name__ == "__main__":
    main()
