import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:partner/core/map_pins.dart';
import 'package:partner/features/orders/presentation/booking_chat_screen.dart';

class _ManeuverStep {
  final String maneuver;
  final String instruction;
  final double distanceMeters;
  final LatLng startLoc;
  final LatLng endLoc;

  _ManeuverStep({
    required this.maneuver,
    required this.instruction,
    required this.distanceMeters,
    required this.startLoc,
    required this.endLoc,
  });
}

/// Full-screen dedicated turn-by-turn navigation screen using google_maps_flutter
/// + Google Routes API. Rapido-style maneuver banner + ETA card overlay.
class NavigationScreen extends StatefulWidget {
  final LatLng destination;
  final String destinationTitle; // 'Pickup' or 'Drop-off'
  final String orderId;
  final String peerName;

  const NavigationScreen({
    super.key,
    required this.destination,
    required this.destinationTitle,
    required this.orderId,
    required this.peerName,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _controller;

  bool _mapReady = false;
  bool _arrived = false;
  LatLng _driverLoc = const LatLng(28.6180, 77.3620);
  bool _driverLocInitialized = false;

  double? _routeDistanceMeters;
  int? _routeDurationSeconds;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  List<_ManeuverStep> _steps = [];
  int _currentStepIndex = 0;

  StreamSubscription<Position>? _positionSub;
  bool _routeFetched = false;

  static const _apiKey = 'AIzaSyDEDoT1AQ6WHDZurqMT0bLnfIXLu7DxA4U';

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) await Geolocator.openLocationSettings();

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Seed with last known for fast first paint
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _driverLoc = LatLng(lastKnown.latitude, lastKnown.longitude);
          _driverLocInitialized = true;
        });
      }

      // Live stream
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_onLocationUpdate);
    } catch (e) {
      debugPrint('[NAV] Location init error: $e');
    }
  }

  void _onLocationUpdate(Position pos) {
    if (!mounted) return;
    setState(() {
      _driverLoc = LatLng(pos.latitude, pos.longitude);
      _driverLocInitialized = true;
    });
    _updateDriverMarker();
    _updateActiveStep();
    _checkArrival();
  }

  void _checkArrival() {
    final dist = Geolocator.distanceBetween(
      _driverLoc.latitude,
      _driverLoc.longitude,
      widget.destination.latitude,
      widget.destination.longitude,
    );
    if (dist < 35 && !_arrived) {
      setState(() => _arrived = true);
    }
  }

  void _updateActiveStep() {
    if (_steps.isEmpty) return;
    int index = _currentStepIndex;
    while (index < _steps.length) {
      final distToEnd = Geolocator.distanceBetween(
        _driverLoc.latitude,
        _driverLoc.longitude,
        _steps[index].endLoc.latitude,
        _steps[index].endLoc.longitude,
      );
      if (distToEnd < 25 && (index + 1) < _steps.length) {
        index++;
      } else {
        break;
      }
    }
    if (index != _currentStepIndex && index < _steps.length) {
      setState(() => _currentStepIndex = index);
    }
  }

  /// Called once the GoogleMap is ready. Preloads custom pins, adds markers,
  /// fetches route, and starts camera follow.
  Future<void> _onMapCreated(GoogleMapController controller) async {
    _controller = controller;

    final dpr = MediaQuery.of(context).devicePixelRatio;
    await MapPins.preload(dpr);

    _addDestinationMarker();
    _updateDriverMarker();

    if (_driverLocInitialized) {
      _animateCameraToDriver();
    }

    if (!_routeFetched) {
      _routeFetched = true;
      await _fetchAndDrawRoadRoute();
    }

    if (mounted) setState(() => _mapReady = true);
  }

  void _addDestinationMarker() {
    final icon = MapPins.pickup ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'destination');
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: widget.destination,
        icon: icon,
        anchor: const Offset(0.5, 1.0),
        zIndexInt: 4,
      ));
    });
  }

  void _updateDriverMarker() {
    if (!mounted) return;
    final icon = MapPins.driver ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'driver');
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverLoc,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndexInt: 5,
      ));
    });
    _animateCameraToDriver();
  }

  void _animateCameraToDriver() {
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _driverLoc, zoom: 17, tilt: 45),
      ),
    );
  }

  void _recenterCamera() {
    _animateCameraToDriver();
  }

  Future<void> _fetchAndDrawRoadRoute() async {
    try {
      final uri = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
      final body = jsonEncode({
        'origin': {
          'location': {
            'latLng': {'latitude': _driverLoc.latitude, 'longitude': _driverLoc.longitude}
          }
        },
        'destination': {
          'location': {
            'latLng': {'latitude': widget.destination.latitude, 'longitude': widget.destination.longitude}
          }
        },
        'travelMode': 'TWO_WHEELER',
        'routingPreference': 'TRAFFIC_AWARE',
        'polylineQuality': 'HIGH_QUALITY',
        'languageCode': 'en',
      });

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-LanguageCode': 'en-US',
          'X-Goog-FieldMask':
              'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline,routes.legs.steps.navigationInstruction,routes.legs.steps.distanceMeters,routes.legs.steps.startLocation,routes.legs.steps.endLocation',
        },
        body: body,
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final dist = (routes[0]['distanceMeters'] as num?)?.toDouble();
          final durationStr = routes[0]['duration'] as String?;
          final encoded = routes[0]['polyline']?['encodedPolyline'] as String?;

          int durSec = 120;
          if (durationStr != null) {
            durSec = int.tryParse(durationStr.replaceAll('s', '')) ?? 120;
          }

          // Parse turn-by-turn steps
          final stepsList = <_ManeuverStep>[];
          final legs = routes[0]['legs'] as List?;
          if (legs != null && legs.isNotEmpty) {
            final stepsJson = legs[0]['steps'] as List?;
            if (stepsJson != null) {
              for (final s in stepsJson) {
                final navInst = s['navigationInstruction'];
                final maneuver = navInst?['maneuver'] as String? ?? 'STRAIGHT';
                String rawInstruction = navInst?['instructions'] as String? ?? '';
                if (rawInstruction.contains('\n')) {
                  rawInstruction = rawInstruction.split('\n').first;
                }
                final sDist = (s['distanceMeters'] as num?)?.toDouble() ?? 0.0;
                final startLat = (s['startLocation']?['latLng']?['latitude'] as num?)?.toDouble() ?? 0.0;
                final startLng = (s['startLocation']?['latLng']?['longitude'] as num?)?.toDouble() ?? 0.0;
                final endLat = (s['endLocation']?['latLng']?['latitude'] as num?)?.toDouble() ?? 0.0;
                final endLng = (s['endLocation']?['latLng']?['longitude'] as num?)?.toDouble() ?? 0.0;

                stepsList.add(_ManeuverStep(
                  maneuver: maneuver,
                  instruction: rawInstruction.isNotEmpty ? rawInstruction : 'Head toward ${widget.destinationTitle}',
                  distanceMeters: sDist,
                  startLoc: LatLng(startLat, startLng),
                  endLoc: LatLng(endLat, endLng),
                ));
              }
            }
          }

          if (mounted) {
            setState(() {
              if (dist != null) _routeDistanceMeters = dist;
              if (durSec > 0) _routeDurationSeconds = durSec;
              _steps = stepsList;
              _currentStepIndex = 0;
            });
          }

          if (encoded != null) _drawPolyline(_decodePolyline(encoded));
        }
      } else {
        _drawFallbackPolyline();
      }
    } catch (e) {
      debugPrint('[NAV] Routes API error: $e');
      _drawFallbackPolyline();
    }
  }

  void _drawFallbackPolyline() {
    final dist = Geolocator.distanceBetween(
      _driverLoc.latitude,
      _driverLoc.longitude,
      widget.destination.latitude,
      widget.destination.longitude,
    );
    if (mounted) {
      setState(() {
        _routeDistanceMeters = dist;
        _routeDurationSeconds = (dist / 1000 / 25 * 3600).round();
      });
    }
    _drawPolyline([_driverLoc, widget.destination]);
  }

  void _drawPolyline(List<LatLng> points) {
    if (!mounted || points.isEmpty) return;
    setState(() {
      _polylines
        ..removeWhere((p) => p.polylineId.value == 'route')
        ..add(Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: const Color(0xFF0066FF),
          width: 6,
          geodesic: true,
        ));
    });
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  void _exitNavigation({required bool reached}) {
    Navigator.pop(context, reached);
  }

  IconData _getManeuverIcon(String maneuver) {
    switch (maneuver.toUpperCase()) {
      case 'TURN_RIGHT':
      case 'RAMP_RIGHT':
      case 'FORK_RIGHT':
        return Icons.turn_right_rounded;
      case 'TURN_LEFT':
      case 'RAMP_LEFT':
      case 'FORK_LEFT':
        return Icons.turn_left_rounded;
      case 'TURN_SLIGHT_RIGHT':
        return Icons.turn_slight_right_rounded;
      case 'TURN_SLIGHT_LEFT':
        return Icons.turn_slight_left_rounded;
      case 'UTURN_RIGHT':
      case 'UTURN_LEFT':
        return Icons.u_turn_right_rounded;
      case 'ROUNDABOUT_RIGHT':
      case 'ROUNDABOUT_LEFT':
        return Icons.roundabout_right_rounded;
      case 'STRAIGHT':
      case 'DEPART':
      default:
        return Icons.arrow_upward_rounded;
    }
  }

  String _formatEtaTime(int? durationSeconds) {
    final now = DateTime.now().add(Duration(seconds: durationSeconds ?? 120));
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDistanceStr(double? meters) {
    if (meters == null) return '700 m';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    const kCardBg = Color(0xFF161A22);
    const kCyan = Color(0xFF22D3EE);

    final durationMin = ((_routeDurationSeconds ?? 120) / 60).ceil();
    final etaTimeStr = _formatEtaTime(_routeDurationSeconds);
    final distStr = _formatDistanceStr(_routeDistanceMeters);

    _ManeuverStep? activeStep = _steps.isNotEmpty && _currentStepIndex < _steps.length ? _steps[_currentStepIndex] : null;
    _ManeuverStep? nextStep = _steps.isNotEmpty && (_currentStepIndex + 1) < _steps.length ? _steps[_currentStepIndex + 1] : null;

    final double distToStepEnd = activeStep != null
        ? Geolocator.distanceBetween(
            _driverLoc.latitude,
            _driverLoc.longitude,
            activeStep.endLoc.latitude,
            activeStep.endLoc.longitude,
          )
        : (_routeDistanceMeters ?? 0.0);

    final turnDistStr = _formatDistanceStr(distToStepEnd);
    final turnIcon = activeStep != null ? _getManeuverIcon(activeStep.maneuver) : Icons.arrow_upward_rounded;
    final turnInstruction = activeStep != null ? activeStep.instruction : 'toward ${widget.destinationTitle}';

    final nextTurnIcon = nextStep != null ? _getManeuverIcon(nextStep.maneuver) : Icons.subdirectory_arrow_right_rounded;
    final nextTurnInstruction = nextStep != null ? nextStep.instruction : 'Continue on route';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. Full-screen Google Map ─────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              key: const ValueKey('navigation_map_view'),
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _driverLocInitialized ? _driverLoc : widget.destination,
                zoom: 16,
                tilt: 45,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              trafficEnabled: true,
              buildingsEnabled: true,
              mapType: MapType.normal,
            ),
          ),

          // Loading indicator while map initializes
          if (!_mapReady)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xFF090A0F),
                child: Center(child: CircularProgressIndicator(color: kCyan)),
              ),
            ),

          // ── 2. Top Turn-by-Turn Green Maneuver Banner ─────────────────
          if (_mapReady && !_arrived)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF046A38),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(turnIcon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'In $turnDistStr',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            turnInstruction,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF004429),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Then',
                                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 4),
                                Icon(nextTurnIcon, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    nextTurnInstruction,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── 3. Floating Re-center Button ──────────────────────────────
          if (_mapReady && !_arrived)
            Positioned(
              left: 16,
              bottom: 110,
              child: GestureDetector(
                onTap: _recenterCamera,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.navigation_rounded, color: Color(0xFF0066FF), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Re-center',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E2430),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── 4. Bottom ETA Card ────────────────────────────────────────
          if (_mapReady && !_arrived)
            Positioned(
              bottom: 16,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$durationMin min',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E2430),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$distStr  •  $etaTimeStr',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Chat button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingChatScreen(
                              bookingId: widget.orderId,
                              peerName: widget.peerName,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0066FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Close button
                    GestureDetector(
                      onTap: () => _exitNavigation(reached: false),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Color(0xFF374151), size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── 5. Arrived Popup ──────────────────────────────────────────
          if (_arrived)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          '${widget.destinationTitle} Reached',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You have arrived at the target location 🙌',
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _exitNavigation(reached: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
