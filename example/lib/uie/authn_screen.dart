//  Created by Crt Vavros, copyright © 2021 ZeroPass. All rights reserved.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity/connectivity.dart';
import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:open_settings/open_settings.dart';
import 'package:port/port.dart';

import '../passport_scanner.dart';
import '../preferences.dart';
import '../srv_sec_ctx.dart';
import '../utils.dart';
import 'efdg1_dialog.dart';
import 'flat_btn_style.dart';
import 'success_screen.dart';
import 'uiutils.dart';

enum PortAction { register, login }

class AuthnScreen extends StatefulWidget {
  final PortAction _action;
  AuthnScreen(this._action, {Key? key}) : super(key: key);
  _AuthnScreenState createState() => _AuthnScreenState(_action);
}


class _AuthnScreenState extends State<AuthnScreen>
    with WidgetsBindingObserver {
  _AuthnScreenState(this._action);

  final PortAction _action;
  final _log = Logger('action.screen');
  PortClient? _port;

  var _isNfcAvailable = false;
  var _isScanningMrtd = false;

  final GlobalKey _keyNfcAlert = GlobalKey();
  bool _isBusyIndicatorVisible = false;
  final GlobalKey<State> _keyBusyIndicator =
      GlobalKey<State>(debugLabel: 'key_action_screen_busy_indicator');

  // mrz data
  final _mrzData = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _docNumber = TextEditingController();
  final _dob = TextEditingController(); // date of birth
  final _doe = TextEditingController(); // date of doc expiry

  // UI components
  IconButton? _settingsButton;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);

    final httpClient = ServerSecurityContext
      .getHttpClient(timeout: Preferences.getConnectionTimeout())
      ..badCertificateCallback = badCertificateHostCheck;

     _updateNfcStatus().then((value) async {
        if(!_isNfcAvailable) {
          await _showNfcAlert();
          if(!_isNfcAvailable) {
            return;
          }
        }

        unawaited(_showBusyIndicator().then((value) async {
          try {
            // Init PortClient
            _port = PortClient(Preferences.getServerUrl(), httpClient: httpClient);
            _port!.onConnectionError  = _handleConnectionError;
            await _port!.ping(Random().nextInt(0xffffffff));
            unawaited(_hideBusyIndicator());
          } catch(e) {
            String? alertTitle;
            String? alertMsg;
            if (e is SocketException) {} // should be already handled through _handleConnectionError callback
            else {
              _log.error('An unhandled exception was encountered, closing this screen.\n error=$e');
              alertTitle = 'Error';
              alertMsg = (e is Exception)
                ? e.toString().split('Exception: ').first
                : 'An unknown error has occurred.';
            }

            // Show alert dialog
            if(alertMsg != null && alertTitle != null) {
              await showAlert(context, Text(alertTitle), Text(alertMsg), [
                TextButton(
                  style: flatButtonStyle,
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'MAIN MENU',
                    style: TextStyle(
                        color: Theme.of(context).errorColor,
                        fontWeight: FontWeight.bold),
                  ))
              ]);
            }

            // Return to main menu
            _goToMain();
          }
        }));
     });
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    final uid = _uid();
    if (uid != null) {
      _port?.disposeChallenge(uid);
    }
    _username.dispose();
    _docNumber.dispose();
    _dob.dispose();
    _doe.dispose();
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _log.debug('App resumed, updating NFC status');
      await _updateNfcStatus();
      if(!_isNfcAvailable) {
        _log.debug('NFC is disabled showing alert');
        unawaited(_showNfcAlert());
      }
      else {
        _hideNfcAlert();
      }
    }
  }

  @override
  void didChangeLocales(List<Locale>? locale) {
    super.didChangeLocales(locale);
  }

  @override
  Widget build(BuildContext context) {
    _settingsButton = settingsButton(
      context,
      onWillPop: (){
        final timeout = Preferences.getConnectionTimeout();
        final url = Preferences.getServerUrl();
        _log.verbose('Updating client timeout=$timeout url=$url');
        _port!.timeout = timeout;
        _port!.url     = url;
    } as Future<void> Function()?);

    return Scaffold(
            backgroundColor: Theme.of(context).backgroundColor,
            appBar: AppBar(
                elevation: 1.0,
                title: Text(_action == PortAction.register ? 'Sign Up' : 'Login'),
                backgroundColor: Theme.of(context).cardColor,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios),
                  tooltip: 'Back',
                  onPressed: () => _goToMain(),
                ),
                actions: <Widget>[
                 _settingsButton!
                ],
            ),
            body: Container(
                //height: MediaQuery.of(context).size.height,
                decoration: BoxDecoration(
                  color: Theme.of(context).backgroundColor,
                ),
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Card(
                        elevation: 1.0,
                        shape: RoundedRectangleBorder(
                            side: const BorderSide(color: Color(0xff0c0c0c)),
                            borderRadius: BorderRadius.circular(5.0)),
                        child: SingleChildScrollView(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                              const ListTile(
                                leading: Icon(Icons.nfc),
                                title: Text('Passport information'),
                              ),
                              const SizedBox(height: 20),
                              _buildForm(context),
                              const SizedBox(height: 20),
                              makeButton(
                                context: context,
                                text: 'SCAN PASSPORT',
                                disabled: _disabledInput(),
                                visible: _mrzData.currentState?.validate() ?? false,
                                onPressed: _scan,
                              ),
                              const SizedBox(height: 16),
                            ]))))));
  }

  Padding _buildForm(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 30.0),
        child: Form(
          key: _mrzData,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                enabled: !_disabledInput(),
                controller: _username,
                keyboardAppearance: Brightness.dark,
                decoration: const InputDecoration(labelText: 'Username'),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[a-z]+')),
                  LengthLimitingTextInputFormatter(20)
                ],
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.none,
                autofocus: true,
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              makeButton(
                context: context,
                text: 'FILL FROM STORAGE',
                padding: null,
                disabled: _disabledInput(),
                visible:  Preferences.getDBAKeys() != null && !(_mrzData.currentState?.validate() ?? false),
                onPressed: () {
                  final keys = Preferences.getDBAKeys();
                  if(keys != null) {
                    setState(() {
                      _docNumber.text = keys.mrtdNumber;
                      final locale = getLocaleOf(context);
                      _dob.text = formatDate(keys.dateOfBirth, locale: locale);
                      _doe.text = formatDate(keys.dateOfExpiry, locale: locale);
                    });
                  }
                }
              ),
              const SizedBox(height: 20),
              TextFormField(
                enabled: !_disabledInput(),
                controller: _docNumber,
                keyboardAppearance: Brightness.dark,
                decoration: const InputDecoration(labelText: 'Passport number'),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]+')),
                  LengthLimitingTextInputFormatter(14)
                ],
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter passport number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                  enabled: !_disabledInput(),
                  controller: _dob,
                  decoration: const InputDecoration(labelText: 'Date of Birth'),
                  autofocus: false,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Please select Date of Birth';
                    }
                    return null;
                  },
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    // Can pick date which dates 15 years back or more
                    final now = DateTime.now();
                    final firstDate =
                        DateTime(now.year - 90, now.month, now.day);
                    final lastDate =
                        DateTime(now.year - 15, now.month, now.day);
                    final initDate = _getDOBDate();
                    final date = await pickDate(context, firstDate,
                        initDate ?? lastDate, lastDate);

                    FocusScope.of(context).requestFocus(FocusNode());
                    if (date != null) {
                      final locale = getLocaleOf(context);
                      _dob.text = formatDate(date, locale: locale);
                    }
                  }),
              const SizedBox(height: 12),
              TextFormField(
                enabled: !_disabledInput(),
                controller: _doe,
                decoration:
                    const InputDecoration(labelText: 'Date of Expiry'),
                autofocus: false,
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please select Date of Expiry';
                  }
                  return null;
                },
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  // Can pick date from tomorrow and up to 10 years
                  final now = DateTime.now();
                  final firstDate =
                      DateTime(now.year, now.month, now.day + 1);
                  final lastDate =
                      DateTime(now.year + 10, now.month + 6, now.day);
                  final initDate = _getDOEDate();
                  final date = await pickDate(context, firstDate,
                      initDate ?? firstDate, lastDate);

                  FocusScope.of(context).requestFocus(FocusNode());
                  if (date != null) {
                    final locale = getLocaleOf(context);
                    _doe.text = formatDate(date, locale: locale);
                  }
              }),

            ],
          ),
        ));
  }

  bool _disabledInput() {
    return _isScanningMrtd || !_isNfcAvailable;
  }

  UserId? _uid() {
    if (_username.text.isEmpty) {
      return null;
    }
    return UserId.fromString(_username.text);
  }

  DateTime? _getDOBDate() {
    if (_dob.text.isEmpty) {
      return null;
    }
    return DateFormat.yMd().parse(_dob.text);
  }

  DateTime? _getDOEDate() {
    if (_doe.text.isEmpty) {
      return null;
    }
    return DateFormat.yMd().parse(_doe.text);
  }

  void _goToMain() {
    Navigator.popUntil(context, (route) {
      if(route.settings.name == '/') {
        return true;
      }
      return false;
    });
  }

  // Returns true if client should retry connection action
  // otherwise false.
  Future<bool> _handleConnectionError(final SocketException e) async {
    String title;
    String msg;
    Function settingsAction;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none ||
     !await testConnection()) {
      settingsAction = () => OpenSettings.openWIFISetting();
      title = 'No Internet connection';
      msg   = 'Internet connection is required in order to '
              "${_action == PortAction.register ? "sign up" : "login"}.";
    }
    else {
      settingsAction = () => _settingsButton!.onPressed!();
      title = 'Connection error';
      msg   = 'Failed to connect to server.\n'
              'Check server connection settings.';
    }

    return showAlert<bool>(context,
      Text(title),
      Text(msg),
      [
        TextButton(
          style: flatButtonStyle,
          child: Text('MAIN MENU',
            style: TextStyle(
                color: Theme.of(context).errorColor,
                fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.pop(context, false)
        ),
        TextButton(
          style: flatButtonStyle,
          child: const Text(
            'SETTINGS',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: settingsAction as void Function()?,
        ),
        TextButton(
          style: flatButtonStyle,
          child: const Text(
            'RETRY',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context, true)
        )
      ]
    ) as Future<bool>;
  }

  Future<void> _showBusyIndicator({String msg = 'Please Wait ....'}) async {
    await _hideBusyIndicator();
    await showBusyDialog(context, _keyBusyIndicator, msg: msg);
    _isBusyIndicatorVisible = true;
  }

  Future<void> _hideBusyIndicator({ Duration syncWait = const Duration(milliseconds: 200)}) async {
    if (_keyBusyIndicator.currentContext != null) {
      await hideBusyDialog(_keyBusyIndicator,
          syncWait: syncWait);
      _isBusyIndicatorVisible = false;
    } else if (_isBusyIndicatorVisible) {
      await Future.delayed(const Duration(milliseconds: 200), () async {
        await _hideBusyIndicator();
      });
    }
  }

  Future<void> _showNfcAlert() async {
    if (_keyNfcAlert.currentContext == null) {
      await showAlert(context,
        Text('NFC disabled'),
        Text('NFC adapter is required to be enabled.'),
        [
          TextButton(
            style: flatButtonStyle,
            child: Text('MAIN MENU',
                style: TextStyle(
                    color: Theme.of(context).errorColor,
                    fontWeight: FontWeight.bold)),
            onPressed: () => _goToMain()
          ),
          TextButton(
            style: flatButtonStyle,
            child: const Text(
              'SETTINGS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => OpenSettings.openMainSetting(),
          )
        ],
        key: _keyNfcAlert
      );
    }
  }

  void _hideNfcAlert() async {
    if (_keyNfcAlert.currentContext != null) {
      Navigator.of(_keyNfcAlert.currentContext!, rootNavigator: true).pop();
    }
  }

  Future<PassportData> _scanPassport({ProtoChallenge? challenge}) async {
    try {
      setState(() {
        _isScanningMrtd = true;
      });

      final dbaKeys = DBAKeys(_docNumber.text, _getDOBDate()!, _getDOEDate()!);
      final data = await PassportScanner(
        context: context,
        challenge: challenge,
        action: _action
      ).scan(dbaKeys);
      await Preferences.setDBAKeys(dbaKeys);  // Save MRZ data
      return data;
    } //catch(e) {} // ignore: empty_catches
    finally {
      setState(() {
        _isScanningMrtd = false;
      });
    }
  }

  Future<void> _scan() async {
    try {
      // Execute authn action on Port client
      Map<String, dynamic> srvResult;
      switch(_action) {
        case PortAction.register:
          unawaited(_hideBusyIndicator());
          var passdata = await _scanPassport();
          srvResult = await _port!.register(_uid()!, passdata.sod!, dg15: passdata.dg15, dg14: passdata.dg14);
          break;
        case PortAction.login:
          srvResult = await _port!.getAssertion(_uid()!, (challenge) async {
              unawaited(_hideBusyIndicator());
              return _scanPassport(challenge: challenge).then((data) {
                _showBusyIndicator(msg: 'Logging in ...');
                return data.csig!;
              });
          });
        break;
      }

      String? srvMsg;
      if (srvResult.isNotEmpty) {
        srvMsg = jsonEncode(srvResult);
      }

      await Navigator.pushReplacement(
        context, CupertinoPageRoute(
          builder: (context) => SuccessScreen(_action, _uid()!, srvMsg),
      ));
    }
    on PassportScannerError {/* Should be handled by scanner*/} // ignore: empty_catches
    catch(e) {
      String? alertTitle;
      String? alertMsg;
      bool justClose = false;
      if (e is SocketException) {} // should be already handled through _handleConnectionError callback
      else if(e is PortError) {
        _log.error('An unhandled Port exception, closing this screen.\n error=$e');
        alertTitle = 'Port Error';

        // ignore_for_file: curly_braces_in_flow_control_structures
        if (e == PortError.accountAlreadyRegistered)              alertMsg = 'Account already exists!';
        else if (e == PortError.accountAttestationExpired)        alertMsg = 'Account attestation has expired!';
        else if (e == PortError.accountNotAttested)               alertMsg = 'Account not attested!';
        else if (e == PortError.accountNotFound)                  {alertMsg = 'Account not registered!'; if (_action == PortAction.login) justClose = true;}
        else if (e == PortError.challengeExpired)                 alertMsg = 'Protocol challenge has expired!';
        else if (e == PortError.challengeNotFound)                alertMsg = 'Protocol challenge was not found!';
        else if (e == PortError.challengeVerificationFailed)      alertMsg = 'Protocol challenge verification failed!';
        else if (e == PortError.countryCodeMismatch)              alertMsg = 'Provided passport can\'t be used to attest ${_uid()}!';
        else if (e == PortError.cscaNotFound)                     alertMsg = 'Server is missing CSCA certificate which issued provided passport!';
        else if (e == PortError.dscNotFound)                      alertMsg = 'Server is missing DSC certificate which issued provided passport!';
        else if (e == PortError.efDg14MissingAAInfo)              alertMsg = 'Provided passport is missing data crucial for verifying passport signature!';
        else if (e == PortError.efSodMatch)                       alertMsg = 'Provided passport was already used to attest another account!';
        else if (e == PortError.efSodNotGenuine)                  alertMsg = 'Provided passport is not genuine!';
        else if (e == PortError.invalidDataGroupFile(14))         alertMsg = 'Provided passport contains corrupted file(s)!'; // broken EF.DG14 file
        else if (e == PortError.invalidDataGroupFile(15))         alertMsg = 'Provided passport contains corrupted file(s)!'; // broken EF.DG15 file
        else if (e == PortError.invalidDsc)                       alertMsg = 'DSC certificate which issued provided passport is not genuine!';
        else if (e == PortError.invalidEfSod)                     alertMsg = 'Non-conformant passport!';
        else if (e == PortError.trustchainCheckFailedExpiredCert) alertMsg = 'Expired certificate in the trustchain!';
        else if (e == PortError.trustchainCheckFailedRevokedCert) alertMsg = 'Revoked certificate in the trustchain!';
        else if (e == PortError.trustchainCheckFailedNoCsca)      alertMsg = 'Server couldn\'t verify trustchain of provided passport due to missing issuer CSCA certificate!';
        else if (e.code == PortError.ecServerError)               alertMsg = 'Internal server error!';
        else                                                      alertMsg = 'Server returned error:\n\n${e.message}';
      }
      else if (e is HttpException) {
        _log.error('HttpConnection error has occurred\n error=$e');
        alertTitle = 'Http Error';
        alertMsg = e.message;
      }
      else {
        _log.error('Unhandled exception was encountered, closing this screen.\n error=$e');
        alertTitle = 'Error';
        alertMsg = (e is Exception)
          ? e.toString().split('Exception: ').last
          : 'Unknown error has occurred.';
      }

      // Show alert dialog
      if(alertMsg != null && alertTitle != null) {
        await showAlert(context, Text(alertTitle), Text(alertMsg), [
          TextButton(
            style: flatButtonStyle,
            onPressed: () => Navigator.pop(context),
            child: Text(
              justClose ? 'OK' : 'MAIN MENU',
              style: TextStyle(
                  color: Theme.of(context).errorColor,
                  fontWeight: FontWeight.bold),
            ))
        ]);
      }

      // Return to main menu
      if (!justClose) _goToMain();
    }
  }

  Future<void> _updateNfcStatus() async {
    bool isNfcAvailable;
    try {
      var status = await NfcProvider.nfcStatus;
      isNfcAvailable = (status == NfcStatus.enabled);
    } on PlatformException {
      isNfcAvailable = false;
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _isNfcAvailable = isNfcAvailable;
    });
  }
}