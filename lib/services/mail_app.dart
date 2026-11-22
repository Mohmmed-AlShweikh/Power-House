import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MailAppLauncher {
  static const channel = MethodChannel('generator_portal/platform');
  Future<bool> open() async {
    try {
      return await channel.invokeMethod<bool>('openMail') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

final mailAppProvider = Provider((_) => MailAppLauncher());
