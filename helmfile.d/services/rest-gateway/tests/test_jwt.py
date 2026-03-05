#!/usr/bin/env python3
import unittest
import datetime

from smokepy.http import *
from smokepy import env
from smokepy import values

import jwtools
import helpers

class JwtTest(unittest.TestCase):

    target_url = None
    default_endpoint = None
    jwt_exempt_endpoint = None
    jwt_required_endpoint = None
    probe_config = None

    @classmethod
    def setUpClass(cls):
        JwtTest.probe_config = env.values.get("smokepy.gateway")
        JwtTest.target_url = helpers.getTargetUrl(JwtTest.probe_config)
        helpers.checkHealthz(JwtTest.target_url)

        JwtTest.default_endpoint = JwtTest.probe_config.default_policy_endpoint
        JwtTest.jwt_exempt_endpoint = JwtTest.probe_config.jwt_exempt_endpoint
        JwtTest.jwt_required_endpoint = JwtTest.probe_config.jwt_required_endpoint

        print(f"Running JWT tests on {JwtTest.target_url}")
        print(f"    standard endpoint: {JwtTest.default_endpoint}")
        print(f"    exempt endpoint:   {JwtTest.jwt_exempt_endpoint}")
        print(f"    strict endpoint:   {JwtTest.jwt_required_endpoint}")

        if not JwtTest.default_endpoint:
            raise ValueError("default_policy_endpoint is not configured")
        if not JwtTest.jwt_exempt_endpoint:
            raise ValueError("jwt_exempt_endpoint is not configured")
        if not JwtTest.jwt_required_endpoint:
            raise ValueError("jwt_required_endpoint is not configured")

    def setUp(self):
        headers = JwtTest.probe_config.get("headers", {})
        self.target = Target(JwtTest.target_url, headers = headers)

    ###################################################################################
    ## Most endpoints don't require tokens but require bearer tokens to be valid.
    ###################################################################################
    def test_no_token_needed(self):
        """Assert that normal endpoints don't require a JWT."""

        headers = { "x-client-ip": env.nextIp(), }
        rest = self.target.get(self.default_endpoint, headers = headers)
        self.assertEqual(rest.status, 200, "no token should be needed")

    def test_expired_token_rejected(self):
        """Assert that normal endpoints reject an expired bearer token."""

        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            exp = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=4)
        )

        headers = { "x-client-ip": env.nextIp(), "Authorization": "Bearer " + token }
        resp = self.target.get(self.default_endpoint, headers = headers)

        # See RFC 6750 section 3
        self.assertEqual(401, resp.status, "expired token should be rejected")
        self.assertIn('www-authenticate', resp.headers, "response should have www-authenticate header")
        self.assertIn('error="invalid_token"', resp.headers['www-authenticate'], "www-authenticate header should contain 'invalid_token' error")

    def test_expired_cookie_allowed(self):
        """Assert that normal endpoints allow an expired JWT cookie."""

        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            exp = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=4)
        )

        headers = { "x-client-ip": env.nextIp(), "cookie": "sessionJwt=" + token }
        rest = self.target.get(self.default_endpoint, headers = headers)
        self.assertEqual(rest.status, 200, "expired cookie should be allowed")

    ###################################################################################
    ## Some endpoints require a valid token
    ###################################################################################
    def test_token_required(self):
        """ Assert that certain endpoints require a JWT."""

        headers = { "x-client-ip": env.nextIp() }
        rest = self.target.get(self.jwt_required_endpoint, headers = headers)
        self.assertEqual(rest.status, 401, "should require a token")

    def test_token_not_required_for_options(self):
        """ Assert that even endpoints the require a JWT for GET do not require one for OPTIONS."""

        # Note: the :method pseudo-header is handled by the http helper and sets the actual method.
        headers = { "x-client-ip": env.nextIp(), ":method": "OPTIONS" }
        rest = self.target.get(self.jwt_required_endpoint, headers = headers)
        self.assertEqual(rest.status, 200, "OPTIONS request should not require a token")

    def test_valid_token_accepted(self):
        """ Assert that endpoints that require a JWT accept a bearer token."""

        ip = env.nextIp()
        token = jwtools.getValidJwtOrSkip(self)

        headers = { "x-client-ip": ip, "Authorization": "Bearer " + token }
        rest = self.target.get(self.jwt_required_endpoint, headers = headers)
        self.assertEqual(rest.status, 200, "valid token should be accepted")

    def test_valid_cookie_accepted(self):
        """ Assert that endpoints that require a JWT accept a token cookie."""

        ip = env.nextIp()
        token = jwtools.getValidJwtOrSkip(self)

        headers = { "x-client-ip": ip, "Cookie": "sessionJwt=" + token }
        rest = self.target.get(self.jwt_required_endpoint, headers = headers)
        self.assertEqual(rest.status, 200, "valid token should be accepted")

    def test_expired_cookie_rejected(self):
        """ Assert that endpoints that require a JWT reject an expired token cookie."""

        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            exp = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=4)
        )

        headers = { "x-client-ip": env.nextIp(), "cookie": "sessionJwt=" + token }
        rest = self.target.get(self.jwt_required_endpoint, headers = headers)
        self.assertEqual(rest.status, 401, "expired cookie should be rejected")

    ###################################################################################
    ## Some endpoints ignore even invalid tokens (useful for authentication endpoints)
    ###################################################################################
    def test_expired_token_allowed(self):
        """ Assert that are exempt from JWT checks allow expired tokens. """
        ip = env.nextIp()
        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            exp = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=4)
        )

        headers = { "x-client-ip": ip, "Authorization": "Bearer " + token }
        rest = self.target.get(JwtTest.jwt_exempt_endpoint, headers = headers)
        self.assertEqual(rest.status, 200, "expired token should be allowed for this endpoint")

def main():
    unittest.main()

#############################################
helpers.initEnv()

if __name__ == "__main__":
    main()
