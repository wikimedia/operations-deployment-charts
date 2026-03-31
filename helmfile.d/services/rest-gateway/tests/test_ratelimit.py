#!/usr/bin/env python3
import argparse
import sys
import os
import unittest
import datetime

from smokepy.http import *
from smokepy import env
from smokepy import values

import jwtools
import helpers

def getRateLimits(rlc, policies = None):
    try:
        policies = env.values.main_app.ratelimiter.default_policies if policies is None else policies

        if not policies:
            return None

        minLimits = {}
        for p in policies:
            pLimits = env.values.main_app.ratelimiter.policies[p].limits[rlc]
            for k in pLimits:
                minLimits[k] = pLimits[k] if k not in minLimits or pLimits[k] < minLimits[k] else minLimits[k]
        return values.Values(minLimits)
    except TypeError:
        pass
    except AttributeError:
        pass

    assert False, """cannot access values: main_app.ratelimiter...
    You may have to use --values or $SMOKEPY_VALUE_FILES to specify the appropriate value files."""

class RateLimitTest(unittest.TestCase):

    target_url = None
    default_endpoint = None
    shadow_endpoint = None
    shadow_policy_name = None
    probe_config = None
    uses_fake_backend = False

    @classmethod
    def setUpClass(cls):
        cls.probe_config = env.values.get("smokepy.gateway")
        cls.target_url = helpers.getTargetUrl(cls.probe_config)
        helpers.checkHealthz(cls.target_url)

        cls.uses_fake_backend = env.values.main_app.http_https_echo

        cls.default_endpoint = cls.probe_config.default_policy_endpoint
        cls.shadow_endpoint = cls.probe_config.shadow_policy_endpoint

        print(f"Running ratelimit tests on {cls.target_url}")
        print(f"    rate limited endpoint: {cls.default_endpoint}")
        print(f"    shadow mode endpoint:  {cls.shadow_endpoint}")

    def setUp(self):
        self.target = helpers.makeHttpTarget(self.target_url, self.probe_config)

    def assert_rate_limit_counts( self, path, allowed, assertions, headers = None, debug = None):
        # Try three times as many requests as allowed.
        # At most twice as many requests as allowed can pass (when crossing a window boundary).
        # At least the last two requests must fail, assuming the requests can be performed within
        # the span of one window (so in at most two windows).
        n = allowed*2 + 2
        predicates = {
            "429": Predicates.has_status(429),
            "x-ratelimit-remaining": Predicates.has_header("x-ratelimit-remaining"),
            "x-wmf-ratelimit-class": Predicates.has_header("x-wmf-ratelimit-class"),
            "retry-after": Predicates.has_header("retry-after"),
            "notice": Predicates.body_contains("bot-traffic@wikimedia.org")
        }

        counts = self.target.count_get(path, n=n, predicates = predicates, headers = headers, debug = debug )

        countErrors = counts.get("error", 0)
        self.assertEqual( countErrors, 0, "expected no connection errors" )

        for assertion in assertions:
            assertion(allowed, n, counts)

    def assert_rate_limit_enforced( self, path, allowed, headers = None, debug = None):
        def assert_ratelimit_headers(allowed, submitted, counts):
            xrl_count = counts.get("x-ratelimit-remaining", 0)
            if env.values.main_app.ratelimiter.enable_x_ratelimit_headers:
                self.assertEqual( xrl_count, submitted, "expected all responses to contain an x-ratelimit-remaining header")
            else:
                self.assertEqual( xrl_count, 0, "expected no response to contain an x-ratelimit-remaining header")

            rlc_count = counts.get("x-wmf-ratelimit-class", 0)
            self.assertEqual( rlc_count, submitted, "expected all responses to contain an x-wmf-ratelimit-class header")

        def assert_good_response(allowed, submitted, counts):
            count_2xx = counts.get("2xx", 0)
            self.assertGreaterEqual( count_2xx, allowed, f"expected at least {allowed} requests to be allowed")
            self.assertLessEqual( count_2xx, allowed*2, f"expected at most {allowed*2} requests to be allowed")

        def assert_denied_responses(allowed, submitted, counts):
            count_2xx = counts.get("2xx", 0)
            count_429 = counts.get("429", 0)
            ra_count = counts.get("retry-after", 0)
            notice_count = counts.get("notice", 0)

            self.assertEqual( count_429, submitted - count_2xx, "expected requests to be denied using status 429")
            self.assertEqual( ra_count, count_429, "expected all requests with status 429 to have a retry-after header")
            self.assertEqual( notice_count, count_429, "expected all requests with status 429 to contain the notice")

        assertions = (assert_ratelimit_headers, assert_good_response, assert_denied_responses)
        self.assert_rate_limit_counts(path, allowed, assertions, headers, debug)

    def assert_rate_limit_bypassed( self, path, allowed, headers = None, debug = None):
        def assert_no_denied_responses(allowed, submitted, counts):
            self.assertEqual( counts.get("429", 0), 0, "expected no request to be denied")
            self.assertEqual( counts.get("2xx", 0), submitted, "expected all requests to be allowed")

        def assert_no_ratelimit_headers(allowed, submitted, counts):
            count_headers = counts.get("x-ratelimit-remaining", 0)
            self.assertEqual(  count_headers, 0, "expected no response to contain an x-ratelimit-remaining header")

        assertions = (assert_no_denied_responses, assert_no_ratelimit_headers)
        self.assert_rate_limit_counts(path, allowed, assertions, headers, debug)

    def assert_rate_limit_shadowed( self, path, allowed, headers = None, debug = None):
        def assert_no_denied_responses(allowed, submitted, counts):
            self.assertEqual( counts.get("429", 0), 0, "expected no request to be denied")
            self.assertEqual( counts.get("2xx", 0), submitted, "expected all requests to be allowed")

        def assert_ratelimit_headers(allowed, submitted, counts):
            xrl_count = counts.get("x-ratelimit-remaining", 0)
            if env.values.main_app.ratelimiter.enable_x_ratelimit_headers:
                self.assertEqual( xrl_count, submitted, "expected all responses to contain an x-ratelimit-remaining header")
            else:
                self.assertEqual( xrl_count, 0, "expected no response to contain an x-ratelimit-remaining header")

            rlc_count = counts.get("x-wmf-ratelimit-class", 0)
            self.assertEqual( rlc_count, submitted, "expected all responses to contain an x-wmf-ratelimit-class header")

        assertions = (assert_no_denied_responses, assert_ratelimit_headers)
        self.assert_rate_limit_counts(path, allowed, assertions, headers, debug)

    def test_anon_limit(self):
        headers = { "x-client-ip": env.nextIp() }
        limits = getRateLimits("anon")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers )

        # Try again with a different IP, to check that it is used as the rate limit key.
        headers = {
            "x-client-ip": env.nextIp(),
        }
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

        # Make an additional request, with the origin header set, and check that we get CORS headers.
        # NOTE: this may flake out due to a race condition
        headers["origin"] = "http://just.a.test"
        resp = self.target.get(self.default_endpoint, headers = headers)
        self.assertEqual(429, resp.status, "expected rate limit to be exceeded by previous test (race condition?)")
        self.assertEqual("http://just.a.test", resp.headers.get("Access-Control-Allow-Origin"), "Access-Control-Allow-Origin")
        self.assertEqual("true", resp.headers.get("Access-Control-Allow-Credentials"), "Access-Control-Allow-Credentials")
        self.assertIn("Retry-After,WWW-Authenticate", resp.headers.get("Access-Control-Expose-Headers"), "Access-Control-Expose-Headers")

    def test_local_requests_bypass_limit(self):
        localHeaders = {} # no x-client-ip!
        limits = getRateLimits("anon")
        self.assert_rate_limit_bypassed(self.default_endpoint, limits.MINUTE, headers = localHeaders)

    def test_options_requests_bypass_limit(self):
        headers = {
            "x-client-ip": env.nextIp(),
            ":method": "OPTIONS"
        }
        limits = getRateLimits("anon")
        self.assert_rate_limit_bypassed(self.default_endpoint, limits.MINUTE, headers = headers)

    def test_shadow_policy(self):
        if not self.shadow_endpoint:
            self.skipTest("shadow_endpoint is not set")

        headers = { "x-client-ip": env.nextIp() }
        limits = getRateLimits("anon")
        self.assert_rate_limit_shadowed(self.shadow_endpoint, limits.MINUTE, headers = headers)

    def test_cspreport_exempt(self):
        cspreport_endpoint = "/w/api.php?action=cspreport&format=json"

        headers = { "x-client-ip": env.nextIp() }
        limits = getRateLimits("anon")
        self.assert_rate_limit_bypassed(cspreport_endpoint, limits.MINUTE, headers = headers)

    def test_wikilambda_policy(self):
        host = self.probe_config.get("wikilambda_host")
        if not host:
            self.skipTest("wikilambda_host is not configured")

        wikilambda_query = "/w/api.php?action=query&format=json&list=wikilambdaload_zobjects&formatversion=2&wikilambdaload_zids=Z23&wikilambdaload_language=en"

        headers = {
            "host": host,
            "x-client-ip": env.nextIp(),
        }
        limits = getRateLimits("anon", ["WikiLambda"])
        self.assert_rate_limit_enforced(wikilambda_query, limits.MINUTE, headers = headers)

    def test_setting_headers_allowed_locally(self):
        policy = env.values.main_app.ratelimiter.default_policies[0]

        testing_headers = {
            # no x-client-ip, it's a "local" request
            "x-wmf-user-id": env.nextName("Youser"),
            "x-wmf-ratelimit-class": "anon",
            "x-wmf-ratelimit-policy-1": policy,
        }
        limits = getRateLimits("anon", [ policy ])
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = testing_headers)

    def test_deny_policy(self):
        testing_headers = {
            "x-wmf-user-id": env.nextName("Jane"),
            "x-wmf-ratelimit-class": "anon",
            "x-wmf-ratelimit-policy-1": "DENY",
        }
        self.assert_rate_limit_enforced(self.default_endpoint, 0, headers = testing_headers)

    def test_deny_class(self):
        policy = env.values.main_app.ratelimiter.default_policies[0]

        testing_headers = {
            "x-wmf-user-id": env.nextName("Judy"),
            "x-wmf-ratelimit-class": "DENY",
            "x-wmf-ratelimit-policy-1": policy,
        }
        self.assert_rate_limit_enforced(self.default_endpoint, 0, headers = testing_headers)

    def test_setting_headers_blocked_externally(self):
        policy = env.values.main_app.ratelimiter.default_policies[0]

        testing_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-wmf-user-id": env.nextName("Xyzzy"),
            "x-wmf-ratelimit-class": "approved-bot",
            "x-wmf-ratelimit-policy-1": policy,
        }
        limits = getRateLimits("anon", [ policy ])
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = testing_headers)

    def test_trust_level_A(self):
        request_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "A", # WMF network (WMCS, etc)
            "x-provenance": "client=" + env.nextName("coolbot"), # ignored
            "user-agent": env.nextName("CoolBot/1.0"), # used as key
        }

        limits = getRateLimits("known-network")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = request_headers)

        # try again with a different user-agent, to check that it is used as the rate limit key
        request_headers["user-agent"] = env.nextName("KoolBoot/2.0")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = request_headers)

    def test_trust_level_B(self):
        request_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "B", # known client
            "x-provenance": "client=" + env.nextName("coolbot"), # used as key
            "user-agent": env.nextName("CoolBot/1.0"), # ignored
        }

        limits = getRateLimits("known-client")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = request_headers)

        # try again with a different user-agent, to check that it is used as the rate limit key
        request_headers["x-provenance"] = "client=" + env.nextName("yyy")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = request_headers)

    def test_trust_level_D(self):
        request_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "D", # compliant bot
            "x-ua-contact": env.nextName("bob") + "@acme.test", # compliant bot contact
        }

        limits = getRateLimits("unauthed-bot")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = request_headers)

    def test_anon_class_by_address(self):
        for (ip, cls) in env.values.main_app.ratelimiter.anon_class_by_address.items():
            break # just use the first entry

        request_headers = {
            "x-client-ip": ip + "." + env.nextIp(), # known network range - not a valid IP address, but that doesn't matter
            "x-trusted-request": "E", # generic anon
        }

        limits = getRateLimits(cls)
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = request_headers)

        # try again with a different IP, to check that it is used as the rate limit key
        request_headers["x-client-ip"] = ip + "." + env.nextIp()
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = request_headers)

    def test_trust_level_F(self):
        request_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "F", # suspicious/abusive
        }

        limits = getRateLimits("anon")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = request_headers)

    def test_anon_browsers(self):
        request_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "E", # general fallback
            "x-is-browser": "100", # >= 80 is good (see browser_threshold value)
        }

        limits = getRateLimits("anon-browser")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = request_headers)

    def test_unauthed_mediawiki(self):
        request_headers = {
            "user-agent": "MediaWiki/1.43.1 (https://some.fandom.com) ForeignAPIRepo/2.1", # InstantCommons
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "E", # general fallback
            "x-is-browser": "20", # >= 80 is good (see browser_threshold value)
        }

        limits = getRateLimits("unauthed-mediawiki")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = request_headers)

    def test_bearer_token_limit(self):
        ip = env.nextIp()
        token = jwtools.getValidJwtOrSkip(self)

        headers = { "x-client-ip": ip, "Authorization": "Bearer " + token }

        limits = getRateLimits("authed-user")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

        #if we can,  try again with a different payload, to check that it is used as the rate limit key
        token = jwtools.createJwt(sub = env.nextName("Testorator") )
        if token:
            headers = { "x-client-ip": ip, "Authorization": "Bearer " + token }
            self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

    def test_bearer_token_limit_uses_rlc_claim(self):
        ip = env.nextIp()
        name = env.nextName("Tester")
        token = jwtools.createJwtOrSkip(self,
            sub = name,
            rlc = "known-client" # should be used
        )
        cookie_token = jwtools.createJwtOrSkip(self,
            sub = name,
            rlc = "approved-bot" # should be ignored
        )
        headers = {
            "x-client-ip": ip,
            "Authorization": "Bearer " + token,
            "cookie": "sessionJwt=" + cookie_token
        }

        # should apply known-client limits, not approved-bot limits
        limits = getRateLimits("known-client")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

    def test_centralauthtoken_limit_uses_rlc_claim(self):
        if not self.uses_fake_backend:
            self.skipTest( "Cannot test centralauth token on real backend without logging in" )

        ip = env.nextIp()
        name = env.nextName("Tester")
        token = jwtools.createJwtOrSkip(self,
            sub = name,
            rlc = "known-client"
        )
        headers = {
            "x-client-ip": ip,
            "Authorization": "CentralAuthToken " + token,
        }

        # should apply known-client limits, not approved-bot limits
        limits = getRateLimits("known-client")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

    def test_centralauthtoken_param_limit_uses_rlc_claim(self):
        if not self.uses_fake_backend:
            self.skipTest( "Cannot test centralauth token on real backend without logging in" )

        ip = env.nextIp()
        name = env.nextName("Tester")
        token = jwtools.createJwtOrSkip(self,
            sub = name,
            rlc = "known-client"
        )
        headers = { "x-client-ip": ip, }

        # should apply known-client limits, not approved-bot limits
        limits = getRateLimits("known-client")
        path = helpers.append_params(self.default_endpoint, 'centralauthtoken=' + token )
        self.assert_rate_limit_enforced(path, limits.MINUTE, headers = headers)

    def test_bearer_token_limit_uses_rlc_claim_from_cookie(self):
        ip = env.nextIp()
        name = env.nextName("Tester")
        token = jwtools.createJwtOrSkip(self,
            sub = name,
        )
        cookie_token = jwtools.createJwtOrSkip(self,
            sub = name,
            rlc = "approved-bot" # should be used
        )
        headers = {
            "x-client-ip": ip,
            "Authorization": "Bearer " + token,
            "cookie": "sessionJwt=" + cookie_token
        }

        # should apply approved-bot limits
        limits = getRateLimits("approved-bot")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

    def test_authed_user_limit(self):
        ip = env.nextIp()
        token = jwtools.getValidJwtOrSkip(self)

        headers = {
            "x-client-ip": ip,
            "cookie": "sessionJwt=" + token,
            "x-is-browser": "100", # >= 80 means "browser", but that should be ignored here
        }

        limits = getRateLimits("authed-user") # not a browser
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

    def test_jwt_cookie_limit_uses_rlc_claim(self):
        ip = env.nextIp()
        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            rlc = "approved-bot"
        )
        headers = { "x-client-ip": ip, "cookie": "sessionJwt=" + token }

        # should apply approved-bot limits, not authed-user limits
        limits = getRateLimits("approved-bot")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

    def test_jwt_cookie_no_limit(self):
        ip = env.nextIp()
        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            rlc = "BYPASS" # magic value to bypass rate limiting entirely
        )
        headers = { "x-client-ip": ip, "cookie": "sessionJwt=" + token }

        # should apply no rate limiting at all
        limits = getRateLimits("anon")
        self.assert_rate_limit_bypassed(self.default_endpoint, limits.MINUTE, headers = headers)

    def test_expired_jwt_cookie(self):
        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            exp = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=4)
        )

        request_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "E", # general fallback
            "x-is-browser": "100", # >= 80 is good (see browser_threshold value)
            "cookie": "sessionJwt=" + token
        }

        limits = getRateLimits("anon-browser")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = request_headers)

def main():
    unittest.main()

#############################################
helpers.initEnv()

if __name__ == "__main__":
    main()
