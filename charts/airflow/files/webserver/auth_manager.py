"""
Overloading airflow:providers/fab/src/airflow/providers/fab/auth_manager/fab_auth_manager.py.
See https://airflow.apache.org/docs/apache-airflow-providers-fab/stable/auth-manager/token.html
for official documentation, and https://phabricator.wikimedia.org/T437236 for the design.

Needs access to "https://kubernetes.default.svc/.well-known/openid-configuration", which is
usually require authentication and controlled with the system:service-account-issuer-discovery
cluster role. This code implements logic to use default projected K8s-bound service token to
access this endpoint, as Airflow needs such token to create Pods in K8s anyways. However,
unauthenticated access to this endpoint can also be configured with K8s RBAC.

Converts a service token to a user:
{
    "username": "system:serviceaccount:$NAMESPACE:$SERVICE_ACCOUNT",
    "email": "$USERNAME@email.notfound",
    "role_keys": ["kubernetes.io:namespace:$NAMESPACE"],
}

Configuration options:

AUTH_K8S_TOKEN_VERIFICATION_OPTIONS = {
    "audience": [
        "server.discovery.svc"  # should match audience in a service token
    ]
}
AUTH_ROLES_MAPPING = {
    "kubernetes.io:namespace:$NAMESPACE": ["Op"],
}

1. For AUTH_K8S_TOKEN_VERIFICATION_OPTIONS values,
   see https://pyjwt.readthedocs.io/en/stable/api.html#jwt.decode
2. role_keys will be matched against AUTH_ROLES_MAPPING to resolve roles

"""

import logging
import pathlib
import ssl
from typing import Any

import jwt
import requests
from airflow.providers.fab.auth_manager.fab_auth_manager import (
    FabAuthManager as AirflowFabAuthManager,
)
from airflow.providers.fab.auth_manager.models import User
from flask import current_app

log = logging.getLogger(__name__)

# Kubernetes OIDC token federation
K8S_TOKEN_SERVICE_URL = "https://kubernetes.default.svc"
K8S_OPENID_URL = f"{K8S_TOKEN_SERVICE_URL}/.well-known/openid-configuration"
DEFAULT_K8S_TOKEN_VERIFICATION_OPTIONS = {"options": {"verify_aud": False}}
DEFAULT_K8S_SERVICE_ACCOUNT = pathlib.Path(
    "/var/run/secrets/kubernetes.io/serviceaccount"
)
DEFAULT_K8S_SERVICE_ACCOUNT_TOKEN_PATH = DEFAULT_K8S_SERVICE_ACCOUNT.joinpath("token")
K8S_CA_CERT_PATH = DEFAULT_K8S_SERVICE_ACCOUNT.joinpath("ca.crt")


class FabAuthManager(AirflowFabAuthManager):

    @property
    def _k8s_token_verification(self) -> dict[str, Any]:
        return current_app.config.get(
            "AUTH_K8S_TOKEN_VERIFICATION_OPTIONS",
            DEFAULT_K8S_TOKEN_VERIFICATION_OPTIONS,
        )

    @property
    def _k8s_auth_header(self) -> dict[str, str]:
        if DEFAULT_K8S_SERVICE_ACCOUNT_TOKEN_PATH.exists():
            server_token = DEFAULT_K8S_SERVICE_ACCOUNT_TOKEN_PATH.read_text().strip()
            return {"Authorization": f"Bearer {server_token}"}
        return {}

    @property
    def _k8s_ca_cert_path(self) -> str | None:
        if K8S_CA_CERT_PATH.exists():
            return K8S_CA_CERT_PATH.as_posix()

    def _auth_k8s_user(self, oauth_token: str) -> User | None:
        headers = self._k8s_auth_header
        ca_cert = self._k8s_ca_cert_path
        oidc = requests.get(K8S_OPENID_URL, headers=headers, verify=ca_cert).json()
        if (jwks_uri := oidc.get("jwks_uri")) is None:
            log.error("K8s: failed to contact %s: %s", K8S_OPENID_URL, oidc)
            return None

        try:
            jwks_client = jwt.PyJWKClient(
                jwks_uri,
                headers=headers,
                ssl_context=ca_cert and ssl.create_default_context(cafile=ca_cert),
            )
            signing_key = jwks_client.get_signing_key_from_jwt(oauth_token)
            log.info("K8s: verification options: %s", self._k8s_token_verification)
            decoded = jwt.decode(
                oauth_token, signing_key, **self._k8s_token_verification
            )
        except jwt.exceptions.PyJWTError:
            log.exception("K8s: failed to decode token")
            return None

        subject = decoded["sub"]
        namespace = decoded["kubernetes.io"]["namespace"]
        role_keys = [
            f"kubernetes.io:namespace:{namespace}",
        ]

        log.info("K8s: authenticating username=%s, role_keys=%s", subject, role_keys)
        userinfo = {
            "username": subject,
            "email": f"{subject}@email.notfound",
            "role_keys": role_keys,
        }
        user = self.security_manager.auth_user_oauth(userinfo, rotate_session_id=False)
        return user

    def create_token(
        self, headers: dict[str, str], body: dict[str, Any]
    ) -> User | None:
        user: User | None = None

        if (k8s_token := body.get("k8s_token")) is not None:
            user = self._auth_k8s_user(k8s_token)
            log.info("k8s_token authentication result: %s", user and user.username)

        if user is None:
            user = super().create_token(headers, body)
        return user
