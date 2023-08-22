//  Created by Crt Vavros, copyright © 2021 ZeroPass. All rights reserved.
import 'dart:io';

import 'package:dmrtd/dmrtd.dart';
import 'package:egport/uie/flat_btn_style.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart';
import 'package:egport/preferences.dart';
import 'package:flutter/services.dart';

import 'uie/authn_screen.dart';
import 'uie/home_page.dart';
import 'uie/uiutils.dart';
import 'srv_sec_ctx.dart';

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print(
        '${record.loggerName} ${record.level.name}: ${record.time}: ${record.message}');
  });

  WidgetsFlutterBinding.ensureInitialized();
  await Preferences.init();
  final rawSrvCrt = await rootBundle.load('assets/certs/port_server.cer');
  ServerSecurityContext.init(rawSrvCrt.buffer.asUint8List());
  runApp(EgPortApp());
}

class EgPortApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'egPort',
      localizationsDelegates: <LocalizationsDelegate>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      theme: ThemeData(
          disabledColor: Colors.black38,
          applyElevationOverlayColor: true,
          primaryColor: const Color(0xffeaeaea),
          //accentColor: const Color(0xffbb86fc),
          errorColor: const Color(0xffcf6679),
          cardColor: const Color(0xff121212),
          snackBarTheme: const SnackBarThemeData(
              backgroundColor: Color(0xff292929),
              contentTextStyle: TextStyle(color: Color(0xffeaeaea))),
          backgroundColor: const Color(0xff121212),
          //accentColorBrightness: Brightness.dark,
          brightness: Brightness.dark,
          primaryColorBrightness: Brightness.dark,
          inputDecorationTheme: InputDecorationTheme(
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.87), width: 2.0),
              ))),
      home: EgPortWidget(),
    );
  }
}

class EgPortWidget extends StatefulWidget {
  @override
  _EgPortWidgetState createState() => _EgPortWidgetState();
}

class _EgPortWidgetState extends State<EgPortWidget>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []); // hide status bar
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _checkNfcIsSupported();
  }

  void gotoLogin() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AuthnScreen(PortAction.login),
      ),
    );
  }

  void gotoSignup() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AuthnScreen(PortAction.register),
      ),
    );
  }

  void _checkNfcIsSupported() {
    NfcProvider.nfcStatus.then((status) {
      if (status == NfcStatus.notSupported ||
          (Platform.isIOS && status == NfcStatus.disabled)) {
        showAlert(
            context,
            Text('NFC not supported'),
            Text(
                "This device doesn't support NFC.\nNFC is required to use this app."),
            [
              TextButton(
                style: flatButtonStyle,
                onPressed: () {
                  if (Platform.isIOS) {
                    exit(0);
                  } else {
                    SystemNavigator.pop(animated: true);
                  }
                },
                child: Text('EXIT',
                    style: TextStyle(
                        color: Theme.of(context).errorColor,
                        fontWeight: FontWeight.bold)))
            ]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
            height: MediaQuery.of(context).size.height,
            child: HomePage(context, gotoSignup, gotoLogin)));
  }
}
