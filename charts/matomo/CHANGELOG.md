# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---
## [0.0.3]
### Added
- Populate a shared volume with bundled Matomo files using an init container and mount it read-only in the httpd-fgi container (needed for hosting static assets until we get on a version of K8s that supports [Image Volumes](https://kubernetes.io/docs/tasks/configure-pod-container/image-volumes/) ).
- Replace the default HTTPD application site with Matomo-specific static-file serving, PHP-FPM handling, and private-directory restrictions.
- Roll pods when the Matomo site or additional HTTPD configuration changes.
---
## [0.0.2]
### Added
- Support for array variables such as `GENERAL_TRUSTED_HOSTS: '["127.0.0.1:8080","override-me.org", "override-me.co"]'`
### Deprecated
### Removed
### Fixed
---
## [0.0.1]
### Added
- Initial chart design, derived from the WMF scaffold for LAMP applications.
### Deprecated
### Removed
### Fixed
---