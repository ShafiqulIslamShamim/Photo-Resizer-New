import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  /// Writes [bytes] to public storage (if permitted on Android) and opens the share/save sheet.
  static Future<bool> saveBytes(Uint8List bytes, String fileName) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName');
      await file.writeAsBytes(bytes, flush: true);

      // On Android, attempt writing directly to Pictures/Photo-Resizer
      if (Platform.isAndroid) {
        try {
          final picturesDir = Directory('/storage/emulated/0/Pictures/Photo-Resizer');
          if (!picturesDir.existsSync()) {
            picturesDir.createSync(recursive: true);
          }
          final publicFile = File('${picturesDir.path}/$fileName');
          await publicFile.writeAsBytes(bytes, flush: true);
        } catch (_) {
          // Scoped storage fallback - sharing handles the save
        }
      }

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
