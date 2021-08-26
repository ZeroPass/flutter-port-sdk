//  Created by Crt Vavros, copyright © 2021 ZeroPass. All rights reserved.

class PortError implements Exception{
  // Possible Port error codes
  static const int ecGeneralError               = 400;
  static const int ecUnauthorized               = 401;
  static const int ecNotFound                   = 404;
  static const int ecConflict                   = 409; // Returned when trying to register with existing account
  static const int ecPreconditionFailed         = 412; // One or more condition in verification of eMRTD PKI trustchain failed e.g.: CSCA not found or expired ...
                                                       // Or when EfSOD doesn't contain DG file e.g.: DG1, DG15 ...
  static const int ecInvalidOrMissingParam      = 422; // Invalid or missing required protocol parameter (API call)
  static const int ecPreconditionRequired       = 428; // Returned when optional parameter in API call is required e.g. EfDG1, EfDG14
                                                       // or parameter doesn't contain required data e.g. EfDG14 not containing field 'ActiveAuthenticationInfo'
  static const int ecExpired                    = 498; // Signed challenge used in API call has expired
                                                       // or attestation has expired aka account expired
  static const int ecServerError                = 500; // Internal server error.

  // Predefined Port errors
  static const accountAlreadyRegistered         = PortError.conflict('Account already registered');
  static const accountNotAttested               = PortError.unauthorized('Account is not attested'); // If previous account attestation (aka registration) is not valid anymore
  static const accountNotFound                  = PortError.notFound('Account not found');
  static const accountAttestationExpired        = PortError.expired('Account attestation has expired');

  static const challengeExpired                 = PortError.expired('Challenge has expired');
  static const challengeExists                  = PortError.conflict('Challenge already exists');
  static const challengeNotFound                = PortError.notFound('Challenge not found');
  static const challengeVerificationFailed      = PortError.unauthorized('Challenge signature verification failed');

  static const countryCodeMismatch              = PortError.conflict('Country code mismatch'); // If an existing account tries to override attestation with EF.SOD
                                                                                               // issued by different country than previous attestation country.
  static const cscaExists                       = PortError.conflict('CSCA certificate already exists');
  static const cscaNotFound                     = PortError.notFound('CSCA certificate not found');
  static const cscaSelfIssued                   = PortError.notFound('No CSCA link was found for self-issued CSCA');
  static const cscaTooNewOrExpired              = PortError.invalidOrMissingParam('CSCA certificate is too new or has expired');

  static const crlOld                           = PortError.invalidOrMissingParam('Old CRL');
  static const crlTooNew                        = PortError.invalidOrMissingParam("Can't add future CRL");

  static const dscCantIssuePassport             = PortError.invalidOrMissingParam("DSC certificate can't issue biometric passport");
  static const dscExists                        = PortError.conflict('DSC certificate already exists');
  static const dscNotFound                      = PortError.notFound('DSC certificate not found');
  static const dscTooNewOrExpired               = PortError.invalidOrMissingParam('DSC certificate is too new or has expired');

  static const efDg14MissingAAInfo              = PortError.preconditionRequired('EF.DG14 file is missing ActiveAuthenticationInfo');
  static const efDg14Required                   = PortError.invalidOrMissingParam('EF.DG14 file required');
  static const efSodMatch                       = PortError.conflict('Matching EF.SOD file already registered'); // If the same or matching EF.SOD is already registered for account attestation.
  static const efSodNotGenuine                  = PortError.unauthorized('EF.SOD file not genuine');

  static const invalidCsca                      = PortError.invalidOrMissingParam('Invalid CSCA certificate');
  static const invalidCrl                       = PortError.invalidOrMissingParam('Invalid CRL file');        // When CRL doesn't conform to the ICAO 9303 standard or verification of the signature with the issuing CSCA certificate fails.
  static const invalidDsc                       = PortError.invalidOrMissingParam('Invalid DSC certificate'); // When CRL doesn't conform to the ICAO 9303 standard or verification of the signature with the issuing CSCA certificate fails.
  static const invalidEfSod                     = PortError.invalidOrMissingParam('Invalid EF.SOD file');     // If no valid signer is found for EF.SOD file, file is not signed or contains invalid signer infos.

  static const trustchainCheckFailedExpiredCert = PortError.preconditionFailed('Expired certificate in the trustchain');
  static const trustchainCheckFailedNoCsca      = PortError.preconditionFailed('Missing issuer CSCA certificate in the trustchain');
  static const trustchainCheckFailedRevokedCert = PortError.preconditionFailed('Revoked certificate in the trustchain');

  final int code;
  final String message;
  const PortError(this.code, this.message);

  const PortError.conflict(String error) : this(ecConflict, error);
  const PortError.expired(String error) : this(ecExpired, error);
  const PortError.generalError(String error) : this(ecGeneralError, error);
  const PortError.invalidOrMissingParam(String error) : this(ecInvalidOrMissingParam, error);
  const PortError.notFound(String error) : this(ecNotFound, error);
  const PortError.preconditionFailed(String error) : this(ecPreconditionFailed, error);
  const PortError.preconditionRequired(String error) : this(ecPreconditionRequired, error);
  const PortError.serverError(String error) : this(ecServerError, error);
  const PortError.unauthorized(String error) : this(ecUnauthorized, error);

  // Error returned by  server when file EF.SOD  doesn't contain hash of EF.DG file.
  factory PortError.invalidDataGroupFile(int dgNumber) {
    assert(dgNumber >= 1 && dgNumber <= 16);
    return PortError.invalidOrMissingParam('Invalid EF.DG$dgNumber file');
  }

  @override
  bool operator == (covariant PortError other) {
    return code == other.code && message == other.message;
  }

  @override
  String toString() => 'PortError(code=$code, error=$message)';
}