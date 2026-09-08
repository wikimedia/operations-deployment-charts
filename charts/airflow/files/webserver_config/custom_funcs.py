import os
import logging

from airflow.utils.email import send_email_smtp

log = logging.getLogger(__name__)


def get_scheduler_service_name():
    """Function used by the webserver to return the scheduler internal service name"""
    return os.environ["AIRFLOW_SCHEDULER_HOSTNAME"]


def send_email_smtp_dry_run(*args, **kwargs):
    kwargs["dryrun"] = True
    log.info(f"[DRY RUN] send_email_smtp, kwargs={kwargs}")
    return send_email_smtp(*args, **kwargs)
