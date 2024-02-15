import logging

from superset.security import SupersetSecurityManager

logger = logging.getLogger(__name__)


class CustomSsoSecurityManager(SupersetSecurityManager):
    def oauth_user_info(self, provider, response=None):
        if provider == "CAS":
            me = self.appbuilder.sm.oauth_remotes[provider].userinfo()
            logger.info(f"Login with user info {me}")
            return {
                "id": me["id"],
                "username": me.get("preferred_username", me["id"]),
                "name": me.get("name", me["id"]),
                "email": me.get("email", f"{me['id']}@email.notfound"),
            }
