//  Created by Crt Vavros, copyright © 2021 ZeroPass. All rights reserved.
import 'dart:convert';
import 'dart:typed_data';
import 'package:dmrtd/extensions.dart';

class UserId  {
  static const _serKey = 'uid';
  static const _maxLen = 20;
  late final Uint8List _uid;

  UserId(final Uint8List rawUid) {
    if(rawUid.isEmpty || rawUid.length > _maxLen) {
      throw ArgumentError.value(rawUid, 'rawUid', 'Invalid length');
    }
    _uid = rawUid;
  }

  factory UserId.fromJson(final Map<String, dynamic> json) {
    if (!json.containsKey(_serKey)) {
    throw ArgumentError.value(json, 'json',
      "Can't construct UserId from JSON, no key '$_serKey' in argument");
    }
    return UserId((json[_serKey] as String).parseBase64());
  }

  /// Creates UserId from regular string.
  /// Internally [uid] is UTF-8 encoded.
  factory UserId.fromString(final String uid) {
    return UserId(Uint8List.fromList(utf8.encode(uid)));
  }

  Uint8List toBytes() => _uid;

  Map<String, dynamic> toJson() {
    return {_serKey: _uid.base64()};
  }

  @override
  String toString() {
    try {
      return utf8.decode(_uid, allowMalformed: false);
    }
    catch(_) {
      return _uid.hex();
    }
  }
}