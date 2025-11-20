#!/usr/bin/env python3
import os
import unittest
import re

from smokepy.http import *
from smokepy import env

class RedioscopeTest(unittest.TestCase):

    target_url = None
    probe_config = None

    def setUpClass():
        RedioscopeTest.probe_config = env.values.get("smokepy.redioscope")

        if RedioscopeTest.probe_config is None:
            raise ValueError("No smokepy.gateway section found! Add it to a value file.")

        RedioscopeTest.target_url = RedioscopeTest.probe_config.get("target_url")

        tgtvar = os.getenv("REDIOSCOPE_TEST_TARGET_URL")
        if tgtvar is not None and vfvar != "":
            RedioscopeTest.target_url = tgtvar

        if RedioscopeTest.target_url is None:
            raise ValueError("No value set for smokepy.gateway.target_url! " +
                "Specify one in a value file or set REDIOSCOPE_TEST_TARGET_URL")

        print(f"Running tests on {RedioscopeTest.target_url}")

    def setUp(self):
        headers = RedioscopeTest.probe_config.get("headers", {})
        self.target = Target(RedioscopeTest.target_url, headers = headers)

    def assertRegexp(self, text, exp):
        self.assertIsNotNone(exp.search(text), f"Expected string to match {exp}" )

    def test_openmetrics_endpoint(self):
        response = self.target.get("/metrics")

        self.assertEqual(response.status, 200)
        self.assertRegexp(response.body, re.compile( r'^# TYPE redioscope_scan_duration', re.MULTILINE ))

def init():
    default_value_files = [
        "../../../../charts/redioscope/values.yaml", # chart defaults
        "../values.yaml", # service defaults
    ]

    env.init(__file__, default_value_files)

def main():
    unittest.main()

#############################################
init()

if __name__ == "__main__":
    main()

