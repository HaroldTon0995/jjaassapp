import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

class LaptopPickedFile {
  final String name;
  final int size;
  final Uint8List bytes;
  final String dataUrl;

  LaptopPickedFile({
    required this.name,
    required this.size,
    required this.bytes,
    required this.dataUrl,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class LaptopFilePicker {
  /// Opens laptop native file browser for images (PNG, JPG, JPEG, WebP)
  static Future<LaptopPickedFile?> pickImage() async {
    if (!kIsWeb) return null;

    final completer = Completer<LaptopPickedFile?>();
    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = 'image/png,image/jpeg,image/webp,image/jpg';

    input.onchange = (web.Event e) {
      final files = input.files;
      if (files == null || files.length == 0) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final file = files.item(0)!;
      _readFile(file, (picked) {
        if (!completer.isCompleted) completer.complete(picked);
      });
    }.toJS;

    input.click();
    return completer.future;
  }

  static void _readFile(web.File file, Function(LaptopPickedFile?) callback) {
    final fileName = file.name;
    final fileSize = file.size;

    final reader = web.FileReader();
    reader.onloadend = (web.ProgressEvent pe) {
      final result = reader.result;
      if (result != null) {
        final dataUrl = (result as JSString).toDart;
        try {
          final base64Str = dataUrl.contains(',') ? dataUrl.split(',')[1] : dataUrl;
          final bytes = base64Decode(base64Str);
          callback(LaptopPickedFile(
            name: fileName,
            size: fileSize,
            bytes: bytes,
            dataUrl: dataUrl,
          ));
        } catch (_) {
          callback(null);
        }
      } else {
        callback(null);
      }
    }.toJS;

    reader.onerror = (web.Event pe) {
      callback(null);
    }.toJS;

    reader.readAsDataURL(file);
  }

  /// Sets up drag and drop listener on the laptop browser window
  static void Function() startDropListener(Function(LaptopPickedFile file) onFileDropped) {
    if (!kIsWeb) return () {};

    final dragOverHandler = (web.DragEvent e) {
      e.preventDefault();
    }.toJS;

    final dropHandler = (web.DragEvent e) {
      e.preventDefault();
      final dt = e.dataTransfer;
      if (dt != null) {
        final files = dt.files;
        if (files.length > 0) {
          final file = files.item(0);
          if (file != null) {
            final lower = file.name.toLowerCase();
            if (lower.endsWith('.png') ||
                lower.endsWith('.jpg') ||
                lower.endsWith('.jpeg') ||
                lower.endsWith('.webp')) {
              _readFile(file, (picked) {
                if (picked != null) onFileDropped(picked);
              });
            }
          }
        }
      }
    }.toJS;

    web.window.addEventListener('dragover', dragOverHandler);
    web.window.addEventListener('drop', dropHandler);

    return () {
      web.window.removeEventListener('dragover', dragOverHandler);
      web.window.removeEventListener('drop', dropHandler);
    };
  }
}
