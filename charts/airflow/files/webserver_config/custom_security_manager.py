import airflow
from typing import Optional

from airflow.providers.fab.auth_manager.security_manager.override import \
    FabAirflowSecurityManagerOverride

IS_AIRFLOW_V3 = airflow.__version__.startswith("3.")

if IS_AIRFLOW_V3:
    import jwt
    import logging

    from airflow.providers.fab.auth_manager.views.auth_oauth import \
        CustomAuthOAuthView as AirflowCustomAuthOAuthView
    from flask import flash, g, redirect, request, session, url_for
    from flask_appbuilder import expose
    from flask_appbuilder._compat import as_unicode
    from flask_appbuilder.security.utils import generate_random_string

    log = logging.getLogger(__name__)

    class CustomAuthOAuthView(AirflowCustomAuthOAuthView):
        @expose("/login/")
        @expose("/login/<provider>")
        def login(self, provider=None):
            """
            Modified code from
            https://github.com/dpgaspar/Flask-AppBuilder/blob/v5.2.2/flask_appbuilder/security/views.py#L667

            With our configuration, the redirect is going to
            http://SERVERNAME/auth/oauth-authorized/<provider>

            Adding _scheme="https".
            """
            log.debug("Provider: %s", provider)
            if g.user is not None and g.user.is_authenticated:
                log.debug("Already authenticated %s", g.user)
                return redirect(self.appbuilder.get_url_for_index)

            if provider is None:
                return self.render_template(
                    self.login_template,
                    providers=self.appbuilder.sm.oauth_providers,
                    title=self.title,
                    appbuilder=self.appbuilder,
                )

            log.debug("Going to call authorize for: %s", provider)
            random_state = generate_random_string()
            state = jwt.encode(
                request.args.to_dict(flat=False), random_state, algorithm="HS256"
            )
            session["oauth_state"] = random_state
            try:
                # forcing https here
                redirect_uri = url_for(
                    ".oauth_authorized",
                    provider=provider,
                    _external=True,
                    _scheme="https",
                )
                return self.appbuilder.sm.oauth_remotes[provider].authorize_redirect(
                    redirect_uri=redirect_uri,
                    state=state.decode("ascii") if isinstance(state, bytes) else state,
                )
            except Exception as e:
                log.error("Error on OAuth authorize: %s", e)
                flash(as_unicode(self.invalid_login_message), "warning")
                return redirect(self.appbuilder.get_url_for_index)


class CustomSecurityManager(FabAirflowSecurityManagerOverride):
    if IS_AIRFLOW_V3:
        authoauthview = CustomAuthOAuthView

    def find_user(self, username: Optional[str] = None, email: Optional[str] = None):
        # If the username comes from a kerberos ticket (which happens when a kerberos-authenticated
        # user calls the API) it will suffixed with @WIKIMEDIA, which does not match what we have
        # in database. We simply strip the suffix to get back to the actual username.
        if username and username.endswith("@WIKIMEDIA"):
            username = username.replace("@WIKIMEDIA", "")
        return super().find_user(username=username, email=email)

    def get_oauth_user_info(self, provider: str, response=None) -> dict:
        if provider == "CAS":
            me = self.appbuilder.sm.oauth_remotes[provider].userinfo()
            # Similar to superset
            # We need to make sure that role_keys is a list of strings,
            # as CAS sends back a string in the case of a user belonging
            # to a single role, which breaks the LDAP group to Airflow role
            # mapping. Indeed, in the case of a single string, the mapping
            # method iterates over the characters in that string when it should
            # be iterating over a list of a single string.
            role_keys = me.get("memberOf", [])
            if isinstance(role_keys, str):
                role_keys = [role_keys]

            userinfo = {
                "username": me.get("preferred_username", me["id"]),
                "first_name": me.get("name", me["id"]),
                "email": me.get("email", f"{me['id']}@email.notfound"),
                "role_keys": role_keys,
            }
            return userinfo


SECURITY_MANAGER_CLASS = CustomSecurityManager
