import os

def get_scheduler_service_name():
    """Function used by the webserver to return the scheduler internal service name"""
    return os.environ['AIRFLOW_SCHEDULER_HOSTNAME']
