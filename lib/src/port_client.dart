//  Created by Crt Vavros, copyright © 2021 ZeroPass. All rights reserved.
import 'dart:convert';
import 'dart:io';
import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/extensions.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:port/src/proto/challenge_signature.dart';
import 'package:port/src/proto/uid.dart';

import 'proto/port_api.dart';
import 'proto/port_error.dart';
import 'proto/proto_challenge.dart';

class PortClient {

  final _log = Logger('port.client');
  final PortApi _api;
  final _challenges = <UserId, ProtoChallenge>{};
  var _tint = Duration(minutes: 5); // tidy-up interval
  var _ttime = DateTime.now(); // last tidy-up time

  Future<bool> Function(SocketException e)? _onConnectionError;

  /// Returns connection timeout.
  Duration? get timeout => _api.timeout;
  set timeout(Duration? timeout) => _api.timeout = timeout;

  /// Returns server [Uri] url.
  Uri get url => _api.url;
  set url(Uri url) => _api.url = url;

  /// Constructs new [PortClient] using server [url] address and
  /// optionally [httpClient].
  PortClient(Uri url, {HttpClient? httpClient}) :
    _api = PortApi(url, httpClient: httpClient ?? HttpClient()) {
      PackageInfo.fromPlatform().then((pi) => {
        _api.userAgent = '${pi.packageName}/${pi.version}'
      });
    }

  /// Callback invoked when sending request fails due to connection errors.
  /// If [callback] returns true the the client will retry to connect.
  set onConnectionError(Future<bool> Function(SocketException e) callback) =>
    _onConnectionError = callback;

  /// Notifies server to dispose challenge used for register/getAssertion.
  void disposeChallenge(UserId uid) {
    final c = _challenges[uid];
    if (c != null) {
      _log.debug('Disposing challenge. uid=$uid cid=${c.id}');
      _api.cancelChallenge(c);
      _challenges.remove(uid);
    }
  }

  /// Request authn assertion for eMRTD active authentication by calling Port `get_assertion`
  /// for [uid] using passport [ChallengeSignature] returned via [callback] as authentication credential.
  /// Note, the [uid] should be already registered with Port server before calling this method.
  ///
  /// Returns server specific user authn assertion result in JSON format.
  ///
  /// Throws [SocketException] on connection error if not handled by [onConnectionError] callback.
  /// Throws [PortError] when [callback] returns empty list of `csigs`, or
  /// server error e.g. [uid] not registered or invalid signatures in `csigs` fo challenge.
  Future<Map<String, dynamic>> getAssertion(UserId uid, Future<ChallengeSignature> Function(ProtoChallenge challenge) callback) async {
    _log.verbose('::getAssertion: uid=$uid');
    final challenge = await _retriableCall(()=>_fetchChallenge(uid));

    _log.verbose('Invoking callback with received challenge, cid=${challenge.id}');
    final csig   = await callback(challenge);
    if(csig.isEmpty){
        _log.error('Callback returned empty `csigs`.');
        throw PortError(-32602, 'Missing required eMRTD authentication data');
    }

    final result = await _retriableCallEx((error) async {
      if(error != null) {
        _log.error('An error has occurred while requesting assertion from server. uid=$uid');
        _log.error('  e=$error');
        throw _RethrowPortError(error);
      }
      return _api.getAssertion(uid, challenge.id, csig);
    });

    _log.debug('Retrieved assertion from server for uid=$uid:');
    _log.debug(jsonEncode(result));
    _challenges.remove(uid);
    return result;
  }

  /// Calls pasID ping API with [number] and returns [pong] number.
  /// Throws [SocketException] on connection error if not handled by [onConnectionError] callback.
  Future<int> ping(int number) async {
    _log.verbose('Pinging server with: $number');
    return await _retriableCall(() => _api.ping(number));
  }

  /// Registers new Port biometric passport Passive Attestation for [uid] using [sod] and optionally EF files [dg15] and [dg14].
  /// The [dg15] file is required when passport supports Active Authentication and file [dg14] if AA public key in [dg15] is of type [EC].
  /// If [override] is True an existing registration under [uid] will be overridden.
  /// Note, if previous registration is overridden the old passport can't be used anymore.
  ///
  /// Returns server specific user registration result in JSON format.
  ///
  /// Throws [SocketException] on connection error if not handled by [onConnectionError] callback.
  /// Throws [PortError] when required data returned by [callback] is missing or
  /// when provided data is invalid e.g. verification of challenge signature fails.
  Future<Map<String, dynamic>> register(final UserId uid, final EfSOD sod, {final EfDG15? dg15, final EfDG14? dg14, final bool? override}) async {
    _log.verbose('::register: uid=$uid');

    if(  sod.toBytes().isEmpty
      || (dg15?.aaPublicKey.type == AAPublicKeyType.EC && dg14 == null)){
        throw PortError(-32602, 'Missing required eMRTD attestation data for registration');
    }

    final result = await _retriableCallEx((error) async {
      if(error != null) {
        _log.error('An error has occurred while registering attestation for user with uid=$uid');
        _log.error('  e=$error');
        throw _RethrowPortError(error);
      }
      return _api.register(uid, sod, dg15: dg15, dg14: dg14, override: override);
    });

    _challenges.remove(uid);
    return result;
  }

  Future<ProtoChallenge> _fetchChallenge(final UserId uid) async {
    final t = DateTime.now();
    // if tidy-up time, remove any expired challenge
    if (_ttime.isBefore(t.subtract(_tint))) {
      _challenges.keys
      .where((k) => _challenges[k]!.expires.compareTo(t) <= 0)
      .toList()
      .forEach(_challenges.remove);
      _ttime = t;
    }

    var c = _challenges[uid];
    if (c == null || c.expires.compareTo(t) <= 0) {
      _log.debug('Requesting new challenge for uid=$uid');
      c = await _api.getChallenge(uid);
      _log.debug('Received challenge for uid=$uid: ${c.data.hex()}');
      _challenges[uid] = c;
    }
    return c;
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