//  Created by Crt Vavros, copyright © 2021 ZeroPass. All rights reserved.
import 'dart:io';
import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/extensions.dart';
import 'package:logging/logging.dart';
import 'package:port/port.dart';

import 'rpc/jrpc.dart';
import 'rpc/jrpc_objects.dart';

import 'port_error.dart';
import 'proto_challenge.dart';
import 'uid.dart';

class PortApi {
  final _log = Logger('port.api');
  final JRPClient _rpc;
  static const String _apiPrefix = 'port.';

  Duration? get timeout => _rpc.httpClient.connectionTimeout;
  set timeout(Duration? timeout) => _rpc.httpClient.connectionTimeout = timeout;

  Uri get url => _rpc.url;
  set url(Uri url) => _rpc.url = url;

  String? get userAgent => _rpc.userAgent;
  set userAgent(String? agent) => _rpc.userAgent = agent;

  PortApi(Uri url, {HttpClient? httpClient}) :
     _rpc = JRPClient(url,
         httpClient: httpClient ?? HttpClient(),
         persistentConnection: false); //it should be false because server itself terminate connection

/******************************************** API CALLS *****************************************************/
/************************************************************************************************************/

  /// API: port.ping
  /// Sends [ping] and returns [pong] received from server.
  /// Can throw [JRPClientError], [PortError] and [SocketException] on connection errors.
  Future<int> ping(int ping) async {
    _log.debug('${_apiPrefix}ping($ping) =>');
    final resp = await _transceive(method: 'ping', params: {'ping': ping });
    _throwIfError(resp);

    final pong = resp['pong'] as int;
    _log.debug('${_apiPrefix}ping <= pong: $pong');
    return pong;
  }

  /// API: port.get_challenge
  /// Returns [ProtoChallenge] from server.
  /// Can throw [JRPClientError], [PortError] and [SocketException] on connection errors.
  Future<ProtoChallenge> getChallenge(final UserId uid, ) async {
    _log.debug('${_apiPrefix}get_challenge(uid=$uid) =>');
    final resp = await _transceive(method: 'get_challenge', params: {...uid.toJson()});
    _throwIfError(resp);

    final c = ProtoChallenge.fromJson(resp);
    _log.debug('${_apiPrefix}get_challenge <= challenge: ${c.data.hex()}');
    return c;
  }

  /// API: port.cancel_challenge
  /// Notifies server to discard previously requested [challenge].
  /// Any exception is suppressed e.g.[SocketException] on connection errors.
  Future<void> cancelChallenge(ProtoChallenge challenge) async {
    _log.debug('${_apiPrefix}cancel_challenge(challenge=${challenge.data.hex()}) =>');
    try {
      final params = { 'challenge' : challenge.data.base64() };
      await _transceive(method: 'cancel_challenge', params: params, notify: true);
    } catch(e) {
      _log.warning('An exception was encountered while notifying server to cancel challenge width cid=${challenge.id}.\n Error="$e"');
    }
  }

  /// API: port.register
  /// Returns [Dictionary] from server.
  /// Can throw [JRPClientError], [PortError] and [SocketException] on connection errors.
  Future<Map<String, dynamic>> register(final UserId uid, final EfSOD sod, {final EfDG15? dg15, final EfDG14? dg14, final bool? override}) async {
    _log.debug('${_apiPrefix}register() =>');
    final params = {
      ...uid.toJson(),
      'sod' : sod.toBytes().base64(),
      if(dg15 != null) 'dg15': dg15.toBytes().base64(),
      if(dg14 != null) 'dg14': dg14.toBytes().base64(),
      if(override != null) 'override': override
    };

    final resp = await _transceive(method: 'register', params: params);
    _throwIfError(resp);
    _log.debug('${_apiPrefix}register <= result: $resp');
    return resp;
  }

  /// API: port.get_assertion
  /// Returns [Dictionary] from server.
  /// Can throw [JRPClientError], [PortError] and [SocketException] on connection errors.
  Future<Map<String, dynamic>> getAssertion(final UserId uid, final CID cid, final ChallengeSignature csig) async {
    _log.debug('${_apiPrefix}getAssertion() =>');
    final params = {
      ...uid.toJson(),
      ...cid.toJson(),
      ...csig.toJson()
    };

    final resp = await _transceive(method: 'get_assertion', params: params);
    _throwIfError(resp);
    _log.debug('${_apiPrefix}getAssertion <= result: $resp');
    return resp;
  }

/******************************************** API CALLS END *************************************************/
/************************************************************************************************************/

  Future<dynamic> _transceive({ required String method, dynamic params, bool notify = false }) {
    final apiMethod = _apiPrefix + method;
    return _rpc.call(method: apiMethod, params: params, notify: notify);
  }

  void _throwIfError(dynamic resp) {
    if(resp is JRpcError) {
      throw PortError(resp.code, resp.message);
    }
  }
}
