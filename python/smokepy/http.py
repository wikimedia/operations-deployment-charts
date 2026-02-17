# Add HTTP helper imports
import urllib.request
import urllib.error
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
        Perform <n> HTTP GET requests to url and return a response object.
        """

        headers = headers or {}
        debug = debug or []

        url = self.url + path
        headers = { **self.headers, **headers }
        req = urllib.request.Request(url, method="GET", headers = headers )

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

    def mget(self, paths, headers = None, debug = None):
        """
        Perform multiple HTTP GET requests in parallel and returns a list of responses,
        one for each path.
        """

        threads = [None] * len(paths)
        responses = [None] * len(paths)

        def target(p, i):
            responses[i] = self.get(p, headers=headers, debug=debug)

        for i in range(len(paths)):
            threads[i] = threading.Thread(target=target, args=(paths[i], i, ))
            threads[i].start()

        for thread in threads:
            thread.join()

        return responses

    def count_get(self, path, n = 10, predicates = None, headers = None, debug = None):
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

        responses = self.mget([path] * n, headers=headers, debug=debug)

        for resp in responses:
            for key, p in predicates.items():
                if p(resp):
                    counts[key] = counts.get(key, 0) + 1

        return counts
