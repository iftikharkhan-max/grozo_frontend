import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:grozo/utils/constants.dart';
import 'package:grozo/services/api.dart';

class LocationService {
  StreamSubscription<Position>? _positionStreamSubscription;
  WebSocketChannel? _channel;

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  int? _trackingOrderId;
  int? get trackingOrderId => _trackingOrderId;

  /// Starts streaming live coordinates to the backend via WebSockets.
  /// The server keeps only the latest position for the customer of [orderId].
  Future<void> startTrackingRider(int orderId, int riderId) async {
    if (_trackingOrderId == orderId) return;
    stopTracking();
    // Location permission is needed before the position stream can start.
    if (await getCurrentLocation() == null) return;
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
    });
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