import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether the delivery-location picker can use Google Maps: only on Android,
/// and only when the build has a Google Maps API key (android/key.properties,
/// `mapsApiKey=...`). Otherwise the picker uses OpenStreetMap.
class GoogleMapsConfig {
  static const _channel = MethodChannel('grozo/config');
  static bool? _available;

  static Future<bool> available() async {
    if (_available != null) return _available!;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _available = false;
    }
    try {
      _available = await _channel.invokeMethod<bool>('hasMapsKey') ?? false;
    } catch (_) {
      _available = false; // e.g. tests, or an older build without the channel
    }
    return _available!;
  }
}
