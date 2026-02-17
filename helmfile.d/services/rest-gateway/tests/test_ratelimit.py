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

    @classmethod
    def setUpClass(cls):
        RateLimitTest.probe_config = env.values.get("smokepy.gateway")

        if RateLimitTest.probe_config is None:
            raise ValueError("No smokepy.gateway section found! Add it to a value file.")

        RateLimitTest.target_url = RateLimitTest.probe_config.get("target_url")

        tgtvar = os.getenv("GATEWAY_TEST_TARGET_URL")
        if tgtvar is not None and vfvar != "":
            RateLimitTest.target_url = tgtvar

        if RateLimitTest.target_url is None:
            raise ValueError("No value set for smokepy.gateway.target_url! " +
                "Specify one in a value file or set GATEWAY_TEST_TARGET_URL")

        RateLimitTest.default_endpoint = RateLimitTest.probe_config.default_policy_endpoint
        print(f"Running tests on {RateLimitTest.target_url}{RateLimitTest.default_endpoint}")

        RateLimitTest.shadow_endpoint = RateLimitTest.probe_config.shadow_policy_endpoint

    def setUp(self):
        headers = RateLimitTest.probe_config.get("headers", {})
        self.target = Target(RateLimitTest.target_url, headers = headers)

    def assert_rate_limit_counts( self, path, allowed, assertions, headers = None, debug = None):
        # Try three times as many requests as allowed.
        # At most twice as many requests as allowed can pass (when crossing a window boundary).
        # The last third of requests must fail, assuming the requests can be performed within
        # the span of one window (so in at most two windows).
        n = allowed*3
        predicates = {
            "429": Predicates.has_status(429),
            "x-ratelimit-remaining": Predicates.has_header("x-ratelimit-remaining"),
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

        assertions = (assert_no_denied_responses, assert_ratelimit_headers)
        self.assert_rate_limit_counts(path, allowed, assertions, headers, debug)

    def test_anon_limit(self):
        headers = { "x-client-ip": env.nextIp() }
        limits = getRateLimits("anon")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers )

        # try again with a different IP, to check that it is used as the rate limit key
        headers = { "x-client-ip": env.nextIp() }
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

    def test_authed_browser_limit(self):
        cookie = env.values.main_app.ratelimiter.user_id_cookie

        if cookie is None or cookie == "":
            self.skipTest("user_id_cookie is not set")

        cookieHeaders = {
            "x-client-ip": env.nextIp(),
            "cookie": f"{cookie}=" + env.nextName("Eva"),
            "x-is-browser": "100", # >= 80 is good
        }
        limits = getRateLimits("authed-browser")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = cookieHeaders)

        # try again with a different cookie value, to check that it is used as the rate limit key
        cookieHeaders["cookie"] = f"{cookie}=" + env.nextName("Lea")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = cookieHeaders)

    def test_authed_other_limit(self):
        cookie = env.values.main_app.ratelimiter.user_id_cookie

        if cookie is None or cookie == "":
            self.skipTest("user_id_cookie is not set")

        cookieHeaders = {
            "x-client-ip": env.nextIp(),
            "cookie": f"{cookie}=" + env.nextName("Eva"),
            "x-is-browser": "20", # <= 80 is good
        }
        limits = getRateLimits("authed-other")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = cookieHeaders)

        # try again with a different cookie value, to check that it is used as the rate limit key
        cookieHeaders["cookie"] = f"{cookie}=" + env.nextName("Lea")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = cookieHeaders)

    def test_local_requests_bypass_limit(self):
        localHeaders = {} # no x-client-ip!
        limits = getRateLimits("anon")
        self.assert_rate_limit_bypassed(self.default_endpoint, limits.MINUTE, headers = localHeaders)

    def test_shadow_policy(self):
        if not self.shadow_endpoint:
            self.skipTest("shadow_endpoint is not set")

        headers = { "x-client-ip": env.nextIp() }
        limits = getRateLimits("anon")
        self.assert_rate_limit_shadowed(self.shadow_endpoint, limits.MINUTE, headers = headers)

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
            "x-is-browser": "100", # >= 80 is good
        }

        limits = getRateLimits("anon-browser")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = request_headers)

    def test_bearer_token_limit(self):
        ip = env.nextIp()
        token = jwtools.getValidJwtOrSkip(self)

        headers = { "x-client-ip": ip, "Authorization": "Bearer " + token }

        limits = getRateLimits("authed-bot")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

        #if we can,  try again with a different payload, to check that it is used as the rate limit key
        token = jwtools.createJwt(sub = env.nextName("Testorator") )
        if token:
            headers = { "x-client-ip": ip, "Authorization": "Bearer " + token }
            self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

    def test_bearer_token_limit_uses_rlc_claim(self):
        ip = env.nextIp()
        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            rlc = "approved-bot"
        )
        headers = { "x-client-ip": ip, "Authorization": "Bearer " + token }

        # should apply approved-bot limits, not authed-bot limits
        limits = getRateLimits("approved-bot")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

    def test_expired_bearer_token(self):
        ip = env.nextIp()
        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            exp = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=4)
        )

        headers = { "x-client-ip": ip, "Authorization": "Bearer " + token }
        rest = self.target.get(self.default_endpoint, headers = headers)
        self.assertEqual(401, rest.status, "expired token should be rejected")

    def test_jwt_cookie_limit(self):
        ip = env.nextIp()
        token = jwtools.getValidJwtOrSkip(self)

        headers = { "x-client-ip": ip, "cookie": "sessionJwt=" + token }

        limits = getRateLimits("authed-other")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

        # if we can, try again with a different payload, to check that it is used as the rate limit key
        token = jwtools.createJwt(sub = env.nextName("Testorator") )
        if token:
            headers = { "x-client-ip": ip, "cookie": "sessionJwt=" + token }
            self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

    def test_jwt_cookie_limit_uses_rlc_claim(self):
        ip = env.nextIp()
        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            rlc = "approved-bot"
        )
        headers = { "x-client-ip": ip, "cookie": "sessionJwt=" + token }

        # should apply approved-bot limits, not authed-bot limits
        limits = getRateLimits("approved-bot")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = headers)

    def test_expired_jwt_cookie(self):
        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            exp = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=4)
        )

        request_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "E", # general fallback
            "x-is-browser": "100", # >= 80 is good
            "cookie": "sessionJwt=" + token
        }

        limits = getRateLimits("anon-browser")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.MINUTE, headers = request_headers)

def init():
    default_value_files = [
        # Relevant value files from the service directory need to be specified
        # using the SMOKEPY_VALUE_FILES environment variable.
        "../../../../charts/api-gateway/values.yaml", # chart defaults
    ]

    env.init(__file__, default_value_files)

def main():
    unittest.main()

#############################################
init()

if __name__ == "__main__":
    main()
