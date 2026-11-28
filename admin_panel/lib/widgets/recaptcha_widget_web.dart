import 'dart:async';
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
    this.bridgeUrl = '',
    required this.resetTrigger,
    required this.onTokenChanged,
  });

  @override
  State<RecaptchaWidget> createState() => _RecaptchaWidgetState();
}

class _RecaptchaWidgetState extends State<RecaptchaWidget> {
  static int _viewCounter = 0;
  late final String _viewType;
  web.HTMLDivElement? _container;
  Timer? _initTimer;
  JSAny? _recaptchaWidgetId;
  bool _rendered = false;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  void _registerView() {
    _viewCounter++;
    _viewType = 'jjaass-recaptcha-div-$_viewCounter';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final div = web.HTMLDivElement()
        ..id = _viewType
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'flex'
        ..style.justifyContent = 'center'
        ..style.alignItems = 'center'
        ..style.overflow = 'visible';
      _container = div;
      _scheduleRender();
      return div;
    });
  }

  void _scheduleRender() {
    _initTimer?.cancel();
    if (_tryRender()) return;
    _initTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_tryRender()) {
        timer.cancel();
      }
    });
  }

  JSObject? _getGrecaptcha() {
    if (!web.window.hasProperty('grecaptcha'.toJS).toDart) return null;
    final raw = web.window.getProperty('grecaptcha'.toJS);
    if (raw == null || !raw.isA<JSObject>()) return null;
    final obj = raw as JSObject;
    if (!obj.hasProperty('render'.toJS).toDart) return null;
    return obj;
  }

  bool _tryRender() {
    if (_rendered) return true;
    final div = _container;
    final grecaptcha = _getGrecaptcha();
    if (div == null || grecaptcha == null) return false;

    final options = JSObject();
    options.setProperty('sitekey'.toJS, widget.siteKey.toJS);
    options.setProperty(
      'callback'.toJS,
      ((JSString token) {
        if (mounted) {
          widget.onTokenChanged(token.toDart);
        }
      }).toJS,
    );
    options.setProperty(
      'expired-callback'.toJS,
      (() {
        if (mounted) {
          widget.onTokenChanged('');
        }
      }).toJS,
    );
    options.setProperty(
      'error-callback'.toJS,
      (() {
        if (mounted) {
          widget.onTokenChanged('');
        }
      }).toJS,
    );

    _recaptchaWidgetId = grecaptcha.callMethod('render'.toJS, div, options);
    _rendered = true;
    return true;
  }

  @override
  void didUpdateWidget(covariant RecaptchaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetTrigger != widget.resetTrigger && _rendered) {
      final grecaptcha = _getGrecaptcha();
      if (grecaptcha != null && _recaptchaWidgetId != null) {
        grecaptcha.callMethod('reset'.toJS, _recaptchaWidgetId);
      }
    }
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      width: double.infinity,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
