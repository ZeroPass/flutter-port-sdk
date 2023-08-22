//  Created by Crt Vavros, copyright © 2021 ZeroPass. All rights reserved.

import 'package:flutter/material.dart';
import 'package:egport/uie/uiutils.dart';

Widget HomePage(
    BuildContext context, Function onSignupPressed, Function onLoginPressed) {
  return Container(
    height: MediaQuery.of(context).size.height,
    decoration: BoxDecoration(
      color: Colors.deepPurple,
      image: DecorationImage(
        colorFilter:
            ColorFilter.mode(Colors.black.withOpacity(0.13), BlendMode.dstATop),
        image: AssetImage('assets/images/mountains.jpg'),
        fit: BoxFit.cover,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        settingsButton(context, iconSize: 40.0),
        Container(
          padding: EdgeInsets.only(top: 100.0),
          child: Center(
            child: Image(
              image: AssetImage('assets/images/port.png'),
              fit: BoxFit.scaleDown,
              height: 70,
              width: 70,
              filterQuality: FilterQuality.high,
            )
          ),
        ),
        Container(
          padding: EdgeInsets.only(top: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'eg',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30.0,
                ),
              ),
              Text(
                'Port',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 30.0,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Container(
          width: MediaQuery.of(context).size.width,
          margin: const EdgeInsets.only(left: 30.0, right: 30.0, top: 150.0),
          alignment: Alignment.center,
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onSignupPressed as void Function()?,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20.0,
                      horizontal: 20.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'SIGN UP',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: MediaQuery.of(context).size.width,
          margin: const EdgeInsets.only(left: 30.0, right: 30.0, top: 30.0),
          alignment: Alignment.center,
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextButton(
                  onPressed: onLoginPressed as void Function()?,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20.0,
                      horizontal: 20.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'LOGIN',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}