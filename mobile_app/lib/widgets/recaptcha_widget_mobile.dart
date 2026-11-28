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
  late final WebViewController _controller;

  Uri get _targetUri => Uri.parse(
        '${widget.bridgeUrl}?sitekey=${Uri.encodeComponent(widget.siteKey)}&v=${widget.resetTrigger}',
      );

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'RecaptchaChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (mounted) {
            widget.onTokenChanged(message.message.trim());
          }
        },
      )
      ..loadRequest(_targetUri);
  }

  @override
  void didUpdateWidget(covariant RecaptchaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetTrigger != widget.resetTrigger ||
        oldWidget.siteKey != widget.siteKey ||
        oldWidget.bridgeUrl != widget.bridgeUrl) {
      _controller.loadRequest(_targetUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      width: double.infinity,
      child: WebViewWidget(controller: _controller),
    );
  }
}
