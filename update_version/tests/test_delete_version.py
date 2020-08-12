"""
Make sure the version can be deleted from the yaml
"""

from update_version import update_version


VU = update_version.NewValuesUpdater


def test_deletes_version():
    vu = VU("", [], "bloop", "")
    yaml = """
        main_app:
            version: "foo"
            other: "bar"
    """

    data = vu.load_yaml(yaml)
    vu.delete_version(data)

    assert "version" not in data["main_app"]


def test_deletes_main_app():
    vu = VU("", [], "bloop", "")
    yaml = """
        main_app:
            version: "foo"
        other_thing:
            bar: "baz"
    """

    data = vu.load_yaml(yaml)
    vu.delete_version(data)

    assert "main_app" not in data
    assert "other_thing" in data

    yaml = """
        main_app: {}
        other_thing:
            bar: "baz"
    """

    data = vu.load_yaml(yaml)
    vu.delete_version(data)

    assert "main_app" not in data
    assert "other_thing" in data


def test_deletes_returns_empty():
    vu = VU("", [], "foo", "")
    yaml = """
        main_app:
            version: "bar"
    """

    data = vu.load_yaml(yaml)
    vu.delete_version(data)

    assert data == {}
