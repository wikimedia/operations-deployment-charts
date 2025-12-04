import os
import sys
import yaml

class Values:
    def __init__(self, v = {}):
        self.values = v

    def __getitem__(self, key):
        return self.__getattr__(key)

    def __getattr__(self, key):
        if not key in self.values:
            keys = self.values.keys()
            raise KeyError(f"{key} not in {keys}")

        v = self.values[key]
        if isinstance(v, dict):
            return Values(v)
        else:
            return v

    def __str__(self):
        return f"Values({self.values})"

    def __dict__(self):
        return self.values

    def keys(self):
        return self.values.keys()

    def get(self, key, default = None):
        path = key.split(".", 1)

        v = self.values.get(path[0])

        if v is None:
            v = default

        isdict = isinstance(v, dict)
        if isdict:
            v = Values(v)

        if len(path)>1:
            if not isdict:
                raise ValueError(f"indexing non-dict value {v} or key {path[0]}")

            return v.get(path[1], default)
        else:
            return v

    # Recursive merge: dicts are merged by key, lists are concatenated, scalars are replaced by b
    def merge(self, moreValues: dict):
        self.values = _merge(self.values, moreValues)

    def load_yaml_file(self, path: str):
        if not os.path.isfile(path):
            raise Exception(f"YAML file not found: {path}")

        with open(path, "r") as f:
            self.merge( yaml.safe_load(f) )

def _merge(a, b):
    if a is None:
        return b
    if b is None:
        return a

    # dict + dict => merge keys
    if isinstance(a, dict) and isinstance(b, dict):
        out = dict(a)  # shallow copy of a
        for k, vb in b.items():
            if k in out:
                out[k] = _merge(out[k], vb)
            else:
                out[k] = vb
        return out

    # list + list => concatenate
    if isinstance(a, list) and isinstance(b, list):
        return a + b

    # different types or scalars: override with b
    return b
