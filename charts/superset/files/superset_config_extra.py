def lookup_password(uri):
    # We strip the password from the URI, as the test database command
    # passes a URI with redacted password,
    # (ex: mysql://research:XXXXXXXXXX@dbstore1009.eqiad.wmnet:3320/wikishared)
    # which does not exist in our password mapping dictionary
    uri = uri.set(password="PASSWORD")
    passwordless_uri = str(uri).replace(":PASSWORD", "")
    return password_mapping.get(passwordless_uri, None)


SQLALCHEMY_CUSTOM_PASSWORD_STORE = lookup_password
