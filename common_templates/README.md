This directory includes helpers for common setup options, like setting
up TLS, or debugging.

The templates are versioned by path, and will be selected when
creating a new chart depending on the helm_scaffold_version value.

Breaking changes to these templates should only happen when we move to
a version to the next, while bugfixes can happen within the same
version.

An example of a breaking change is any change that requires a change
in the default values.yaml file.
