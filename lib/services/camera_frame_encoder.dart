import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class CameraFrameEncoder {
  const CameraFrameEncoder._();

  static Uint8List? encodeJpeg(CameraImage image) {
    if (image.planes.isEmpty) {
      return null;
    }
    if (image.format.group == ImageFormatGroup.bgra8888) {
      final converted = _convertBgra8888ToImage(image);
      if (converted == null) {
        return null;
      }
      return Uint8List.fromList(img.encodeJpg(converted, quality: 82));
    }
    
    if (image.format.group == ImageFormatGroup.yuv420 || image.planes.length >= 3) {
      final converted = _convertYuv420ToImage(image);
      if (converted == null) {
        return null;
      }
      return Uint8List.fromList(img.encodeJpg(converted, quality: 82));
    }

    if (image.planes.isNotEmpty) {
      final bytes = image.planes.first.bytes;
      if (bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
        return bytes;
      }
      if (image.format.group == ImageFormatGroup.jpeg) {
        return bytes;
      }
    }
    
    if (image.planes.length >= 3) {
      final converted = _convertYuv420ToImage(image);
      if (converted != null) {
        return Uint8List.fromList(img.encodeJpg(converted, quality: 82));
      }
    }
    
    return null;
  }

  static img.Image? _convertYuv420ToImage(CameraImage image) {
    if (image.planes.length < 3) {
      return null;
    }
    final width = image.width;
    final height = image.height;
    final out = img.Image(width: width, height: height);
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    var yRowStride = yPlane.bytesPerRow;
    var uRowStride = uPlane.bytesPerRow;
    var vRowStride = vPlane.bytesPerRow;

    // Detect Motorola/budget device bug where reported rowStride includes alignment padding 
    // but the actual buffer is tightly packed without padding.
    if (yPlane.bytes.length == width * height) {
      yRowStride = width;
    }
    final uvWidth = width >> 1;
    final uvHeight = height >> 1;
    if (uPlane.bytes.length == uvWidth * uvHeight) {
      uRowStride = uvWidth;
    }
    if (vPlane.bytes.length == uvWidth * uvHeight) {
      vRowStride = uvWidth;
    }

    final yPixelStride = yPlane.bytesPerPixel ?? 1;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (var y = 0; y < height; y++) {
      final yRowOffset = y * yRowStride;
      final uvRow = y >> 1;
      for (var x = 0; x < width; x++) {
        final uvCol = x >> 1;
        final yIndex = yRowOffset + (x * yPixelStride);
        final uIndex = (uvRow * uRowStride) + (uvCol * uPixelStride);
        final vIndex = (uvRow * vRowStride) + (uvCol * vPixelStride);

        final yp = yIndex < yPlane.bytes.length ? yPlane.bytes[yIndex] : 0;
        final up = uIndex < uPlane.bytes.length ? uPlane.bytes[uIndex] : 128;
        final vp = vIndex < vPlane.bytes.length ? vPlane.bytes[vIndex] : 128;

        final c = yp - 16;
        final d = up - 128;
        final e = vp - 128;

        final r = (1.164 * c + 1.596 * e).round().clamp(0, 255);
        final g = (1.164 * c - 0.392 * d - 0.813 * e).round().clamp(0, 255);
        final b = (1.164 * c + 2.017 * d).round().clamp(0, 255);

        out.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    return out;
  }

  static img.Image? _convertBgra8888ToImage(CameraImage image) {
    final plane = image.planes.first;
    final width = image.width;
    final height = image.height;
    var rowStride = plane.bytesPerRow;
    const bytesPerPixel = 4;
    
    // Detect Motorola/budget device bug for BGRA
    if (plane.bytes.length == width * height * bytesPerPixel) {
      rowStride = width * bytesPerPixel;
    }

    final out = img.Image(width: width, height: height);

    for (var y = 0; y < height; y++) {
      final rowOffset = y * rowStride;
      for (var x = 0; x < width; x++) {
        final index = rowOffset + (x * bytesPerPixel);
        if (index + 3 < plane.bytes.length) {
          final b = plane.bytes[index];
          final g = plane.bytes[index + 1];
          final r = plane.bytes[index + 2];
          final a = plane.bytes[index + 3];
          out.setPixelRgba(x, y, r, g, b, a);
        }
      }
    }
    return out;
  }
}
