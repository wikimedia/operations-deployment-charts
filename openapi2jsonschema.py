#!/usr/bin/env python3

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This file is:
# Derived from https://github.com/instrumenta/openapi2jsonschema
# Copyright (C) 2017 Gareth Rushgrove
#
# Derived from https://github.com/yannh/kubeconform/
# Copyright (C) 2020 Yann Hamon

import argparse
import json
import os
from pathlib import Path

import yaml


def test_additional_properties():
    for test in iter(
        [
            {
                "input": {"something": {"properties": {}}},
                "expect": {
                    "something": {"properties": {}, "additionalProperties": False}
                },
            },
            {
                "input": {"something": {"somethingelse": {}}},
                "expect": {"something": {"somethingelse": {}}},
            },
        ]
    ):
        assert additional_properties(test["input"]) == test["expect"]


def additional_properties(data, skip=False):
    "This recreates the behaviour of kubectl at https://github.com/kubernetes/kubernetes/blob/225b9119d6a8f03fcbe3cc3d590c261965d928d0/pkg/kubectl/validation/schema.go#L312"
    if isinstance(data, dict):
        if "properties" in data and not skip:
            if "additionalProperties" not in data:
                data["additionalProperties"] = False
        for _, v in data.items():
            additional_properties(v)
    return data


def test_replace_int_or_string():
    for test in iter(
        [
            {
                "input": {"something": {"format": "int-or-string"}},
                "expect": {
                    "something": {"oneOf": [{"type": "string"}, {"type": "integer"}]}
                },
            },
            {
                "input": {"something": {"format": "string"}},
                "expect": {"something": {"format": "string"}},
            },
        ]
    ):
        assert replace_int_or_string(test["input"]) == test["expect"]


def replace_int_or_string(data):
    new = {}
    try:
        for k, v in iter(data.items()):
            new_v = v
            if isinstance(v, dict):
                if "format" in v and v["format"] == "int-or-string":
                    new_v = {"oneOf": [{"type": "string"}, {"type": "integer"}]}
                else:
                    new_v = replace_int_or_string(v)
            elif isinstance(v, list):
                new_v = list()
                for x in v:
                    new_v.append(replace_int_or_string(x))
            else:
                new_v = v
            new[k] = new_v
        return new
    except AttributeError:
        return data


def append_no_duplicates(obj, key, value):
    """
    Given a dictionary, lookup the given key, if it doesn't exist create a new array.
    Then check if the given value already exists in the array, if it doesn't add it.
    """
    if key not in obj:
        obj[key] = []
    if value not in obj[key]:
        obj[key].append(value)


def write_schema_file(args, schema, filename):
    schema = additional_properties(
        schema, skip=not os.getenv("DENY_ROOT_ADDITIONAL_PROPERTIES")
    )
    schema = replace_int_or_string(schema)

    # Dealing with user input here..
    path = args.output / Path(filename)
    with path.open("w") as f:
        json.dump(schema, f, indent=2)

    if args.verbose:
        print("JSON schema written to {path}".format(path=path))


def construct_value(load, node):
    # Handle nodes that start with '='
    # See https://github.com/yaml/pyyaml/issues/89
    if not isinstance(node, yaml.ScalarNode):
        raise yaml.constructor.ConstructorError(
            "while constructing a value",
            node.start_mark,
            "expected a scalar, but found %s" % node.id,
            node.start_mark,
        )
    yield str(node.value)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "crdfiles",
        nargs="+",
        type=argparse.FileType("r"),
        help="CustomResourceDefinition YAML to process",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=lambda p: Path(p).absolute(),
        default=Path(__file__).absolute(),
        help="Write JSON schema files to this directory",
    )
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    for crdFile in args.crdfiles:
        defs = []
        yaml.SafeLoader.add_constructor(u"tag:yaml.org,2002:value", construct_value)
        for y in yaml.load_all(crdFile, Loader=yaml.SafeLoader):
            if y is None:
                continue
            if "items" in y:
                defs.extend(y["items"])
            if "kind" not in y:
                continue
            if y["kind"] != "CustomResourceDefinition":
                continue
            else:
                defs.append(y)

        for y in defs:
            filename_format = os.getenv("FILENAME_FORMAT", "{kind}_{version}")
            filename = ""
            if "spec" in y and "versions" in y["spec"] and y["spec"]["versions"]:
                for version in y["spec"]["versions"]:
                    if "schema" in version and "openAPIV3Schema" in version["schema"]:
                        filename = (
                            filename_format.format(
                                kind=y["spec"]["names"]["kind"],
                                group=y["spec"]["group"].split(".")[0],
                                version=version["name"],
                            ).lower()
                            + ".json"
                        )

                        schema = version["schema"]["openAPIV3Schema"]
                        write_schema_file(args, schema, filename)
                    elif (
                        "validation" in y["spec"]
                        and "openAPIV3Schema" in y["spec"]["validation"]
                    ):
                        filename = (
                            filename_format.format(
                                kind=y["spec"]["names"]["kind"],
                                group=y["spec"]["group"].split(".")[0],
                                version=version["name"],
                            ).lower()
                            + ".json"
                        )

                        schema = y["spec"]["validation"]["openAPIV3Schema"]
                        write_schema_file(args, schema, filename)
            elif (
                "spec" in y
                and "validation" in y["spec"]
                and "openAPIV3Schema" in y["spec"]["validation"]
            ):
                filename = (
                    filename_format.format(
                        kind=y["spec"]["names"]["kind"],
                        group=y["spec"]["group"].split(".")[0],
                        version=y["spec"]["version"],
                    ).lower()
                    + ".json"
                )

                schema = y["spec"]["validation"]["openAPIV3Schema"]
                write_schema_file(args, schema, filename)

    exit(0)
