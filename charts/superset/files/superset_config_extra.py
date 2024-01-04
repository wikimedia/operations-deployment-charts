# Set environ['REMOTE_USER'] = HTTP_X_REMOTE_USER header.
# Make sure your HTTP proxy that handles athentication
# sets the X-Remote-User header properly.
class RemoteUserMiddleware(object):
    def __init__(self, app):
        self.app = app

    def __call__(self, environ, start_response):
        user = environ.pop("HTTP_X_CAS_UID", None)
        environ["REMOTE_USER"] = user
        return self.app(environ, start_response)


def lookup_password(uri):
    # We strip the password from the URI, as the test database command
    # passes a URI with redacted password,
    # (ex: mysql://research:XXXXXXXXXX@dbstore1009.eqiad.wmnet:3320/wikishared)
    # which does not exist in our password mapping dictionary
    uri = uri.set(password="PASSWORD")
    passwordless_uri = str(uri).replace(":PASSWORD", "")
    return password_mapping.get(passwordless_uri, None)


ADDITIONAL_MIDDLEWARE = [RemoteUserMiddleware]

SQLALCHEMY_CUSTOM_PASSWORD_STORE = lookup_password
