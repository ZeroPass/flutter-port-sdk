//  Created by Crt Vavros, copyright © 2021 ZeroPass. All rights reserved.
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_cache_builder.dart';
import 'package:flare_flutter/provider/asset_flare.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:port/port.dart';
import 'package:egport/uie/uiutils.dart';
import 'authn_screen.dart';

class SuccessScreen extends StatelessWidget {
  final PortAction action;
  final UserId? uid;
  final String? serverMsg;

  final _successCheck =
      AssetFlare(bundle: rootBundle, name: 'assets/anim/success_check.flr');

  SuccessScreen(this.action, this.uid, this.serverMsg);

  void _goToMain(BuildContext context) {
    Navigator.popUntil(context, (route) {
      if (route.settings.name == '/') {
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        body: Container(
            child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Card(
                    child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                            (action == PortAction.register
                                    ? 'Sign up'
                                    : 'Login') +
                                ' succeeded',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 24)),
                        Expanded(
                            flex: 30,
                            child: FlareCacheBuilder(
                              [_successCheck],
                              builder: (BuildContext context, bool isWarm) {
                                return !isWarm
                                    ? Container()
                                    : FlareActor.asset(
                                        _successCheck,
                                        alignment: Alignment.center,
                                        fit: BoxFit.cover,
                                        animation: 'Untitled',
                                      );
                              },
                            )),
                        //Spacer(flex: 2),
                        if (serverMsg != null && serverMsg!.isNotEmpty)
                          Row(children: <Widget>[
                            Expanded(
                                child: Text('Server returned:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20)))
                          ]),
                        if (serverMsg != null && serverMsg!.isNotEmpty)
                          Text(serverMsg ?? '', style: TextStyle(fontSize: 18)),

                        Spacer(flex: 5),
                        makeButton(
                            context: context,
                            text: 'MAIN MENU',
                            onPressed: () => _goToMain(context)),
                        const SizedBox(height: 20),
                        Row(children: <Widget>[
                          Text('UID: '),
                          Text(uid.toString()),
                          // Expanded(
                          //     child: FittedBox(
                          //         fit: BoxFit.fitWidth,
                          //         child: Text(uid.toString())))
                        ]),
                      ]),
                )))));
  }
}
