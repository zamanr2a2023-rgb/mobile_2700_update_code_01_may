import 'dart:typed_data';
import 'dart:ui' as ui;

/// Shrinks job photos before multipart upload to avoid nginx 413 errors.
Future<Uint8List> prepareJobPhotoBytes(List<int> raw, {int maxDimension = 960}) async {
  if (raw.isEmpty) return Uint8List(0);

  try {
    final codec = await ui.instantiateImageCodec(
      Uint8List.fromList(raw),
      targetWidth: maxDimension,
      targetHeight: maxDimension,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return Uint8List.fromList(raw);
    return byteData.buffer.asUint8List();
  } catch (_) {
    return Uint8List.fromList(raw);
  }
}

/// Keeps total upload under typical nginx limits (~1MB default on some VPS configs).
Future<Uint8List> prepareJobPhotoBytesForUpload(List<int> raw) async {
  const maxBytes = 750 * 1024;
  var bytes = await prepareJobPhotoBytes(raw);
  if (bytes.length <= maxBytes) return bytes;

  // Second pass — smaller target if still too large.
  bytes = await prepareJobPhotoBytes(raw, maxDimension: 720);
  if (bytes.length <= maxBytes) return bytes;

  bytes = await prepareJobPhotoBytes(raw, maxDimension: 512);
  return bytes;
}
