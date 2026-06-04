from smokepy import values

DEFINED = object()    # any value including None
NOT_NONE = object()   # not None, but can be empty/falsy
NOT_EMPTY = object()  # not empty (must be truthy)

class HelmData (values.Values):
    """
    A HelmData object represents a nested yaml-style structure as used by Helm.
    This can be used to represent the contents of helm value files (Helm input)
    or of kubernetes manifest files (Helm output).
    """

    def _wrap_value(self, v):
        if isinstance(v, dict):
            return HelmData(v)
        else:
            return v

    def get(self, path, default = None):
        """
        Gets the value identified by the path. If the path cannot be found,
        the default value is returned (which is None, if not otherwise specified).
        The path may be specified in several ways:
        In the simplest case, it is just the name of a property of the HelmData.
        But it can also be a list of property names to be resolved
        recursively on a nested structure of dicts and lists. If the path is given
        as a string that contains dots ("."), it is split at the dots to produce a
        list.
        Each path element can be one of the following:
        - A string to be used as a property name on a dict.
        - an integer or numeric string to be used as an index on a list.
        - a key/value pair separated by an equals sign ("=") to be used with find()
          to identify an element in a list.
        """

        if isinstance(path, str):
            path = path.split(".")

        v = self.values
        for i, k in enumerate(path):
            if isinstance(v, list):
                try:
                    if isinstance(k, str):
                        k = _parse_list_key(k)

                    if isinstance(k, dict):
                        v = find(k, v)
                    else:
                        v = v[k]

                    continue
                except (KeyError, TypeError) as ex:
                    raise KeyError( f"Failed to resolve path {path} at step {i} with key {k}: {ex}" )
            else:
                if isinstance(k, dict):
                    raise KeyError( f"Failed to resolve path {path} at step {i} with seletor {k}: expected list to scan, got {type(v)}" )

            try:
                # EAFP: If v is not dict-like, just catch and continue.
                if not k in v:
                    v = default
                    break
            except:
                pass

            try:
                v = v[k]
            except (KeyError, TypeError) as ex:
                raise KeyError( f"Failed to resolve path {path} at step {i}: {ex}" )

        return self._wrap_value(v)

def _parse_list_key(k):
    try:
        return int(k)
    except:
        pass

    try:
        p, v = k.split("=", 1)
        return { p: v }
    except:
        pass

    raise KeyError(f"Invalid list index {k}")

def find_all(selectors: dict | None, data: list, clazz = HelmData):
    """
    Find all structs in the list that match the given selectors.
    The selectors are given as a dict that associate value paths with expected values.
    Value paths used as selector keys must follow the form accepted by HelmData.get().
    If selectors is empty, all objects in data are returned.
    """

    found = []

    for elem in data:
        if isinstance(elem, dict):
            # wrap dict in HelmData
            elem = clazz(elem)

        if isinstance(elem, HelmData) and clazz != HelmData:
            # wrap plain HelmData in subclass
            elem = clazz(elem)

        if not isinstance(elem, clazz):
            # ignore non-structs
            continue

        for k, exp in selectors.items():
            actual = elem.get(k)

            if exp is DEFINED:
                continue

            if exp is NOT_NONE and actual is not None:
                continue

            if exp is NOT_EMPTY and bool(actual):
                continue

            if type(actual) != type(exp):
                break

            if actual != exp:
                break
        else:
            found.append(elem)

    return found

def find(selectors: dict, data: list, clazz = HelmData):
    """
    Find an element in the list that match the given selectors (or None).
    See find_all for details.
    """

    all_matches = find_all( selectors, data, clazz )

    return all_matches[0] if len(all_matches) > 0 else None
