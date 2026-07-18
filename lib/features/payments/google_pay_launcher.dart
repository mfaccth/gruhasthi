import 'dart:io';

import 'package:flutter/services.dart';

class GooglePayLauncher {
  static const _channel = MethodChannel('com.gruhasthi.gruhasthi/payment_apps');

  Future<bool> openManually() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openGooglePay') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
