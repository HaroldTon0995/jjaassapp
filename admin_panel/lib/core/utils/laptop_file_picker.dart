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

  /// Picks an image on Web and resizes/compresses it via Canvas (max 480px JPEG)
  /// so Base64 data URLs stay lightweight for localStorage and Supabase sync.
  static Future<LaptopPickedFile?> pickCompressedImage({
    int maxDimension = 480,
    double quality = 0.78,
  }) async {
    final picked = await pickImage();
    if (picked == null || !kIsWeb) return picked;

    final completer = Completer<LaptopPickedFile?>();
    final img = web.HTMLImageElement();

    img.onload = (web.Event _) {
      try {
        final origW = img.naturalWidth;
        final origH = img.naturalHeight;
        if (origW <= 0 || origH <= 0) {
          if (!completer.isCompleted) completer.complete(picked);
          return;
        }
        double scale = 1.0;
        if (origW > maxDimension || origH > maxDimension) {
          scale = maxDimension / (origW > origH ? origW : origH);
        }
        final targetW = (origW * scale).round().clamp(1, maxDimension);
        final targetH = (origH * scale).round().clamp(1, maxDimension);

        final canvas = web.HTMLCanvasElement()
          ..width = targetW
          ..height = targetH;
        final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
        if (ctx == null) {
          if (!completer.isCompleted) completer.complete(picked);
          return;
        }
        ctx.drawImage(img, 0, 0, targetW.toDouble(), targetH.toDouble());
        final compressedDataUrl = canvas.toDataURL('image/jpeg', quality.toJS);
        final base64Str = compressedDataUrl.contains(',')
            ? compressedDataUrl.split(',')[1]
            : compressedDataUrl;
        final bytes = base64Decode(base64Str);
        if (!completer.isCompleted) {
          completer.complete(
            LaptopPickedFile(
              name: picked.name,
              size: bytes.length,
              bytes: bytes,
              dataUrl: compressedDataUrl,
            ),
          );
        }
      } catch (_) {
        if (!completer.isCompleted) completer.complete(picked);
      }
    }.toJS;

    img.onerror = (web.Event _) {
      if (!completer.isCompleted) completer.complete(picked);
    }.toJS;

    img.src = picked.dataUrl;
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
