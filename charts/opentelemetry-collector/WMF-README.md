
This is vendored from
https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-collector.

README.md is the upstream readme file. In addition, in the upstream repo but not copied here, see
UPGRADING.md and the examples/ directory.


When importing a new chart version from upstream, prefer to use the upstream version number for the
`version` field. If subsequent WMF revisions are necessary after merging to the deployment-charts
repo, bump the patch version (e.g. 0.1.2 to 0.1.3) and ensure the upstream version number is
commented correctly.

If the new upstream version number is less than or equal to the current WMF version (according to 
https://semver.org/#spec-item-11) then you won't be able to use it, since it wouldn't roll out as
an update. Instead you'll need to increment the patch number again, and in this case be extra-sure
that the upstream version number is commented correctly.

(For example: Suppose we vendored 0.1.0 from upstream, then amended it locally to 0.1.1 and 0.1.2.
If upstream 0.1.1 came out next, we would have to vendor it as "0.1.3" -- but if 0.2.0 came out, we
would be able to call it "0.2.0".)


Changes from upstream:

* .fixturectl.yml and .fixtures.yaml are added, to customize WMF CI.

* `mode: daemonset` is set in values.yaml, because the chart doesn't build without it. (We'd be fine
  just setting the mode in the helmfile, but then it would fail to validate as-is in our CI. For
  now this is fine, as we only need one setting in production anyway. If that changes in the
  future, we could consider leaving the default `mode: ""` as upstream does, and addressing the CI
  issue differently.)

* `additionalProperties` is changed from `false` to `true` in values.schema.json at the top level.
  This is needed because our infrastructure adds some more stuff, merged in from under
  /etc/helmfile-defaults, and the schema still needs to validate. (Listing each new field in the
  schema, and then updating it every time we change something in the defaults, wouldn't be
  practical.) As a result, use extra caution when modifying `values.yaml` -- a typo in a field name
  will *not* be caught by the schema validation.
