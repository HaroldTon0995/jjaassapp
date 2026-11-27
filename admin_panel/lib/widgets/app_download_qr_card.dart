import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';

class AppDownloadQrCard extends StatefulWidget {
  final bool isDark;

  const AppDownloadQrCard({
    super.key,
    this.isDark = false,
  });

  @override
  State<AppDownloadQrCard> createState() => _AppDownloadQrCardState();
}

class _AppDownloadQrCardState extends State<AppDownloadQrCard> {
  static const String _latestReleaseApiUrl =
      'https://api.github.com/repos/HaroldTon0995/jjaassapp/releases/latest';
  static const String _fallbackApkUrl =
      'https://github.com/HaroldTon0995/jjaassapp/releases/latest/download/JJAASS-Water-Market.apk';

  String _apkUrl = _fallbackApkUrl;
  String _releaseVersion = 'Latest Release';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLatestRelease();
  }

  Future<void> _fetchLatestRelease() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final response = await http
          .get(
            Uri.parse(_latestReleaseApiUrl),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tag = (data['tag_name'] ?? '').toString().trim();
        final assets = (data['assets'] as List<dynamic>?) ?? [];

        String resolvedUrl = _fallbackApkUrl;
        for (final asset in assets) {
          if (asset is Map) {
            final name = (asset['name'] ?? '').toString().toLowerCase();
            final downloadUrl =
                (asset['browser_download_url'] ?? '').toString().trim();
            if (name.endsWith('.apk') && downloadUrl.isNotEmpty) {
              resolvedUrl = downloadUrl;
              break;
            }
          }
        }

        if (tag.isNotEmpty && !resolvedUrl.contains(tag)) {
          resolvedUrl = '$resolvedUrl?v=${Uri.encodeComponent(tag)}';
        }

        if (mounted) {
          setState(() {
            _apkUrl = resolvedUrl;
            _releaseVersion = tag.isNotEmpty ? tag : 'Latest Release';
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String get _qrImageUrl =>
      'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${Uri.encodeComponent(_apkUrl)}';

  Future<void> _openDownloadUrl() async {
    final uri = Uri.parse(_apkUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 460;
          final qrWidget = Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Image.network(
              _qrImageUrl,
              width: 112,
              height: 112,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 112,
                height: 112,
                child: Icon(
                  Icons.qr_code_2_rounded,
                  size: 72,
                  color: AppTheme.navyColor,
                ),
              ),
            ),
          );

          final infoWidget = Column(
            crossAxisAlignment: isCompact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment:
                    isCompact ? WrapAlignment.center : WrapAlignment.start,
                children: [
                  Text(
                    'Download JJAASSApp (Android APK)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.navyColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _releaseVersion,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Scan this QR code with your phone camera to download the latest APK. Automatically updates whenever a new release is published.',
                textAlign: isCompact ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment:
                    isCompact ? WrapAlignment.center : WrapAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openDownloadUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navyColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text(
                      'Download APK',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _fetchLatestRelease,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(
                        color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text(
                      'Check Update',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );

          if (isCompact) {
            return Column(
              children: [
                qrWidget,
                const SizedBox(height: 14),
                infoWidget,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              qrWidget,
              const SizedBox(width: 18),
              Expanded(child: infoWidget),
            ],
          );
        },
      ),
    );
  }
}
