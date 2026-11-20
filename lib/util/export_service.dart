/// Platform-selecting facade for exporting the processed image.
///
/// On Android/iOS the bytes are written to the temporary directory and handed
/// to the native share sheet (which lets the user save to the gallery/Files).
/// On web a browser download is triggered instead.
export 'export_service_io.dart' if (dart.library.html) 'export_service_web.dart';
