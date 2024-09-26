from airflow.providers.fab.auth_manager.fab_auth_manager import FabAuthManager
from airflow.providers.fab.auth_manager.models import User


class CustomAuthManager(FabAuthManager):
    """An authentication manager supporting both session and Keberos authentication for the Airflow stable API."""

    def get_user(self) -> User:
        """Attempt to find the current user in g.user, as defined by the kerberos authentication backend.

        If no such user is found, return the `current_user` local proxy object, linked to the user session.

        """
        from flask_login import current_user
        from flask import g

        # If a user has gone through the Kerberos dance, the kerberos authentication manager
        # has linked it with a User model, stored in g.user, and not the session.
        if (
            current_user.is_anonymous
            and getattr(g, "user", None) is not None
            and not g.user.is_anonymous
        ):
            return g.user
        return super().get_user()
