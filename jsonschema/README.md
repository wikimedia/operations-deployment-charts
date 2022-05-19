This directory contains JSON schema files for CustomResourceDefinitions.

Those can be generated from kubernetes spec by running `./openapi2jsonschema.py path/to/crd.yaml`.

The "charts/" subfolder contains JSON schema for CRDs shipped by helm charts which will be generated on
demand by CI (or via `rake json_schema`). For this to work, all helm charts shipping CRDs are **required**
to provide a `.fixture/crds.yaml` file with the values necessary to template the CRDs.

The "istio/" subfolder contains the JSON schema for Istio CRDs which are committed to git because we don't
have a helm chart for Istio. Source for the CRDs is:
https://github.com/istio/istio/raw/1.9.5/manifests/charts/base/crds/crd-all.gen.yaml
