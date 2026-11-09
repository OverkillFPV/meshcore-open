import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/connector/meshcore_protocol.dart';
import 'package:meshcore_open/l10n/app_localizations.dart';
import 'package:meshcore_open/l10n/contact_localization.dart';
import 'package:meshcore_open/models/contact.dart';
import 'package:meshcore_open/storage/contact_discovery_store.dart';
import 'package:meshcore_open/storage/contact_store.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _pubKey = Uint8List.fromList(List.generate(32, (i) => i + 1));

final _advertAt = DateTime.utc(2026, 11, 7, 10, 0);
final _receivedAt = DateTime.utc(2026, 11, 7, 10, 0, 30);

Contact _contact({
  int pathLength = 2,
  DateTime? advertReceivedAt,
  String? advertScope,
}) {
  return Contact(
    publicKey: _pubKey,
    name: 'Node',
    type: advTypeChat,
    pathLength: pathLength,
    path: Uint8List(0),
    lastSeen: _advertAt,
    advertReceivedAt: advertReceivedAt,
    advertScope: advertScope,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('Contact advert metadata', () {
    test('copyWith keeps advert fields when omitted', () {
      final contact = _contact(
        advertReceivedAt: _receivedAt,
        advertScope: 'EU',
      );
      final copy = contact.copyWith(name: 'Renamed');
      expect(copy.advertReceivedAt, _receivedAt);
      expect(copy.advertScope, 'EU');
    });

    test('copyWith can replace the scope but keeps it when null', () {
      final contact = _contact(advertScope: 'EU');
      expect(contact.copyWith(name: 'x').advertScope, 'EU');
      expect(contact.copyWith(advertScope: 'US').advertScope, 'US');
      expect(contact.copyWith(clearAdvertScope: true).advertScope, isNull);
    });

    test('lastHeard uses the local receipt when newer than the advert', () {
      final contact = _contact(advertReceivedAt: _receivedAt);
      expect(contact.lastHeard, _receivedAt);
    });

    test('lastHeard keeps the advert when local receipt is older', () {
      final contact = _contact(
        advertReceivedAt: _advertAt.subtract(const Duration(days: 1)),
      );
      expect(contact.lastHeard, _advertAt);
    });
  });

  group('advert labels', () {
    test('hops label covers flood, direct and hop counts', () {
      expect(_contact(pathLength: -1).advertHopsLabel(l10n), 'flood');
      expect(_contact(pathLength: 0).advertHopsLabel(l10n), 'direct');
      expect(_contact(pathLength: 3).advertHopsLabel(l10n), '3 hops');
    });

    test('scope label falls back to unscoped', () {
      expect(_contact().advertScopeLabel(l10n), 'unscoped');
      expect(_contact(advertScope: 'EU').advertScopeLabel(l10n), 'EU');
    });

    test('meta label joins hops and scope', () {
      expect(
        _contact(pathLength: 2, advertScope: 'EU').advertMetaLabel(l10n),
        '2 hops · EU',
      );
      expect(
        _contact(pathLength: 0).advertMetaLabel(l10n),
        'direct · unscoped',
      );
    });

    test('time sync label compares advert and local clocks', () {
      final synced = _contact(advertReceivedAt: _receivedAt);
      expect(synced.advertTimeSyncLabel(l10n), 'synced');
      final drifted = _contact(
        advertReceivedAt: _advertAt.add(const Duration(hours: 5)),
      );
      expect(drifted.advertTimeSyncLabel(l10n), 'unsynced');
      expect(_contact().advertTimeSyncLabel(l10n), '');
    });
  });

  group('stores persist advert metadata', () {
    Future<void> init() async {
      SharedPreferences.setMockInitialValues({});
      PrefsManager.reset();
      await PrefsManager.initialize();
    }

    test('contact store round-trips both times and the scope', () async {
      await init();
      final store = ContactStore()..setPublicKeyHex = 'aaaaaaaaaaa';
      await store.saveContacts([
        _contact(advertReceivedAt: _receivedAt, advertScope: 'EU'),
      ]);
      final loaded = await store.loadContacts();
      expect(
        loaded.single.advertReceivedAt!.millisecondsSinceEpoch,
        _receivedAt.millisecondsSinceEpoch,
      );
      expect(loaded.single.advertScope, 'EU');
    });

    test('discovery store round-trips both times and the scope', () async {
      await init();
      final store = ContactDiscoveryStore()..setPublicKeyHex = 'aaaaaaaaaaa';
      await store.saveContacts([
        _contact(advertReceivedAt: _receivedAt, advertScope: 'EU'),
      ]);
      final loaded = await store.loadContacts();
      expect(
        loaded.single.advertReceivedAt!.millisecondsSinceEpoch,
        _receivedAt.millisecondsSinceEpoch,
      );
      expect(loaded.single.advertScope, 'EU');
    });

    test('stored contacts without the keys still load', () async {
      await init();
      final store = ContactStore()..setPublicKeyHex = 'aaaaaaaaaaa';
      await store.saveContacts([_contact()]);
      final loaded = await store.loadContacts();
      expect(loaded.single.advertReceivedAt, isNull);
      expect(loaded.single.advertScope, isNull);
    });
  });
}
