#!/usr/bin/env python3
import argparse
import sys
import os
import unittest
import datetime
from typing import Callable, NamedTuple, Optional

from smokepy.http import *
from smokepy import env
from smokepy import values

import jwtools
import helpers

class RateLimit(NamedTuple):
    # Effective request count allowance for the unit (raw // upfront_cost).
    # Used by count-based assertions.
    allowed: int
    # Raw policy limit as configured (cost-units per unit).
    # Used by cost-based assertions as the budget.
    raw: int
    # Per-request cost charged on the request flow.
    upfront_cost: int

# Predicate label -> count of responses matching that predicate.
ResponseCounts = dict[str, int]

# Classifies a Response (returns True for matches). See smokepy.http.Predicates.
Predicate = Callable[[Response], bool]

# Assertion callback used by assert_rate_limit_counts:
# (allowed, submitted, counts) -> None. Raises on failure.
Assertion = Callable[[int, int, ResponseCounts], None]

def getRateLimits(rlc: str, policies: Optional[list] = None) -> values.Values:
    if rlc == "DENY":
        denyLimits = {
            "SECOND": RateLimit(allowed=0, raw=0, upfront_cost=1),
            "MINUTE": RateLimit(allowed=0, raw=0, upfront_cost=1),
            "HOUR": RateLimit(allowed=0, raw=0, upfront_cost=1),
        }
        return values.Values(denyLimits)

    try:
        policies = env.values.main_app.ratelimiter.default_policies if policies is None else policies

        minLimits = {}
        for p in policies:
            policy = env.values.main_app.ratelimiter.policies[p]
            pLimits = policy.limits[rlc]
            cost = getattr(policy, 'upfront_cost', 1)

            for k in pLimits:
                scaled_lim = pLimits[k] // cost
                if k not in minLimits or scaled_lim < minLimits[k].allowed:
                    minLimits[k] = RateLimit(allowed=scaled_lim, raw=pLimits[k], upfront_cost=cost)

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

    def assert_rate_limit_counts(
        self,
        path: str,
        allowed: int,
        assertions: tuple[Assertion, ...],
        body: Optional[dict] = None,
        extra_predicates: Optional[dict[str, Predicate]] = None,
        headers: Optional[dict[str, str]] = None,
        debug: Optional[list] = None,
        n: Optional[int] = None,
    ) -> None:
        # By default, try allowed*2 + 2 as many requests as allowed:
        # At most twice as many requests as allowed can pass (when crossing a window boundary).
        # At least the last two requests must fail, assuming the requests can be performed within
        # the span of one window (so in at most two windows).
        n = n or ( allowed*2 + 2 )
        predicates = {
            "429": Predicates.has_status(429),
            "x-ratelimit-remaining": Predicates.has_header("x-ratelimit-remaining"),
            "x-wmf-ratelimit-class": Predicates.has_header("x-wmf-ratelimit-class"),
            "retry-after": Predicates.has_header("retry-after"),
            "notice": Predicates.body_contains("bot-traffic@wikimedia.org"),
            **(extra_predicates or {}),
        }

        method = 'POST' if body else 'GET'
        if headers and ':method' in headers:
            method = headers[':method']
            headers = { **headers }
            del headers[':method']

        counts = self.target.count_responses(n, path, method, body, headers = headers, predicates = predicates, debug = debug )

        countErrors = counts.get("error", 0)
        self.assertEqual( countErrors, 0, "expected no connection errors" )

        for assertion in assertions:
            assertion(allowed, n, counts)

    def assert_rate_limit_enforced(self, path: str, limit: str, policies: Optional[list] = None, **kwargs) -> None:
        configured_limits = getRateLimits(limit, policies)
        allowed = configured_limits.MINUTE.allowed

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

        extra_predicates = {
            "correct_ratelimit_class": Predicates.header_is("x-wmf-ratelimit-class", limit),
        }

        def assert_correct_class(allowed, submitted, counts):
            correct_class_count = counts.get("correct_ratelimit_class", 0)

            self.assertEqual( correct_class_count, submitted, "expected all requests to have the correct rate limit class")

        assertions = (assert_ratelimit_headers, assert_good_response, assert_denied_responses)
        self.assert_rate_limit_counts(path, allowed, assertions = assertions, extra_predicates = extra_predicates, **kwargs)

    def assert_cost_limit_enforced(self, path: str, limit: str, policies: Optional[list] = None, **kwargs) -> None:
        configured_limits = getRateLimits(limit, policies)
        allowed = configured_limits.MINUTE.raw
        upfront_cost = configured_limits.MINUTE.upfront_cost

        # Assume each request costs at least the up-front cost, and at most twice that.
        # So the minimum expected number is the 1x allowed limited divided by 2x the up-front cost,
        # and the maximum expected number is 2x the allowed limited divided by 1x the up-front cost.

        min_expected = allowed // (2*upfront_cost)
        max_expected = (2*allowed) // upfront_cost

        if min_expected < 2:
            raise Exception( f"The cost limit ({allowed}) is too close to the up-front cost ({upfront_cost}) for reliable testing")

        # Try so many requests that some must be denied
        n = min_expected + max_expected

        if n > 100:
            raise Exception( f"The cost limit ({allowed}) is so high that we would need to test too many requests({n})")

        def assert_ratelimit_headers(allowed, submitted, counts):
            xrl_count = counts.get("x-ratelimit-remaining", 0)
            if env.values.main_app.ratelimiter.enable_x_ratelimit_headers:
                self.assertEqual( xrl_count, submitted, "expected all responses to contain an x-ratelimit-remaining header")
            else:
                self.assertEqual( xrl_count, 0, "expected no response to contain an x-ratelimit-remaining header")

        def assert_good_response(allowed, submitted, counts):
            count2xx = counts.get("2xx", 0)
            self.assertGreaterEqual( count2xx, min_expected, f"expected at least {min_expected} requests to be allowed")
            self.assertLessEqual( count2xx, max_expected, f"expected at most {max_expected} requests to be allowed")

        def assert_denied_responses(allowed, submitted, counts):
            count2xx = counts.get("2xx", 0)
            count429 = counts.get("429", 0)
            self.assertEqual( count429, n - count2xx, f"expected requests to be denied using status 429")

        assertions = (assert_ratelimit_headers, assert_good_response, assert_denied_responses)
        self.assert_rate_limit_counts(path, allowed, assertions = assertions, n = n, **kwargs)


    def assert_rate_limit_bypassed(self, path: str, limit: str, policies: Optional[list] = None, **kwargs) -> None:
        configured_limits = getRateLimits(limit, policies)
        allowed = configured_limits.MINUTE.allowed

        def assert_no_denied_responses(allowed, submitted, counts):
            self.assertEqual( counts.get("429", 0), 0, "expected no request to be denied")
            self.assertEqual( counts.get("2xx", 0), submitted, "expected all requests to be allowed")

        def assert_no_ratelimit_headers(allowed, submitted, counts):
            count_headers = counts.get("x-ratelimit-remaining", 0)
            self.assertEqual(  count_headers, 0, "expected no response to contain an x-ratelimit-remaining header")

        assertions = (assert_no_denied_responses, assert_no_ratelimit_headers)
        self.assert_rate_limit_counts(path, allowed, assertions = assertions, **kwargs)

    def assert_rate_limit_shadowed(self, path: str, limit: str, policies: Optional[list] = None, **kwargs) -> None:
        configured_limits = getRateLimits(limit, policies)
        allowed = configured_limits.MINUTE.allowed

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
        self.assert_rate_limit_counts(path, allowed, assertions = assertions, **kwargs)

    def test_abstractwiki_policy(self):
        abstractwiki_query = r'/w/api.php?action=abstractwiki_run_fragment&format=json&formatversion=2&abstractwiki_run_fragment_qid=Q188815'
        headers = {
            "x-client-ip": env.nextIp(),
            "host": "abstract.wikipedia.org" # this triggers the different limit
        }

        self.assert_rate_limit_enforced(abstractwiki_query, "anon", policies = ["AbstractWiki"], headers = headers )

    def test_liftwing_policy(self):
        liftwing_host = 'api.wikimedia.org'
        liftwing_path = '/service/lw/inference/v1/models/enwiki-articlequality:predict'
        liftwing_body = {"rev_id": 12345} # body implies POST

        headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "B", # known client
            "x-provenance": "client=" + env.nextName("coolbot"), # used as key
            "host": liftwing_host,
            "content-type": "application/json",
        }

        self.assert_rate_limit_enforced(liftwing_path, "known-client", policies = ["LiftWing"], body = liftwing_body, headers = headers )

    def test_liftwing_deny_anon(self):
        liftwing_host = 'api.wikimedia.org'
        liftwing_path = '/service/lw/inference/v1/models/enwiki-articlequality:predict'
        liftwing_body = {"rev_id": 12345} # body implies POST

        headers = {
            "x-client-ip": env.nextIp(),
            "host": liftwing_host,
            "content-type": "application/json",
        }

        resp = self.target.post(liftwing_path, liftwing_body, headers = headers)
        self.assertEqual(401, resp.status, "expected anon request to be rejected because the rate limit is 0")
        self.assertIn("Bearer", resp.headers.get("WWW-Authenticate"), "WWW-Authenticate")

    def test_anon_limit(self):
        headers = { "x-client-ip": env.nextIp() }
        self.assert_rate_limit_enforced(self.default_endpoint, "anon", headers = headers )

        # Try again with a different IP, to check that it is used as the rate limit key.
        headers = {
            "x-client-ip": env.nextIp(),
        }
        self.assert_rate_limit_enforced(self.default_endpoint, "anon", headers = headers)

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
        self.assert_rate_limit_bypassed(self.default_endpoint, "anon", headers = localHeaders)

    def test_options_requests_bypass_limit(self):
        headers = {
            "x-client-ip": env.nextIp(),
            ":method": "OPTIONS"
        }
        self.assert_rate_limit_bypassed(self.default_endpoint, "anon", headers = headers)

    def test_shadow_policy(self):
        if not self.shadow_endpoint:
            self.skipTest("shadow_endpoint is not set")

        headers = { "x-client-ip": env.nextIp() }
        self.assert_rate_limit_shadowed(self.shadow_endpoint, "anon", headers = headers)

    def test_cspreport_exempt(self):
        cspreport_endpoint = "/w/api.php?action=cspreport&format=json"

        headers = { "x-client-ip": env.nextIp() }
        self.assert_rate_limit_bypassed(cspreport_endpoint, "anon", headers = headers)

    def test_meta_tokens_exempt(self):
        cspreport_endpoint = "/w/api.php?action=query&meta=tokens%7Cuserinfo&format=json"

        headers = { "x-client-ip": env.nextIp() }
        self.assert_rate_limit_bypassed(cspreport_endpoint, "anon", headers = headers)

    def test_setting_headers_allowed_locally(self):
        policy = env.values.main_app.ratelimiter.default_policies[0]

        testing_headers = {
            # no x-client-ip, it's a "local" request
            "x-wmf-user-id": env.nextName("Youser"),
            "x-wmf-ratelimit-class": "anon",
            "x-wmf-ratelimit-policy-1": policy,
            "x-wmf-ratelimit-cost-1": "1",
        }
        self.assert_rate_limit_enforced(self.default_endpoint, "anon",
            policies = [ policy ], headers = testing_headers)

    def test_deny_policy(self):
        testing_headers = {
            "x-wmf-user-id": env.nextName("Jane"),
            "x-wmf-ratelimit-class": "anon",
            "x-wmf-ratelimit-policy-1": "DENY",
            "x-wmf-ratelimit-cost-1": "1",
            "x-wmf-debug-flags": "keep-429-on-zero-limit",
        }
        self.assert_rate_limit_enforced(self.default_endpoint, "DENY", headers = testing_headers)

    def test_deny_class(self):
        policy = env.values.main_app.ratelimiter.default_policies[0]

        testing_headers = {
            "x-wmf-user-id": env.nextName("Judy"),
            "x-wmf-ratelimit-class": "DENY",
            "x-wmf-ratelimit-policy-1": policy,
            "x-wmf-ratelimit-cost-1": "1",
            "x-wmf-debug-flags": "keep-429-on-zero-limit",
        }
        self.assert_rate_limit_enforced(self.default_endpoint, "DENY", headers = testing_headers)

    def test_deny_response(self):
        headers = {
            "x-wmf-user-id": env.nextName("Jane"),
            "x-wmf-ratelimit-class": "anon",
            "x-wmf-ratelimit-policy-1": "DENY",
            "x-wmf-ratelimit-cost-1": "1",
            "x-wmf-debug-flags": "keep-429-on-zero-limit",
            "x-request-id": "12345", # should be looped through to the response body
        }

        resp = self.target.get(self.default_endpoint, headers = headers)
        self.assertEqual(429, resp.status, "expected request to be denied")
        self.assertIn("bot-traffic@wikimedia.org", resp.body, "body contains notice text")
        self.assertIn("12345", resp.body, "body contains request ID")

    def test_setting_headers_blocked_externally(self):
        policy = env.values.main_app.ratelimiter.default_policies[0]

        testing_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-wmf-user-id": env.nextName("Xyzzy"),
            "x-wmf-ratelimit-class": "approved-bot",
            "x-wmf-ratelimit-policy-1": policy,
            "x-wmf-ratelimit-cost-1": "1",
        }
        self.assert_rate_limit_enforced(self.default_endpoint, "anon",
            policies = [ policy ], headers = testing_headers)

    def test_trust_level_A(self):
        request_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "A", # WMF network (WMCS, etc)
            "x-provenance": "client=" + env.nextName("coolbot"), # ignored
            "user-agent": env.nextName("CoolBot/1.0"), # used as key
        }

        self.assert_rate_limit_enforced(self.default_endpoint, "known-network", headers = request_headers)

        # try again with a different user-agent, to check that it is used as the rate limit key
        request_headers["user-agent"] = env.nextName("KoolBoot/2.0")
        self.assert_rate_limit_enforced(self.default_endpoint, "known-network", headers = request_headers)

    def test_trust_level_B(self):
        request_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "B", # known client
            "x-provenance": "client=" + env.nextName("coolbot"), # used as key
            "user-agent": env.nextName("CoolBot/1.0"), # ignored
        }

        self.assert_rate_limit_enforced(self.default_endpoint, "known-client", headers = request_headers)

        # try again with a different user-agent, to check that it is used as the rate limit key
        request_headers["x-provenance"] = "client=" + env.nextName("yyy")
        self.assert_rate_limit_enforced(self.default_endpoint, "known-client", headers = request_headers)

    def test_trust_level_D(self):
        request_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "D", # compliant bot
            "x-ua-contact": env.nextName("bob") + "@acme.test", # compliant bot contact
        }

        self.assert_rate_limit_enforced(self.default_endpoint, "unauthed-bot", headers = request_headers)

    def test_trust_level_F(self):
        request_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "F", # suspicious/abusive
        }

        self.assert_rate_limit_enforced(self.default_endpoint, "anon", headers = request_headers)

    def test_anon_browsers(self):
        request_headers = {
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "E", # general fallback
            "x-is-browser": "100", # >= 80 is good (see browser_threshold value)
        }

        self.assert_rate_limit_enforced(self.default_endpoint, "anon-browser", headers = request_headers)

    def test_anon_app(self):
        """ Test class_overrides for WikipediaApp"""

        request_headers = {
            "user-agent": "WikipediaApp/8.0.0", # WikipediaApp (matched by class_override pattern)
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "E", # general fallback
            "x-is-browser": "100", # The app should be recognized as a browser
        }

        self.assert_rate_limit_enforced(self.default_endpoint, "anon-app", headers = request_headers)

    def test_anon_mediawiki(self):
        """ Test class_overrides for InstantCommons (no contact info)"""

        request_headers = {
            "user-agent": "MediaWiki/1.43.1", # MediaWiki (no contact info)
            "x-client-ip": env.nextIp(), # external request
            "x-trusted-request": "E", # general fallback
            "x-is-browser": "20", # >= 80 is good (see browser_threshold value)
        }

        self.assert_rate_limit_enforced(self.default_endpoint, "anon-mediawiki", headers = request_headers)

    def test_unauthed_mediawiki(self):
        """ Test class_overrides for InstantCommons (with contact info)"""

        request_headers = {
            "user-agent": "MediaWiki/1.43.1 (https://some.fandom.com) ForeignAPIRepo/2.1", # InstantCommons
            "x-client-ip": env.nextIp(), # external request
            "x-ua-contact": "https://some.fandom.com " + env.nextName("Test"), # has contact info
            "x-trusted-request": "D", # good UA
            "x-is-browser": "20", # >= 80 is good (see browser_threshold value)
        }

        self.assert_rate_limit_enforced(self.default_endpoint, "unauthed-mediawiki", headers = request_headers)

    def test_bearer_token_limit(self):
        ip = env.nextIp()
        token = jwtools.getValidJwtOrSkip(self)

        headers = { "x-client-ip": ip, "Authorization": "Bearer " + token }

        self.assert_rate_limit_enforced(self.default_endpoint, "authed-user", headers = headers)

        #if we can,  try again with a different payload, to check that it is used as the rate limit key
        token = jwtools.createJwt(sub = env.nextName("Testorator") )
        if token:
            headers = { "x-client-ip": ip, "Authorization": "Bearer " + token }
            self.assert_rate_limit_enforced(self.default_endpoint, "authed-user", headers = headers)

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

        self.assert_rate_limit_enforced(self.default_endpoint, "known-client", headers = headers)

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
        self.assert_rate_limit_enforced(self.default_endpoint, "known-client", headers = headers)

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
        path = helpers.append_params(self.default_endpoint, 'centralauthtoken=' + token )
        self.assert_rate_limit_enforced(path, "known-client", headers = headers)

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
        self.assert_rate_limit_enforced(self.default_endpoint, "approved-bot", headers = headers)

    def test_authed_user_limit(self):
        ip = env.nextIp()
        token = jwtools.getValidJwtOrSkip(self)

        headers = {
            "x-client-ip": ip,
            "cookie": "sessionJwt=" + token,
            "x-is-browser": "100", # >= 80 means "browser", but that should be ignored here
        }

        self.assert_rate_limit_enforced(self.default_endpoint, "authed-user", headers = headers)

    def test_timelimit_policy(self):
        if not self.probe_config.timelimit_endpoint:
            self.skipTest("timelimit_endpoint is not set")

        anonHeaders = { "x-client-ip": env.nextIp() }
        self.assert_cost_limit_enforced(self.probe_config.timelimit_endpoint, "anon",
                                        headers = anonHeaders, policies = ["ParseCost"])

    def test_jwt_cookie_limit_uses_rlc_claim(self):
        ip = env.nextIp()
        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            rlc = "approved-bot"
        )
        headers = { "x-client-ip": ip, "cookie": "sessionJwt=" + token }

        # should apply approved-bot limits, not authed-user limits
        self.assert_rate_limit_enforced(self.default_endpoint, "approved-bot", headers = headers)

    def test_jwt_cookie_no_limit(self):
        ip = env.nextIp()
        token = jwtools.createJwtOrSkip(self,
            sub = env.nextName("Tester"),
            rlc = "BYPASS" # magic value to bypass rate limiting entirely
        )
        headers = { "x-client-ip": ip, "cookie": "sessionJwt=" + token }

        # should apply no rate limiting at all
        self.assert_rate_limit_bypassed(self.default_endpoint, "anon", headers = headers)

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

        self.assert_rate_limit_enforced(self.default_endpoint, "anon-browser", headers = request_headers)

def main():
    unittest.main()

#############################################
helpers.initEnv()

if __name__ == "__main__":
    main()
