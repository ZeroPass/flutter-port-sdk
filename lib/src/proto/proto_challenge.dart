//  Created by Crt Vavros, copyright © 2021 ZeroPass. All rights reserved.
import 'dart:typed_data';
import 'package:dmrtd/extensions.dart';

// Represents proto challenge id
class CID {
  static const _serKey = 'cid';
  final Uint8List value;

  CID(this.value) {
    if (value.length != 4) {
      throw ArgumentError.value(value, '', 'Invalid raw CID bytes length');
    }
  }

  factory CID.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey(_serKey)) {
      throw ArgumentError.value(json, 'json',
          "Can't construct CID from JSON, no key '$_serKey' in argument");
    }
    return CID((json[_serKey] as String).parseHex());
  }

  Map<String, dynamic> toJson() {
    return {_serKey: toString()};
  }

  int toInt() {
    return ByteData.view(value.buffer).getUint32(0, Endian.big);
  }

  @override
  String toString() => value.hex();
}

class ProtoChallenge {
  static const _serKeyChallenge = 'challenge';
  static const _serKeyExpires   = 'expires';

  final Uint8List data;
  final DateTime expires;


  CID get id {
    return CID(data.sublist(0, 4));
  }

  ProtoChallenge(this.data, this.expires) {
    if (data.length != 32) {
      throw ArgumentError.value(data, '', 'Invalid raw challenge bytes length');
    }
  }

  factory ProtoChallenge.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey(_serKeyChallenge)) {
      throw ArgumentError.value(json, 'json',
          "Can't construct ProtoChallenge from JSON, no key '$_serKeyChallenge' in argument");
    }
    else if (!json.containsKey(_serKeyExpires)) {
      throw ArgumentError.value(json, 'json',
          "Can't construct ProtoChallenge from JSON, no key '$_serKeyExpires' in argument");
    }

    final c = (json[_serKeyChallenge] as String).parseBase64();
    final e = json[_serKeyExpires] as int;
    return ProtoChallenge(c, DateTime.fromMillisecondsSinceEpoch(e * 1000));
  }

  /// Returns list of [chunkSize] big chunks of challenge bytes.
  List<Uint8List> getChunks(int chunkSize) {
    if(data.length % chunkSize != 0) {
      throw ArgumentError.value(chunkSize, null, 'Invalid chunk size');
    }

    final chunks = <Uint8List>[];
    for(var i = 0; i < data.length; i += chunkSize) {
      final c = data.sublist(i,  i + chunkSize);
      chunks.add(Uint8List.fromList(c));
    }
    return chunks;
  }

  Map<String, dynamic> toJson() {
    return {
      _serKeyChallenge: data.base64(),
       _serKeyExpires: (expires.millisecondsSinceEpoch * 0.001).toInt()
    };
  }
}