import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
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
///
/// v2 — proper turn-by-turn:
///  * Step tracking is ROUTE-PROGRESS based (snapped to polyline), not
///    "am I within 25m of the step end" — so steps can never get stuck.
///  * Camera rotates with driver heading (direction-of-travel is up).
///  * Driver marker is a rotating navigation arrow, not a static pin.
///  * Remaining distance / ETA / "In X m" all update live along the route.
///  * Travelled part of the polyline is trimmed away (Rapido/GMaps style).
///  * Off-route detection → automatic re-route.
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

  // ── Route data ────────────────────────────────────────────────────────
  List<LatLng>? _routedPoints; // full route from Routes API
  List<double> _cumDist = []; // cumulative meters at every polyline index
  double _totalRouteDist = 0;
  int _initialDurationSeconds = 0;

  // Live progress along the route
  int _nearestIdx = 0; // driver's snapped index on the polyline
  double _snapDistMeters = 0; // perpendicular dist from driver to route
  double _traveledDist = 0;
  double _remainingDist = 0;
  int _remainingSeconds = 0;
  double _distToNextTurn = 0;

  List<_ManeuverStep> _steps = [];
  List<double> _stepEndCumDist = []; // cum. route distance at each step's end
  int _currentStepIndex = 0;

  // ── Heading / camera ──────────────────────────────────────────────────
  double _heading = 0;
  LatLng? _prevLoc;
  bool _followMode = true;
  bool _programmaticMove = false;

  BitmapDescriptor? _driverIcon;

  StreamSubscription<Position>? _positionSub;
  bool _fetchingRoute = false;
  bool _routeFetched = false;
  int _offRouteCount = 0;

  static const _apiKey = 'AIzaSyDEDoT1AQ6WHDZurqMT0bLnfIXLu7DxA4U';
  static const double _offRouteThresholdMeters = 40;
  static const int _offRouteConsecutiveHits = 3;

  @override
  void initState() {
    super.initState();
    _createDriverIcon();
    _initLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // ── Driver arrow icon (Rapido-style rotating puck) ────────────────────
  Future<void> _createDriverIcon() async {
    const double size = 110;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    // soft halo
    canvas.drawCircle(
        center, size / 2, Paint()..color = const Color(0x330066FF));
    // white ring
    canvas.drawCircle(center, size * 0.36, Paint()..color = Colors.white);
    // blue disc
    canvas.drawCircle(
        center, size * 0.30, Paint()..color = const Color(0xFF0066FF));
    // white navigation arrow pointing "up" (north) — marker rotation handles
    // the actual heading.
    final arrow = Path()
      ..moveTo(size / 2, size * 0.24)
      ..lineTo(size * 0.66, size * 0.62)
      ..lineTo(size / 2, size * 0.53)
      ..lineTo(size * 0.34, size * 0.62)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white);

    final img =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    if (mounted) {
      setState(() {
        _driverIcon = BitmapDescriptor.bytes(bytes.buffer.asUint8List());
        // NOTE: on older google_maps_flutter versions use:
        // BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
      });
    }
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
        _fetchRouteIfNeeded();
      }

      // Live stream
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
        ),
      ).listen(_onLocationUpdate);
    } catch (e) {
      debugPrint('[NAV] Location init error: $e');
    }
  }

  void _onLocationUpdate(Position pos) {
    if (!mounted) return;

    final newLoc = LatLng(pos.latitude, pos.longitude);

    // ── Heading: prefer GPS course when actually moving, else derive it
    //    from the last two points. A stationary phone reports garbage
    //    heading, which used to make the camera/arrow spin randomly.
    double heading = _heading;
    if (pos.speed > 0.8 && pos.heading >= 0) {
      heading = pos.heading;
    } else if (_prevLoc != null) {
      final moved = Geolocator.distanceBetween(_prevLoc!.latitude,
          _prevLoc!.longitude, newLoc.latitude, newLoc.longitude);
      if (moved > 4) {
        heading = Geolocator.bearingBetween(_prevLoc!.latitude,
            _prevLoc!.longitude, newLoc.latitude, newLoc.longitude);
      }
    }
    if (heading < 0) heading += 360;

    setState(() {
      _prevLoc = _driverLoc;
      _driverLoc = newLoc;
      _driverLocInitialized = true;
      _heading = heading;
    });

    _fetchRouteIfNeeded();
    _updateRouteProgress();
    _maybeReroute();
    _checkArrival();

    if (_followMode) _animateCameraToDriver();
  }

  // ── Snap driver onto route & update everything derived from progress ──
  void _updateRouteProgress() {
    final pts = _routedPoints;
    if (pts == null || pts.isEmpty || _cumDist.isEmpty) return;

    // Windowed nearest-point search (fast), widen to full scan if lost.
    double best = double.infinity;
    int bestIdx = _nearestIdx;
    void scan(int a, int b) {
      for (int i = a; i <= b; i++) {
        final d = Geolocator.distanceBetween(_driverLoc.latitude,
            _driverLoc.longitude, pts[i].latitude, pts[i].longitude);
        if (d < best) {
          best = d;
          bestIdx = i;
        }
      }
    }

    final start = (_nearestIdx - 25).clamp(0, pts.length - 1);
    final end = (_nearestIdx + 80).clamp(0, pts.length - 1);
    scan(start, end);
    if (best > 80) {
      best = double.infinity;
      scan(0, pts.length - 1);
    }

    // Never allow progress to jump backwards on GPS jitter
    if (bestIdx < _nearestIdx && best > 20) bestIdx = _nearestIdx;

    _nearestIdx = bestIdx;
    _snapDistMeters = best;
    _traveledDist = _cumDist[bestIdx];
    _remainingDist = (_totalRouteDist - _traveledDist).clamp(0, double.infinity);

    // Remaining time = initial duration scaled by remaining fraction
    if (_totalRouteDist > 0 && _initialDurationSeconds > 0) {
      _remainingSeconds =
          (_initialDurationSeconds * (_remainingDist / _totalRouteDist))
              .round();
    }

    // ── Active step by ROUTE PROGRESS (the core turn-by-turn fix) ──
    // The active step is the first one whose end we haven't crossed yet.
    // The old logic ("advance only when within 25m of the step end") got
    // permanently stuck the moment one GPS tick landed >25m past a turn.
    if (_steps.isNotEmpty && _stepEndCumDist.isNotEmpty) {
      int idx = 0;
      while (idx < _steps.length - 1 &&
          _stepEndCumDist[idx] <= _traveledDist + 12) {
        idx++;
      }
      _distToNextTurn =
          (_stepEndCumDist[idx] - _traveledDist).clamp(0, double.infinity);
      if (idx != _currentStepIndex) {
        _currentStepIndex = idx;
      }
    }

    if (mounted) setState(() {});
  }

  // ── Off-route → automatic re-route ────────────────────────────────────
  void _maybeReroute() {
    if (_routedPoints == null || _fetchingRoute) return;
    if (_snapDistMeters > _offRouteThresholdMeters) {
      _offRouteCount++;
      if (_offRouteCount >= _offRouteConsecutiveHits) {
        debugPrint('[NAV] Off-route (${_snapDistMeters.round()}m) — rerouting');
        _offRouteCount = 0;
        _routeFetched = false;
        _fetchRouteIfNeeded();
      }
    } else {
      _offRouteCount = 0;
    }
  }

  void _checkArrival() {
    final straight = Geolocator.distanceBetween(
      _driverLoc.latitude,
      _driverLoc.longitude,
      widget.destination.latitude,
      widget.destination.longitude,
    );
    final byRoute = _routedPoints != null ? _remainingDist : straight;
    if ((straight < 35 || byRoute < 30) && !_arrived) {
      setState(() => _arrived = true);
    }
  }

  /// Called once the GoogleMap is ready.
  Future<void> _onMapCreated(GoogleMapController controller) async {
    _controller = controller;
    if (_driverLocInitialized) _animateCameraToDriver();
    _fetchRouteIfNeeded();
    if (!mounted) return;
    setState(() => _mapReady = true);
  }

  void _fetchRouteIfNeeded() {
    if (_routeFetched || !_driverLocInitialized || _fetchingRoute) return;
    _routeFetched = true;
    _fetchAndDrawRoadRoute();
  }

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('destination'),
        position: widget.destination,
        zIndexInt: 4,
      ),
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverLoc,
        icon: _driverIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        rotation: _driverIcon != null ? _heading : 0,
        flat: true, // rotates with the map plane, like Rapido's bike puck
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 5,
      ),
    };
  }

  /// Route line trimmed to the part still ahead of the driver.
  Set<Polyline> _buildPolylines() {
    List<LatLng> points;
    if (_routedPoints != null && _routedPoints!.isNotEmpty) {
      final ahead = _routedPoints!
          .sublist(_nearestIdx.clamp(0, _routedPoints!.length - 1));
      points = [_driverLoc, ...ahead];
    } else {
      points = [_driverLoc, widget.destination];
    }
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: const Color(0xFF0066FF),
        width: 7,
        geodesic: true,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  void _animateCameraToDriver() {
    _programmaticMove = true;
    _controller
        ?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _driverLoc,
          zoom: 17.5,
          tilt: 55,
          bearing: _heading, // direction of travel is "up" — Rapido style
        ),
      ),
    )
        .whenComplete(() => _programmaticMove = false);
  }

  void _recenterCamera() {
    setState(() => _followMode = true);
    _animateCameraToDriver();
  }

  Future<void> _fetchAndDrawRoadRoute() async {
    _fetchingRoute = true;
    try {
      final uri = Uri.parse(
          'https://routes.googleapis.com/directions/v2:computeRoutes');
      final body = jsonEncode({
        'origin': {
          'location': {
            'latLng': {
              'latitude': _driverLoc.latitude,
              'longitude': _driverLoc.longitude
            }
          }
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': widget.destination.latitude,
              'longitude': widget.destination.longitude
            }
          }
        },
        'travelMode': 'TWO_WHEELER',
        'routingPreference': 'TRAFFIC_AWARE',
        'polylineQuality': 'HIGH_QUALITY',
        'languageCode': 'en',
      });

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _apiKey,
              'X-Goog-LanguageCode': 'en-US',
              'X-Goog-FieldMask':
                  'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline,routes.legs.steps.navigationInstruction,routes.legs.steps.distanceMeters,routes.legs.steps.startLocation,routes.legs.steps.endLocation',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 8));

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
                String rawInstruction =
                    navInst?['instructions'] as String? ?? '';
                if (rawInstruction.contains('\n')) {
                  rawInstruction = rawInstruction.split('\n').first;
                }
                final sDist = (s['distanceMeters'] as num?)?.toDouble() ?? 0.0;
                final startLat =
                    (s['startLocation']?['latLng']?['latitude'] as num?)
                            ?.toDouble() ??
                        0.0;
                final startLng =
                    (s['startLocation']?['latLng']?['longitude'] as num?)
                            ?.toDouble() ??
                        0.0;
                final endLat =
                    (s['endLocation']?['latLng']?['latitude'] as num?)
                            ?.toDouble() ??
                        0.0;
                final endLng =
                    (s['endLocation']?['latLng']?['longitude'] as num?)
                            ?.toDouble() ??
                        0.0;

                stepsList.add(_ManeuverStep(
                  maneuver: maneuver,
                  instruction: rawInstruction.isNotEmpty
                      ? rawInstruction
                      : 'Head toward ${widget.destinationTitle}',
                  distanceMeters: sDist,
                  startLoc: LatLng(startLat, startLng),
                  endLoc: LatLng(endLat, endLng),
                ));
              }
            }
          }

          final decoded = encoded != null ? _decodePolyline(encoded) : null;

          if (mounted && decoded != null && decoded.length >= 2) {
            // ── Precompute cumulative distances along the polyline ──
            final cum = List<double>.filled(decoded.length, 0);
            for (int i = 1; i < decoded.length; i++) {
              cum[i] = cum[i - 1] +
                  Geolocator.distanceBetween(
                      decoded[i - 1].latitude,
                      decoded[i - 1].longitude,
                      decoded[i].latitude,
                      decoded[i].longitude);
            }

            // ── Map every step's end point to its cumulative distance ──
            // This is what lets us track "which turn is next" by route
            // progress instead of fragile radius checks.
            final stepEnds = <double>[];
            for (final st in stepsList) {
              double bd = double.infinity;
              int bi = 0;
              for (int i = 0; i < decoded.length; i++) {
                final d = Geolocator.distanceBetween(
                    st.endLoc.latitude,
                    st.endLoc.longitude,
                    decoded[i].latitude,
                    decoded[i].longitude);
                if (d < bd) {
                  bd = d;
                  bi = i;
                }
              }
              stepEnds.add(cum[bi]);
            }

            setState(() {
              _routedPoints = decoded;
              _cumDist = cum;
              _totalRouteDist = dist ?? cum.last;
              _initialDurationSeconds = durSec;
              _remainingDist = _totalRouteDist;
              _remainingSeconds = durSec;
              _steps = stepsList;
              _stepEndCumDist = stepEnds;
              _currentStepIndex = 0;
              _nearestIdx = 0;
              _offRouteCount = 0;
            });
            _updateRouteProgress();
          } else {
            _drawFallbackPolyline();
          }
        }
      } else {
        debugPrint('[NAV] Routes API ${response.statusCode}: ${response.body}');
        _drawFallbackPolyline();
      }
    } catch (e) {
      debugPrint('[NAV] Routes API error: $e');
      _drawFallbackPolyline();
    } finally {
      _fetchingRoute = false;
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
        _routedPoints = null;
        _remainingDist = dist;
        _remainingSeconds = (dist / 1000 / 25 * 3600).round();
      });
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

  String _formatEtaTime(int durationSeconds) {
    final now = DateTime.now().add(Duration(seconds: durationSeconds));
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDistanceStr(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    const kCardBg = Color(0xFF161A22);
    const kCyan = Color(0xFF22D3EE);

    final durationMin = (_remainingSeconds / 60).ceil().clamp(0, 999);
    final etaTimeStr = _formatEtaTime(_remainingSeconds);
    final distStr = _formatDistanceStr(_remainingDist);

    _ManeuverStep? activeStep =
        _steps.isNotEmpty && _currentStepIndex < _steps.length
            ? _steps[_currentStepIndex]
            : null;
    _ManeuverStep? nextStep =
        _steps.isNotEmpty && (_currentStepIndex + 1) < _steps.length
            ? _steps[_currentStepIndex + 1]
            : null;

    final turnDistStr = _formatDistanceStr(
        activeStep != null ? _distToNextTurn : _remainingDist);
    final turnIcon = activeStep != null
        ? _getManeuverIcon(activeStep.maneuver)
        : Icons.arrow_upward_rounded;
    final turnInstruction = activeStep != null
        ? activeStep.instruction
        : 'toward ${widget.destinationTitle}';

    final nextTurnIcon = nextStep != null
        ? _getManeuverIcon(nextStep.maneuver)
        : Icons.flag_rounded;
    final nextTurnInstruction = nextStep != null
        ? nextStep.instruction
        : 'Arrive at ${widget.destinationTitle}';

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
                target:
                    _driverLocInitialized ? _driverLoc : widget.destination,
                zoom: 16,
                tilt: 45,
              ),
              markers: _buildMarkers(),
              polylines: _buildPolylines(),
              onCameraMoveStarted: () {
                // User dragged the map → stop auto-follow until Re-center
                if (!_programmaticMove && _followMode) {
                  setState(() => _followMode = false);
                }
              },
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF046A38),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black45,
                        blurRadius: 12,
                        offset: Offset(0, 4)),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF004429),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Then',
                                  style: GoogleFonts.outfit(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 4),
                                Icon(nextTurnIcon,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    nextTurnInstruction,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
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

          // ── 3. Floating Re-center Button (only when follow is off) ────
          if (_mapReady && !_arrived && !_followMode)
            Positioned(
              left: 16,
              bottom: 110,
              child: GestureDetector(
                onTap: _recenterCamera,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black38,
                          blurRadius: 10,
                          offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.navigation_rounded,
                          color: Color(0xFF0066FF), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Re-centre',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black45,
                        blurRadius: 16,
                        offset: Offset(0, 4)),
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
                              color: const Color(0xFFE8710A),
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
                        child: const Icon(Icons.chat_bubble_rounded,
                            color: Colors.white, size: 20),
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
                        child: const Icon(Icons.close_rounded,
                            color: Color(0xFF374151), size: 22),
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
                    BoxShadow(
                        color: Colors.black54,
                        blurRadius: 16,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.greenAccent, size: 24),
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
                      style: GoogleFonts.outfit(
                          color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _exitNavigation(reached: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold, fontSize: 15),
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