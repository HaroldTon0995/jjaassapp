import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

/// Renders the JJAASS Water Market logo emblem.
class WaterDropletLogo extends StatelessWidget {
  final double size;
  final bool rounded;
  final bool showShadow;

  const WaterDropletLogo({
    super.key,
    this.size = 64,
    this.rounded = true,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(rounded ? size / 2 : 12),
      child: Image.asset(
        'assets/images/logo_icon.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _WaterDropletPainter(),
          ),
        ),
      ),
    );

    if (showShadow) {
      return Container(
        decoration: BoxDecoration(
          shape: rounded ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: rounded ? null : BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: imageWidget,
      );
    }
    return imageWidget;
  }
}

/// Renders the full horizontal banner logo of JJAASS Water Market.
class JjaassFullLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const JjaassFullLogo({
    super.key,
    this.width,
    this.height = 50,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      'assets/images/logo_full.jpg',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WaterDropletLogo(size: height ?? 40),
          const SizedBox(width: 10),
          const Text(
            'JJAASS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 1.2,
              color: Color(0xFF0F2B5C),
            ),
          ),
        ],
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }
    return image;
  }
}

class _WaterDropletPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final path = Path();
    // Drop shape: top point at center top, curves down-left and down-right, rounded bottom
    path.moveTo(size.width / 2, size.height * 0.08);
    // Left shoulder / curve
    path.cubicTo(
      size.width * 0.22, size.height * 0.45,
      size.width * 0.08, size.height * 0.65,
      size.width * 0.5, size.height * 0.95,
    );
    // Right shoulder / curve
    path.cubicTo(
      size.width * 0.92, size.height * 0.65,
      size.width * 0.78, size.height * 0.45,
      size.width / 2, size.height * 0.08,
    );
    path.close();

    canvas.drawPath(path, paint);

    // Dynamic inner reflection
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final highlightPath = Path();
    highlightPath.moveTo(size.width * 0.46, size.height * 0.28);
    highlightPath.quadraticBezierTo(
      size.width * 0.25, size.height * 0.48,
      size.width * 0.32, size.height * 0.68,
    );
    highlightPath.quadraticBezierTo(
      size.width * 0.36, size.height * 0.48,
      size.width * 0.46, size.height * 0.28,
    );
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Sticker illustration removed for a clean, professional layout.
class WaterJugIllustration extends StatelessWidget {
  final double width;
  final double height;
  const WaterJugIllustration({super.key, this.width = 0, this.height = 0});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// A wrapper widget that paints double overlapping waves at the bottom.
class WaveBackground extends StatelessWidget {
  final Widget child;
  const WaveBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: WaveBackgroundPainter(),
          ),
        ),
        child,
      ],
    );
  }
}

class WaveBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // First wave (Logo Deep Navy tint)
    final paint1 = Paint()
      ..color = const Color(0xFF0F2B5C).withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.86);
    path1.quadraticBezierTo(
      size.width * 0.25, size.height * 0.80,
      size.width * 0.55, size.height * 0.89,
    );
    path1.quadraticBezierTo(
      size.width * 0.8, size.height * 0.95,
      size.width, size.height * 0.88,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Second wave (Logo Cornflower/Azure Blue tint)
    final paint2 = Paint()
      ..color = const Color(0xFF4788D7).withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.92);
    path2.quadraticBezierTo(
      size.width * 0.35, size.height * 0.97,
      size.width * 0.65, size.height * 0.89,
    );
    path2.quadraticBezierTo(
      size.width * 0.85, size.height * 0.84,
      size.width, size.height * 0.92,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Renders a beautiful curve/line chart matching the screenshot.
/// Renders an interactive, auto-scaling curve/line chart matching live transactions.
class SalesOverviewLineChart extends StatefulWidget {
  final List<double> dataPoints;
  final List<String> labels;
  final int? selectedIndex;
  final ValueChanged<int>? onPointSelected;
  final bool isDark;

  const SalesOverviewLineChart({
    super.key,
    required this.dataPoints,
    this.labels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    this.selectedIndex,
    this.onPointSelected,
    this.isDark = false,
  });

  @override
  State<SalesOverviewLineChart> createState() => _SalesOverviewLineChartState();
}

class _SalesOverviewLineChartState extends State<SalesOverviewLineChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final activeIndex = _hoveredIndex ?? widget.selectedIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            if (widget.dataPoints.isEmpty) return;
            final double width = constraints.maxWidth;
            final double stepX = widget.dataPoints.length > 1
                ? width / (widget.dataPoints.length - 1)
                : width;
            final int tappedIndex = (details.localPosition.dx / stepX).round().clamp(0, widget.dataPoints.length - 1);
            setState(() {
              _hoveredIndex = tappedIndex;
            });
            widget.onPointSelected?.call(tappedIndex);
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _SalesOverviewPainter(
              data: widget.dataPoints,
              labels: widget.labels,
              selectedIndex: activeIndex,
              isDark: widget.isDark,
            ),
          ),
        );
      },
    );
  }
}

