#!/usr/bin/env python3

import argparse
import io
import os

import ruamel.yaml


BASE_PATH = os.path.dirname(__file__)
VALUES_ROOT = os.path.abspath(
    os.path.join(
        BASE_PATH,
        '..',
        'helmfile.d',
        'services'
    )
)

VALID_ENVS = ['staging', 'codfw', 'eqiad']


def parse_args():
    """Parses and returns the arguments."""

    ap = argparse.ArgumentParser()
    ap.add_argument(
        '-s', '--service',
        help='The name of the service to update values for',
        required=True
    )
    ap.add_argument(
        '-v', '--version',
        help='The version of the image to use',
        required=True
    )
    ap.add_argument(
        '-e', '--envs',
        help='The environments to update values for',
        choices=VALID_ENVS,
        action='append',
        default=None
    )

    args = ap.parse_args()

    if args.envs is None:
        args.envs = VALID_ENVS

    return args


class ValuesUpdater:
    def __init__(self, service, envs, version, path):
        self.service = service
        self.envs = envs
        self.version = version
        self.dir_path = path

    def load_file(self, path):
        """Loads a file and returns it"""

        return open(path, 'r+')

    @staticmethod
    def load_yaml(file):
        """Loads yaml from a file or returns an empty object."""

        try:
            data = ruamel.yaml.load(
                file,
                ruamel.yaml.RoundTripLoader,
                preserve_quotes=True
            )
        except io.UnsupportedOperation:
            print(
                """Warning: Could not load yaml from file.
                This could be due to the file being empty.
                Returning empty object
                """
            )
            data = {}
        finally:
            return data

    @staticmethod
    def dump_yaml(data, file):
        """Dumps yaml to a file (replacing the contents)."""

        file.seek(0)
        ruamel.yaml.dump(data, file, Dumper=ruamel.yaml.RoundTripDumper)
        file.truncate()

    def update_version(self, data):
        """Updates the main_app.version in a dictionary."""

        if "main_app" in data:
            data["main_app"]["version"] = self.version
        else:
            data["main_app"] = {
                "version": self.version
            }

    def update_values_version(self, path):
        """Updates the image version in a values file.
        """

        f = self.load_file(path)

        data = self.load_yaml(f)
        self.update_version(data)
        self.dump_yaml(data, f)

        f.close()

    def update(self):
        """Updates the image version in the values file for each environment.
        """
        for env in self.envs:
            path = "{}/{}/{}/values.yaml".format(self.dir_path, env, self.service)
            self.update_values_version(path)


class NewValuesUpdater(ValuesUpdater):
    def update(self):
        """Updates the image versions in the values files for each environment,
            or deletes it and updates the default values file, based on whether
            all environments are to be updated or not.
        """
        if set(self.envs) == set(VALID_ENVS):
            # updating all envs / default values
            self.update_values_version("{}/values.yaml".format(self.dir_path))

            for env in self.envs:
                path = "{}/values-{}.yaml".format(self.dir_path, env)
                self.delete_values_version(path)
        else:
            # specific environments only
            for env in self.envs:
                path = "{}/values-{}.yaml".format(self.dir_path, env)
                self.update_values_version(path)

    def update_values_version(self, path):
        """Updates the image version in a values file.
            Creates the file when it doesn't exist.
        """

        if os.path.isfile(path):
            f = self.load_file(path)
            data = self.load_yaml(f)
        else:
            f = open(path, 'x')
            data = {}

        self.update_version(data)
        self.dump_yaml(data, f)
        f.close()

    @staticmethod
    def delete_version(data):
        """Deletes the main_app.version from a dictionary."""

        if data and "main_app" in data:
            data["main_app"].pop('version', None)
            if not data["main_app"]:
                data.pop('main_app', None)

    def delete_values_version(self, path):
        """Deletes the image version in a values file, if it exists.
            Deletes the file if it has no more content.
        """

        delete_file = False

        if os.path.isfile(path):
            f = self.load_file(path)
            data = self.load_yaml(f)
            self.delete_version(data)

            if not data:
                delete_file = True
            else:
                self.dump_yaml(data, f)

            f.close()

        if delete_file:
            os.remove(path)


def main():
    args = parse_args()
    envs = args.envs
    service = args.service
    version = args.version
    dir_path = "{}/{}".format(VALUES_ROOT, service)

    if os.path.isdir(dir_path):
        # new directory structure
        vu = NewValuesUpdater(service, envs, version, dir_path)
    else:
        # old directory structure
        vu = ValuesUpdater(service, envs, version, VALUES_ROOT)

    vu.update()


if __name__ == '__main__':
    main()
