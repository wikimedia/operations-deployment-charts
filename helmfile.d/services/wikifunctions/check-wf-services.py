#!/usr/bin/env python3
"""Deployment verification script for Wikifunctions back-end services.

Add new tests by appending a Test() to TESTS. The checker argument is any
callable that receives the extracted response value and returns True/False,
so you can use eq() for simple equality or write a lambda/function for
anything more complex.

Add new clusters by appending a (label, url) tuple to CLUSTERS.
"""

import json
import sys
import urllib.request
import urllib.error
from dataclasses import dataclass
from typing import Any, Callable, Optional

# ---------------------------------------------------------------------------
# ANSI colors
# ---------------------------------------------------------------------------
RESET  = '\033[0m'
GREEN  = '\033[32m'
YELLOW = '\033[33m'
ORANGE = '\033[91m'
BLUE   = '\033[34m'
WHITE  = '\033[97m'


# ---------------------------------------------------------------------------
# Checker helpers
# ---------------------------------------------------------------------------

def eq(expected: Any) -> Callable[[Any], bool]:
    """Return a checker that passes when the response value equals *expected*."""
    return lambda value: value == expected


# ---------------------------------------------------------------------------
# Test definition
# ---------------------------------------------------------------------------

@dataclass
class Test:
    name: str
    zobject: dict
    checker: Callable[[Any], bool]
    extract: Callable[[Any], Any] = lambda v: v


# ---------------------------------------------------------------------------
# Tests  —  payload and expected result together; add new Test() entries here
# ---------------------------------------------------------------------------

BASIC_ECHO = Test('Basic echo', {
    "Z1K1": "Z7",
    "Z7K1": "Z801",
    "Z801K1": "foo",
}, eq('foo'))

JS_ADD_CALL = Test('JavaScript add', {
    "Z1K1": "Z7",
    "Z7K1": {
        "Z1K1": "Z8",
        "Z8K1": [
            "Z17",
            {
                "Z1K1": "Z17", "Z17K1": "Z6",
                "Z17K2": {"Z1K1": "Z6", "Z6K1": "Z400K1"},
                "Z17K3": {"Z1K1": "Z12", "Z12K1": ["Z11"]},
            },
            {
                "Z1K1": "Z17", "Z17K1": "Z6",
                "Z17K2": {"Z1K1": "Z6", "Z6K1": "Z400K2"},
                "Z17K3": {"Z1K1": "Z12", "Z12K1": ["Z11"]},
            },
        ],
        "Z8K2": "Z1",
        "Z8K3": ["Z20"],
        "Z8K4": [
            "Z14",
            {
                "Z1K1": "Z14",
                "Z14K1": "Z400",
                "Z14K3": {
                    "Z1K1": "Z16",
                    "Z16K1": "Z600",
                    "Z16K2": "function\tZ400(Z400K1,Z400K2)"
                             "{return(parseInt(Z400K1)+parseInt(Z400K2)).toString();}",
                },
            },
        ],
        "Z8K5": "Z400",
    },
    "Z400K1": "15",
    "Z400K2": "18",
}, eq('33'))

PY_ADD_CALL = Test('Python lambda', {
    "Z1K1": "Z7",
    "Z7K1": {
        "Z1K1": "Z8",
        "Z8K1": ["Z17"],
        "Z8K2": "Z1",
        "Z8K3": ["Z20"],
        "Z8K4": [
            "Z14",
            {
                "Z1K1": "Z14",
                "Z14K1": "Z400",
                "Z14K3": {
                    "Z1K1": "Z16",
                    "Z16K1": "Z610",
                    "Z16K2": "Z400=lambda:str(13)",
                },
            },
        ],
        "Z8K5": "Z400",
    },
}, eq('13'))

STRING_JOIN = Test('String join', {
    "Z1K1": "Z7",
    "Z7K1": "Z10000",
    "Z10000K1": "foo",
    "Z10000K2": "bar",
}, eq('foobar'))

LEXEME_ONE = Test('Lexeme fetch', {
    "Z1K1": "Z7",
    "Z7K1": "Z6825",
    "Z6825K1": {"Z1K1": "Z6095", "Z6095K1": "L2"},
}, eq('first'), extract=lambda v: v['Z6005K2']['Z12K1'][1]['Z11K2'])

ERROR_HANDLER = Test('Error handler', {
    "Z1K1": "Z7",
    "Z7K1": "Z828",
    "Z828K1": {"Z1K1": "Z99", "Z99K1": {"Z1K1": "Z9", "Z9K1": "Z4"}},
}, eq('Z4'), extract=lambda v: v['Z2K1']['Z6K1'])

TESTS: list[Test] = [
    BASIC_ECHO,
    JS_ADD_CALL,
    PY_ADD_CALL,
    STRING_JOIN,
    LEXEME_ONE,
    ERROR_HANDLER,
]


# ---------------------------------------------------------------------------
# Clusters  —  add new (label, url) entries here
# ---------------------------------------------------------------------------

CLUSTERS: list[tuple[str, str]] = [
    ('Staging',    'https://wikifunctions.k8s-staging.discovery.wmnet:30443/1/v2/evaluate/'),
    ('Production', 'https://wikifunctions.discovery.wmnet:30443/1/v2/evaluate/'),
]


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

def _timing_color(ms: int) -> str:
    if ms < 100:  return GREEN
    if ms < 500:  return YELLOW
    if ms < 1000: return ORANGE
    return BLUE


def _get_metadata(response: dict, key: str) -> Optional[Any]:
    for item in response.get('Z22K2', {}).get('K1', []):
        if item.get('K1') == key:
            return item.get('K2')
    return None


def run_test(test: Test, cluster_url: str) -> bool:
    print(f' - {test.name:<20}: ', end='', flush=True)

    body = json.dumps({'zobject': test.zobject, 'doValidate': False}).encode()
    req = urllib.request.Request(
        cluster_url, data=body,
        headers={'Content-Type': 'application/json'},
        method='POST',
    )
    try:
        with urllib.request.urlopen(req) as resp:
            response = json.loads(resp.read().decode())
    except urllib.error.URLError as exc:
        print(f'{BLUE}Connection error{RESET}: {exc}')
        return False
    except json.JSONDecodeError as exc:
        print(f'{BLUE}Invalid JSON{RESET}: {exc}')
        return False

    if 'Z22K1' not in response:
        print(f'{BLUE}Failed response{RESET}: {response}')
        return False

    value = test.extract(response.get('Z22K1'))
    passed = test.checker(value)
    color = GREEN if passed else BLUE
    print(f'{color}{json.dumps(value):<10}{RESET}', end=' \u2013 ')

    timing_raw = _get_metadata(response, 'orchestrationDuration')
    if timing_raw is not None:
        timing_ms = int(''.join(c for c in str(timing_raw) if c.isdigit()) or '0')
        print(f'{_timing_color(timing_ms)}{timing_ms}ms{RESET}', end='')

    memory = _get_metadata(response, 'orchestrationMemoryUsage')
    if memory is not None:
        print(f' ~ {memory}', end='')

    print()
    return passed


def main() -> int:
    all_passed = True
    for i, (cluster_name, cluster_url) in enumerate(CLUSTERS):
        if i:
            print()
        print(f'{WHITE}{cluster_name}{RESET} tests:')
        for test in TESTS:
            if not run_test(test, cluster_url):
                all_passed = False
    return 0 if all_passed else 1


if __name__ == '__main__':
    sys.exit(main())
