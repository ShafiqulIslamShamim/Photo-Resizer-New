import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  /// Writes [bytes] to a temp file and opens the share/save sheet.
  static Future<bool> saveBytes(Uint8List bytes, String fileName) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, name: fileName)],
        subject: 'Photo Resizer export',
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
