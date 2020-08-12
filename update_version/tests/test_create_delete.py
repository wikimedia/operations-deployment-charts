import os
import uuid

from update_version import update_version


VU = update_version.NewValuesUpdater


def test_creates_new():
    path = "/tmp/" + uuid.uuid4().hex
    vu = VU("", [], "foo", "")

    assert not os.path.isfile(path)

    vu.update_values_version(path)

    assert os.path.isfile(path)
    os.remove(path)


def test_deletes_empty():
    path = "/tmp/" + uuid.uuid4().hex
    vu = VU("", [], "foo", "")

    open(path, 'x').close()
    vu.delete_values_version(path)

    assert not os.path.isfile(path)
