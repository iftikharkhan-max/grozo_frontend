import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:grozo/utils/constants.dart';
import 'package:grozo/services/api.dart';

class LocationService {
  StreamSubscription<Position>? _positionStreamSubscription;
  WebSocketChannel? _channel;

  /// Current position, or null when location is off, refused or unavailable.
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 20));
    } catch (_) {
      // e.g. GPS timeout or a platform error: treat as "no location".
      return null;
    }
  }

  int? _trackingOrderId;
  int? get trackingOrderId => _trackingOrderId;

  /// Starts streaming live coordinates to the backend via WebSockets.
  /// The server keeps only the latest position for the customer of [orderId].
  /// Returns false when location is off or refused (nothing is shared).
  Future<bool> startTrackingRider(int orderId, int riderId) async {
    if (_trackingOrderId == orderId) return true;
    stopTracking();
    // Location permission is needed before the position stream can start.
    if (await getCurrentLocation() == null) return false;
    _trackingOrderId = orderId;
    final uri = Uri.parse(Config.wsUrl);
    _channel = WebSocketChannel.connect(
      Api.token == null ? uri : uri.replace(queryParameters: {'token': Api.token}),
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Fire every 10 meters changed
      ),
    ).listen((Position position) {
      final telemetryData = {
        "type": "location_update",
        "orderId": orderId,
        "riderId": riderId,
        "latitude": position.latitude,
        "longitude": position.longitude,
        "timestamp": DateTime.now().toIso8601String(),
      };

      // Push tracking payload through the pipe
      _channel?.sink.add(jsonEncode(telemetryData));
    }, onError: (_) {}); // GPS hiccups must not crash the rider screen
    return true;
  }

  /// Stops tracking updates and cleanly severs websocket pipes
  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _channel?.sink.close();
    _channel = null;
    _trackingOrderId = null;
  }
}