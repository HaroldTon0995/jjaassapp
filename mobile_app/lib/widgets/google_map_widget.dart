import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme/app_theme.dart';
import '../services/tracking_service.dart';

class GoogleMapWidget extends StatefulWidget {
  final double? destinationLat;
  final double? destinationLng;
  final String destinationAddress;
  final String? customerName;
  final String? customerPhone;
  final bool isDriverView;
  final bool isCollectionJob;
  final String orderId;
  final List<dynamic>? otherActiveOrders;
  final ValueChanged<String>? onOrderPinTapped;

  const GoogleMapWidget({
    super.key,
    this.destinationLat,
    this.destinationLng,
    required this.destinationAddress,
    this.customerName,
    this.customerPhone,
    required this.isDriverView,
    this.isCollectionJob = false,
    required this.orderId,
    this.otherActiveOrders,
    this.onOrderPinTapped,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  StreamSubscription<Position>? _positionStreamSub;
  StreamSubscription<DriverLocation>? _trackingStreamSub;
  bool _hasRealLocation = false;

  // Default coordinates: Tabaco City / Bacacay (Albay 1st District)
  static const LatLng _defaultAlbayFirstDistrict = LatLng(13.3583, 123.7336);

  LatLng get _destinationCoord {
    if (widget.destinationLat != null && widget.destinationLng != null) {
      return LatLng(widget.destinationLat!, widget.destinationLng!);
    }
    final addr = widget.destinationAddress.toLowerCase();
    if (addr.contains('bacacay')) return const LatLng(13.2925, 123.7917);
    if (addr.contains('malilipot')) return const LatLng(13.3189, 123.7397);
    if (addr.contains('malinao')) return const LatLng(13.4025, 123.7042);
    if (addr.contains('santo domingo') || addr.contains('sto. domingo')) {
      return const LatLng(13.2356, 123.7764);
    }
    if (addr.contains('tiwi')) return const LatLng(13.4586, 123.6806);
    if (addr.contains('tabaco')) return const LatLng(13.3583, 123.7336);

    final hash = widget.destinationAddress.hashCode;
    final latOffset = ((hash % 40) - 20) / 1000.0;
    final lngOffset = (((hash >> 4) % 40) - 20) / 1000.0;
    return LatLng(
      _defaultAlbayFirstDistrict.latitude + latOffset,
      _defaultAlbayFirstDistrict.longitude + lngOffset,
    );
  }

  late LatLng _driverCoord;
  late LatLng _mapCenter;
  int _zoom = 14;
  bool _isLoadingLocation = false;
  Timer? _mockMovementTimer;

  @override
  void initState() {
    super.initState();
    final dest = _destinationCoord;
    _driverCoord = LatLng(dest.latitude - 0.008, dest.longitude - 0.008);
    _mapCenter = LatLng(
      (dest.latitude + _driverCoord.latitude) / 2.0,
      (dest.longitude + _driverCoord.longitude) / 2.0,
    );
    _initLocationTracking();
  }

  @override
  void didUpdateWidget(covariant GoogleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId ||
        oldWidget.destinationAddress != widget.destinationAddress ||
        oldWidget.destinationLat != widget.destinationLat ||
        oldWidget.destinationLng != widget.destinationLng) {
      final dest = _destinationCoord;
      _driverCoord = LatLng(dest.latitude - 0.008, dest.longitude - 0.008);
      _zoomToFitMarkers();
    }
  }

  @override
  void dispose() {
    _trackingStreamSub?.cancel();
    _positionStreamSub?.cancel();
    _mockMovementTimer?.cancel();
    super.dispose();
  }

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

  bool _isWithinAlbayArea(double lat, double lng) {
    return lat >= 13.0 && lat <= 13.7 && lng >= 123.3 && lng <= 124.1;
  }

  Future<void> _initLocationTracking() async {
    if (!widget.isDriverView) {
      _trackingStreamSub = TrackingService.watch(widget.orderId).listen((loc) {
        if (mounted) {
          _hasRealLocation = true;
          _mockMovementTimer?.cancel();
          setState(() {
            _driverCoord = loc.position;
            _isLoadingLocation = false;
          });
          _zoomToFitMarkers();
        }
      });

      Timer(const Duration(seconds: 2), () {
        if (mounted && !_hasRealLocation) {
          _startMockDriverMovement();
        }
      });
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _startMockDriverMovement();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _startMockDriverMovement();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _startMockDriverMovement();
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );

      if (mounted) {
        final useReal = _isWithinAlbayArea(pos.latitude, pos.longitude);
        setState(() {
          if (useReal) {
            _driverCoord = LatLng(pos.latitude, pos.longitude);
          }
          _isLoadingLocation = false;
        });
        _zoomToFitMarkers();

        TrackingService.publish(
          orderId: widget.orderId,
          driverId: 'driver',
          lat: _driverCoord.latitude,
          lng: _driverCoord.longitude,
        );
        if (!useReal) {
          _startMockDriverMovement();
        }
      }

      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        if (mounted && _isWithinAlbayArea(position.latitude, position.longitude)) {
          setState(() {
            _driverCoord = LatLng(position.latitude, position.longitude);
          });
          TrackingService.publish(
            orderId: widget.orderId,
            driverId: 'driver',
            lat: position.latitude,
            lng: position.longitude,
          );
        }
      });
    } catch (_) {
      _startMockDriverMovement();
    }
  }

  void _startMockDriverMovement() {
    _mockMovementTimer?.cancel();
    double progress = 0.0;
    final LatLng start = _driverCoord;
    final LatLng end = _destinationCoord;

    _mockMovementTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      progress += 0.05;
      if (progress >= 0.88) {
        progress = 0.25;
      }

      setState(() {
        _driverCoord = LatLng(
          start.latitude + (end.latitude - start.latitude) * progress,
          start.longitude + (end.longitude - start.longitude) * progress,
        );
      });
    });
  }

  void _zoomToFitMarkers() {
    if (!mounted) return;
    final dest = _destinationCoord;
    setState(() {
      _mapCenter = LatLng(
        (dest.latitude + _driverCoord.latitude) / 2.0,
        (dest.longitude + _driverCoord.longitude) / 2.0,
      );
      final latSpan = (dest.latitude - _driverCoord.latitude).abs();
      final lngSpan = (dest.longitude - _driverCoord.longitude).abs();
      final maxSpan = max(latSpan, lngSpan);
      if (maxSpan < 0.008) {
        _zoom = 15;
      } else if (maxSpan < 0.025) {
        _zoom = 14;
      } else if (maxSpan < 0.06) {
        _zoom = 13;
      } else {
        _zoom = 12;
      }
    });
  }

  double _calculateDistanceKm(LatLng a, LatLng b) {
    const p = 0.017453292519943295;
    final c = cos;
    final val = 0.5 -
        c((b.latitude - a.latitude) * p) / 2 +
        c(a.latitude * p) *
            c(b.latitude * p) *
            (1 - c((b.longitude - a.longitude) * p)) /
            2;
    return 12742 * asin(sqrt(val));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    final dest = _destinationCoord;
    final distKm = _calculateDistanceKm(_driverCoord, dest);
    final etaMins = max(2, (distKm * 3.5).round());

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 0 ? constraints.maxWidth : 360.0;
        final height = constraints.maxHeight > 0 ? constraints.maxHeight : 260.0;
        final centerWx = _lngToWorldX(_mapCenter.longitude, _zoom);
        final centerWy = _latToWorldY(_mapCenter.latitude, _zoom);
        final leftWx = centerWx - width / 2.0;
        final topWy = centerWy - height / 2.0;

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
                key: ValueKey('track_tile_${_zoom}_${tx}_$ty'),
                left: tileLeft,
                top: tileTop,
                width: 256,
                height: 256,
                child: Image.network(
                  'https://tile.openstreetmap.org/$_zoom/$tx/$ty.png',
                  fit: BoxFit.cover,
                  headers: const {
                    'User-Agent': 'JJAASSWaterMarketApp/1.0',
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return CustomPaint(
                      painter: _FallbackTrackTilePainter(tx: tx, ty: ty),
                    );
                  },
                ),
              ),
            );
          }
        }

        final driverX = _lngToWorldX(_driverCoord.longitude, _zoom) - leftWx;
        final driverY = _latToWorldY(_driverCoord.latitude, _zoom) - topWy;
        final destX = _lngToWorldX(dest.longitude, _zoom) - leftWx;
        final destY = _latToWorldY(dest.latitude, _zoom) - topWy;

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
            clipBehavior: Clip.hardEdge,
            children: [
              Container(color: const Color(0xFFE8EEF5)),
              ...tiles,

              // Route Polyline Overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _RouteLinePainter(
                      start: Offset(driverX, driverY),
                      end: Offset(destX, destY),
                    ),
                  ),
                ),
              ),

              // Destination Marker (Customer Address)
              Positioned(
                left: destX - 65,
                top: destY - 54,
                width: 130,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        widget.destinationAddress.isNotEmpty
                            ? widget.destinationAddress
                            : 'Customer Location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFEF4444),
                      size: 34,
                    ),
                  ],
                ),
              ),

              // Driver Live Marker
              Positioned(
                left: driverX - 55,
                top: driverY - 50,
                width: 110,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        widget.isDriverView ? 'Your Rider GPS' : 'Delivery Rider',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),

              // Top Live Status Pill
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Albay 1st District • ${distKm.toStringAsFixed(1)} km (~$etaMins min)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Zoom & Center Controls
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildZoomBtn(
                      icon: Icons.add_rounded,
                      onTap: () {
                        if (_zoom < 18) setState(() => _zoom++);
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildZoomBtn(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        if (_zoom > 11) setState(() => _zoom--);
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildZoomBtn(
                      icon: Icons.center_focus_strong_rounded,
                      onTap: _zoomToFitMarkers,
                      isPrimary: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZoomBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: isPrimary ? AppTheme.primaryColor : Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 18,
            color: isPrimary ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}

class _RouteLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;

  const _RouteLinePainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final routePaint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant _RouteLinePainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}

class _FallbackTrackTilePainter extends CustomPainter {
  final int tx;
  final int ty;

  const _FallbackTrackTilePainter({required this.tx, required this.ty});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFEFF6FF);
    canvas.drawRect(Offset.zero & size, bg);

    final grid = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.0;
    for (double i = 0; i <= size.width; i += 64) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), grid);
      canvas.drawLine(Offset(0, i), Offset(size.width, i), grid);
    }

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.0;
    canvas.drawLine(Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.55), road);
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.65, size.height), road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
