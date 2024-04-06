import logging
from typing import Dict

from superset.security import SupersetSecurityManager

logger = logging.getLogger(__name__)


class CustomSsoSecurityManager(SupersetSecurityManager):
    def auth_user_oauth(self, userinfo: Dict):
        """Update the user details if need be.

        This method overrides the auth_user_oauth method detailed at
        https://flask-appbuilder.readthedocs.io/en/latest/_modules/flask_appbuilder/security/manager.html#BaseSecurityManager.auth_user_oauth
        and make sure to update the user with the details provided by the
        OIDC provider (name, username, email).

        """
        user = super().auth_user_oauth(userinfo)
        if user and self.auth_user_registration:
            user.first_name = userinfo["name"]
            user.username = userinfo["username"]
            user.email = userinfo["email"]
            self.update_user_auth_stat(user)
        return user

    def oauth_user_info(self, provider: str, response=None) -> Dict:
        if provider == "CAS":
            me = self.appbuilder.sm.oauth_remotes[provider].userinfo()

            # We need to make sure that role_keys is a list of strings,
            # as CAS sends back a string in the case of a user belonging
            # to a single role, which breaks the LDAP group to Superset role
            # mapping. Indeed, in the case of a single string, the mapping
            # method iterates over the characters in that string when it should
            # be iterating over a list of a single string.
            role_keys = me.get("memberOf", [])
            if isinstance(role_keys, str):
                role_keys = [role_keys]

            userinfo = {
                "id": me["id"],
                "username": me.get("preferred_username", me["id"]),
                "name": me.get("name", me["id"]),
                "email": me.get("email", f"{me['id']}@email.notfound"),
                "role_keys": role_keys,
            }
            return userinfo
