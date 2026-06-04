import os
import sys
import yaml
from io import StringIO

class Values:
    def __init__(self, v = None):
        if v is None:
            v = {}

        if isinstance(v, Values):
            v = v.values

        if not isinstance(v, dict):
            raise ValueError( f"Struct values must be given as a dict, got {type(v)}" )

        self.values = v

    def _wrap_value(self, v):
        if isinstance(v, dict):
            return self.__class__(v)
        else:
            return v

    def __getitem__(self, key):
        try:
            return self.__getattr__(key)
        except AttributeError as ex:
            raise KeyError(f"{key} not found") from ex

    def __getattr__(self, key):
        if not key in self.values:
            keys = self.values.keys()
            raise AttributeError(f"{key} not in {keys}")

        return self._wrap_value( self.values[key] )

    def __str__(self):
        return f"Values({self.values})"

    def __iter__(self):
        for key in self.values.keys():
            yield key

    def __contains__(self, key):
        return key in self.values

    def keys(self):
        return self.values.keys()

    def items(self):
        # TODO: wrap dict values?
        return self.values.items()

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

    def update(self, moreValues):
        """
        Merge moreValues into this Values object recursively:
        If both values are dicts, they are merged by key,
        otherwise the old value is replaced by the new value.
        """
        if isinstance(moreValues, Values):
            moreValues = moreValues.values

        if not isinstance(moreValues, dict):
            raise TypeError(f"merge() expects a dict or a Values object, got a {type(moreValues)}")

        self.values = _update_dict(self.values, moreValues)

    def empty(self):
        return len(self.values.keys()) == 0

    def dump(self):
        return yaml.dump(self.values)

    def load_yaml_data(self, data: str):
        with StringIO(data) as s:
            self.update( yaml.safe_load(s) )

    def load_yaml_file(self, path: str):
        if not os.path.isfile(path):
            raise Exception(f"YAML file not found: {path}")

        with open(path, "r") as f:
            values = yaml.safe_load(f)

            if values is None:
                # empty file
                return

            self.update( values )

def _update_dict(a, b):
    if a is None:
        return b
    if b is None:
        return a

    # if both values are dicts, merge recursively
    if isinstance(a, dict) and isinstance(b, dict):
        out = dict(a)  # shallow copy of a
        for k, vb in b.items():
            if k in out:
                out[k] = _update_dict(out[k], vb)
            else:
                out[k] = vb
        return out

    # NOTE: Lists get replaced like scalars, not concatenated. That's how helm does it.

    # different types or scalars: override with b
    return b
