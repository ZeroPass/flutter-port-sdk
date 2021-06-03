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
import 'session.dart';
import 'uid.dart';


class PortApi {
  final _log = Logger('port.api');
  final JRPClient _rpc;
  static const String _apiPrefix = 'port.';

  Duration? get timeout => _rpc.httpClient.connectionTimeout;
  set timeout(Duration? timeout) => _rpc.httpClient.connectionTimeout = timeout;

  Uri get url => _rpc.url;
  set url(Uri url) => _rpc.url = url;

  PortApi(Uri url, {HttpClient? httpClient}) :
     _rpc = JRPClient(url, httpClient: httpClient ?? HttpClient());


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

  /// API: port.getChallenge
  /// Returns [ProtoChallenge] from server.
  /// Can throw [JRPClientError], [PortError] and [SocketException] on connection errors.
  Future<ProtoChallenge> getChallenge() async {
    _log.debug('${_apiPrefix}getChallenge() =>');
    final resp = await _transceive(method: 'getChallenge');
    _throwIfError(resp);

    final c = ProtoChallenge.fromJson(resp);
    _log.debug('${_apiPrefix}getChallenge <= challenge: ${c.data.hex()}');
    return c;
  }

  /// API: port.cancelChallenge
  /// Notifies server to discard previously requested [challenge].
  /// [SocketException] on connection errors.
  Future<void> cancelChallenge(ProtoChallenge challenge) async {
    _log.debug('${_apiPrefix}cancelChallenge(challenge=${challenge.data.hex()}) =>');
    try {
      await _transceive(method: 'cancelChallenge', params: challenge.toJson(), notify: true);
    } catch(e) {
      _log.warning('An exception was encountered while notifying server to cancel challenge.\n Error="$e"');
    }
  }

  /// API: port.login
  /// Returns [Session] from server.
  /// Can throw [JRPClientError], [PortError] and [SocketException] on connection errors.
  Future<Session> login(UserId uid, CID cid, ChallengeSignature csig, { EfDG1? dg1 }) async {
    _log.debug('${_apiPrefix}login() =>');
    final params = {
      ...uid.toJson(),
      ...cid.toJson(),
      ...csig.toJson(),
      if(dg1 != null) 'dg1': dg1.toBytes().base64()
    };

    final resp = await _transceive(method: 'login', params: params);
    _throwIfError(resp);

    final s = Session.fromJson(resp, uid: uid);
    _log.debug('${_apiPrefix}login <= session= $s');
    return s;
  }

  /// API: port.register
  /// Returns [Session] from server.
  /// Can throw [JRPClientError], [PortError] and [SocketException] on connection errors.
  Future<Session> register(final EfSOD sod, final EfDG15 dg15, final CID cid, final ChallengeSignature csig, {EfDG14? dg14}) async {
    _log.debug('${_apiPrefix}register() =>');
    final params = {
      'sod' : sod.toBytes().base64(),
      'dg15' : dg15.toBytes().base64(),
      ...cid.toJson(),
      ...csig.toJson(),
      if(dg14 != null) 'dg14': dg14.toBytes().base64()
    };

    final resp = await _transceive(method: 'register', params: params);
    _throwIfError(resp);

    final s = Session.fromJson(resp);
    _log.debug('${_apiPrefix}register <= session= $s');
    return s;
  }

  /// API: port.sayHello
  /// Returns [String] greeting message from server.
  /// Can throw [JRPClientError], [PortError] and [SocketException] on connection errors.
  Future<String> sayHello(Session session) async {
    _log.debug('${_apiPrefix}sayHello() => session=$session');

    final mac = session.calculateMAC(apiName: 'sayHello', rawParams: session.uid.toBytes());
    final params = {
      ...session.uid.toJson(),
      ...mac.toJson()
    };

    final resp = await _transceive(method: 'sayHello', params: params);
    _throwIfError(resp);

    final srvMsg = resp['msg'] as String;
    _log.debug('${_apiPrefix}register <= srvMsg="$srvMsg"');
    return srvMsg;
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
