from airflow.providers.fab.auth_manager.security_manager.override import FabAirflowSecurityManagerOverride
from typing import Optional


class CustomSecurityManager(FabAirflowSecurityManagerOverride):
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
