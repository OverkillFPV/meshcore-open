/// Reads and restores the connected device's own settings (name, radio
/// parameters, identity private key, ...) through the companion CLI, which
/// firmware 1.14+ answers over Bluetooth.
typedef DeviceCliRunner = Future<String> Function(String command);

/// Entry holding the public key of the device the settings came from.
const String kDevicePublicKeyEntry = 'public.key';

/// Settings read with `get <key>` and restored with `set <key> <value>`.
const List<String> kDeviceSettingKeys = [
  'prv.key',
  'name',
  'lat',
  'lon',
  'radio',
  'tx',
  'dutycycle',
  'radio.rxgain',
  'advert.interval',
  'flood.advert.interval',
  'flood.max',
  'flood.max.unscoped',
  'flood.max.advert',
  'repeat',
  'loop.detect',
  'path.hash.mode',
  'multi.acks',
  'rxdelay',
  'txdelay',
  'direct.txdelay',
  'int.thresh',
  'cad',
  'agc.reset.interval',
  'owner.info',
  'guest.password',
  'adc.multiplier',
];

/// Reads all settings the device answers. Keys the device rejects or leaves
/// unset are omitted; an empty map means the device cannot be read at all.
Future<Map<String, String>> readDeviceSettings(DeviceCliRunner run) async {
  final settings = <String, String>{};
  final publicKey = await _readValue(run, kDevicePublicKeyEntry);
  if (publicKey == null) return settings;
  settings[kDevicePublicKeyEntry] = publicKey;
  for (final key in kDeviceSettingKeys) {
    final value = await _readValue(run, key);
    if (value != null) settings[key] = value;
  }
  return settings;
}

/// Applies the device settings from a backup and returns how many settings the
/// device confirmed. Unknown or unsupported entries are skipped.
Future<int> applyDeviceSettings(
  DeviceCliRunner run,
  Map<String, dynamic> entries,
) async {
  var applied = 0;
  for (final entry in entries.entries) {
    final key = entry.key;
    if (key == kDevicePublicKeyEntry) continue;
    if (!kDeviceSettingKeys.contains(key)) continue;
    final value = entry.value;
    if (value is! String || value.isEmpty) continue;
    try {
      final reply = await run('set $key $value');
      if (reply.startsWith('OK')) applied++;
    } catch (_) {}
  }
  return applied;
}

Future<String?> _readValue(DeviceCliRunner run, String key) async {
  try {
    return _parseGetReply(await run('get $key'));
  } catch (_) {
    return null;
  }
}

String? _parseGetReply(String reply) {
  final trimmed = reply.trim();
  if (!trimmed.startsWith('>')) return null;
  final value = trimmed.substring(1).trim();
  if (value.isEmpty || value == '?') return null;
  return value.endsWith('%') ? value.substring(0, value.length - 1) : value;
}