class _SalesOverviewPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final int? selectedIndex;
  final bool isDark;

  _SalesOverviewPainter({
    required this.data,
    required this.labels,
    this.selectedIndex,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double gridHeight = size.height;
    final double gridWidth = size.width;

    // Draw background grid lines (horizontal)
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = gridHeight * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(gridWidth, y), gridPaint);
    }

    double minVal = data.reduce(min);
    double maxVal = data.reduce(max);
    if (maxVal == minVal) {
      if (maxVal == 0) {
        maxVal = 1000;
        minVal = 0;
      } else {
        maxVal = maxVal * 1.25;
        minVal = minVal * 0.75;
      }
    }
    final double valRange = maxVal - minVal;

    final double stepX = data.length > 1 ? gridWidth / (data.length - 1) : gridWidth;

    double getX(int index) => index * stepX;
    double getY(double val) {
      final double normalized = (val - minVal) / valRange;
      // Keep within comfortable padding bounds
      return gridHeight - (normalized * gridHeight * 0.60) - (gridHeight * 0.15);
    }

    final path = Path();
    final fillPath = Path();

    path.moveTo(getX(0), getY(data[0]));
    fillPath.moveTo(getX(0), gridHeight);
    fillPath.lineTo(getX(0), getY(data[0]));

    for (int i = 1; i < data.length; i++) {
      final double prevX = getX(i - 1);
      final double prevY = getY(data[i - 1]);
      final double currX = getX(i);
      final double currY = getY(data[i]);

      // Smooth cubic bezier control points
      final double cpX1 = prevX + (currX - prevX) / 2;
      final double cpY1 = prevY;
      final double cpX2 = prevX + (currX - prevX) / 2;
      final double cpY2 = currY;

      path.cubicTo(cpX1, cpY1, cpX2, cpY2, currX, currY);
      fillPath.cubicTo(cpX1, cpY1, cpX2, cpY2, currX, currY);
    }

    fillPath.lineTo(getX(data.length - 1), gridHeight);
    fillPath.close();

    // Fill paint with cyan/blue gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF0284C7).withValues(alpha: 0.22),
          const Color(0xFF0284C7).withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, gridWidth, gridHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Line paint
    final linePaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw marker dots
    final dotPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;

    final dotOuterPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    // Determine which point to highlight (default to peak index or last non-zero)
    int highlightIdx = selectedIndex ?? 0;
    if (selectedIndex == null) {
      double highest = -1;
      for (int i = 0; i < data.length; i++) {
        if (data[i] >= highest) {
          highest = data[i];
          highlightIdx = i;
        }
      }
    }

    for (int i = 0; i < data.length; i++) {
      final Offset pt = Offset(getX(i), getY(data[i]));
      canvas.drawCircle(pt, 6, dotOuterPaint);
      canvas.drawCircle(pt, 3.5, dotPaint);

      if (i == highlightIdx) {
        // Highlight active point
        canvas.drawCircle(
          pt,
          11,
          Paint()
            ..color = const Color(0xFF0284C7).withValues(alpha: 0.2)
            ..style = PaintingStyle.fill,
        );

        // Draw Dynamic Tooltip Box above the point
        final double boxWidth = 92;
        final double boxHeight = 38;
        double boxLeft = (pt.dx - boxWidth / 2).clamp(4.0, gridWidth - boxWidth - 4.0);
        double boxTop = pt.dy - boxHeight - 12;
        if (boxTop < 2) boxTop = pt.dy + 12;

        final boxRect = Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight);
        final boxPaint = Paint()
          ..color = isDark ? const Color(0xFF1E293B) : Colors.white
          ..style = PaintingStyle.fill;
        final borderPaint = Paint()
          ..color = isDark ? Colors.white24 : const Color(0xFFE2E8F0)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

        final RRect rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(8));
        canvas.drawRRect(rrect, boxPaint);
        canvas.drawRRect(rrect, borderPaint);

        // Day label and formatted Revenue
        final String dayText = i < labels.length ? labels[i] : 'Day ${i + 1}';
        final String valText = '₱${data[i].toStringAsFixed(data[i] % 1 == 0 ? 0 : 2)}';

        final textStyleDay = TextStyle(
          color: isDark ? Colors.white60 : Colors.grey.shade600,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        );
        final textStyleVal = TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        );

        final textPainterDay = TextPainter(
          text: TextSpan(text: dayText, style: textStyleDay),
          textDirection: TextDirection.ltr,
        )..layout();

        final textPainterVal = TextPainter(
          text: TextSpan(text: valText, style: textStyleVal),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainterDay.paint(
          canvas,
          Offset(boxLeft + (boxWidth - textPainterDay.width) / 2, boxTop + 4),
        );
        textPainterVal.paint(
          canvas,
          Offset(boxLeft + (boxWidth - textPainterVal.width) / 2, boxTop + 18),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SalesOverviewPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.isDark != isDark;
}

/// Renders a live, real-time Order Status donut chart.
class OrderStatusDonutChart extends StatelessWidget {
  final int completedCount;
  final int onDeliveryCount;
  final int pendingCount;
  final int cancelledCount;
  final bool isDark;

  const OrderStatusDonutChart({
    super.key,
    this.completedCount = 0,
    this.onDeliveryCount = 0,
    this.pendingCount = 0,
    this.cancelledCount = 0,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final int total = completedCount + onDeliveryCount + pendingCount + cancelledCount;

    final double pctCompleted = total > 0 ? completedCount / total : 0.0;
    final double pctOnDelivery = total > 0 ? onDeliveryCount / total : 0.0;
    final double pctPending = total > 0 ? pendingCount / total : 0.0;
    final double pctCancelled = total > 0 ? cancelledCount / total : 0.0;

    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DonutChartPainter(
                  percentages: [pctCompleted, pctOnDelivery, pctPending, pctCancelled],
                  total: total,
                  isDark: isDark,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$total',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Total Orders',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<double> percentages;
  final int total;
  final bool isDark;

  _DonutChartPainter({
    required this.percentages,
    required this.total,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 22.0;
    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    // Colors matching theme:
    // Completed: Teal / Sky Blue
    // On Delivery: Bright Blue
    // Pending: Amber / Orange
    // Cancelled: Rose / Red
    final List<Color> colors = [
      const Color(0xFF0284C7), // Completed (Teal/Sky)
      const Color(0xFF38BDF8), // On Delivery (Cyan/Blue)
      const Color(0xFFF59E0B), // Pending (Amber)
      const Color(0xFFEF4444), // Cancelled (Red)
    ];

    if (total == 0) {
      // Draw placeholder empty ring
      final emptyPaint = Paint()
        ..color = (isDark ? Colors.white12 : const Color(0xFFE2E8F0))
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      canvas.drawArc(rect, 0, 2 * pi, false, emptyPaint);
      return;
    }

    double startAngle = -pi / 2; // Start at the top

    for (int i = 0; i < percentages.length; i++) {
      final double sweepAngle = 2 * pi * percentages[i];
      if (sweepAngle <= 0.001) continue;

      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.percentages != percentages ||
      oldDelegate.total != total ||
      oldDelegate.isDark != isDark;
}

/// Live Interactive Fleet GPS Route Monitor with Real Google Map & Telemetry
class LiveFleetGpsMapWidget extends StatefulWidget {
  final List<OrderModel> orders;
  final List<UserModel> drivers;
  final OrderModel? selectedOrder;
  final ValueChanged<OrderModel>? onSelectOrder;
  final VoidCallback? onChatTap;
  final VoidCallback? onHelpTap;
  final bool isDark;
  final bool satelliteMode;

  const LiveFleetGpsMapWidget({
    super.key,
    required this.orders,
    required this.drivers,
    this.selectedOrder,
    this.onSelectOrder,
    this.onChatTap,
    this.onHelpTap,
    this.isDark = false,
    this.satelliteMode = false,
  });

  @override
  State<LiveFleetGpsMapWidget> createState() => _LiveFleetGpsMapWidgetState();
}

class _LiveFleetGpsMapWidgetState extends State<LiveFleetGpsMapWidget> {
  // JJAASS Water Market HQ in Albay 1st District (Tabaco City / Bacacay)
  static const LatLng _stationHQ = LatLng(13.3583, 123.7336);

  LatLng _mapCenter = _stationHQ;
  int _zoom = 14;
  final Map<String, List<LatLng>> _mapboxRouteCache = {};
  final Map<String, int> _mapboxEtaCache = {};
  final Set<String> _fetchingRouteIds = {};

  static double _lngToWorldX(double lng, int zoom) {
    final worldSize = 256.0 * (1 << zoom);
    return (lng + 180.0) / 360.0 * worldSize;
  }

  static double _latToWorldY(double lat, int zoom) {
    final worldSize = 256.0 * (1 << zoom);
    final sinLat = sin(lat * pi / 180.0).clamp(-0.9999, 0.9999);
    return (0.5 - log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * pi)) * worldSize;
  }

  static double _worldXToLng(double wx, int zoom) {
    final worldSize = 256.0 * (1 << zoom);
    return (wx / worldSize) * 360.0 - 180.0;
  }

  static double _worldYToLat(double wy, int zoom) {
    final worldSize = 256.0 * (1 << zoom);
    final n = pi - 2.0 * pi * wy / worldSize;
    return 180.0 / pi * atan(0.5 * (exp(n) - exp(-n)));
  }

  LatLng _getOrderCoord(OrderModel order, int index) {
    if (order.latitude != null && order.longitude != null) {
      return LatLng(order.latitude!, order.longitude!);
    }
    final hash = order.id.hashCode;
    final latOffset = ((hash % 100) / 10000.0) - 0.005 + (index * 0.0018);
    final lngOffset = (((hash >> 4) % 100) / 10000.0) - 0.005 - (index * 0.0016);
    return LatLng(_stationHQ.latitude + latOffset, _stationHQ.longitude + lngOffset);
  }

  List<LatLng> _buildStreetRouteWaypoints(LatLng start, LatLng end) {
    final dLat = end.latitude - start.latitude;
    final dLng = end.longitude - start.longitude;
    return [
      start,
      LatLng(start.latitude + dLat * 0.32, start.longitude + dLng * 0.12),
      LatLng(start.latitude + dLat * 0.72, start.longitude + dLng * 0.28),
      LatLng(start.latitude + dLat * 0.88, start.longitude + dLng * 0.68),
      LatLng(start.latitude + dLat * 1.04, start.longitude + dLng * 0.94),
      end,
    ];
  }

  Future<void> _ensureMapboxRoute(String orderId, LatLng destCoord) async {
    if (_mapboxRouteCache.containsKey(orderId) ||
        _fetchingRouteIds.contains(orderId) ||
        AppConstants.mapboxAccessToken.isEmpty) {
      return;
    }
    _fetchingRouteIds.add(orderId);
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${_stationHQ.longitude},${_stationHQ.latitude};${destCoord.longitude},${destCoord.latitude}'
        '?geometries=geojson&overview=full&access_token=${AppConstants.mapboxAccessToken}',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes.first as Map<String, dynamic>;
          final coords = (firstRoute['geometry'] as Map<String, dynamic>?)?['coordinates'] as List<dynamic>?;
          final durationSecs = (firstRoute['duration'] as num?)?.toDouble();
          if (coords != null && coords.length >= 2) {
            setState(() {
              _mapboxRouteCache[orderId] = coords.map((c) {
                final pair = c as List<dynamic>;
                return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
              }).toList();
              if (durationSecs != null && durationSecs > 0) {
                _mapboxEtaCache[orderId] = max(2, (durationSecs / 60.0).round());
              }
            });
          }
        }
      }
    } catch (_) {
      // Keep street-grid fallback
    } finally {
      _fetchingRouteIds.remove(orderId);
    }
  }

  LatLng _getDriverCoord(OrderModel order, List<LatLng> routePts) {
    if (routePts.length < 2) return _stationHQ;
    if (order.orderStatus == OrderStatus.onDelivery) {
      return routePts[(routePts.length * 0.68).floor().clamp(0, routePts.length - 1)];
    } else if (order.orderStatus == OrderStatus.assigned) {
      return routePts[(routePts.length * 0.30).floor().clamp(0, routePts.length - 1)];
    }
    return _stationHQ;
  }

  void _zoomIn() {
    if (_zoom < 18) setState(() => _zoom++);
  }

  void _zoomOut() {
    if (_zoom > 11) setState(() => _zoom--);
  }

  void _resetView() {
    setState(() {
      _mapCenter = _stationHQ;
      _zoom = 14;
    });
  }

  @override
  void didUpdateWidget(covariant LiveFleetGpsMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOrder != null && widget.selectedOrder != oldWidget.selectedOrder) {
      final dest = _getOrderCoord(widget.selectedOrder!, 0);
      setState(() {
        _mapCenter = LatLng(
          (dest.latitude + _stationHQ.latitude) / 2.0 - 0.001,
          (dest.longitude + _stationHQ.longitude) / 2.0,
        );
        _zoom = 15;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final activeOrders = widget.orders.where((o) => !o.isWalkIn).toList();
    final activeDispatches = activeOrders
        .where((o) => o.orderStatus == OrderStatus.onDelivery || o.orderStatus == OrderStatus.assigned)
        .toList();
    final OrderModel? trackedOrder = widget.selectedOrder ??
        (activeDispatches.isNotEmpty ? activeDispatches.first : null);

    // Prefetch Mapbox Directions routes for active dispatches
    for (int i = 0; i < activeDispatches.length; i++) {
      final o = activeDispatches[i];
      _ensureMapboxRoute(o.id, _getOrderCoord(o, i));
    }

    final double routeProgress = trackedOrder == null
        ? 0.0
        : (trackedOrder.orderStatus == OrderStatus.completed
            ? 1.0
            : (trackedOrder.orderStatus == OrderStatus.onDelivery ? 0.68 : 0.32));
    final String driverLabel =
        (trackedOrder?.driverName != null && trackedOrder!.driverName!.trim().isNotEmpty)
            ? trackedOrder.driverName!.trim()
            : 'Assigned JJAASS Rider';
    final int? trackedEta = trackedOrder != null ? _mapboxEtaCache[trackedOrder.id] : null;
    final String etaRangeLabel = trackedOrder?.orderStatus == OrderStatus.completed
        ? 'Delivered'
        : (trackedEta != null
            ? '${max(2, trackedEta - 2)} – ${trackedEta + 3} mins'
            : '5 – 10 mins');

    return Container(
      height: 460,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth > 0 ? constraints.maxWidth : 800.0;
          final height = constraints.maxHeight > 0 ? constraints.maxHeight : 460.0;
          final mapViewportHeight = trackedOrder != null ? height * 0.64 : height;

          final centerWx = _lngToWorldX(_mapCenter.longitude, _zoom);
          final centerWy = _latToWorldY(_mapCenter.latitude, _zoom);
          final leftWx = centerWx - width / 2.0;
          final topWy = centerWy - mapViewportHeight / 2.0;

          final maxTile = (1 << _zoom) - 1;
          final minTx = (leftWx / 256.0).floor().clamp(0, maxTile);
          final maxTx = ((leftWx + width) / 256.0).floor().clamp(0, maxTile);
          final minTy = (topWy / 256.0).floor().clamp(0, maxTile);
          final maxTy = ((topWy + height) / 256.0).floor().clamp(0, maxTile);

          final tiles = <Widget>[];
          for (int tx = minTx; tx <= maxTx; tx++) {
            for (int ty = minTy; ty <= maxTy; ty++) {
              final tileLeft = tx * 256.0 - leftWx;
              final tileTop = ty * 256.0 - topWy;
              tiles.add(
                Positioned(
                  key: ValueKey('admin_mb_${widget.satelliteMode}_${_zoom}_${tx}_$ty'),
                  left: tileLeft,
                  top: tileTop,
                  width: 256,
                  height: 256,
                  child: Image.network(
                    AppConstants.mapboxAccessToken.isNotEmpty
                        ? AppConstants.mapboxTileUrl(
                            _zoom,
                            tx,
                            ty,
                            satellite: widget.satelliteMode,
                          )
                        : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/$_zoom/$ty/$tx',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.network(
                        'https://tile.openstreetmap.org/$_zoom/$tx/$ty.png',
                        headers: const {
                          'User-Agent': 'JJAASSWaterMarket/1.0 (water delivery app)'
                        },
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      );
                    },
                  ),
                ),
              );
            }
          }

          Offset toScreen(LatLng pt) => Offset(
                _lngToWorldX(pt.longitude, _zoom) - leftWx,
                _latToWorldY(pt.latitude, _zoom) - topWy,
              );

          final routeOverlays = <Map<String, dynamic>>[];
          final pinWidgets = <Widget>[];

          // 1. Station HQ Pin
          final hqPt = toScreen(_stationHQ);
          pinWidgets.add(
            Positioned(
              left: hqPt.dx - 18,
              top: hqPt.dy - 18,
              child: Tooltip(
                message: 'JJAASS Water Market HQ • Albay 1st District',
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.navyColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.store_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
          );

          // 2. Active & Pending Orders + Riders
          for (int i = 0; i < activeOrders.length; i++) {
            final o = activeOrders[i];
            final isSelected = trackedOrder?.id == o.id;
            final destCoord = _getOrderCoord(o, i);
            final routeCoords = _mapboxRouteCache[o.id] ??
                _buildStreetRouteWaypoints(_stationHQ, destCoord);
            final driverCoord = _getDriverCoord(o, routeCoords);
            final isActive =
                o.orderStatus == OrderStatus.onDelivery || o.orderStatus == OrderStatus.assigned;
            final isCompleted = o.orderStatus == OrderStatus.completed;

            if (isActive) {
              routeOverlays.add({
                'points': routeCoords.map(toScreen).toList(),
                'isSelected': isSelected,
              });
            }

            final destPt = toScreen(destCoord);
            pinWidgets.add(
              Positioned(
                left: destPt.dx - 15,
                top: destPt.dy - 30,
                child: GestureDetector(
                  onTap: () => widget.onSelectOrder?.call(o),
                  child: Tooltip(
                    message: '${o.id} • ${o.customerName} (${o.orderStatus.displayName})',
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : (isCompleted
                                ? const Color(0xFF10B981)
                                : (isActive ? const Color(0xFF0284C7) : const Color(0xFFF59E0B))),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.24),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.water_drop_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ),
            );

            if (isActive && o.driverName != null) {
              final drvPt = toScreen(driverCoord);
              pinWidgets.add(
                Positioned(
                  left: drvPt.dx - 17,
                  top: drvPt.dy - 17,
                  child: GestureDetector(
                    onTap: () => widget.onSelectOrder?.call(o),
                    child: Tooltip(
                      message: '🛵 Rider: ${o.driverName} (${o.id})',
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0284C7), Color(0xFF1D63B8)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.45),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.two_wheeler_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) {},
            onScaleUpdate: (details) {
              final delta = details.focalPointDelta;
              if (delta.dx == 0 && delta.dy == 0) return;
              final newWx = _lngToWorldX(_mapCenter.longitude, _zoom) - delta.dx;
              final newWy = _latToWorldY(_mapCenter.latitude, _zoom) - delta.dy;
              setState(() {
                _mapCenter = LatLng(
                  _worldYToLat(newWy, _zoom).clamp(13.0, 13.7),
                  _worldXToLng(newWx, _zoom).clamp(123.3, 124.1),
                );
              });
            },
            child: Stack(
              children: [
                ...tiles,

                // Mapbox Directions Street Route Polylines
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _AdminFleetRoutesPainter(routes: routeOverlays),
                    ),
                  ),
                ),

                ...pinWidgets,

                // Map Header Legend & Badge
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.90)
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mapbox Live Fleet • Albay 1st District',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${activeDispatches.length} Active Dispatches',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top-Right "Help" Pill Button
                Positioned(
                  top: 14,
                  right: 56,
                  child: Material(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: widget.onHelpTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                          ),
                        ),
                        child: Text(
                          'Help',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Map Control Floating Action Buttons (Zoom / Recenter 🎯)
                Positioned(
                  top: 14,
                  right: 14,
                  child: Column(
                    children: [
                      _buildMapButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Zoom In',
                        isDark: isDark,
                        onTap: _zoomIn,
                      ),
                      const SizedBox(height: 6),
                      _buildMapButton(
                        icon: Icons.remove_rounded,
                        tooltip: 'Zoom Out',
                        isDark: isDark,
                        onTap: _zoomOut,
                      ),
                      const SizedBox(height: 6),
                      _buildMapButton(
                        icon: Icons.gps_fixed_rounded,
                        tooltip: 'Recenter Route',
                        isDark: isDark,
                        onTap: _resetView,
                      ),
                    ],
                  ),
                ),

                // Foodpanda-Style 2-Card Live Tracker Overlay
                if (trackedOrder != null)
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A).withValues(alpha: 0.96)
                                : Colors.white.withValues(alpha: 0.98),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          etaRangeLabel,
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            letterSpacing: -0.5,
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            trackedOrder.id,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      trackedOrder.isCollectionJob
                                          ? 'Collecting empty gallons'
                                          : (trackedOrder.orderStatus == OrderStatus.assigned
                                              ? 'Rider assigned & preparing'
                                              : 'On the way'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Rider $driverLabel is heading to ${trackedOrder.customerName} (${trackedOrder.deliveryAddress})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              SizedBox(
                                width: 60,
                                height: 60,
                                child: CustomPaint(
                                  painter: _AdminTrackerRingPainter(progress: routeProgress),
                                  child: Center(
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF0284C7), Color(0xFF1D63B8)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: const Icon(
                                        Icons.water_drop_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A).withValues(alpha: 0.96)
                                : Colors.white.withValues(alpha: 0.98),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE0F2FE),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.sports_motorsports_rounded,
                                        color: Color(0xFF0284C7),
                                        size: 19,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'The rider ($driverLabel) will deliver ${trackedOrder.itemsSummary} to ${trackedOrder.customerName} by motorbike',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(16),
                                  ),
                                  onTap: widget.onChatTap,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 16,
                                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Chat with rider or customer (${trackedOrder.id})',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                        ),
                                      ],
                                    ),
                                  ),
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
          );
        },
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminTrackerRingPainter extends CustomPainter {
  final double progress;
  const _AdminTrackerRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.135;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final trackPaint = Paint()
      ..color = const Color(0xFFD1FAE5)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final sweep = 2 * pi * progress.clamp(0.18, 0.98);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AdminTrackerRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _AdminFleetRoutesPainter extends CustomPainter {
  final List<Map<String, dynamic>> routes;
  const _AdminFleetRoutesPainter({required this.routes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in routes) {
      final pts = r['points'] as List<Offset>;
      final isSelected = r['isSelected'] == true;
      if (pts.length < 2) continue;

      final casing = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = isSelected ? 8.0 : 5.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final line = Paint()
        ..color = isSelected ? const Color(0xFF0284C7) : const Color(0xFF38BDF8)
        ..strokeWidth = isSelected ? 4.8 : 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, casing);
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(covariant _AdminFleetRoutesPainter oldDelegate) => true;
}
