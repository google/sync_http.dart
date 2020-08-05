[![Build Status](https://travis-ci.org/dart-lang/sync_http.svg?branch=master)](https://travis-ci.org/dart-lang/sync_http/)
[![pub package](https://img.shields.io/pub/v/sync_http.svg)](https://pub.dev/packages/sync_http)

A simple Dart HTTP client implemented using RawSynchronousSockets to allow for
synchronous HTTP requests.

**Warning**: This library should probably only be used to connect to HTTP 
servers that are hosted on 'localhost'. The operations in this library will
block the calling thread to wait for a response from the HTTP server. The thread
can process no other events while waiting for the server to respond. As such,
this synchronous HTTP client library is not suitable for applications that
require high performance. Instead, such applications should use libraries built
on asynchronous I/O, including
[dart:io](https://api.dart.dev/stable/dart-io/dart-io-library.html)
and [package:http](https://pub.dev/packages/http), for the best 
performance.
