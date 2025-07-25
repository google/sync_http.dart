// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:sync_http/sync_http.dart';
import 'package:test/test.dart';

typedef ServerCallback = void Function(int? port);

class TestServerMain {
  TestServerMain() : _statusPort = ReceivePort();

  final ReceivePort _statusPort; // Port for receiving messages from the server.
  late SendPort _serverPort; // Port for sending messages to the server.
  late ServerCallback _startedCallback;

  void setServerStartedHandler(ServerCallback startedCallback) {
    _startedCallback = startedCallback;
  }

  void start() {
    final receivePort = ReceivePort();
    Isolate.spawn(startTestServer, receivePort.sendPort);
    receivePort.first.then((port) {
      _serverPort = port as SendPort;

      // Send server start message to the server.
      final command = TestServerCommand.start();
      port.send([command, _statusPort.sendPort]);
    });

    // Handle status messages from the server.
    _statusPort.listen((var value) {
      final status = value as TestServerStatus;
      if (status.isStarted) {
        _startedCallback(status.port);
      }
    });
  }

  void close() {
    // Send server stop message to the server.
    _serverPort.send([TestServerCommand.stop(), _statusPort.sendPort]);
    _statusPort.close();
  }
}

enum TestServerCommandState { start, stop }

class TestServerCommand {
  TestServerCommand.start() : _command = TestServerCommandState.start;

  TestServerCommand.stop() : _command = TestServerCommandState.stop;

  bool get isStart => _command == TestServerCommandState.start;

  bool get isStop => _command == TestServerCommandState.stop;

  final TestServerCommandState _command;
}

enum TestServerStatusState { started, stopped, error }

class TestServerStatus {
  TestServerStatus.started(this._port) : _state = TestServerStatusState.started;

  TestServerStatus.stopped() : _state = TestServerStatusState.stopped;

  TestServerStatus.error() : _state = TestServerStatusState.error;

  bool get isStarted => _state == TestServerStatusState.started;

  int? get port => _port;

  final TestServerStatusState _state;
  int? _port;
}

void startTestServer(SendPort replyTo) {
  final server = TestServer();
  server.init();
  replyTo.send(server.dispatchSendPort);
}

class TestServer {
  // Echo the request content back to the response.
  void _echoHandler(HttpRequest request) {
    final response = request.response;
    if (request.method != 'POST') {
      response.close();
      return;
    }
    response.contentLength = request.contentLength;
    request.listen((List<int> data) {
      final string = String.fromCharCodes(data);
      response.write(string);
      response.close();
    });
  }

  // Echo the request content back to the response.
  void _zeroToTenHandler(HttpRequest request) {
    final response = request.response;
    const msg = '01234567890';
    if (request.method != 'GET') {
      response.close();
      return;
    }
    response.contentLength = msg.length;
    response.write(msg);
    response.close();
  }

  // Return a 404.
  void _notFoundHandler(HttpRequest request) {
    final response = request.response;
    response.statusCode = HttpStatus.notFound;
    const msg = 'Page not found';
    response.contentLength = msg.length;
    response.headers.set('Content-Type', 'text/html; charset=UTF-8');
    response.write(msg);
    response.close();
  }

  // Return a 301 with a custom reason phrase.
  void _reasonForMovingHandler(HttpRequest request) {
    final response = request.response;
    response.statusCode = HttpStatus.movedPermanently;
    response.reasonPhrase = "Don't come looking here any more";
    response.close();
  }

  // Check the "Host" header.
  void _hostHandler(HttpRequest request) {
    final response = request.response;
    expect(1, equals(request.headers['Host']!.length));
    expect('dart.dev:1234', equals(request.headers['Host']![0]));
    expect('dart.dev', equals(request.headers.host));
    expect(1234, equals(request.headers.port));
    response.statusCode = HttpStatus.ok;
    response.close();
  }

  void _hugeHandler(HttpRequest request) {
    final response = request.response;
    final expected = List<int>.generate(1 << 20, (i) => (i + 1) % 256);
    final msg = expected.toString();
    response.contentLength = msg.length;
    response.statusCode = HttpStatus.ok;
    response.write(msg);
    response.close();
  }

  void init() {
    // Setup request handlers.
    _requestHandlers = {};
    _requestHandlers['/echo'] = _echoHandler;
    _requestHandlers['/0123456789'] = _zeroToTenHandler;
    _requestHandlers['/reasonformoving'] = _reasonForMovingHandler;
    _requestHandlers['/host'] = _hostHandler;
    _requestHandlers['/huge'] = _hugeHandler;
    _dispatchPort = ReceivePort();
    _dispatchPort.listen(dispatch);
  }

  SendPort get dispatchSendPort => _dispatchPort.sendPort;

