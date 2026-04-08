"""
This helper overloads default heruistic for filtering Dags, see
* https://airflow.apache.org/docs/apache-airflow/2.10.5/core-concepts/dags.html#loading-dags
* https://github.com/apache/airflow/blob/e8be1bf8b2260f6dbe64b1f879a8d017a9b77e56/airflow/utils/file.py#L299-L326

It is enabled with core.might_contain_dag_callable = import_helper.focused_import
in airflow.cfg.

When ${AIRFLOW_HOME}/airflowfiter is present and has non-empty and non-comment
strings, airflow will only consider Dags that are in the list.

Valid entries for airflowfilter file are the filenames relative to
core.dags_folder directory.
"""

from __future__ import annotations

import logging
import os
import pathlib
import zipfile

from airflow.configuration import conf  # type: ignore
from airflow.utils.file import might_contain_dag_via_default_heuristic  # type: ignore

log = logging.getLogger(__name__)

AIRFLOW_ROOT = pathlib.Path(os.environ.get("AIRFLOW_HOME", "/"))

DAGS_FOLDER = pathlib.Path(
    conf.get_mandatory_value(
        "core", "DAGS_FOLDER", fallback=AIRFLOW_ROOT.joinpath("dags")
    ),
)

DAGS_FILTER_FILE = AIRFLOW_ROOT.joinpath("airflowfilter")
DAGS_FILTER: set[str] = set()


def _populate_dags_filter() -> None:
    if not DAGS_FILTER_FILE.exists():
        return

    with DAGS_FILTER_FILE.open("r") as f:
        DAGS_FILTER.update(
            line.strip()
            for line in f.read().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        )

    log.info("Filter %s has %s rules", DAGS_FILTER_FILE, DAGS_FILTER)


def _dag_file_allowed(file_path: str, zip_file: zipfile.ZipFile | None = None) -> bool:
    """
    Returns True if there are no filters, or it is shipped as zip,
    or it is not in the correct directory.
    Assumes that the files in the list are relative to the Dags folder.
    """
    if not DAGS_FILTER:
        return True
    if zip_file:
        return True

    try:
        dag_file_path = pathlib.Path(file_path).relative_to(DAGS_FOLDER).as_posix()
    except ValueError:
        log.exception("unable to get relative path for %s, skipped", file_path)
        return True

    result = dag_file_path in DAGS_FILTER
    log.info("Dag file %s is %s", dag_file_path, (result and "allowed" or "skipped"))
    return result


def focused_import(file_path: str, zip_file: zipfile.ZipFile | None = None) -> bool:
    log.debug(
        "focused_import helper called with file_path=%s zip_file=%s",
        file_path,
        zip_file,
    )

    if not _dag_file_allowed(file_path, zip_file):
        return False

    return might_contain_dag_via_default_heuristic(file_path, zip_file)


_populate_dags_filter()
