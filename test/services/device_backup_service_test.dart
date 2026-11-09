import 'package:flutter_test/flutter_test.dart';

import 'package:meshcore_open/services/device_backup_service.dart';

void main() {
  final commands = <String>[];

  DeviceCliRunner runnerReturning(Map<String, String> replies) =>
      (command) async {
        commands.add(command);
        return replies[command] ?? 'Unknown command';
      };

  final fullReplies = <String, String>{
    'get public.key': '> ${'ab' * 32}',
    'get prv.key': '> ${'cd' * 64}',
    'get name': '> MyCompanion',
    'get lat': '> 52.5145',
    'get lon': '> 13.3501',
    'get radio': '> 869.618,62.5,8,5',
    'get tx': '> 22',
    'get dutycycle': '> 50.0%',
    'get guest.password': '> ',
  };

  setUp(() => commands.clear());

  test('readDeviceSettings collects gettable settings', () async {
    final settings = await readDeviceSettings(runnerReturning(fullReplies));

    expect(settings[kDevicePublicKeyEntry], 'ab' * 32);
    expect(settings['prv.key'], 'cd' * 64);
    expect(settings['name'], 'MyCompanion');
    expect(settings['radio'], '869.618,62.5,8,5');
    expect(settings['dutycycle'], '50.0');
    expect(settings.containsKey('guest.password'), isFalse);
    expect(commands, contains('get prv.key'));
  });

  test('readDeviceSettings omits unknown and errored keys', () async {
    final settings = await readDeviceSettings(
      runnerReturning({
        'get public.key': '> ab',
        'get name': '> N',
        'get tx': '> 3',
      }),
    );

    expect(settings.keys, {kDevicePublicKeyEntry, 'name', 'tx'});
  });

  test('readDeviceSettings returns empty when the public key fails', () async {
    final settings = await readDeviceSettings(
      runnerReturning({'get public.key': 'Unknown command'}),
    );
    expect(settings, isEmpty);
  });

  test(
    'readDeviceSettings tolerates firmware without the companion CLI',
    () async {
      final settings = await readDeviceSettings(
        (command) async => throw UnsupportedError('nope'),
      );
      expect(settings, isEmpty);
    },
  );

  test(
    'applyDeviceSettings runs set commands and counts confirmations',
    () async {
      final entries = <String, dynamic>{
        kDevicePublicKeyEntry: 'ab',
        'prv.key': 'cd' * 64,
        'name': 'MyCompanion',
        'radio': '869.618,62.5,8,5',
        'tx': '22',
        'loop.detect': 'unknown-key',
        'bad.key': 'value',
        'int.thresh': 5,
      };

      final applied = await applyDeviceSettings((command) async {
        commands.add(command);
        if (command.startsWith('set tx ') ||
            command.startsWith('set loop.detect')) {
          return 'Error, invalid value';
        }
        return 'OK';
      }, entries);

      expect(applied, 3);
      expect(commands, [
        'set prv.key ${'cd' * 64}',
        'set name MyCompanion',
        'set radio 869.618,62.5,8,5',
        'set tx 22',
        'set loop.detect unknown-key',
      ]);
    },
  );
}
