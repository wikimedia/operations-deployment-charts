## mcrouter 1.3.3
- Add KeyModifyRoute support

## service 2.0.0

- Add the ability to define the clusterIP of the service
- BREAKING: Rename public_service to enabled and put it under a new service stanza

## mcrouter 1.3.2

- Fix mcrouter module to work out of the box from scaffold
- Set proper values for common_images in mcrouter values.yaml
- Remove (re-)definiton of common_images in mcrouter scaffold values and
- implement proper defaults in the template
- Fix indentation of mcrouter values in scaffolding

## mcrouter 1.3.1
- fixed mcrouter-service.yaml fixture
- added a default value for .Values.mcrouter.port
- fixed identation in values.yaml

## mcrouter 1.3.0
- Allow port definition
- Rename cache.mcrouter.deployment to cache.mcrouter.container
- Add cache.service module of cluster level traffic
- Added fixture for cache.service module

## mcrouter  1.2.0
- Add exporter resources definition

## mcrouter  1.1.0
- Add prestop_sleep options

