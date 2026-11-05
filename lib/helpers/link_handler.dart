import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../utils/platform_info.dart';
import '../helpers/snack_bar_builder.dart';
import '../helpers/utf8_length_limiter.dart';

/// Matches a `@[name]` mention and captures just the name.
final RegExp mentionRegExp = RegExp(r'@\[([^\]]+)\]');

/// Matches a `#word` hashtag and captures the word (without the `#`). The
/// tag must start with a letter so issue numbers like `#123` stay plain, and
/// must not continue a preceding word (`abc#def` stays plain too).
final RegExp hashtagRegExp = RegExp(
  r'(?<![\p{L}\p{N}_])#(\p{L}[\p{L}\p{N}_]*)',
  unicode: true,
);

/// A `#word` hashtag, tappable to offer adding it as a channel.
class HashtagElement extends LinkifyElement {
  HashtagElement(super.name);

  @override
  bool equals(other) => other is HashtagElement && super.equals(other);
}

/// Splits `#word` hashtags out of text elements.
class HashtagLinkifier extends Linkifier {
  const HashtagLinkifier();

  @override
  List<LinkifyElement> parse(
    List<LinkifyElement> elements,
    LinkifyOptions options,
  ) {
    final list = <LinkifyElement>[];
    for (final element in elements) {
      if (element is TextElement) {
        var lastEnd = 0;
        for (final match in hashtagRegExp.allMatches(element.text)) {
          if (match.start > lastEnd) {
            list.add(TextElement(element.text.substring(lastEnd, match.start)));
          }
          list.add(HashtagElement(match.group(1)!));
          lastEnd = match.end;
        }
        if (lastEnd == 0) {
          list.add(element);
        } else if (lastEnd < element.text.length) {
          list.add(TextElement(element.text.substring(lastEnd)));
        }
      } else {
        list.add(element);
      }
    }
    return list;
  }
}

/// A `@[name]` mention, shown as the bare name in the mention style.
class MentionElement extends LinkifyElement {
  MentionElement(super.name);

  @override
  bool equals(other) => other is MentionElement && super.equals(other);
}

/// Splits `@[name]` mentions out of text elements.
class MentionLinkifier extends Linkifier {
  const MentionLinkifier();

  @override
  List<LinkifyElement> parse(
    List<LinkifyElement> elements,
    LinkifyOptions options,
  ) {
    final list = <LinkifyElement>[];
    for (final element in elements) {
      if (element is TextElement) {
        var lastEnd = 0;
        for (final match in mentionRegExp.allMatches(element.text)) {
          if (match.start > lastEnd) {
            list.add(TextElement(element.text.substring(lastEnd, match.start)));
          }
          list.add(MentionElement(match.group(1)!));
          lastEnd = match.end;
        }
        if (lastEnd == 0) {
          list.add(element);
        } else if (lastEnd < element.text.length) {
          list.add(TextElement(element.text.substring(lastEnd)));
        }
      } else {
        list.add(element);
      }
    }
    return list;
  }
}

class LinkHandler {
  static TextStyle defaultLinkStyle(BuildContext context, TextStyle base) {
    final brightness = Theme.of(context).brightness;
    final orange = brightness == Brightness.dark
        ? const Color(0xFFFFB74D)
        : const Color(0xFFE65100);
    return base.copyWith(color: orange, decoration: TextDecoration.underline);
  }

