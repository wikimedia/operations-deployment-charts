## configuration 1.1.1
- Support a custom error page T287983
- Fix the bug with the certificates configmap introduced with 1.1.0

## 1.1.0

- Support mesh service proxy without exposing a Service for public_port.
  This allows us to use the the service mesh for egress,
  without exposing a listener if it isn't needed.
