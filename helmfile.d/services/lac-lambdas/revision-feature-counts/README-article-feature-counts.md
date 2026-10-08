# RevisionFeatureCounts

The lambda that the Linked Artifact Cache calls to compute the `revision_feature_counts` artifact.

* Service code: https://gitlab.wikimedia.org/repos/data-engineering/linked-artifact-lambdas
* Ticket: [T432604](https://phabricator.wikimedia.org/T432604)
* Documentation: [wikitech:Revision_Feature_Counts](https://wikitech.wikimedia.org/wiki/Revision_Feature_Counts)
* Owner: Data Engineering

## Deploying

```bash
cd /srv/deployment-charts/helmfile.d/services/lac-lambdas
helmfile -e staging -i apply --selector name=revision-feature-counts
helmfile -e codfw -i apply --selector name=revision-feature-counts
helmfile -e eqiad -i apply --selector name=revision-feature-counts
```
