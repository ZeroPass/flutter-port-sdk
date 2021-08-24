//  Created by Crt Vavros, copyright © 2021 ZeroPass. All rights reserved.
import 'package:dmrtd/dmrtd.dart';
import 'proto/challenge_signature.dart';

/// Class holds biometric passport data needed for Port registration.
class RegistrationAuthnData {
  final EfSOD sod;
  final EfDG14? dg14;
  final EfDG15 dg15;
  final ChallengeSignature csig;
  RegistrationAuthnData({required this.sod, this.dg14, required this.dg15, required this.csig});
}
