#!/usr/bin/env python3

# Generate a dependency tree SVG off all releases in a helmfile environment.
#
# This script was designed to visualize dependencies in admin_ng environments
# in order to make them easier to debug/understand. It might work as well for
# service helmfiles.
#
# Pipe in the output of `helmfile build` and it will generate a SVG file
# with the dependency tree.
#
# Install the required dependencies with: `pip install dagviz networkx pyyaml`

import sys
import dagviz
import networkx as nx
import yaml
from typing import IO


def main(output: str, input_stream: IO[str] = sys.stdin) -> bool:
    try:
        y = yaml.safe_load(input_stream)
    except KeyboardInterrupt:
        return False

    releases = y["releases"]
    release_names = set(
        [f"{release['namespace']}/{release['name']}" for release in releases]
    )

    G = nx.DiGraph()
    G.add_nodes_from(release_names)

    for release in releases:
        if "needs" not in release:
            continue

        release_name = f"{release['namespace']}/{release['name']}"
        for dep in release["needs"]:
            if dep not in G.nodes:
                print(
                    f"Warning: Dependency '{dep}' for release '{release_name}' not found in releases."
                )
                continue
            G.add_edge(release_name, dep)

    with open(output, "w") as f:
        svg = dagviz.render_svg(G)
        f.write(svg)
    return True


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description=(
            "Generate a dependency tree from helmfile releases (reads YAML from stdin).\n\n"
            "Expects the output of 'helmfile build' (YAML) on stdin.\n\n"
            "Example usage:\n"
            "    helmfile -e <environment> build | ./helmfile-dependency-tree.py tree.svg\n\n"
            "This will generate a dependency tree SVG from the provided helmfile build output."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "output",
        type=str,
        help="Output file for the dependency tree SVG.",
    )
    args = parser.parse_args()
    if main(args.output) is False:
        parser.print_help()
        parser.exit(1)
