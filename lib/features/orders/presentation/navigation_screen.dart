import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
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

/// Full-screen dedicated turn-by-turn navigation screen (Rapido / Google Maps style).
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
  GoogleNavigationViewController? _controller;

  bool _sessionReady = false;
  bool _guidanceStarted = false;
  bool _arrived = false;
  LatLng _driverLoc = const LatLng(latitude: 28.6180, longitude: 77.3620);
  bool _driverLocInitialized = false;

  double? _routeDistanceMeters;
  int? _routeDurationSeconds;
  Polyline? _bluePolyline;
  Marker? _driverMarker;
  Marker? _destinationMarker;

  List<_ManeuverStep> _steps = [];
  int _currentStepIndex = 0;

  StreamSubscription<OnArrivalEvent>? _arrivalSub;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  @override
  void dispose() {
    _arrivalSub?.cancel();
    _positionSub?.cancel();
    GoogleMapsNavigator.stopGuidance().catchError((_) => null);
    GoogleMapsNavigator.clearDestinations().catchError((_) => null);
    super.dispose();
  }

  Future<void> _initSession() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Fast seed driver position
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        _driverLoc = LatLng(latitude: lastKnown.latitude, longitude: lastKnown.longitude);
        _driverLocInitialized = true;
      }

      // Start position stream for live movement update
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_onLocationUpdate);

      if (!await GoogleMapsNavigator.isInitialized()) {
        await GoogleMapsNavigator.initializeNavigationSession(
          taskRemovedBehavior: TaskRemovedBehavior.continueService,
        ).catchError((_) => null);
      }

      _arrivalSub = GoogleMapsNavigator.setOnArrivalListener(_onArrival);

      if (mounted) setState(() => _sessionReady = true);
    } catch (e) {
      debugPrint('[NAV] Init session error: $e');
      if (mounted) setState(() => _sessionReady = true);
    }
  }

  void _onLocationUpdate(Position pos) {
    if (!mounted) return;
    setState(() {
      _driverLoc = LatLng(latitude: pos.latitude, longitude: pos.longitude);
      _driverLocInitialized = true;
    });

    _syncMarkersAndCamera();
    _updateActiveStep();

    // Check if driver reached destination (< 35 meters)
    final distanceToDest = Geolocator.distanceBetween(
      _driverLoc.latitude,
      _driverLoc.longitude,
      widget.destination.latitude,
      widget.destination.longitude,
    );

    if (distanceToDest < 35 && !_arrived) {
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

  Future<void> _startNavigation() async {
    if (_guidanceStarted) return;
    try {
      // 1. Seed location to simulator if available
      try {
        await GoogleMapsNavigator.simulator.setUserLocation(_driverLoc);
      } catch (_) {}

      // 2. Set native destinations
      try {
        final status = await GoogleMapsNavigator.setDestinations(
          Destinations(
            waypoints: [
              NavigationWaypoint.withLatLngTarget(
                title: widget.destinationTitle,
                target: widget.destination,
              ),
            ],
            displayOptions: NavigationDisplayOptions(showDestinationMarkers: true),
          ),
        );
        debugPrint('[NAV] Native setDestinations status: $status');
        await GoogleMapsNavigator.startGuidance();
      } catch (e) {
        debugPrint('[NAV] Native guidance error: $e');
      }

      // 3. Enable Native UI controls & Camera Following (Tilted Perspective)
      await _controller?.setNavigationUIEnabled(true);
      await _controller?.setNavigationHeaderEnabled(true);
      await _controller?.setNavigationFooterEnabled(true);
      await _controller?.setRecenterButtonEnabled(true);
      await _controller?.followMyLocation(CameraPerspective.tilted);

      // 4. Fetch real road polyline & step maneuvers from Routes API
      await _fetchAndDrawRoadRoute();

      // 5. Start simulator movement if testing
      try {
        await GoogleMapsNavigator.simulator.simulateLocationsAlongExistingRoute();
      } catch (_) {}
    } catch (e) {
      debugPrint('[NAV] Start navigation error: $e');
    } finally {
      if (mounted) setState(() => _guidanceStarted = true);
    }
  }

  Future<void> _fetchAndDrawRoadRoute() async {
    try {
      const apiKey = 'AIzaSyDEDoT1AQ6WHDZurqMT0bLnfIXLu7DxA4U';
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
          'X-Goog-Api-Key': apiKey,
          'X-Goog-LanguageCode': 'en-US',
          'X-Goog-FieldMask':
              'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline,routes.legs.steps.navigationInstruction,routes.legs.steps.distanceMeters,routes.legs.steps.startLocation,routes.legs.steps.endLocation',
        },
        body: body,
      ).timeout(const Duration(seconds: 6));

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
                  startLoc: LatLng(latitude: startLat, longitude: startLng),
                  endLoc: LatLng(latitude: endLat, longitude: endLng),
                ));
              }
            }
          }

          setState(() {
            if (dist != null) _routeDistanceMeters = dist;
            if (durSec > 0) _routeDurationSeconds = durSec;
            _steps = stepsList;
            _currentStepIndex = 0;
          });

          if (encoded != null) await _drawBlueRoadPolyline(_decodePolyline(encoded));
        }
      } else {
        _drawFallbackDirectPolyline();
      }
    } catch (e) {
      debugPrint('[NAV] Routes API fetch error: $e');
      _drawFallbackDirectPolyline();
    }
  }

  void _drawFallbackDirectPolyline() {
    final dist = Geolocator.distanceBetween(
      _driverLoc.latitude,
      _driverLoc.longitude,
      widget.destination.latitude,
      widget.destination.longitude,
    );
    setState(() {
      _routeDistanceMeters = dist;
      _routeDurationSeconds = (dist / 1000 / 25 * 3600).round();
    });
    _drawBlueRoadPolyline([_driverLoc, widget.destination]);
  }

  Future<void> _drawBlueRoadPolyline(List<LatLng> points) async {
    final controller = _controller;
    if (controller == null || points.isEmpty) return;
    try {
      if (_bluePolyline != null) {
        await controller.removePolylines([_bluePolyline!]);
        _bluePolyline = null;
      }
      final added = await controller.addPolylines([
        PolylineOptions(
          points: points,
          strokeWidth: 8.0,
          strokeColor: const Color(0xFF0066FF),
          zIndex: 10,
          geodesic: true,
        ),
      ]);
      if (added.isNotEmpty) _bluePolyline = added.first;
    } catch (e) {
      debugPrint('[NAV] Blue polyline draw failed: $e');
    }
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
      points.add(LatLng(latitude: lat / 1e5, longitude: lng / 1e5));
    }
    return points;
  }

  Future<void> _syncMarkersAndCamera() async {
    final controller = _controller;
    if (controller == null || !_driverLocInitialized) return;

    try {
      final driverIcon = MapPins.driver;
      if (driverIcon != null) {
        final options = MarkerOptions(
          position: _driverLoc,
          icon: driverIcon,
          anchor: const MarkerAnchor(u: 0.5, v: 0.5),
          flat: true,
          zIndex: 5.0,
        );
        if (_driverMarker == null) {
          final added = await controller.addMarkers([options]);
          if (added.isNotEmpty) _driverMarker = added.first;
        } else {
          final updated = await controller.updateMarkers([_driverMarker!.copyWith(options: options)]);
          if (updated.isNotEmpty) _driverMarker = updated.first;
        }
      }

      final pickupIcon = MapPins.pickup;
      if (pickupIcon != null && _destinationMarker == null) {
        final added = await controller.addMarkers([
          MarkerOptions(
            position: widget.destination,
            icon: pickupIcon,
            anchor: const MarkerAnchor(u: 0.5, v: 1.0),
            zIndex: 4.0,
          ),
        ]);
        if (added.isNotEmpty) _destinationMarker = added.first;
      }
    } catch (e) {
      debugPrint('[NAV] Sync markers error: $e');
    }
  }

  void _recenterCamera() {
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _driverLoc,
          zoom: 17,
        ),
      ),
    );
    _controller?.followMyLocation(CameraPerspective.tilted);
  }

  void _onArrival(OnArrivalEvent event) {
    if (!mounted) return;
    setState(() => _arrived = true);
  }

  Future<void> _exitNavigation({required bool reached}) async {
    try {
      await GoogleMapsNavigator.stopGuidance();
      await _controller?.setNavigationUIEnabled(false);
      await GoogleMapsNavigator.clearDestinations();
    } catch (_) {}
    if (mounted) Navigator.pop(context, reached);
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

    if (!_sessionReady) {
      return const Scaffold(
        backgroundColor: Color(0xFF090A0F),
        body: Center(child: CircularProgressIndicator(color: kCyan)),
      );
    }

    final durationMin = ((_routeDurationSeconds ?? 120) / 60).ceil();
    final etaTimeStr = _formatEtaTime(_routeDurationSeconds);
    final distStr = _formatDistanceStr(_routeDistanceMeters);

    // Active maneuver & Next maneuver data
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
          // ── 1. Full-screen Interactive Navigation View ───────────────
          Positioned.fill(
            child: GoogleMapsNavigationView(
              key: const ValueKey('navigation_map_view'),
              onViewCreated: (controller) {
                _controller = controller;
                _startNavigation();
              },
              initialCameraPosition: CameraPosition(
                target: widget.destination,
                zoom: 16,
              ),
              initialNavigationUIEnabledPreference: NavigationUIEnabledPreference.automatic,
              initialZoomControlsEnabled: false,
              initialCompassEnabled: false,
              initialMapColorScheme: MapColorScheme.light,
            ),
          ),

          // ── 2. Top Turn-by-Turn Green Maneuver Banner (Rapido UI + Real Steps) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF046A38), // Rapido dark green banner
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

          // ── 3. Floating Re-center Button (Bottom-Left) ───────────────
          if (!_arrived)
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

          // ── 4. Bottom Rapido-Style ETA Card ──────────────────────────
          if (!_arrived)
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

          // ── 5. Reached Arrival Popup ──────────────────────────────────
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
