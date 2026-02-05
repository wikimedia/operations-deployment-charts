#!/usr/bin/env python3
import argparse
import sys
import os
import unittest
import datetime

from smokepy.http import *
from smokepy import env

import jwtools

def getRateLimits(rlc):
    try:
        policy = env.values.main_app.ratelimiter.default_policy
        limits = env.values.main_app.ratelimiter.policies[policy][rlc]
        return limits
    except TypeError:
        pass
    except AttributeError:
        pass

    assert False, """cannot access values: main_app.ratelimiter...
    You may have to use --values or $SMOKEPY_VALUE_FILES to specify the appropriate value files."""

class RateLimitTest(unittest.TestCase):

    target_url = None
    default_endpoint = None
    probe_config = None

    def setUpClass():
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

        RateLimitTest.default_endpoint = RateLimitTest.probe_config.probe_path
        print(f"Running tests on {RateLimitTest.target_url}{RateLimitTest.default_endpoint}")

    def setUp(self):
        headers = RateLimitTest.probe_config.get("headers", {})
        self.target = Target(RateLimitTest.target_url, headers = headers)

    def assert_rate_limit_enforced( self, path, allowed, headers = {}, debug = []):
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

        xrlCount = counts.get("x-ratelimit-remaining", 0)
        raCount = counts.get("retry-after", 0)
        noticeCount = counts.get("notice", 0)

        if env.values.main_app.ratelimiter.enable_x_ratelimit_headers:
            self.assertEqual( xrlCount, n, "expected all responses to contain an x-ratelimit-remaining header")
        else:
            self.assertEqual( xrlCount, 0, "expected no response to contain an x-ratelimit-remaining header")

        count2xx = counts.get("2xx", 0)
        self.assertGreaterEqual( count2xx, allowed, f"expected at least {allowed} requests to be allowed")
        self.assertLessEqual( count2xx, allowed*2, f"expected at most {allowed*2} requests to be allowed")

        count429 = counts.get("429", 0)
        self.assertEqual( count429, n - count2xx, f"expected requests to be denied using status 429")
        self.assertEqual( raCount, count429, f"expected all requests with status 429 to have a retry-after header")
        self.assertEqual( noticeCount, count429, f"expected all requests with status 429 to contain the notice")

    def assert_rate_limit_bypassed( self, path, allowed, headers = {}, debug = []):
        # Try three times as many requests as allowed.
        # At most twice as many requests as allowed can pass (when crossing a window boundary).
        # The last third of requests must fail, assuming the requests can be performed within
        # the span of one window (so in at most two windows).
        n = allowed*3
        predicates = {
            "429": Predicates.has_status(429),
            "x-ratelimit-remaining": Predicates.has_header("x-ratelimit-remaining"),
        }

        counts = self.target.count_get(path, n=n, predicates = predicates, headers = headers, debug = debug )

        countErrors = counts.get("error", 0)
        self.assertEqual( countErrors, 0, "expected no connection errors" )

        count429 = counts.get("429", 0)
        self.assertEqual( count429, 0, "expected no request to be denied")

        countHeaders = counts.get("x-ratelimit-remaining", 0)
        self.assertEqual(  countHeaders, 0, "expected no response to contain an x-ratelimit-remaining header")

    def test_anon_limit(self):
        anonHeaders = { "x-client-ip": env.nextIp() }
        limits = getRateLimits("anon")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = anonHeaders )

        # try again with a different IP, to check that it is used as the rate limit key
        anonHeaders = { "x-client-ip": env.nextIp() }
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = anonHeaders)

    def test_coookie_user_limit(self):
        cookie = env.values.main_app.ratelimiter.user_id_cookie

        if cookie is None or cookie == "":
            self.skipTest("user_id_cookie is not set")

        cookieHeaders = {
            "x-client-ip": env.nextIp(),
            "cookie": f"{cookie}=" + env.nextName("Eva"),
        }
        limits = getRateLimits("cookie-user")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = cookieHeaders)

        # try again with a different cookie value, to check that it is used as the rate limit key
        cookieHeaders["cookie"] = f"{cookie}=" + env.nextName("Lea")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = cookieHeaders)

    def test_local_requests_bypass_limit(self):
        localHeaders = {} # no x-client-ip!
        limits = getRateLimits("anon")
        self.assert_rate_limit_bypassed(self.default_endpoint, limits.SECOND, headers = localHeaders)

    def test_setting_headers_allowed_locally(self):
        policy = env.values.main_app.ratelimiter.default_policy

        testingHeaders = {
            # no x-client-ip, it's a "local" request
            "x-wmf-user-id": env.nextName("Youser"),
            "x-wmf-ratelimit-class": "anon",
            "x-wmf-ratelimit-policy": policy,
        }
        limits = getRateLimits("anon")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = testingHeaders)

    def test_setting_headers_blocked_externally(self):
        policy = env.values.main_app.ratelimiter.default_policy

        testingHeaders = {
            "x-client-ip": env.nextIp(), # external request
            "x-wmf-user-id": env.nextName("Xyzzy"),
            "x-wmf-ratelimit-class": "cookie-user",
            "x-wmf-ratelimit-policy": policy,
        }
        limits = getRateLimits("anon")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = testingHeaders)

    def test_trust_level_A(self):
        requestHeaders = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "A", # WMF network (WMCS, etc)
            "x-provenance": "client=" + env.nextName("coolbot"), # ignored
            "user-agent": env.nextName("CoolBot/1.0"), # used as key
        }

        limits = getRateLimits("approved-bot")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = requestHeaders)

        # try again with a different user-agent, to check that it is used as the rate limit key
        requestHeaders["user-agent"] = env.nextName("KoolBoot/2.0")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = requestHeaders)

    def test_trust_level_B(self):
        requestHeaders = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "B", # known client
            "x-provenance": "client=" + env.nextName("coolbot"), # used as key
            "user-agent": env.nextName("CoolBot/1.0"), # ignored
        }

        limits = getRateLimits("known-client")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = requestHeaders)

        # try again with a different user-agent, to check that it is used as the rate limit key
        requestHeaders["x-provenance"] = "client=" + env.nextName("yyy")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = requestHeaders)

    def test_trust_level_D(self):
        requestHeaders = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "D", # compliant bot
            "x-ua-contact": env.nextName("bob") + "@acme.test", # compliant bot contact
        }

        limits = getRateLimits("ua-bot")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = requestHeaders)

    def test_trust_level_F(self):
        requestHeaders = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "F", # suspicious/abusive
        }

        limits = getRateLimits("anon-sus")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = requestHeaders)

    def test_anon_browsers(self):
        requestHeaders = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "E", # general fallback
            "x-is-browser": "100", # >= 80 is good
        }

        limits = getRateLimits("anon-browser")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = requestHeaders)

    def test_bearer_token_limit(self):
        ip = env.nextIp()
        token = jwtools.getValidJwtOrSkip(self)

        anonHeaders = { "x-client-ip": ip, "Authorization": "Bearer " + token }

        limits = getRateLimits("jwt-user")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = anonHeaders)

        #if we can,  try again with a different payload, to check that it is used as the rate limit key
        token = jwtools.createJwt(sub = env.nextName("Testorator") )
        if token:
            headers = { "x-client-ip": ip, "Authorization": "Bearer " + token }
            self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = headers)

    def test_bearer_token_limit_uses_rlc_claim(self):
        ip = env.nextIp()
        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            rlc = "approved-bot"
        )
        headers = { "x-client-ip": ip, "Authorization": "Bearer " + token }

        # should apply approved-bot limits, not jwt-user limits
        limits = getRateLimits("approved-bot")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = headers)

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

        anonHeaders = { "x-client-ip": ip, "cookie": "sessionJwt=" + token }

        limits = getRateLimits("cookie-user")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = anonHeaders)

        # if we can, try again with a different payload, to check that it is used as the rate limit key
        token = jwtools.createJwt(sub = env.nextName("Testorator") )
        if token:
            headers = { "x-client-ip": ip, "cookie": "sessionJwt=" + token }
            self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = headers)

    def test_jwt_cookie_limit_uses_rlc_claim(self):
        ip = env.nextIp()
        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            rlc = "approved-bot"
        )
        headers = { "x-client-ip": ip, "cookie": "sessionJwt=" + token }

        # should apply approved-bot limits, not jwt-user limits
        limits = getRateLimits("approved-bot")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = headers)

    def test_expired_jwt_cookie(self):
        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            exp = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=4)
        )

        requestHeaders = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "E", # general fallback
            "x-is-browser": "100", # >= 80 is good
            "cookie": "sessionJwt=" + token
        }

        limits = getRateLimits("anon-browser")
        self.assert_rate_limit_enforced(self.default_endpoint, limits.SECOND, headers = requestHeaders)

def init():
    default_value_files = [
        "../../../../charts/api-gateway/values.yaml", # chart defaults
        "../values.yaml", # service defaults
    ]

    env.init(__file__, default_value_files)

def main():
    unittest.main()

#############################################
init()

if __name__ == "__main__":
    main()
