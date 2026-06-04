import os
import jwt
import datetime
import base64

from smokepy import env

def getValidJwtOrSkip(test):
    token = getValidJwt()
    if token is None:
        test.skipTest(
            "No valid token available: no smokepy.valid_token value or $SMOKEPY_VALID_JWT variable, " +
            "and main_app.jwks.type is not OCT."
        )
    return token

def createJwtOrSkip(test, **payload):
    token = createJwt(**payload)
    if token is None:
        test.skipTest(
            "main_app.jwks.type is not OCT, cannot generate token for testing"
        )
    return token

def getValidJwt():
    if env.values.smokepy.valid_jwt:
        return env.values.smokepy.valid_jwt
    jwtvar = os.getenv("SMOKEPY_VALID_JWT")
    if jwtvar is not None and jwtvar != "":
        return jwtvar
    return createJwt()

def createJwt(**payload):
    if env.values.main_app.jwks.type is None or env.values.main_app.jwks.type != "OCT":
        return None
    default_payload = {
        "sub": env.nextName("Tester"),
        "ratelimit": {"requests_per_unit":5000, "unit":"HOUR"}, # should be ignored
        "scopes": ["basic", "createeditmovepage"], # unused
        "iss": env.values.main_app.jwt.issuer,
        "iat": datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=8),
        "exp": datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=4),
    }
    payload = { **default_payload, **payload}
    secret = base64.b64decode( env.values.main_app.jwks.key )
    return jwt.encode(payload, secret, algorithm="HS256")