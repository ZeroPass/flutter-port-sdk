//  Created by Crt Vavros, copyright © 2021 ZeroPass. All rights reserved.
import 'dart:io';
import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/extensions.dart';
import 'package:logging/logging.dart';
import 'package:port/src/proto/uid.dart';

import 'authn_data.dart';
import 'proto/port_api.dart';
import 'proto/port_error.dart';
import 'proto/proto_challenge.dart';
import 'proto/session.dart';


class PortClient {

  final _log = Logger('port.client');
  final PortApi _api;
  ProtoChallenge? _challenge;
  Session? _session;
  Future<bool> Function(SocketException e)? _onConnectionError;
  Future<bool> Function(EfDG1 dg1)? _onDG1FileRequest;

  /// Returns connection timeout.
  Duration? get timeout => _api.timeout;
  set timeout(Duration? timeout) => _api.timeout = timeout;

  /// Returns [UserId] or [null]
  /// if session is not established yet.
  UserId? get uid => _session?.uid;

  /// Returns server [Uri] url.
  Uri get url => _api.url;
  set url(Uri url) => _api.url = url;

  /// Constructs new [PortClient] using server [url] address and
  /// optionally [httpClient].
  PortClient(Uri url, {HttpClient? httpClient}) :
    _api = PortApi(url, httpClient: httpClient ?? HttpClient());


  /// Callback invoked when sending request fails due to connection errors.
  /// If [callback] returns true the the client will retry to connect.
  set onConnectionError(Future<bool> Function(SocketException e) callback) =>
    _onConnectionError = callback;

  /// Callback invoked when signing up via login method and
  /// server requested DG1 file (data from MRZ) in order to establish login session.
  /// If [callback] returns true the EfDG1 file will be send to the server.
  set onDG1FileRequested(Future<bool> Function(EfDG1 dg1) callback) =>
    _onDG1FileRequest = callback;

  /// Notifies server to dispose session
  /// establishment challenge used for register/login.
  void disposeChallenge() {
    if(_challenge != null) {
       _api.cancelChallenge(_challenge!);
      _resetChallenge();
    }
  }

  /// Establishes session by calling Port login API using [AuthnData] returned via [callback].
  /// [AuthnData] should have assigned fields: [csig], [sod] and [dg1] in case server request it.
  /// If argument [sendEfDG1] is true then file EfDG1 will be sent to server in any case without
  /// server requesting it first.
  ///
  /// Note: If login fails due to server requested EF.DG1 file this request
  ///       is handled via callback [onDG1FileRequested]. If not [PortError] is thrown.
  ///
  /// Throws [SocketException] on connection error if not handled by [onConnectionError] callback.
  /// Throws [PortError] when required data returned by [callback] is missing or
  /// when provided data is invalid e.g. verification of challenge signature fails.
  Future<void> login(Future<AuthnData> Function(ProtoChallenge challenge) callback, {bool sendEfDG1 = false}) async {
    _log.verbose('::login');
    await _retriableCall(_getNewChallenge);

     _log.verbose('Invoking callback with recieved challenge');
    final data = await callback(_challenge!);
    _throwIfMissingRequiredAuthnData(data);

    final uid = UserId.fromDG15(data.dg15);
    _session = await _retriableCallEx((error) async {
      if(error != null) {
        // Handle request for EfDG1 file
        if(!error.isDG1Required() || data.dg1 == null ||
           !(await _onDG1FileRequest?.call(data.dg1!) ?? false)) {
          throw _RethrowPortError(error);
        }
        sendEfDG1 = true;
      }
      final dg1 = sendEfDG1 ? data.dg1 : null;
      return _api.login(uid, _challenge!.id, data.csig, dg1: dg1);
    });

    _resetChallenge();
  }

  /// Calls pasID ping API with [number] and returns [pong] number.
  /// Throws [SocketException] on connection error if not handled by [onConnectionError] callback.
  Future<int> ping(int number) async {
    _log.verbose('Pinging server with: $number');
    return _api.ping(number);
  }

  /// Establishes session by calling Port register API using [AuthnData] returned via [callback].
  /// [AuthnData] should have assigned fields: [dg15], [csig], [sod] and
  /// [dg14] if AA public key in [dg15] is of type [EC].
  ///
  /// Throws [SocketException] on connection error if not handled by [onConnectionError] callback.
  /// Throws [PortError] when required data returned by [callback] is missing or
  /// when provided data is invalid e.g. verification of challenge signature fails.
  Future<void> register(Future<AuthnData> Function(ProtoChallenge challenge) callback) async {
    _log.verbose('::register');
    await _retriableCall(_getNewChallenge);

    _log.verbose('Invoking callback with recieved challenge');
    final data = await callback(_challenge!);
    _throwIfMissingRequiredAuthnData(data);
    if(data.sod == null) {
      throw throw PortError(-32602, 'Missing proto data to establish session');
    }

    _session = await _retriableCall(() =>
      _api.register(data.sod!, data.dg15, _challenge!.id, data.csig, dg14: data.dg14)
    );

    _resetChallenge();
  }

  /// Calls Port sayHello API and returns greeting from server.
  /// Session must be established prior calling this function via
  /// either [register] or [login] method.
  ///
  /// Throws [SocketException] on connection error if not handled by [onConnectionError] callback.
  /// Throws [PortError] if session is not set or
  /// invalid session parameters.
  Future<String> requestGreeting() {
    _log.verbose('::requestGreeting');
    if(_session == null) {
      throw PortError(-32602, 'Session not established');
    }
    return _retriableCall(() =>
      _api.sayHello(_session!)
    );
  }

  Future<void> _getNewChallenge() async {
    _challenge = await _api.getChallenge();
    _log.debug('Received new challenge: ${_challenge.toString()}');
  }

  /// Function recursively calls [func] in case of a handled exception until result is returned.
  /// Unhandled exceptions are passed on.
  /// For example when there is connection error and callback [_onConnectionError]
  /// returns true to retry connecting.
  Future<T> _retriableCallEx<T> (Future<T> Function(PortError? error) func, {PortError? error}) async {
    try{
      return await func(error);
    }
    on _RethrowPortError catch(e) {
      e.unwrapAndThrow();
    }
    on SocketException catch(e) {
      if(await _onConnectionError?.call(e) ?? false) {
        return await _retriableCallEx(func);
      }
      rethrow;
    }
    on PortError catch(e) {
      return _retriableCallEx(func, error: e);
    }
  }

  Future<T> _retriableCall<T> (Future<T> Function() func) async {
    return _retriableCallEx((error) {
      if(error != null) {
        throw _RethrowPortError(error);
      }
      return func();
    });
  }

  void _resetChallenge() {
    _challenge = null;
  }

  /// Session data is data needed to establish Port proto session
  /// e.g: dg15 (AA public key) and csig.
  void _throwIfMissingRequiredAuthnData(final AuthnData data) {
    if( (data.dg15.aaPublicKey.type == AAPublicKeyType.EC && data.dg14 == null)
      || data.csig.isEmpty){
        throw PortError(-32602, 'Missing required authentication data to establish session');
    }
  }
}

/// Wrapper exception for PortError to
/// rethrow it in _retriableCallEx
class _RethrowPortError {
  final PortError error;
  _RethrowPortError(this.error);
  Never unwrapAndThrow() {
    throw error;
  }
}