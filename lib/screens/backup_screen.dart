import 'package:flutter/material.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../services/app_settings_service.dart';
import '../services/backup_service.dart';
import '../services/device_backup_service.dart';
import '../utils/backup_file.dart';
import '../helpers/snack_bar_builder.dart';
import '../widgets/app_bar.dart';
import '../widgets/mesh_nav_tile.dart';
import '../widgets/mesh_ui.dart';
import 'package:provider/provider.dart';

/// Selective export/import of the app's settings and stored data. Each
/// category maps to the SharedPreferences keys of one store, so users can
/// move a subset (or everything) between devices.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final Set<String> _exportSelected = kBackupCategories
      .map((c) => c.id)
      .toSet();
  bool _busy = false;

  String _categoryTitle(BackupCategory category) {
    final l10n = context.l10n;
    return switch (category.id) {
      'settings' => l10n.backup_categorySettings,
      'uiState' => l10n.backup_categoryUiState,
      'contacts' => l10n.backup_categoryContacts,
      'contactGroups' => l10n.backup_categoryContactGroups,
      'contactSettings' => l10n.backup_categoryContactSettings,
      'discoveredContacts' => l10n.backup_categoryDiscoveredContacts,
      'messages' => l10n.backup_categoryMessages,
      'channels' => l10n.backup_categoryChannels,
      'channelSettings' => l10n.backup_categoryChannelSettings,
      'channelMessages' => l10n.backup_categoryChannelMessages,
      'communities' => l10n.backup_categoryCommunities,
      'unread' => l10n.backup_categoryUnread,
      'paths' => l10n.backup_categoryPaths,
      'repeaterPasswords' => l10n.backup_categoryRepeaterPasswords,
      'regions' => l10n.backup_categoryRegions,
      'mapMarkers' => l10n.backup_categoryMapMarkers,
      'deviceSettings' => l10n.backup_categoryDeviceSettings,
      _ => category.id,
    };
  }

  String _categorySubtitle(BackupCategory category) {
    final l10n = context.l10n;
    return switch (category.id) {
      'settings' => l10n.backup_categorySettingsDesc,
      'uiState' => l10n.backup_categoryUiStateDesc,
      'contacts' => l10n.backup_categoryContactsDesc,
      'contactGroups' => l10n.backup_categoryContactGroupsDesc,
      'contactSettings' => l10n.backup_categoryContactSettingsDesc,
      'discoveredContacts' => l10n.backup_categoryDiscoveredContactsDesc,
      'messages' => l10n.backup_categoryMessagesDesc,
      'channels' => l10n.backup_categoryChannelsDesc,
      'channelSettings' => l10n.backup_categoryChannelSettingsDesc,
      'channelMessages' => l10n.backup_categoryChannelMessagesDesc,
      'communities' => l10n.backup_categoryCommunitiesDesc,
      'unread' => l10n.backup_categoryUnreadDesc,
      'paths' => l10n.backup_categoryPathsDesc,
      'repeaterPasswords' => l10n.backup_categoryRepeaterPasswordsDesc,
      'regions' => l10n.backup_categoryRegionsDesc,
      'mapMarkers' => l10n.backup_categoryMapMarkersDesc,
      'deviceSettings' => l10n.backup_categoryDeviceSettingsDesc,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          l10n.backup_title,
          indicators: false,
          subtitle: false,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          children: [
            SectionHeader(l10n.backup_exportTitle),
            MeshCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final category in kBackupCategories) ...[
                    CheckboxListTile(
                      value: _exportSelected.contains(category.id),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _exportSelected.add(category.id);
                        } else {
                          _exportSelected.remove(category.id);
                        }
                      }),
                      title: Text(_categoryTitle(category)),
                      subtitle: Text(
                        _categorySubtitle(category),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                  const Divider(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _busy
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(10),
                                    child: SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  ),
                                )
                              : FilledButton.icon(
                                  onPressed: _exportSelected.isEmpty
                                      ? null
                                      : _export,
                                  icon: const Icon(Icons.download_outlined),
                                  label: Text(l10n.backup_exportButton),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SectionHeader(l10n.backup_importTitle),
            MeshCard(
              padding: EdgeInsets.zero,
              child: MeshNavTile(
                icon: Icons.upload_outlined,
                title: l10n.backup_importButton,
                subtitle: l10n.backup_importButtonSubtitle,
                showChevron: false,
                onTap: _import,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export() async {
    final l10n = context.l10n;
    final selected = kBackupCategories
        .where((c) => _exportSelected.contains(c.id))
        .toList();
    Map<String, String>? deviceEntries;
    if (selected.any((c) => c.isDevice)) {
      final connector = context.read<MeshCoreConnector>();
      if (!connector.isConnected) {
        showDismissibleSnackBar(
          context,
          content: Text(l10n.backup_deviceNotConnected),
        );
        return;
      }
      setState(() => _busy = true);
      deviceEntries = await readDeviceSettings(connector.runCliCommand);
      if (!mounted) return;
      setState(() => _busy = false);
      if (deviceEntries.isEmpty) {
        showDismissibleSnackBar(
          context,
          content: Text(l10n.backup_deviceUnreadable),
        );
        return;
      }
    }
    final now = DateTime.now();
    final stamp = now
        .toIso8601String()
        .split('.')
        .first
        .replaceAll(':', '')
        .replaceAll('T', '_');
    final fileName = 'meshcore_backup_$stamp.$kBackupFileExtension';
    final text = encodeBackup(selected, deviceEntries: deviceEntries);
    final result = await exportBackupFile(text, fileName: fileName);
    if (!mounted) return;
    switch (result) {
      case BackupFileResult.saved:
        showDismissibleSnackBar(
          context,
          content: Text(context.l10n.backup_exportSuccess),
        );
      case BackupFileResult.cancelled:
        break;
      case BackupFileResult.failed:
        showDismissibleSnackBar(
          context,
          content: Text(context.l10n.backup_exportFailed),
        );
    }
  }

  Future<void> _import() async {
    final l10n = context.l10n;
    final String? text;
    try {
      text = await pickBackupFile();
    } catch (_) {
      if (!mounted) return;
      showDismissibleSnackBar(
        context,
        content: Text(l10n.backup_importInvalid),
      );
      return;
    }
    if (text == null || !mounted) return;
    final file = decodeBackup(text);
    final available = file?.availableCategories ?? const <BackupCategory>[];
    if (file == null || available.isEmpty) {
      if (!mounted) return;
      showDismissibleSnackBar(
        context,
        content: Text(l10n.backup_importInvalid),
      );
      return;
    }

    final selected = available.map((c) => c.id).toSet();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(builderContext.l10n.backup_importTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                builderContext.l10n.backup_importWarning,
                style: Theme.of(builderContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              for (final category in available)
                CheckboxListTile(
                  value: selected.contains(category.id),
                  onChanged: (checked) => setDialogState(() {
                    if (checked == true) {
                      selected.add(category.id);
                    } else {
                      selected.remove(category.id);
                    }
                  }),
                  title: Text(_categoryTitle(category)),
                  subtitle: Text(
                    _categorySubtitle(category),
                    style: const TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(builderContext.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(builderContext.l10n.backup_importApplyButton),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final toApply = available.where((c) => selected.contains(c.id)).toList();
    MeshCoreConnector? connector;
    if (toApply.any((c) => c.isDevice)) {
      connector = context.read<MeshCoreConnector>();
      if (!connector.isConnected) {
        showDismissibleSnackBar(
          context,
          content: Text(l10n.backup_deviceNotConnected),
        );
        return;
      }
    }
    int written;
    try {
      written = await applyBackup(file, toApply);
      if (connector != null) {
        written += await applyDeviceSettings(
          connector.runCliCommand,
          file.categories['deviceSettings'] ?? const <String, dynamic>{},
        );
      }
    } catch (e) {
      if (!mounted) return;
      showDismissibleSnackBar(
        context,
        content: Text('$e'),
        backgroundColor: Colors.red,
      );
      return;
    }
    if (!mounted) return;
    // Apply the settings blob live so theme/language/etc. react immediately;
    // the other stores reload on next launch, hence the restart hint.
    await context.read<AppSettingsService>().loadSettings();
    if (!mounted) return;
    showDismissibleSnackBar(
      context,
      content: Text(
        '${context.l10n.backup_importResult(written)}\n'
        '${context.l10n.backup_importRestartHint}',
      ),
      duration: const Duration(seconds: 6),
    );
  }
}
