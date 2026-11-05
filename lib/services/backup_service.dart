import 'dart:convert';

import '../storage/prefs_manager.dart';

/// One selectable group of persisted data for export/import. Matching is by
/// SharedPreferences key prefix, which is how every store scopes its data.
class BackupCategory {
  /// Stable ID stored in the backup file; never rename.
  final String id;

  /// Key prefixes owned by this category. A key matches when it equals a
  /// prefix or starts with it.
  final List<String> prefixes;

  const BackupCategory({required this.id, required this.prefixes});

  bool matches(String key) =>
      prefixes.any((p) => key == p || key.startsWith(p));
}

/// Everything the app keeps in SharedPreferences, grouped so users can pick
/// what to export or import.
const List<BackupCategory> kBackupCategories = [
  BackupCategory(
    id: 'settings',
    prefixes: [
      'app_settings',
      'image_codec_settings',
      'chat_text_scale',
      'chat_backgrounds_v1',
      'notification_permission_requested',
    ],
  ),
  BackupCategory(
    id: 'uiState',
    prefixes: ['ui_', 'map_last_camera', 'node_banner_'],
  ),
  BackupCategory(id: 'contacts', prefixes: ['contacts']),
  BackupCategory(id: 'contactGroups', prefixes: ['contact_groups']),
  BackupCategory(
    id: 'contactSettings',
    prefixes: ['contact_smaz_', 'contact_cyr2lat_', 'contact_url_images_'],
  ),
  BackupCategory(id: 'discoveredContacts', prefixes: ['discovered_contacts']),
  BackupCategory(id: 'messages', prefixes: ['messages_']),
  BackupCategory(
    id: 'channels',
    prefixes: ['channels', 'channel_slot_ids_', 'channel_storage_v2_'],
  ),
  BackupCategory(
    id: 'channelSettings',
    prefixes: [
      'channel_order_',
      'channel_region_',
      'channel_smaz_',
      'channel_cyr2lat_',
      'channel_url_images_',
      'default_region_',
    ],
  ),
  BackupCategory(id: 'channelMessages', prefixes: ['channel_messages_']),
  BackupCategory(id: 'communities', prefixes: ['communities_v1']),
  BackupCategory(id: 'unread', prefixes: ['contact_unread_count']),
  BackupCategory(
    id: 'paths',
    prefixes: [
      'path_history_',
      'delivery_observations',
      'packet_paths',
      'pending_messages',
    ],
  ),
  BackupCategory(
    id: 'repeaterPasswords',
    prefixes: ['repeater_passwords', 'repeater_auto_clock_sync_after_login'],
  ),
  BackupCategory(id: 'regions', prefixes: ['regions']),
  BackupCategory(id: 'mapMarkers', prefixes: ['map_removed_marker_ids']),
];

BackupCategory? backupCategoryById(String id) {
  for (final category in kBackupCategories) {
    if (category.id == id) return category;
  }
  return null;
}

/// File extension for exported backups (plain JSON).
const String kBackupFileExtension = 'json';

/// Current backup file layout version.
const int kBackupFormatVersion = 1;

/// Serializes the selected categories' SharedPreferences entries into the
/// backup file text.
String encodeBackup(List<BackupCategory> selected) {
  final prefs = PrefsManager.instance;
  final keys = prefs.getKeys();
  final categories = <String, Map<String, dynamic>>{};
  for (final category in selected) {
    final entries = <String, dynamic>{};
    for (final key in keys) {
      if (!category.matches(key)) continue;
      final value = prefs.get(key);
      if (value != null) entries[key] = value;
    }
    if (entries.isNotEmpty) categories[category.id] = entries;
  }
  return const JsonEncoder.withIndent('  ').convert({
    'format': 'meshcore-open-backup',
    'version': kBackupFormatVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'categories': categories,
  });
}

/// Parsed contents of a backup file.
class BackupFile {
  /// Category ID → prefs key → value, restricted to known categories.
  final Map<String, Map<String, dynamic>> categories;

  BackupFile(this.categories);

  List<BackupCategory> get availableCategories =>
      categories.keys.nonNulls.map(backupCategoryById).nonNulls.toList();
}

/// Reads a backup file's text, or null when it is not a valid backup.
BackupFile? decodeBackup(String text) {
  Object? json;
  try {
    json = jsonDecode(text);
  } catch (_) {
    return null;
  }
  if (json is! Map<String, dynamic>) return null;
  if (json['format'] != 'meshcore-open-backup') return null;
  final version = json['version'];
  if (version is! int || version > kBackupFormatVersion) return null;
  final raw = json['categories'];
  if (raw is! Map<String, dynamic>) return null;

  final categories = <String, Map<String, dynamic>>{};
  for (final entry in raw.entries) {
    final category = backupCategoryById(entry.key);
    final entries = entry.value;
    if (category == null || entries is! Map<String, dynamic>) continue;
    final filtered = <String, dynamic>{};
    entries.forEach((key, value) {
      if (!category.matches(key)) return;
      if (value is String ||
          value is bool ||
          value is int ||
          value is double ||
          value is List<dynamic>) {
        filtered[key] = value;
      }
    });
    if (filtered.isNotEmpty) categories[entry.key] = filtered;
  }
  if (categories.isEmpty) return null;
  return BackupFile(categories);
}

/// Applies the selected categories of [file] to SharedPreferences, replacing
/// any existing entries those categories currently hold. Returns the number
/// of keys written.
Future<int> applyBackup(BackupFile file, List<BackupCategory> selected) async {
  final prefs = PrefsManager.instance;
  var written = 0;
  for (final category in selected) {
    final entries = file.categories[category.id];
    if (entries == null) continue;
    // Replace semantics: drop what this category owns now, then restore.
    for (final key in prefs.getKeys().toList()) {
      if (category.matches(key)) await prefs.remove(key);
    }
    for (final entry in entries.entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is List<dynamic>) {
        final strings = value.whereType<String>().toList();
        await prefs.setStringList(entry.key, strings);
      }
      written++;
    }
  }
  return written;
}
