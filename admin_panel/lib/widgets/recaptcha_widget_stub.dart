import 'package:flutter/material.dart';

class RecaptchaWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 82,
      child: Center(
        child: Text(
          'reCAPTCHA is supported on Web.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    );
  }
}
