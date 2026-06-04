import os
from io import StringIO

from . import data

class Manifest (data.HelmData):
    """
    A kubernetes manifest structure.
    """

    def selectors(self) -> dict[str, str]:
        selectors = {}

        if 'kind' in self:
            selectors["kind"] = self.kind

        if 'metadata' in self:
            if 'name' in self.metadata:
                selectors['metadata.name'] = self.metadata.name

            if 'labels' in self.metadata:
                for label, value in self.metadata.labels.items():
                    selectors['metadata.labels.'+label] = str(value)

        return selectors

    def get_decoded(self, key):
        """
        Get the value for a key, interpret it as YAML, and load it into a HelmData object.
        Useful for getting YAML config files from a config map.
        """

        helm_data = data.HelmData()

        s = self.get(key)

        if s is None:
            return None

        if isinstance(s, str):
            helm_data.load_yaml_data(s)
            return helm_data
        else:
            return s

class ManifestSet:
    def __init__(self, manifests = None):
        self.manifests = manifests or []

    def __iter__(self):
        return iter(self.manifests)

    def find_all(self, selectors = None):
        """
        Find all manifests that match the given descriptors.
        """
        return ManifestSet(data.find_all(selectors, self.manifests, Manifest))

    def find(self, selectors = None):
        """
        Find a manifests that match the given descriptors (or None).
        """

        all_matches = self.find_all(selectors)

        return all_matches.manifests[0] if len(all_matches.manifests) > 0 else None

    def load_yaml_file(self, path: str):
        if not os.path.isfile(path):
            raise FileNotFoundError(f"YAML file not found: {path}")

        with open(path, "r") as f:
            self.load_yaml_lines(f)

    def load_yaml_data(self, data: str):
        with StringIO(data) as s:
            self.load_yaml_lines(s)

    def load_yaml_lines(self, stream):
        stop = False
        while not stop:
            buffer = ""
            for line in stream:
                line = line.rstrip()

                if line == "...":
                    stop = True
                    break

                if line == "---":
                    if buffer != "":
                        self.load_manifest_data(buffer)
                    break

                buffer += line + "\n"
            else:
                # no breaks, found eof
                stop = True

            if buffer != "":
                self.load_manifest_data(buffer)

    def load_manifest_file(self, path: str):
        manifest = Manifest()
        manifest.load_yaml_file(path)
        self.manifests.append(manifest)

    def load_manifest_data(self, data: str):
        manifest = Manifest()
        manifest.load_yaml_data(data)
        self.manifests.append(manifest)

    def dump(self):
        first = True
        buffer = ""
        for manifest in self.manifests:
            if not first:
                buffer += "---\n"

            first = False
            buffer += manifest.dump()

        return buffer