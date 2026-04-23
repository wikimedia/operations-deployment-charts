# Add HTTP helper imports
import urllib.request
import urllib.error
import urllib.parse
import json
import ssl
import threading

class NonRaisingHTTPErrorProcessor(urllib.request.HTTPErrorProcessor):
    http_response = https_response = lambda self, request, response: response

class Predicates:
    def has_status ( status ):
        return lambda resp: resp.status == status

    def has_status_between ( min, max ):
        return lambda resp: resp.status >= min and resp.status <= max

    def has_header ( header ):
        return lambda resp: resp.headers.get(header) is not None

    def header_is ( header, value ):
        return lambda resp: resp.headers.get(header) == value

    def body_contains ( substring ):
        return lambda resp: substring in resp.body

    def untrue ( predicate ):
        return lambda resp: not predicate(resp)

class Response:
    status = 0
    headers = None
    body = None

CONNECTION_ERROR = -1

class Target:
    def __init__(self, url, headers = None, timeout=5):
        self.url = url
        self.timeout = timeout
        self.headers = {
            "user-agent":  "smokepy/0.1 (dkinzler at wikimedia.org)",
            **( headers or {} )
        }

        # create an opener that accepts invalid certificates and doesn't throw on
        # http errors.
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        self.opener = urllib.request.build_opener(
            NonRaisingHTTPErrorProcessor,
            urllib.request.HTTPSHandler(context=ctx)
        )

    def get(self, path, headers = None, debug = None):
        """
        Perform a HTTP GET requests and return a response object.
        """

        # Hack for overriding the method. Good to use with OPTIONS or HEAD.
        # Don't use this for POST or PUT.
        method = "GET"
        if headers and ":method" in headers:
            method = headers[":method"]
            # make a copy, don't mess with the original!
            headers = { **headers }
            del headers[":method"]

        return self.req(path, method = method, headers = headers )

    def post(self, path, body, headers = None, debug = None):
        """
        Perform a HTTP POST requests and return a response object.
        """

        # make a copy, don't mess with the original!
        headers = { **headers }

        # Hack for overriding the method. Good to use with PUT.
        # Don't use this for GET or HEAD.
        method = "POST"
        if ":method" in headers:
            method = headers[":method"]
            del headers[":method"]

        return self.req(path, method = method, headers = headers )

    def req(self, path, method, body = None, headers = None, debug = None):
        """
        Perform a HTTP requests and return a response object.
        """
        headers = headers or {}
        debug = debug or []

        url = self.url + path
        headers = { **self.headers, **headers }

        # dict-like body, encode!
        if body and hasattr(body, "keys") and hasattr(body, "__getitem__"):
            if headers.get("content-type") == "application/json":
                body = json.dumps(body)
            else:
                body = urllib.parse.urlencode(body)
                headers["content-type"] = "application/x-www-form-urlencoded"

        if body and hasattr(body, 'encode'):
            body = body.encode('utf8')

        req = urllib.request.Request(url, data = body, method=method, headers = headers )

        try:
            with self.opener.open(req, timeout=self.timeout) as handle:
                resp = Response()
                resp.status = handle.status
                resp.headers = handle.headers
                resp.body = handle.read().decode(handle.headers.get_content_charset() or "utf-8")

                if debug and "url" in debug:
                    print("DEBUG: url: ", url)

                if debug and "status" in debug:
                    print("DEBUG: status: ", resp.status)

                if debug and "headers" in debug:
                    print("DEBUG: headers: ", resp.headers)

                if debug and "body" in debug:
                    print("DEBUG: body: ", resp.body)

                return resp
        except (OSError, ConnectionError) as e:
            if debug and "error" in debug:
                print("DEBUG: error: ", e)

            resp = Response()
            resp.status = CONNECTION_ERROR
            resp.headers = {}
            resp.body = f"CONNECTION ERROR: {e}"
            return resp

    def mreq(self, params, headers = None, debug = None):
        """
        Perform multiple HTTP GET requests in parallel and returns a list of responses,
        one for each list of params. Each list of params is passed as positional parameters
        to req().
        """

        threads = [None] * len(params)
        responses = [None] * len(params)

        def target(p, i):
            responses[i] = self.req(*p, headers=headers, debug=debug)

        for i in range(len(params)):
            threads[i] = threading.Thread(target=target, args=(params[i], i, ))
            threads[i].start()

        for thread in threads:
            thread.join()

        return responses

    def count_responses(self, n, path, method, body = None, headers = None, predicates = None, debug = None):
        """
        Perform n HTTP GET requests and return a dict that indicates how often each predicate
        matched a response.
        """
        counts = {}

        predicates = predicates or {}
        predicates["error"] = Predicates.has_status(CONNECTION_ERROR)
        predicates["2xx"] = Predicates.has_status_between(200, 299)
        predicates["3xx"] = Predicates.has_status_between(300, 399)
        predicates["4xx"] = Predicates.has_status_between(400, 499)
        predicates["5xx"] = Predicates.has_status_between(500, 599)

        responses = self.mreq([(path, method, body)] * n, headers=headers, debug=debug)

        for resp in responses:
            for key, p in predicates.items():
                if p(resp):
                    counts[key] = counts.get(key, 0) + 1

        return counts
