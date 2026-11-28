import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RecaptchaWidget extends StatefulWidget {
  final String siteKey;
  final String bridgeUrl;
  final int resetTrigger;
  final ValueChanged<String> onTokenChanged;

  const RecaptchaWidget({
    super.key,
    required this.siteKey,
    required this.bridgeUrl,
    required this.resetTrigger,
    required this.onTokenChanged,
  });

  @override
  State<RecaptchaWidget> createState() => _RecaptchaWidgetState();
}

class _RecaptchaWidgetState extends State<RecaptchaWidget> {
  bool _verified = false;

  @override
  void didUpdateWidget(covariant RecaptchaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetTrigger != widget.resetTrigger) {
      setState(() => _verified = false);
    }
  }

  Future<void> _openRecaptchaPopup() async {
    final token = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _RecaptchaPopupDialog(
        siteKey: widget.siteKey,
        bridgeUrl: widget.bridgeUrl,
      ),
    );
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      setState(() => _verified = true);
      widget.onTokenChanged(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openRecaptchaPopup,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _verified ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _verified
                ? const Color(0xFF10B981)
                : const Color(0xFFD1D5DB),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _verified ? const Color(0xFF10B981) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _verified
                      ? const Color(0xFF10B981)
                      : const Color(0xFF9CA3AF),
                  width: 2,
                ),
              ),
              child: _verified
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _verified ? 'Verified (I\'m not a robot)' : 'I\'m not a robot',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _verified
                      ? const Color(0xFF065F46)
                      : const Color(0xFF1F2937),
                ),
              ),
            ),
            const Icon(
              Icons.security_rounded,
              size: 22,
              color: Color(0xFF2563EB),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecaptchaPopupDialog extends StatefulWidget {
  final String siteKey;
  final String bridgeUrl;

  const _RecaptchaPopupDialog({
    required this.siteKey,
    required this.bridgeUrl,
  });

  @override
  State<_RecaptchaPopupDialog> createState() => _RecaptchaPopupDialogState();
}

class _RecaptchaPopupDialogState extends State<_RecaptchaPopupDialog> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final targetUri = Uri.parse(
      '${widget.bridgeUrl}?sitekey=${Uri.encodeComponent(widget.siteKey)}',
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'RecaptchaChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final token = message.message.trim();
          if (mounted && token.isNotEmpty) {
            Navigator.of(context).pop(token);
          }
        },
      )
      ..loadRequest(targetUri);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 360,
        height: (screenHeight * 0.72).clamp(440.0, 580.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 20,
                    color: Color(0xFF0F2B5C),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Human Verification',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F2B5C),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: WebViewWidget(controller: _controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
