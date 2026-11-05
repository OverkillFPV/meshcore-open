import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

import '../services/backup_service.dart';
import 'platform_info.dart';

const _typeGroup = XTypeGroup(
  label: 'MeshCore backup',
  extensions: [kBackupFileExtension],
  mimeTypes: ['application/json'],
  uniformTypeIdentifiers: ['public.json'],
);

enum BackupFileResult { saved, cancelled, failed }

/// Saves the backup text to a file: a save dialog on desktop, a download on
/// web, and the share sheet on phones (which have no save dialog).
Future<BackupFileResult> exportBackupFile(
  String text, {
  required String fileName,
  Rect? sharePositionOrigin,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(text));
  final file = XFile.fromData(
    bytes,
    name: fileName,
    mimeType: 'application/json',
  );
  try {
    if (PlatformInfo.isWeb) {
      await file.saveTo(fileName);
      return BackupFileResult.saved;
    }
    if (PlatformInfo.isDesktop) {
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: const [_typeGroup],
      );
      if (location == null) return BackupFileResult.cancelled;
      await file.saveTo(location.path);
      return BackupFileResult.saved;
    }
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: [fileName],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return result.status == ShareResultStatus.dismissed
        ? BackupFileResult.cancelled
        : BackupFileResult.saved;
  } catch (_) {
    return BackupFileResult.failed;
  }
}

/// Lets the user pick a backup file and returns its text, or null when they
/// cancel. Throws when the file cannot be read.
Future<String?> pickBackupFile() async {
  final file = await openFile(acceptedTypeGroups: const [_typeGroup]);
  if (file == null) return null;
  return utf8.decode(await file.readAsBytes(), allowMalformed: true);
}
