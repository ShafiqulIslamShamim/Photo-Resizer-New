import 'dart:typed_data';

import 'dart:html' as html;

class ExportService {
  /// Triggers a browser download of the encoded image bytes.
  static Future<bool> saveBytes(Uint8List bytes, String fileName) async {
    try {
      final blob = html.Blob(<Object>[bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = fileName
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      return true;
    } catch (_) {
      return false;
    }
  }
}
