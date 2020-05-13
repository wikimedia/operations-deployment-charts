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
import tempfile

import yaml

def parse_args() -> argparse.Namespace:
    """ Parse command line arguments """

    parser = argparse.ArgumentParser(
        description='Generate beta configuration for changeprop in Docker')
    parser.add_argument("helm_chart_path", action="store",
                        help="The path to the changeprop helm chart")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Verbose output")
    args = parser.parse_args()

    return args

def main():
    """ Generate the changeprop configuration file """

    args = parse_args()

    output_dir = tempfile.mkdtemp()

    helm_p = subprocess.Popen(["helm", "template", "-f", "values-beta.yaml",
                               "--output-dir", output_dir, args.helm_chart_path],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = helm_p.communicate()

    if helm_p.returncode:
        print("helm failed:")
        print("stdout: {}".format(stdout))
        print("stderr: {}".format(stderr))
    elif args.verbose:
        print("helm stdout: {}".format(stdout))
        print("helm stderr: {}".format(stderr))

    with open(os.path.join(output_dir, "changeprop",
                           "templates", "configmap.yaml")) as config_f:

        # note - we load all here as helm puts multiple yaml documents in a
        # file
        configmap = yaml.load_all(config_f)
        for doc in configmap:
            if doc and "data" in doc:
                configdata = doc["data"]["config.yaml"]

    if args.verbose:
        print("Config rendered")
        print(configdata)

    output_path = os.path.join(output_dir, "changeprop", "config.yaml")
    with open(output_path, "w") as output_f:
        output_f.write(configdata)
        print("Wrote config to {}".format(output_path))

if __name__ == "__main__":
    main()
