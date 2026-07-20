import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

/// Custom map markers for the pickup/drop preview maps — a direction-aware
/// moped badge for the partner's own position, plus teardrop pins for
/// pickup/drop — replacing the SDK's default markers so the map reads as
/// part of the app's own design system.
///
/// Drawn with `dart:ui` Canvas (no image assets needed), then registered
/// with the Navigation SDK's image registry via [registerBitmapImage].
class MapPins {
  MapPins._();

  static const pickupColor = Color(0xFF16A34A);
  static const dropColor = Color(0xFFE53935);
  static const driverColor = Color(0xFFF2C230); // AppColors.primary

  static ImageDescriptor? _pickup;
  static ImageDescriptor? _drop;
  static ImageDescriptor? _driver;

  static ImageDescriptor? get pickup => _pickup;
  static ImageDescriptor? get drop => _drop;
  static ImageDescriptor? get driver => _driver;

  static Uint8List? pickupPngBytes;
  static Uint8List? driverPngBytes;
  static Uint8List? dropPngBytes;

  /// Renders and registers all three markers once, at [devicePixelRatio]
  /// resolution so they stay crisp on retina screens. Safe to call
  /// repeatedly — a no-op once already registered.
  static Future<void> preload(double devicePixelRatio) async {
    final futures = <Future<void>>[];
    if (_pickup == null) {
      futures.add(_renderPin(color: pickupColor, devicePixelRatio: devicePixelRatio).then((v) => _pickup = v));
    }
    if (_drop == null) {
      futures.add(_renderPin(color: dropColor, devicePixelRatio: devicePixelRatio).then((v) => _drop = v));
    }
    if (_driver == null) {
      futures.add(_renderDriverBadge(devicePixelRatio).then((v) => _driver = v));
    }
    await Future.wait(futures);
  }

  static const _pinWidth = 40.0;
  static const _pinHeight = 50.0;

  /// A rounded teardrop — matches the classic map-pin silhouette. Marker
  /// anchor should be (0.5, 1.0) so the point lands exactly on the
  /// coordinate.
  static Future<ImageDescriptor> _renderPin({
    required Color color,
    required double devicePixelRatio,
  }) async {
    final width = _pinWidth * devicePixelRatio;
    final height = _pinHeight * devicePixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.scale(devicePixelRatio);

    final path = _teardropPath(_pinWidth, _pinHeight);

    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final circleCenter = Offset(_pinWidth / 2, _pinWidth / 2);
    canvas.drawCircle(circleCenter, _pinWidth * 0.2, Paint()..color = Colors.white);
    canvas.drawCircle(circleCenter, _pinWidth * 0.1, Paint()..color = color);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.round(), height.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = bytes?.buffer.asUint8List();
    if (color == pickupColor) pickupPngBytes = pngBytes;
    if (color == dropColor) dropPngBytes = pngBytes;
    try {
      if (bytes != null) {
        return await registerBitmapImage(bitmap: bytes, imagePixelRatio: devicePixelRatio);
      }
      return ImageDescriptor.defaultImage;
    } catch (e) {
      debugPrint('[MapPins] registerBitmapImage error: $e');
      return ImageDescriptor.defaultImage;
    }
  }

  static Path _teardropPath(double w, double h) {
    final r = w / 2;
    final cx = w / 2;
    final circle = Path()..addOval(Rect.fromCircle(center: Offset(cx, r), radius: r));
    final tail = Path()
      ..moveTo(cx - r * 0.62, r + r * 0.55)
      ..quadraticBezierTo(cx, h, cx + r * 0.62, r + r * 0.55)
      ..close();
    return Path.combine(PathOperation.union, circle, tail);
  }

  static const _driverBadgeSize = 46.0;

  /// A yellow circular badge with a moped glyph — rotatable via
  /// `MarkerOptions.rotation` (unlike a teardrop pin, a circle keeps
  /// looking right when spun to face the direction of travel). Anchor
  /// should be (0.5, 0.5).
  static Future<ImageDescriptor> _renderDriverBadge(double devicePixelRatio) async {
    final size = _driverBadgeSize * devicePixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
    canvas.scale(devicePixelRatio);

    final center = Offset(_driverBadgeSize / 2, _driverBadgeSize / 2);
    final radius = _driverBadgeSize / 2 - 3;

    canvas.drawCircle(
      center,
      radius + 2,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(center, radius, Paint()..color = driverColor);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final iconSpan = TextSpan(
      text: String.fromCharCode(Icons.electric_moped.codePoint),
      style: TextStyle(
        fontSize: _driverBadgeSize * 0.52,
        fontFamily: Icons.electric_moped.fontFamily,
        package: Icons.electric_moped.fontPackage,
        color: const Color(0xFF1A1A1A),
      ),
    );
    final painter = TextPainter(text: iconSpan, textDirection: TextDirection.ltr)..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.round(), size.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    driverPngBytes = bytes?.buffer.asUint8List();
    try {
      if (bytes != null) {
        return await registerBitmapImage(bitmap: bytes, imagePixelRatio: devicePixelRatio);
      }
      return ImageDescriptor.defaultImage;
    } catch (e) {
      debugPrint('[MapPins] registerBitmapImage error: $e');
      return ImageDescriptor.defaultImage;
    }
  }
}
