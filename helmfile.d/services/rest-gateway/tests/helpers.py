"""
Helpers shared between test files.
"""

import os

from smokepy.http import *
from smokepy import env

def getTargetUrl(gateway_probe_config):
    if gateway_probe_config is None:
        raise ValueError("No smokepy.gateway section found! Add it to a value file.")

    target_url = gateway_probe_config.get("target_url")

    tgtvar = os.getenv("GATEWAY_TEST_TARGET_URL")
    if tgtvar is not None and tgtvar != "":
        target_url = tgtvar

    if target_url is None:
        raise ValueError("No value set for smokepy.gateway.target_url! " +
            "Specify one in a value file or set GATEWAY_TEST_TARGET_URL")

    return target_url

def checkHealthz(base_url, path = '/healthz'):
    target = Target(base_url)
    resp = target.get(path)

    if resp.status == -1:
        raise IOError( f"Cannot connect to {base_url}. " +
            "Perhaps the service is not running or port-forwarding needs to be enabled." )

    if resp.status != 200:
        raise IOError( f"Health check failed for {base_url}: " +
            resp.body )

def initEnv():
    default_value_files = [
        # Relevant value files from the service directory need to be specified
        # using the SMOKEPY_VALUE_FILES environment variable.
        "../../../../charts/api-gateway/values.yaml", # chart defaults
    ]

    env.init(__file__, default_value_files)

def append_params(path, params):
    if '?' in path:
        return f"{path}&{params}"
    else:
        return f"{path}?{params}"
