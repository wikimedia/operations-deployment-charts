#!/usr/bin/env python3
import unittest

from smokepy import env

import helpers


class ProbesTest(unittest.TestCase):
    """
    Requests each entry of smokepy.gateway.probes and expects status 200.
    The entries are keyed by a name that identifies the check in test output.
    Each entry is a dict with a "path" (relative to smokepy.gateway.target_url)
    and optionally a "host" and "headers". The gateway-level host and headers
    apply to all entries; those of an entry take precedence.
    """

    target_url = None
    probe_config = None
    probes = {}

    @classmethod
    def setUpClass(cls):
        cls.probe_config = env.values.get("smokepy.gateway")
        cls.probes = {}

        if cls.probe_config is not None:
            configured = cls.probe_config.get("probes")
            cls.probes = configured.values if configured else {}

        if not cls.probes:
            raise unittest.SkipTest("smokepy.gateway.probes is empty or not set")

        cls.target_url = helpers.getTargetUrl(cls.probe_config)
        helpers.checkHealthz(cls.target_url)

        print(f"Running probe tests on {cls.target_url}")

    def request_headers(self, entry):
        headers = {}

        gateway_headers = self.probe_config.get("headers")
        if gateway_headers:
            headers.update(gateway_headers.values)

        if self.probe_config.get("host"):
            headers["host"] = self.probe_config.get("host")

        headers.update(entry.get("headers") or {})

        if entry.get("host"):
            headers["host"] = entry["host"]

        return {k.lower(): v for k, v in headers.items()}

    def test_probes_return_200(self):
        """Every configured probe responds with status 200."""
        target = helpers.makeHttpTarget(self.target_url, self.probe_config)

        for name, entry in self.probes.items():
            path = entry["path"]
            host = entry.get("host") or self.probe_config.get("host")

            # Each probe is its own subtest so one failure doesn't hide the others.
            with self.subTest(msg=name, path=path, host=host):
                resp = target.get(path, headers=self.request_headers(entry))
                self.assertEqual(200, resp.status,
                    f"{name}: expected status 200 for {path}, body: {resp.body[:200]}")


helpers.initEnv()

if __name__ == "__main__":
    unittest.main()
