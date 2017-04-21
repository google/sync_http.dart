Dart Synchronous HTTP Client
============================

**Important Note:** This package requires the RawSynchronousSocket class to
work, which should become available in version 1.24 of the Dart SDK. If you
really want to use this package now, you'll have to build the Dart VM from
the most up-to-date source hosted in dart-lang/sdk.

A simple Dart HTTP client implemented using RawSynchronousSockets to allow for
synchronous HTTP requests.

Warning: This library should probably only be used to connect to HTTP servers
that are hosted on 'localhost'. The operations in this library will block the
calling thread to wait for a response from the HTTP server. The thread can
process no other events while waiting for the server to respond. As such, this
synchronous HTTP client library is not suitable for applications that require
high performance. Instead, such applications should use libraries built on
asynchronous I/O, including
[dart:io](https://api.dartlang.org/stable/1.22.1/dart-io/dart-io-library.html)
and [package:http](https://pub.dartlang.org/packages/http), for the best
performance.
