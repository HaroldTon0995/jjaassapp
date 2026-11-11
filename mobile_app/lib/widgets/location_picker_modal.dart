import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme/app_theme.dart';

/// Modal dialog for customers to pin their exact delivery house/building location
/// within Albay 1st District (Tabaco City, Bacacay, Malilipot, Malinao, Santo Domingo, Tiwi).
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
  // Default to Tabaco City / Bacacay (Albay 1st District)
  static const LatLng _defaultLocation = LatLng(13.3583, 123.7336);

  static const Map<String, LatLng> _albayFirstDistrictCenters = {
    'Tabaco City': LatLng(13.3583, 123.7336),
    'Bacacay': LatLng(13.2925, 123.7917),
    'Malilipot': LatLng(13.3189, 123.7397),
    'Malinao': LatLng(13.4025, 123.7042),
    'Santo Domingo': LatLng(13.2356, 123.7764),
    'Tiwi': LatLng(13.4586, 123.6806),
  };

  late LatLng _selectedLocation;
  late LatLng _mapCenter;
  int _zoom = 15;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? _defaultLocation;
    _mapCenter = _selectedLocation;
    if (widget.initialLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCurrentLocation();
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

  bool _isWithinAlbayFirstDistrict(LatLng pos) {
    return pos.latitude >= 13.15 &&
        pos.latitude <= 13.55 &&
        pos.longitude >= 123.55 &&
        pos.longitude <= 123.95;
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
          _isWithinAlbayFirstDistrict(rawCoord) ? rawCoord : _defaultLocation;

      if (mounted) {
        setState(() {
          _selectedLocation = targetCoord;
          _mapCenter = targetCoord;
          _zoom = 16;
          _isLocating = false;
        });
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
                          'Albay 1st District • Tap or drag the map to set your exact pin',
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

            // Quick Municipality Selector Bar (Albay 1st District)
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
                  children: _albayFirstDistrictCenters.entries.map((entry) {
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
                            'https://${['a', 'b', 'c', 'd'][((tx + ty) % 4).abs()]}.basemaps.cartocdn.com/rastertiles/voyager/$_zoom/$tx/$ty.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.network(
                                'https://tile.openstreetmap.org/$_zoom/$tx/$ty.png',
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
                    onScaleStart: (_) {},
                    onScaleUpdate: (details) {
                      final delta = details.focalPointDelta;
                      if (delta.dx == 0 && delta.dy == 0) return;
                      final newWx = _lngToWorldX(_mapCenter.longitude, _zoom) - delta.dx;
                      final newWy = _latToWorldY(_mapCenter.latitude, _zoom) - delta.dy;
                      setState(() {
                        _mapCenter = LatLng(
                          _worldYToLat(newWy, _zoom).clamp(13.05, 13.60),
                          _worldXToLng(newWx, _zoom).clamp(123.45, 124.00),
                        );
                      });
                    },
                    onTapUp: (details) {
                      final local = details.localPosition;
                      final tappedWx = leftWx + local.dx;
                      final tappedWy = topWy + local.dy;
                      final tappedLat = _worldYToLat(tappedWy, _zoom).clamp(13.15, 13.55);
                      final tappedLng = _worldXToLng(tappedWx, _zoom).clamp(123.55, 123.95);
                      setState(() {
                        _selectedLocation = LatLng(tappedLat, tappedLng);
                      });
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

                        // Zoom Controls
                        Positioned(
                          right: 16,
                          top: 16,
                          child: Column(
                            children: [
                              _buildMapControlButton(
                                icon: Icons.add_rounded,
                                onTap: () {
                                  if (_zoom < 18) setState(() => _zoom++);
                                },
                              ),
                              const SizedBox(height: 6),
                              _buildMapControlButton(
                                icon: Icons.remove_rounded,
                                onTap: () {
                                  if (_zoom > 11) setState(() => _zoom--);
                                },
                              ),
                              const SizedBox(height: 6),
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
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
