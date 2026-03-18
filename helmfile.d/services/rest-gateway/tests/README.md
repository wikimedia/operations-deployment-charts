This directory contains end-to-end functionality tests for verifying 
an installation of the REST Gateway. They are designed to be used locally
during development as well as on a deployment host.  

## Running tests
Tests can be run via Make. The `env` parameter selects which environment to test
against:

```bash
make check               # test against the staging cluster, to be used during deployment
make check env=minikube  # test against a local minikube environment
```

When invoked from the Makefile in the api-gateway chart's test directory
(`charts/api-gateway/tests/`), `env=minikube` is applied automatically.
There should rarely be a need to set `env` manually.

Requirements:
* **python3**. If you want to run tests manually instead of using the Makefile,
  you will also need the `python` directory from the root of the
  `deployment-charts` repository in your `PYTHONPATH`.

## Running tests without Make
To run tests directly without Make, set `SMOKEPY_VALUE_FILES` to a colon-separated
list of value files to use (see [Test Configuration](#test_environment_configuration) below)
and set `PYTHONPATH` to include the `python` directory from the repository root:

```bash
export PYTHONPATH=../../../../python
export SMOKEPY_VALUE_FILES=../values.yaml:../values-staging.yaml:../values-minikube.yaml
python3 -m unittest -vv test_*.py
```

Local override files (`values-minikube.local.yaml`, `values-staging.local.yaml`) can
be appended to the list the same way.

##  Test environment configuration
Value files are assembled in this order (later files take precedence):

1. `values.yaml` — base values
2. `values-staging.yaml` — staging overrides, needed for tests 
3. `values-minikube.yaml` — only if `env=minikube` is set.

To add machine-specific or personal settings without touching checked-in files,
create `values-minikube.local.yaml` or `values-staging.local.yaml` (both
git-ignored). These are loaded last.

For example, if you want to target a kubernetes cluster not on localhost,
you might use the following:

```yaml
smokepy:
  gateway:
    target_url: http://somewhere.else:8087
    headers:
      Host: somewhere.else
```

## Writing tests
The end-to-end tests are written in Python using the `pyunit` framework that
ships with Python 3. They use the `smokepy` library located in the `python`
directory in the repository root. Tests have access to the contents of the values
files, so they can adjust to the environment they are running in.