  static TextStyle mentionStyle(BuildContext context, TextStyle base) {
    return base.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: mentionBackground(context),
    );
  }

  /// Background drawn behind a mention to make it stand out.
  static Color mentionBackground(BuildContext context) {
    return Theme.of(context).colorScheme.primary.withValues(alpha: 0.3);
  }

  /// Returns a [SelectableText.rich] on desktop or a [Text.rich] on mobile,
  /// with URLs and emails linkified and `@[name]` mentions rendered as the
  /// bare name in the mention style on a coloured background. The ambient
  /// [TextScaler] applies automatically.
  static Widget buildLinkifyText({
    required BuildContext context,
    required String text,
    required TextStyle style,
    TextStyle? linkStyle,
    VoidCallback? onSecondaryTap,
  }) {
    final effectiveLinkStyle = linkStyle ?? defaultLinkStyle(context, style);
    final effectiveMentionStyle = mentionStyle(context, style);
    const options = LinkifyOptions(humanize: false, defaultToHttps: false);
    const linkifiers = [
      MentionLinkifier(),
      UrlLinkifier(),
      EmailLinkifier(),
      // After URL/Email so `#` inside a URL fragment is not split out.
      HashtagLinkifier(),
    ];
    void onOpen(LinkableElement link) => handleLinkTap(context, link.url);

    var elements = <LinkifyElement>[TextElement(text)];
    for (final linkifier in linkifiers) {
      elements = linkifier.parse(elements, options);
    }

    final children = <InlineSpan>[
      for (final element in elements)
        if (element is MentionElement)
          TextSpan(text: element.text, style: effectiveMentionStyle)
        else if (element is HashtagElement)
          TextSpan(
            text: '#${element.text}',
            style: effectiveLinkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => handleHashtagTap(context, element.text),
            mouseCursor: SystemMouseCursors.click,
          )
        else if (element is LinkableElement)
          TextSpan(
            text: element.text,
            style: effectiveLinkStyle,
            recognizer: TapGestureRecognizer()..onTap = () => onOpen(element),
            mouseCursor: SystemMouseCursors.click,
          )
        else
          TextSpan(text: element.text, style: style),
    ];
    final span = TextSpan(children: children);

    if (PlatformInfo.isDesktop) {
      final selectable = SelectableText.rich(span);
      if (onSecondaryTap == null) return selectable;
      return Listener(
        onPointerDown: (event) {
          if (event.buttons & kSecondaryMouseButton != 0) onSecondaryTap();
        },
        behavior: HitTestBehavior.translucent,
        child: selectable,
      );
    }
    return Text.rich(span);
  }

  static Future<void> handleLinkTap(BuildContext context, String url) async {
    // Show confirmation dialog
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.chat_openLink),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.chat_openLinkConfirmation,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.chat_open),
          ),
        ],
      ),
    );

    if (shouldOpen != true) return;

    // Launch URL
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          showDismissibleSnackBar(
            context,
            content: Text(context.l10n.chat_couldNotOpenLink(url)),
            backgroundColor: Colors.red,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        showDismissibleSnackBar(
          context,
          content: Text(context.l10n.chat_invalidLink),
          backgroundColor: Colors.red,
        );
      }
    }
  }

  /// Offers to add a tapped `#hashtag` as a hashtag channel on the radio.
  static Future<void> handleHashtagTap(
    BuildContext context,
    String hashtag,
  ) async {
    final channelName = '#$hashtag';
    final connector = context.read<MeshCoreConnector>();

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.chat_hashtagAddChannelTitle),
        content: Text(
          dialogContext.l10n.chat_hashtagAddChannelConfirm(channelName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.common_add),
          ),
        ],
      ),
    );
    if (shouldAdd != true || !context.mounted) return;

    if (!connector.isConnected) {
      showDismissibleSnackBar(
        context,
        content: Text(context.l10n.settings_notConnectedError),
      );
      return;
    }
    if (connector.channels.any(
      (c) => c.name.toLowerCase() == channelName.toLowerCase(),
    )) {
      showDismissibleSnackBar(
        context,
        content: Text(context.l10n.chat_hashtagChannelExists(channelName)),
      );
      return;
    }
    if (utf8ByteLength(channelName) > maxRadioNameBytes) {
      showDismissibleSnackBar(
        context,
        content: Text(context.l10n.channels_nameTooLong(maxRadioNameBytes)),
      );
      return;
    }
    if (connector.isSyncingChannels || !connector.hasLoadedChannels) {
      showDismissibleSnackBar(
        context,
        content: Text(context.l10n.channels_waitForSync),
      );
      return;
    }
    final usedIndices = {
      ...connector.channels.map((c) => c.index),
      ...connector.unconfirmedChannelSlots,
    };
    int? slot;
    for (var i = 0; i < connector.maxChannels; i++) {
      if (!usedIndices.contains(i)) {
        slot = i;
        break;
      }
    }
    if (slot == null) {
      showDismissibleSnackBar(
        context,
        content: Text(context.l10n.channels_noFreeSlots),
      );
      return;
    }
    try {
      await connector.setChannel(
        slot,
        channelName,
        Channel.derivePskFromHashtag(hashtag),
      );
    } catch (e) {
      if (context.mounted) {
        showDismissibleSnackBar(
          context,
          content: Text('$e'),
          backgroundColor: Colors.red,
        );
      }
      return;
    }
    if (context.mounted) {
      showDismissibleSnackBar(
        context,
        content: Text(context.l10n.channels_channelAdded(channelName)),
      );
    }
  }
}
