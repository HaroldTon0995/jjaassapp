import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../services/tracking_service.dart';

class GoogleMapWidget extends StatefulWidget {
  final double? destinationLat;
  final double? destinationLng;
  final String destinationAddress;
  final String? customerName;
  final String? customerPhone;
  final String? driverName;
  final String? itemsSummary;
  final String? statusTitle;
  final bool isDriverView;
  final bool isCollectionJob;
  final String orderId;
  final List<dynamic>? otherActiveOrders;
  final ValueChanged<String>? onOrderPinTapped;
  final VoidCallback? onChatTap;
  final VoidCallback? onHelpTap;
  final bool showTrackerCards;

  const GoogleMapWidget({
    super.key,
    this.destinationLat,
    this.destinationLng,
    required this.destinationAddress,
    this.customerName,
    this.customerPhone,
    this.driverName,
    this.itemsSummary,
    this.statusTitle,
    required this.isDriverView,
    this.isCollectionJob = false,
    required this.orderId,
    this.otherActiveOrders,
    this.onOrderPinTapped,
    this.onChatTap,
    this.onHelpTap,
    this.showTrackerCards = true,
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

  late LatLng _originCoord;
  late LatLng _driverCoord;
  late LatLng _mapCenter;
  List<LatLng> _routePoints = [];
  double _routeProgress = 0.42;
  int? _mapboxEtaMinutes;
  double? _mapboxDistanceKm;
  int _zoom = 15;
  bool _isLoadingLocation = false;
  Timer? _mockMovementTimer;

  @override
  void initState() {
    super.initState();
    _setupRouteAndTracking();
  }

  void _setupRouteAndTracking() {
    final dest = _destinationCoord;
    _originCoord = LatLng(dest.latitude - 0.0075, dest.longitude - 0.0065);
    _routePoints = _buildStreetGridFallbackRoute(_originCoord, dest);
    _routeProgress = 0.42;
    _driverCoord = _interpolateAlongRoute(_routePoints, _routeProgress);
    _mapCenter = LatLng(
      (dest.latitude + _driverCoord.latitude) / 2.0 - 0.0012,
      (dest.longitude + _driverCoord.longitude) / 2.0,
    );
    _fetchOsrmStreetRoute(_originCoord, dest);
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
      _originCoord = LatLng(dest.latitude - 0.0075, dest.longitude - 0.0065);
      _routePoints = _buildStreetGridFallbackRoute(_originCoord, dest);
      _routeProgress = 0.42;
      _driverCoord = _interpolateAlongRoute(_routePoints, _routeProgress);
      _zoomToFitMarkers();
      _fetchOsrmStreetRoute(_originCoord, dest);
    }
  }

  @override
  void dispose() {
    _trackingStreamSub?.cancel();
    _positionStreamSub?.cancel();
    _mockMovementTimer?.cancel();
    super.dispose();
  }

  List<LatLng> _buildStreetGridFallbackRoute(LatLng start, LatLng end) {
    final dLat = end.latitude - start.latitude;
    final dLng = end.longitude - start.longitude;
    final p1 = LatLng(
      start.latitude + dLat * 0.32,
      start.longitude + dLng * 0.12,
    );
    final p2 = LatLng(
      start.latitude + dLat * 0.72,
      start.longitude + dLng * 0.28,
    );
    final p3 = LatLng(
      start.latitude + dLat * 0.88,
      start.longitude + dLng * 0.68,
    );
    final p4 = LatLng(
      start.latitude + dLat * 1.04,
      start.longitude + dLng * 0.94,
    );
    final p5 = LatLng(
      end.latitude + dLat * 0.04,
      end.longitude + dLng * 0.06,
    );
    return [start, p1, p2, p3, p4, p5, end];
  }

  Future<void> _fetchOsrmStreetRoute(LatLng start, LatLng end) async {
    // 1. Primary: Mapbox Directions API (traffic-aware driving route + ETA)
    if (AppConstants.mapboxAccessToken.isNotEmpty) {
      try {
        final mbUrl = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/driving/'
          '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
          '?geometries=geojson&overview=full&access_token=${AppConstants.mapboxAccessToken}',
        );
        final mbRes = await http.get(mbUrl).timeout(const Duration(seconds: 5));
        if (mbRes.statusCode == 200 && mounted) {
          final data = jsonDecode(mbRes.body) as Map<String, dynamic>;
          final routes = data['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final firstRoute = routes.first as Map<String, dynamic>;
            final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
            final coords = geometry?['coordinates'] as List<dynamic>?;
            final durationSecs = (firstRoute['duration'] as num?)?.toDouble();
            final distMeters = (firstRoute['distance'] as num?)?.toDouble();
            if (coords != null && coords.length >= 2) {
              final parsed = coords.map((c) {
                final pair = c as List<dynamic>;
                return LatLng(
                  (pair[1] as num).toDouble(),
                  (pair[0] as num).toDouble(),
                );
              }).toList();
              setState(() {
                _routePoints = parsed;
                if (durationSecs != null && durationSecs > 0) {
                  _mapboxEtaMinutes = max(2, (durationSecs / 60.0).round());
                }
                if (distMeters != null && distMeters > 0) {
                  _mapboxDistanceKm = distMeters / 1000.0;
                }
                if (!_hasRealLocation) {
                  _driverCoord = _interpolateAlongRoute(_routePoints, _routeProgress);
                }
              });
              return;
            }
          }
        }
      } catch (_) {}
    }

    // 2. Fallback: OSRM public driving route
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes.first['geometry'] as Map<String, dynamic>?;
          final coords = geometry?['coordinates'] as List<dynamic>?;
          if (coords != null && coords.length >= 3) {
            final parsed = coords.map((c) {
              final pair = c as List<dynamic>;
              return LatLng(
                (pair[1] as num).toDouble(),
                (pair[0] as num).toDouble(),
              );
            }).toList();
            setState(() {
              _routePoints = parsed;
              if (!_hasRealLocation) {
                _driverCoord = _interpolateAlongRoute(_routePoints, _routeProgress);
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  LatLng _interpolateAlongRoute(List<LatLng> points, double t) {
    if (points.isEmpty) return _destinationCoord;
    if (points.length == 1) return points.first;
    final clamped = t.clamp(0.0, 1.0);

    double totalDist = 0.0;
    final segLengths = <double>[];
    for (int i = 0; i < points.length - 1; i++) {
      final d = _calculateDistanceKm(points[i], points[i + 1]);
      segLengths.add(d);
      totalDist += d;
    }
    if (totalDist <= 0.00001) return points.last;

    final targetDist = totalDist * clamped;
    double accum = 0.0;
    for (int i = 0; i < segLengths.length; i++) {
      final seg = segLengths[i];
      if (accum + seg >= targetDist || i == segLengths.length - 1) {
        final localT = seg > 0 ? ((targetDist - accum) / seg).clamp(0.0, 1.0) : 0.0;
        final a = points[i];
        final b = points[i + 1];
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * localT,
          a.longitude + (b.longitude - a.longitude) * localT,
        );
      }
      accum += seg;
    }
    return points.last;
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
          final dest = _destinationCoord;
          final totalDist = max(0.2, _calculateDistanceKm(_originCoord, dest));
          final remDist = _calculateDistanceKm(loc.position, dest);
          setState(() {
            _driverCoord = loc.position;
            _routeProgress = (1.0 - (remDist / totalDist)).clamp(0.15, 0.95);
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
            _originCoord = _driverCoord;
            _fetchOsrmStreetRoute(_originCoord, _destinationCoord);
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
          final dest = _destinationCoord;
          final totalDist = max(0.2, _calculateDistanceKm(_originCoord, dest));
          final newPos = LatLng(position.latitude, position.longitude);
          final remDist = _calculateDistanceKm(newPos, dest);
          setState(() {
            _driverCoord = newPos;
            _routeProgress = (1.0 - (remDist / totalDist)).clamp(0.15, 0.95);
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
    _mockMovementTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      setState(() {
        _routeProgress += 0.04;
        if (_routeProgress >= 0.90) {
          _routeProgress = 0.28;
        }
        _driverCoord = _interpolateAlongRoute(_routePoints, _routeProgress);
      });
    });
  }

  void _zoomToFitMarkers() {
    if (!mounted) return;
    final dest = _destinationCoord;
    setState(() {
      _mapCenter = LatLng(
        (dest.latitude + _driverCoord.latitude) / 2.0 - 0.0012,
        (dest.longitude + _driverCoord.longitude) / 2.0,
      );
      final latSpan = (dest.latitude - _driverCoord.latitude).abs();
      final lngSpan = (dest.longitude - _driverCoord.longitude).abs();
      final maxSpan = max(latSpan, lngSpan);
      if (maxSpan < 0.009) {
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
    final straightDistKm = _calculateDistanceKm(_driverCoord, dest);
    final distKm = _mapboxDistanceKm != null
        ? max(0.1, _mapboxDistanceKm! * (1.0 - _routeProgress * 0.65))
        : straightDistKm;
    final baseEta = _mapboxEtaMinutes != null
        ? max(2, (_mapboxEtaMinutes! * (1.0 - _routeProgress * 0.5)).round())
        : max(3, (distKm * 4.2).round());
    final minEta = max(2, baseEta - 2);
    final maxEta = minEta + 5;

    final driverLabel = (widget.driverName != null && widget.driverName!.trim().isNotEmpty)
        ? widget.driverName!.trim()
        : 'JJAASS Express Rider';
    final customerLabel = (widget.customerName != null && widget.customerName!.trim().isNotEmpty)
        ? widget.customerName!.trim()
        : 'Customer';
    final statusHeadline = widget.statusTitle ??
        (widget.isCollectionJob ? 'Collecting gallons' : 'On the way');
    final statusSubtitle = widget.isDriverView
        ? (widget.isCollectionJob
            ? 'Heading to $customerLabel for gallon pickup'
            : 'Heading to $customerLabel')
        : 'The rider is heading to you';

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 0 ? constraints.maxWidth : 360.0;
        final height = constraints.maxHeight > 0 ? constraints.maxHeight : 360.0;
        final isCompactHeight = height < 320;
        final showCards = widget.showTrackerCards && height >= 210;

        final mapViewportHeight = showCards ? max(130.0, height * 0.58) : height;
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
                key: ValueKey('track_tile_${_zoom}_${tx}_$ty'),
                left: tileLeft,
                top: tileTop,
                width: 256,
                height: 256,
                child: Image.network(
                  AppConstants.mapboxAccessToken.isNotEmpty
                      ? AppConstants.mapboxTileUrl(_zoom, tx, ty)
                      : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/$_zoom/$ty/$tx',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.network(
                      'https://tile.openstreetmap.org/$_zoom/$tx/$ty.png',
                      headers: const {
                        'User-Agent': 'JJAASSWaterMarket/1.0 (water delivery app)'
                      },
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => CustomPaint(
                        painter: _FallbackTrackTilePainter(tx: tx, ty: ty),
                      ),
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

        final routeScreenPoints = _routePoints.map((pt) {
          return Offset(
            _lngToWorldX(pt.longitude, _zoom) - leftWx,
            _latToWorldY(pt.latitude, _zoom) - topWy,
          );
        }).toList();

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

              // Street-Turn Route Polyline Overlay (Foodpanda style)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _RouteLinePainter(
                      routePoints: routeScreenPoints,
                      driverPoint: Offset(driverX, driverY),
                      destPoint: Offset(destX, destY),
                      progress: _routeProgress,
                    ),
                  ),
                ),
              ),

              // Customer Destination Pin
              Positioned(
                left: destX - 68,
                top: destY - 58,
                width: 136,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        widget.destinationAddress.isNotEmpty
                            ? widget.destinationAddress
                            : customerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 26),
                          child: CustomPaint(
                            size: const Size(12, 8),
                            painter: _PinPointerPainter(color: const Color(0xFF0F172A)),
                          ),
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.water_drop_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Moving Rider Pin
              Positioned(
                left: driverX - 24,
                top: driverY - 40,
                width: 48,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 30),
                          child: CustomPaint(
                            size: const Size(12, 8),
                            painter: _PinPointerPainter(color: const Color(0xFF0284C7)),
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF1D63B8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.45),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.two_wheeler_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Top-Left Order / District Status Pill
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(18),
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
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live GPS • ${distKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Top-Right "Help" Pill Button
              Positioned(
                right: 10,
                top: 10,
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: widget.onHelpTap ??
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Need help with this delivery? Open AquaBot AI Support or Chat below!',
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF94A3B8)),
                      ),
                      child: const Text(
                        'Help',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Map Recenter & Zoom Controls
              Positioned(
                right: 10,
                bottom: showCards ? (isCompactHeight ? 132 : 172) : 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildZoomBtn(
                      icon: Icons.add_rounded,
                      onTap: () {
                        if (_zoom < 18) setState(() => _zoom++);
                      },
                    ),
                    const SizedBox(height: 5),
                    _buildZoomBtn(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        if (_zoom > 11) setState(() => _zoom--);
                      },
                    ),
                    const SizedBox(height: 5),
                    _buildZoomBtn(
                      icon: Icons.gps_fixed_rounded,
                      onTap: _zoomToFitMarkers,
                      isRound: true,
                    ),
                  ],
                ),
              ),

              // Foodpanda-Style Floating ETA Progress Ring Card + Bottom Rider Chat Card
              if (showCards)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Part 2: Floating ETA Range & Circular Progress Ring Card
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: isCompactHeight ? 8 : 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
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
                                  Text(
                                    '$minEta – $maxEta mins',
                                    style: TextStyle(
                                      fontSize: isCompactHeight ? 18 : 22,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    statusHeadline,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isCompactHeight ? 11.5 : 13,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    statusSubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isCompactHeight ? 10.5 : 11.5,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: isCompactHeight ? 50 : 62,
                              height: isCompactHeight ? 50 : 62,
                              child: CustomPaint(
                                painter: _TrackerProgressRingPainter(
                                  progress: _routeProgress,
                                ),
                                child: Center(
                                  child: _WaterDeliveryBagBadge(
                                    size: isCompactHeight ? 26 : 32,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isCompactHeight ? 5 : 7),

                      // Part 3: Bottom Rider Motorbike Info & Interactive Chat Action Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.09),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: isCompactHeight ? 6 : 9,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: isCompactHeight ? 28 : 34,
                                    height: isCompactHeight ? 28 : 34,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE0F2FE),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.sports_motorsports_rounded,
                                      color: const Color(0xFF0284C7),
                                      size: isCompactHeight ? 16 : 19,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      widget.isDriverView
                                          ? 'Delivering ${widget.itemsSummary ?? "water order"} to $customerLabel'
                                          : 'The rider ($driverLabel) will deliver your order by motorbike',
                                      maxLines: isCompactHeight ? 1 : 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: isCompactHeight ? 10.5 : 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E293B),
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(16),
                                ),
                                onTap: widget.onChatTap,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: isCompactHeight ? 6 : 8,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 16,
                                        color: Color(0xFF334155),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          widget.isDriverView
                                              ? 'Chat with customer'
                                              : 'Chat with your rider',
                                          style: TextStyle(
                                            fontSize: isCompactHeight ? 11 : 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: Color(0xFF64748B),
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
    );
  }

  Widget _buildZoomBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool isRound = false,
  }) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shape: isRound
          ? const CircleBorder()
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        customBorder: isRound
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 16,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}

class _RouteLinePainter extends CustomPainter {
  final List<Offset> routePoints;
  final Offset driverPoint;
  final Offset destPoint;
  final double progress;

  const _RouteLinePainter({
    required this.routePoints,
    required this.driverPoint,
    required this.destPoint,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pts = routePoints.length >= 2 ? routePoints : [driverPoint, destPoint];

    final casingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final completedPaint = Paint()
      ..color = const Color(0xFF93C5FD)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final activeRoutePaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final fullPath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      fullPath.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(fullPath, casingPaint);
    canvas.drawPath(fullPath, completedPaint);

    final splitIdx = ((pts.length - 1) * progress).floor().clamp(0, pts.length - 1);
    final activePath = Path()..moveTo(driverPoint.dx, driverPoint.dy);
    for (int i = splitIdx + 1; i < pts.length; i++) {
      activePath.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(activePath, activeRoutePaint);
  }

  @override
  bool shouldRepaint(covariant _RouteLinePainter oldDelegate) {
    return oldDelegate.driverPoint != driverPoint ||
        oldDelegate.destPoint != destPoint ||
        oldDelegate.progress != progress ||
        oldDelegate.routePoints.length != routePoints.length;
  }
}

class _PinPointerPainter extends CustomPainter {
  final Color color;
  const _PinPointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinPointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TrackerProgressRingPainter extends CustomPainter {
  final double progress;
  const _TrackerProgressRingPainter({required this.progress});

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

    final sweep = 2 * pi * progress.clamp(0.18, 0.95);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TrackerProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _WaterDeliveryBagBadge extends StatelessWidget {
  final double size;
  const _WaterDeliveryBagBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF1D63B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.28),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.shopping_bag_rounded,
            color: Colors.white,
            size: size * 0.68,
          ),
          Padding(
            padding: EdgeInsets.only(top: size * 0.14),
            child: Icon(
              Icons.water_drop_rounded,
              color: const Color(0xFF38BDF8),
              size: size * 0.30,
            ),
          ),
        ],
      ),
    );
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
    canvas.drawLine(
      Offset(0, size.height * 0.45),
      Offset(size.width, size.height * 0.55),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.35, 0),
      Offset(size.width * 0.65, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
