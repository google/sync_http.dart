## v0.2.0

* Preparation for [HttpHeaders change]. Update signature of `add()`
  and `set()` to match new signature of `HttpHeaders`. The
  parameter is not yet forwarded and will not behave as expected.

  [HttpHeaders change]: https://github.com/dart-lang/sdk/issues/39657

## v0.1.4

* Fixed issue where query parameters were not being sent as part of requests.

## v0.1.3

* Updated SDK version upper bound to 3.0.0.

## v0.1.2

* Require Dart 2.
