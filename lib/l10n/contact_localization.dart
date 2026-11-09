import '../connector/meshcore_protocol.dart';
import '../helpers/path_helper.dart';
import '../models/contact.dart';
import 'app_localizations.dart';

/// UI-level localization helpers for [Contact].
///
/// Kept out of the model layer so `Contact` does not depend on
/// `AppLocalizations`. Use these from widgets/screens; for logs and
/// non-UI export use `Contact.typeLabelRaw`.
extension ContactLocalization on Contact {
  String typeLabel(AppLocalizations l10n) {
    switch (type) {
      case advTypeChat:
        return l10n.contact_typeChat;
      case advTypeRepeater:
        return l10n.contact_typeRepeater;
      case advTypeRoom:
        return l10n.contact_typeRoom;
      case advTypeSensor:
        return l10n.contact_typeSensor;
      default:
        return l10n.contact_typeUnknown;
    }
  }

  String pathLabel(
    AppLocalizations l10n, {
    int pathHashByteWidth = pathHashSize,
  }) {
    if (pathOverride != null) {
      if (pathOverride! < 0) return l10n.chat_floodForced;
      if (pathOverride == 0) return l10n.chat_directForced;
      return l10n.chat_hopsForced(
        _displayHopCount(pathOverrideBytes, pathOverride!, pathHashByteWidth),
      );
    }
    if (pathLength < 0) return l10n.channelPath_floodPath;
    if (pathLength == 0) return l10n.chat_direct;
    return l10n.chat_hopsCount(
      _displayHopCount(path, pathLength, pathHashWidth),
    );
  }

  int _displayHopCount(
    List<int>? pathBytes,
    int storedHopCount,
    int hashWidth,
  ) {
    if (pathBytes == null || pathBytes.isEmpty) return storedHopCount;
    return PathHelper.splitPathBytes(pathBytes, hashWidth).length;
  }

  /// Hops the last advert was received on: direct, flood when the advert
  /// carried no path, otherwise the hop count.
  String advertHopsLabel(AppLocalizations l10n) {
    if (pathLength < 0) return l10n.contacts_advertHopsFlood;
    if (pathLength == 0) return l10n.contacts_advertHopsDirect;
    return l10n.chat_hopsCount(
      _displayHopCount(path, pathLength, pathHashWidth),
    );
  }

  /// Scope the last advert was sent with, or "unscoped" when it carried none.
  String advertScopeLabel(AppLocalizations l10n) =>
      advertScope?.isNotEmpty ?? false
      ? advertScope!
      : l10n.chat_regionUnscoped;

  /// "3 hops · unscoped" summary shown under a contact.
  String advertMetaLabel(AppLocalizations l10n) =>
      '${advertHopsLabel(l10n)} · ${advertScopeLabel(l10n)}';

  /// Whether the node's advert timestamp matches the local receipt time
  /// within a small tolerance, or '' when no local receipt is stored.
  String advertTimeSyncLabel(AppLocalizations l10n) {
    final receivedAt = advertReceivedAt;
    if (receivedAt == null) return '';
    final minutes = receivedAt.difference(lastSeen).inMinutes.abs();
    return minutes <= 15
        ? l10n.contacts_timeSynced
        : l10n.contacts_timeUnsynced;
  }
}
