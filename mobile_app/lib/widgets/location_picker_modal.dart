import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';

/// Modal dialog for customers to pin their exact delivery house/building location
/// within Bacacay, Albay (mainland and island barangays, blocking open sea pins).
class LocationPickerModal extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerModal({
    super.key,
    this.initialLocation,
  });

  /// Helper to display this picker
  static Future<LatLng?> show(
    BuildContext context, {
    LatLng? initialLocation,
  }) {
    return showDialog<LatLng>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LocationPickerModal(
        initialLocation: initialLocation,
      ),
    );
  }

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  // Exact Business Origin: 7R96+J8H, Bacacay, Albay
  static LatLng get _defaultLocation =>
      LatLng(AppConstants.stationLat, AppConstants.stationLng);

  static Map<String, LatLng> get _bacacayCenters => {
        'Bacacay (HQ)': LatLng(AppConstants.stationLat, AppConstants.stationLng),
        'Bacacay Poblacion': const LatLng(13.2925, 123.7917),
        'Cagraray Island': const LatLng(13.2903, 123.8647),
        'Batan Island': const LatLng(13.2375, 123.9722),
      };

  late LatLng _selectedLocation;
  late LatLng _mapCenter;
  int _zoom = 15;
  double _baseZoom = 15.0;
  bool _isLocating = false;
  bool _isValidatingPin = false;
  String? _pinError;
  int _validationToken = 0;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? _defaultLocation;
    _mapCenter = _selectedLocation;
    if (widget.initialLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCurrentLocation();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _validatePinLocation(_selectedLocation);
      });
    }
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

  bool _isWithinBacacayBounds(LatLng pos) {
    return pos.latitude >= 13.20 &&
        pos.latitude <= 13.38 &&
        pos.longitude >= 123.73 &&
        pos.longitude <= 124.06;
  }

  Future<void> _validatePinLocation(LatLng pos) async {
    final token = ++_validationToken;
    if (!_isWithinBacacayBounds(pos)) {
      if (!mounted) return;
      setState(() {
        _isValidatingPin = false;
        _pinError =
            'Location is outside Bacacay, Albay. Please select a pin within Bacacay.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isValidatingPin = true;
        _pinError = null;
      });
    }

    String? errorMsg;
    try {
      // 1. Primary check: Nominatim reverse geocoding (distinguishes sea/water vs Bacacay land)
      final nomUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${pos.latitude}&lon=${pos.longitude}&zoom=14&addressdetails=1',
      );
      final nomRes = await http
          .get(
            nomUrl,
            headers: const {
              'User-Agent': 'JJAASSWaterMarket/1.0 (water delivery app)',
            },
          )
          .timeout(const Duration(seconds: 6));

      if (nomRes.statusCode == 200) {
        final data = jsonDecode(nomRes.body) as Map<String, dynamic>;
        final hasError = data.containsKey('error');
        final category = (data['category'] ?? '').toString().toLowerCase();
        final type = (data['type'] ?? '').toString().toLowerCase();
        final displayName = (data['display_name'] ?? '').toString().toLowerCase();
        final address = data['address'] as Map<String, dynamic>?;
        final isWaterType = category == 'natural' &&
            (type == 'water' ||
                type == 'bay' ||
                type == 'strait' ||
                type == 'sea' ||
                type == 'coastline');
        final hasRoadOrPlace = address != null &&
            (address.containsKey('road') ||
                address.containsKey('village') ||
                address.containsKey('suburb') ||
                address.containsKey('neighbourhood') ||
                address.containsKey('hamlet') ||
                address.containsKey('island') ||
                address.containsKey('town') ||
                address.containsKey('municipality'));

        if (hasError || isWaterType || !hasRoadOrPlace) {
          errorMsg =
              'Cannot pin in the sea or open water. Please tap on land within Bacacay, Albay.';
        } else if (!displayName.contains('bacacay')) {
          errorMsg =
              'Selected pin is outside Bacacay, Albay. Please select a land address in Bacacay.';
        }
      }
    } catch (_) {
      // Fallback to Mapbox Geocoding if Nominatim times out
      if (AppConstants.mapboxAccessToken.isNotEmpty) {
        try {
          final mbUrl = Uri.parse(
            'https://api.mapbox.com/geocoding/v5/mapbox.places/${pos.longitude},${pos.latitude}.json?types=address,poi,neighborhood,locality&limit=2&access_token=${AppConstants.mapboxAccessToken}',
          );
          final mbRes = await http.get(mbUrl).timeout(const Duration(seconds: 6));
          if (mbRes.statusCode == 200) {
            final data = jsonDecode(mbRes.body) as Map<String, dynamic>;
            final features = (data['features'] as List<dynamic>?) ?? [];
            if (features.isEmpty) {
              errorMsg =
                  'Cannot pin in the sea or open water. Please tap on land within Bacacay, Albay.';
            } else {
              final combined = features
                  .map((f) => (f['place_name'] ?? '').toString().toLowerCase())
                  .join(' ');
              if (!combined.contains('bacacay')) {
                errorMsg =
                    'Selected pin is outside Bacacay, Albay. Please select a land address in Bacacay.';
              }
            }
          }
        } catch (_) {}
      }
    }

    if (!mounted || token != _validationToken) return;
    setState(() {
      _isValidatingPin = false;
      _pinError = errorMsg;
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final rawCoord = LatLng(position.latitude, position.longitude);
      final targetCoord =
          _isWithinBacacayBounds(rawCoord) ? rawCoord : _defaultLocation;

      if (mounted) {
        setState(() {
          _selectedLocation = targetCoord;
          _mapCenter = targetCoord;
          _zoom = 16;
          _isLocating = false;
        });
        _validatePinLocation(targetCoord);
      }
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width > 600 ? 580 : double.infinity,
        height: size.height * 0.82,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.pin_drop_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pin Your Delivery Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Bacacay, Albay Only • Tap on land & pinch to zoom',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Quick Area Selector Bar (Bacacay Only)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _bacacayCenters.entries.map((entry) {
                    final isNear = (_selectedLocation.latitude - entry.value.latitude).abs() < 0.03 &&
                        (_selectedLocation.longitude - entry.value.longitude).abs() < 0.03;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isNear ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        selected: isNear,
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          setState(() {
                            _selectedLocation = entry.value;
                            _mapCenter = entry.value;
                            _zoom = 15;
                          });
                          _validatePinLocation(entry.value);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Interactive OpenStreetMap Tile Canvas
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
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
                          key: ValueKey('tile_${_zoom}_${tx}_$ty'),
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
                                  painter: _FallbackMapTilePainter(tx: tx, ty: ty),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }
                  }

                  final pinX = _lngToWorldX(_selectedLocation.longitude, _zoom) - leftWx;
                  final pinY = _latToWorldY(_selectedLocation.latitude, _zoom) - topWy;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (_) {
                      _baseZoom = _zoom.toDouble();
                    },
                    onScaleUpdate: (details) {
                      final delta = details.focalPointDelta;
                      int nextZoom = _zoom;
                      if (details.pointerCount >= 2 ||
                          (details.scale - 1.0).abs() > 0.01) {
                        nextZoom = (_baseZoom + (log(details.scale) / ln2))
                            .round()
                            .clamp(11, 18);
                      }
                      if (delta.dx == 0 && delta.dy == 0 && nextZoom == _zoom) {
                        return;
                      }
                      final newWx = _lngToWorldX(_mapCenter.longitude, _zoom) - delta.dx;
                      final newWy = _latToWorldY(_mapCenter.latitude, _zoom) - delta.dy;
                      setState(() {
                        _zoom = nextZoom;
                        if (delta.dx != 0 || delta.dy != 0) {
                          _mapCenter = LatLng(
                            _worldYToLat(newWy, _zoom).clamp(13.15, 13.42),
                            _worldXToLng(newWx, _zoom).clamp(123.70, 124.08),
                          );
                        }
                      });
                    },
                    onTapUp: (details) {
                      final local = details.localPosition;
                      final tappedWx = leftWx + local.dx;
                      final tappedWy = topWy + local.dy;
                      final tappedLat = _worldYToLat(tappedWy, _zoom).clamp(13.15, 13.42);
                      final tappedLng = _worldXToLng(tappedWx, _zoom).clamp(123.70, 124.08);
                      final tapped = LatLng(tappedLat, tappedLng);
                      setState(() {
                        _selectedLocation = tapped;
                      });
                      _validatePinLocation(tapped);
                    },
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // Base background
                        Container(color: const Color(0xFFE8EEF5)),
                        ...tiles,

                        // Pinned Marker
                        Positioned(
                          left: pinX - 24,
                          top: pinY - 48,
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
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'Delivery Pin',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.location_on_rounded,
                                size: 40,
                                color: Color(0xFFEF4444),
                              ),
                            ],
                          ),
                        ),

                        // Recenter Control (Zooming is pinch-to-zoom only)
                        Positioned(
                          right: 16,
                          top: 16,
                          child: Column(
                            children: [
                              _buildMapControlButton(
                                icon: Icons.center_focus_strong_rounded,
                                onTap: () {
                                  setState(() => _mapCenter = _selectedLocation);
                                },
                              ),
                            ],
                          ),
                        ),

                        // Floating "Locate Me" GPS button
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: FloatingActionButton.extended(
                            heroTag: 'locate_me_btn',
                            onPressed: _isLocating ? null : _getCurrentLocation,
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            elevation: 4,
                            icon: _isLocating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor,
                                    ),
                                  )
                                : const Icon(Icons.my_location_rounded, size: 18),
                            label: const Text(
                              'Locate Me',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Footer coordinates & Confirm button
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                border: const Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.gps_fixed_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Coordinates: ${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isValidatingPin) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Verifying land location in Bacacay...',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ] else if (_pinError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pinError!,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: (_isValidatingPin || _pinError != null)
                          ? null
                          : () {
                              Navigator.of(context).pop(_selectedLocation);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text(
                        'Confirm Pinned Location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: const Color(0xFF1E293B)),
        ),
      ),
    );
  }
}

class _FallbackMapTilePainter extends CustomPainter {
  final int tx;
  final int ty;

  const _FallbackMapTilePainter({required this.tx, required this.ty});

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
