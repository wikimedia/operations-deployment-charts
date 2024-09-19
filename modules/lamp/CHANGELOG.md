## job 3.0.1
- Noop, keeping up with app.job module version
## job 3.0.0
- Allow to define Job properties
- Support for activeDeadlineSeconds
- When updating to this version, the relevant include must be
  added in cronjob.yaml (see cronjob.yaml.skel)
## job 2.0.0
- Breaking change, incompatible with job 1.0
- add support for per environment cronjobs
- add support for volume mounts