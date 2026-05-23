import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Displays a Base64-encoded image from a Firestore document field.
class Base64ImageViewer extends StatelessWidget {
  final String base64String;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const Base64ImageViewer({
    super.key,
    required this.base64String,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Uint8List bytes;
    try {
      bytes = base64Decode(base64String);
    } catch (_) {
      return _ErrorBox();
    }

    final image = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      child: Image.memory(
        bytes,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => _ErrorBox(),
      ),
    );

    return image;
  }
}

class _ErrorBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.3)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, size: 32, color: Colors.grey),
            SizedBox(height: 8),
            Text('تعذر، لا يمكن عرض الصورة', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
