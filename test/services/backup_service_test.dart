import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshcore_open/services/backup_service.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';

void main() {
  setUp(() {
    PrefsManager.reset();
    SharedPreferences.setMockInitialValues({});
  });

  BackupCategory byId(String id) => backupCategoryById(id)!;

  test('category prefixes do not overlap between groups', () {
    final contacts = byId('contacts');
    final channelMessages = byId('channelMessages');
    final channels = byId('channels');
    expect(contacts.matches('contact_groups'), isFalse);
    expect(contacts.matches('contact_unread_count'), isFalse);
    expect(contacts.matches('contacts'), isTrue);
    expect(channels.matches('channel_messages_abc'), isFalse);
    expect(channelMessages.matches('channel_messages_abc'), isTrue);
    expect(channels.matches('channelsabc'), isTrue);
  });

  test('encode then decode round-trips selected categories', () async {
    SharedPreferences.setMockInitialValues({
      'app_settings': '{"themeMode":"dark"}',
      'contacts': '[{"name":"a"}]',
      'channel_messages_abc': '[{"text":"hi"}]',
    });
    await PrefsManager.initialize();

    final text = encodeBackup([byId('settings'), byId('channelMessages')]);
    final file = decodeBackup(text);
    expect(file, isNotNull);
    expect(file!.categories.keys, {'settings', 'channelMessages'});
    expect(
      file.categories['settings']!['app_settings'],
      '{"themeMode":"dark"}',
    );
    expect(file.categories['contacts'], isNull);
    expect(
      file.categories['channelMessages']!['channel_messages_abc'],
      isNotNull,
    );
  });

  test('decodeBackup rejects foreign or malformed files', () {
    expect(decodeBackup('not json'), isNull);
    expect(decodeBackup('{"format":"other","version":1}'), isNull);
    expect(
      decodeBackup('{"format":"meshcore-open-backup","version":99}'),
      isNull,
    );
  });

  test(
    'applyBackup replaces existing keys of the selected categories',
    () async {
      SharedPreferences.setMockInitialValues({
        'contacts': 'old',
        'channel_messages_abc': 'keep',
      });
      await PrefsManager.initialize();

      final file = BackupFile({
        'contacts': {'contacts': 'new'},
      });
      final written = await applyBackup(file, [byId('contacts')]);
      expect(written, 1);

      final prefs = PrefsManager.instance;
      expect(prefs.getString('contacts'), 'new');
      expect(prefs.getString('channel_messages_abc'), 'keep');
    },
  );

  test('applyBackup drops keys the backup no longer has', () async {
    SharedPreferences.setMockInitialValues({
      'channel_messages_abc': 'gone',
      'channel_messages_def': 'gone',
    });
    await PrefsManager.initialize();

    final file = BackupFile({
      'channelMessages': {'channel_messages_xyz': 'kept'},
    });
    await applyBackup(file, [byId('channelMessages')]);

    final prefs = PrefsManager.instance;
    expect(prefs.getString('channel_messages_abc'), isNull);
    expect(prefs.getString('channel_messages_xyz'), 'kept');
  });
}
