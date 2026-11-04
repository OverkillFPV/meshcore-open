import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// One packet's resolved route plus when it was heard, for animation.
class LivePacketRoute {
  final List<LatLng> points;
  final int seenAtMs;

  const LivePacketRoute({required this.points, required this.seenAtMs});
}

/// Animated overlay showing packets travelling their observed paths. Each
/// route draws a travelling dot with a fading trail, then disappears.
class LivePacketLayer extends StatefulWidget {
  final List<LivePacketRoute> routes;
  final Color color;

  const LivePacketLayer({super.key, required this.routes, required this.color});

  @override
  State<LivePacketLayer> createState() => _LivePacketLayerState();
}

class _LivePacketLayerState extends State<LivePacketLayer>
    with SingleTickerProviderStateMixin {
  static const Duration _perHop = Duration(milliseconds: 1300);
  static const Duration _fade = Duration(milliseconds: 600);

  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 32),
    );
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      child: const SizedBox.shrink(),
      builder: (context, _) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final trails = <Polyline>[];
        final dots = <Marker>[];
        var active = false;

        for (final route in widget.routes) {
          if (route.points.length < 2) continue;
          final segments = route.points.length - 1;
          final travelMs = _perHop.inMilliseconds * segments;
          final elapsed = nowMs - route.seenAtMs;
          if (elapsed < 0 || elapsed > travelMs + _fade.inMilliseconds) {
            continue;
          }
          active = true;

          final progress = (elapsed / travelMs).clamp(0.0, 1.0);
          final alpha = elapsed <= travelMs
              ? 1.0
              : 1.0 - (elapsed - travelMs) / _fade.inMilliseconds;

          final position = _positionAtProgress(route.points, progress);
          final trailPoints = <LatLng>[
            for (var i = 0; i < segments; i++) route.points[i],
            position,
          ];
          trails.add(
            Polyline(
              points: trailPoints,
              color: widget.color.withValues(alpha: 0.45 * alpha),
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
            ),
          );
          dots.add(
            Marker(
              point: position,
              width: 18,
              height: 18,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: alpha),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5 * alpha),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (active) {
          if (!_clock.isAnimating) _clock.repeat();
        } else if (_clock.isAnimating) {
          _clock.stop();
        }

        if (trails.isEmpty && dots.isEmpty) return const SizedBox.shrink();
        return Stack(
          children: [
            if (trails.isNotEmpty) PolylineLayer(polylines: trails),
            if (dots.isNotEmpty) MarkerLayer(markers: dots),
          ],
        );
      },
    );
  }

  static LatLng _positionAtProgress(List<LatLng> points, double progress) {
    if (progress <= 0) return points.first;
    if (progress >= 1) return points.last;
    final distance = Distance();
    var total = 0.0;
    final segmentLengths = <double>[];
    for (var i = 0; i < points.length - 1; i++) {
      final length = distance(points[i], points[i + 1]);
      segmentLengths.add(length);
      total += length;
    }
    if (total <= 0) return points.last;
    var remaining = progress * total;
    for (var i = 0; i < segmentLengths.length; i++) {
      if (remaining <= segmentLengths[i]) {
        final fraction = segmentLengths[i] == 0
            ? 1.0
            : remaining / segmentLengths[i];
        return LatLng(
          points[i].latitude +
              (points[i + 1].latitude - points[i].latitude) * fraction,
          points[i].longitude +
              (points[i + 1].longitude - points[i].longitude) * fraction,
        );
      }
      remaining -= segmentLengths[i];
    }
    return points.last;
  }
}
