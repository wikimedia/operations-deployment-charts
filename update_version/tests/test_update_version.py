"""
Make sure the version can be updated in the yaml
"""

from update_version import update_version


VU = update_version.ValuesUpdater


def test_updates_version():
    vu = VU("", [], "baz", "")
    yaml = """
        main_app:
            version: "foo"
            blah: "boop"
        other_thing: "bar"
    """

    data = vu.load_yaml(yaml)
    vu.update_version(data)

    assert data["main_app"]["version"] == "baz"
    assert "blah" in data["main_app"]
    assert "other_thing" in data


def test_adds_version():
    vu = VU("", [], "foo", "")
    yaml = """
        main_app:
            blah: "bloop"
    """

    data = vu.load_yaml(yaml)
    vu.update_version(data)

    assert data["main_app"]["version"] == "foo"


def test_adds_main_app():
    vu = VU("", [], "foo", "")
    yaml = "{}"

    data = vu.load_yaml(yaml)
    vu.update_version(data)

    assert data["main_app"]["version"] == "foo"
