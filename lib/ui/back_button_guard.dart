import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

mixin BackButtonGuard<T extends StatefulWidget> on State<T> {
  DateTime? _lastBackPressTime;

  Widget guard(Widget child) {
    return PopScope(
      canPop: ModalRoute.of(context)?.canPop ?? false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime != null &&
            now.difference(_lastBackPressTime!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
        } else {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: child,
    );
  }
}
