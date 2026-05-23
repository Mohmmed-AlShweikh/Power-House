import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageService {
  /// Compress image and encode to Base64 string
  static Future<String> imageToBase64(Uint8List bytes, {int maxWidth = 800, int quality = 85}) async {
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    // Resize if too large
    img.Image processed = image;
    if (image.width > maxWidth) {
      processed = img.copyResize(image, width: maxWidth);
    }

    // Encode to JPEG
    final jpeg = img.encodeJpg(processed, quality: quality);
    return base64Encode(jpeg);
  }

  /// Decode Base64 string back to image bytes
  static Uint8List base64ToImage(String base64) {
    return base64Decode(base64);
  }

  /// Calculate approximate Base64 size in KB
  static double estimateSizeKB(String base64) {
    return (base64.length * 0.75) / 1024;
  }
}
