import 'package:flutter/services.dart';

/// Obtains a one-time device locality. Coordinates never leave the native
/// location lookup and are not stored by Gruhasthi.
class DeviceLocalityDetector {
  const DeviceLocalityDetector();

  static const _channel = MethodChannel('com.gruhasthi.gruhasthi/locality');

  Future<String> detect() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'detectLocality',
    );
    final locality = (result?['locality'] as String? ?? '').trim();
    if (locality.isEmpty) {
      throw PlatformException(
        code: 'LOCALITY_UNAVAILABLE',
        message: 'Your locality could not be determined.',
      );
    }
    return locality;
  }
}
