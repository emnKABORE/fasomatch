import 'package:flutter/cupertino.dart';

Future<T?> pushIOS<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    CupertinoPageRoute(builder: (_) => page),
  );
}

Future<T?> replaceIOS<T>(BuildContext context, Widget page) {
  return Navigator.of(context).pushReplacement<T, T>(
    CupertinoPageRoute(builder: (_) => page),
  );
}