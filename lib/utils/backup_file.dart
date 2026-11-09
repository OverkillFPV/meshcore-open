import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';

import '../services/backup_service.dart';
import 'platform_info.dart';

const _typeGroup = XTypeGroup(
  label: 'MeshCore backup',
  extensions: [kBackupFileExtension],
  mimeTypes: ['application/json'],
  uniformTypeIdentifiers: ['public.json'],
);

enum BackupFileResult { saved, cancelled, failed }

/// Saves the backup text to a file: a save dialog on desktop and phones, a
/// download on web.
Future<BackupFileResult> exportBackupFile(
  String text, {
  required String fileName,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(text));
  try {
    if (PlatformInfo.isWeb) {
      final file = XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'application/json',
      );
      await file.saveTo(fileName);
      return BackupFileResult.saved;
    }
    if (PlatformInfo.isDesktop) {
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: const [_typeGroup],
      );
      if (location == null) return BackupFileResult.cancelled;
      await XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'application/json',
      ).saveTo(location.path);
      return BackupFileResult.saved;
    }
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
    );
    return saved == null ? BackupFileResult.cancelled : BackupFileResult.saved;
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