  Future<void> dispatch(Object? message) async {
    final command = (message as List)[0] as TestServerCommand;
    final replyTo = message[1] as SendPort;
    if (command.isStart) {
      try {
        final addr = (await InternetAddress.lookup('localhost'))[0];
        await HttpServer.bind(addr, 0).then((server) {
          _server = server;
          _server.listen(_requestReceivedHandler);
          replyTo.send(TestServerStatus.started(_server.port));
        });
      } catch (e) {
        replyTo.send(TestServerStatus.error());
      }
    } else if (command.isStop) {
      await _server.close();
      _dispatchPort.close();
      replyTo.send(TestServerStatus.stopped());
    }
  }

  void _requestReceivedHandler(HttpRequest request) {
    final requestHandler = _requestHandlers[request.uri.path];
    if (requestHandler != null) {
      requestHandler(request);
    } else {
      _notFoundHandler(request);
    }
  }

  late HttpServer _server; // HTTP server instance.
  late ReceivePort _dispatchPort;
  late Map<String, void Function(HttpRequest)> _requestHandlers;
}

Future<void> testStartStop() async {
  final completer = Completer<void>();
  final testServerMain = TestServerMain();
  testServerMain.setServerStartedHandler((int? port) {
    testServerMain.close();
    completer.complete();
  });
  testServerMain.start();
  return completer.future;
}

Future<void> testGET() async {
  final completer = Completer<void>();
  final testServerMain = TestServerMain();
  testServerMain.setServerStartedHandler((int? port) {
    final request = SyncHttpClient.getUrl(
      Uri.http('localhost:$port', '/0123456789'),
    );
    final response = request.close();
    expect(HttpStatus.ok, equals(response.statusCode));
    expect(11, equals(response.contentLength));
    expect('01234567890', equals(response.body));
    testServerMain.close();
    completer.complete();
  });
  testServerMain.start();
  return completer.future;
}

Future<void> testPOST() async {
  final completer = Completer<void>();
  const data = 'ABCDEFGHIJKLMONPQRSTUVWXYZ';
  const kMessageCount = 10;

  final testServerMain = TestServerMain();

  void runTest(int? port) {
    var count = 0;
    void sendRequest() {
      final request = SyncHttpClient.postUrl(
        Uri.http('localhost:$port', '/echo'),
      );
      request.write(data);
      final response = request.close();
      expect(HttpStatus.ok, equals(response.statusCode));
      expect(data, equals(response.body));
      count++;
      if (count < kMessageCount) {
        sendRequest();
      } else {
        testServerMain.close();
        completer.complete();
      }
    }

    sendRequest();
  }

  testServerMain.setServerStartedHandler(runTest);
  testServerMain.start();
  return completer.future;
}

Future<void> test404() async {
  final completer = Completer<void>();
  final testServerMain = TestServerMain();
  testServerMain.setServerStartedHandler((int? port) {
    final request = SyncHttpClient.getUrl(
      Uri.http('localhost:$port', '/thisisnotfound'),
    );
    final response = request.close();
    expect(HttpStatus.notFound, equals(response.statusCode));
    expect('Page not found', equals(response.body));
    testServerMain.close();
    completer.complete();
  });
  testServerMain.start();
  return completer.future;
}

Future<void> testReasonPhrase() async {
  final completer = Completer<void>();
  final testServerMain = TestServerMain();
  testServerMain.setServerStartedHandler((int? port) {
    final request = SyncHttpClient.getUrl(
      Uri.http('localhost:$port', '/reasonformoving'),
    );
    final response = request.close();
    expect(HttpStatus.movedPermanently, equals(response.statusCode));
    expect(
      "Don't come looking here any more\r\n",
      equals(response.reasonPhrase),
    );
    testServerMain.close();
    completer.complete();
  });
  testServerMain.start();
  return completer.future;
}

Future<void> testHuge() async {
  final completer = Completer<void>();
  final testServerMain = TestServerMain();
  testServerMain.setServerStartedHandler((int? port) {
    final request = SyncHttpClient.getUrl(Uri.http('localhost:$port', '/huge'));
    final response = request.close();
    final expected =
        List<int>.generate(1 << 20, (i) => (i + 1) % 256).toString();
    expect(HttpStatus.ok, equals(response.statusCode));
    expect(expected.length, equals(response.contentLength));
    expect(expected.toString(), equals(response.body));
    testServerMain.close();
    completer.complete();
  });
  testServerMain.start();
  return completer.future;
}

void main() {
  test('Simple server test', () async {
    await testStartStop();
  });
  test('Sync HTTP GET test', () async {
    await testGET();
  });
  test('Sync HTTP POST test', () async {
    await testPOST();
  });
  test('Sync HTTP 404 test', () async {
    await test404();
  });
  test('Sync HTTP moved test', () async {
    await testReasonPhrase();
  });
  test('Sync HTTP huge test', () async {
    await testHuge();
  });
}
