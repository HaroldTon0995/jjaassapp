import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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
  static int _viewCounter = 0;
  late String _viewType;
  web.HTMLIFrameElement? _iframe;
  JSFunction? _messageListener;

  String get _iframeUrl =>
      'recaptcha.html?sitekey=${Uri.encodeComponent(widget.siteKey)}&v=${widget.resetTrigger}';

  @override
  void initState() {
    super.initState();
    _registerView();
    _attachMessageListener();
  }

  void _registerView() {
    _viewCounter++;
    _viewType = 'jjaass-recaptcha-$_viewCounter';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = _iframeUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent';
      _iframe = iframe;
      return iframe;
    });
  }

  void _attachMessageListener() {
    _messageListener = ((web.Event event) {
      if (!mounted) return;
      final msgEvent = event as web.MessageEvent;
      final data = msgEvent.data;
      if (data == null || !data.isA<JSObject>()) return;
      final obj = data as JSObject;
      final type = obj.getProperty('type'.toJS);
      if (type != null && type.dartify() == 'recaptcha-token') {
        final token = obj.getProperty('token'.toJS)?.dartify()?.toString() ?? '';
        widget.onTokenChanged(token);
      }
    }).toJS;
    web.window.addEventListener('message', _messageListener);
  }

  @override
  void didUpdateWidget(covariant RecaptchaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetTrigger != widget.resetTrigger ||
        oldWidget.siteKey != widget.siteKey) {
      _iframe?.src = _iframeUrl;
    }
  }

  @override
  void dispose() {
    if (_messageListener != null) {
      web.window.removeEventListener('message', _messageListener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      width: double.infinity,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
