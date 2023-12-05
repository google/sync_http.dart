## 0.3.2-wip

* Require Dart 3.0

## 0.3.1

* Switch to using `package:lints/recommended.yaml`
* Update the usage guidance in the readme.

## 0.3.0

* Stable version for null safety.

* **BREAKING** `SyncHttpClient` functions now require the `url` parameter to be
  `Uri`. Previously, both `Uri` and `String` were supported.

* The `SyncHttpClientResponse.contentLength` getter will return `-1` instead of
  `null` if content length not specified.

* Implement `chunkedTransferEncoding` getters.

## 0.2.0

* Preparation for [HttpHeaders change]. Update signature of `add()`
  and `set()` to match new signature of `HttpHeaders`. The
  parameter is not yet forwarded and will not behave as expected.

  [HttpHeaders change]: https://github.com/dart-lang/sdk/issues/39657

## 0.1.4

* Fixed issue where query parameters were not being sent as part of requests.

## 0.1.3

* Updated SDK version upper bound to 3.0.0.

## 0.1.2

* Require Dart 2.
