import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/info_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../iot/models/network_models.dart';
import '../../iot/providers/network_provider.dart';
import '../data/dummy_messages.dart';
import '../models/message_models.dart';
import '../providers/messaging_provider.dart';
import '../widgets/message_bubble.dart';

/// Individual conversation thread with composer.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() =>
      _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  PriorityLevel _priority = PriorityLevel.normal;
  bool _recording = false;

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _composer.text;
    if (text.trim().isEmpty) return;

    _composer.clear();
    await ref.read(threadsProvider.notifier).send(
          widget.conversationId,
          text,
          priority: _priority,
        );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _attachmentSheet() async {
    await AppDialogs.sheet<void>(
      context,
      title: 'Attach to message',
      subtitle: 'Large files are sent in parts over the SUMPAY Network.',
      child: Column(
        children: <Widget>[
          _AttachOption(
            icon: Symbols.photo_camera_rounded,
            label: 'Take a photo',
            detail: 'Compressed to roughly 20 KB before sending',
            onTap: () => _mockAttach('image', 'Photo evidence', '18 KB'),
          ),
          _AttachOption(
            icon: Symbols.image_rounded,
            label: 'Choose from gallery',
            detail: 'Select an existing image',
            onTap: () => _mockAttach('image', 'Gallery image', '22 KB'),
          ),
          _AttachOption(
            icon: Symbols.location_on_rounded,
            label: 'Share my location',
            detail: 'Sends your last known GPS fix',
            onTap: () =>
                _mockAttach('location', 'Pinned location', '9.30684, 123.30193'),
          ),
          _AttachOption(
            icon: Symbols.description_rounded,
            label: 'Household report',
            detail: 'Attach your current headcount record',
            onTap: () => _mockAttach('document', 'Household report', '4 KB'),
          ),
        ],
      ),
    );
  }

  Future<void> _mockAttach(String kind, String name, String size) async {
    Navigator.of(context).pop();
    await ref.read(threadsProvider.notifier).send(
          widget.conversationId,
          '',
          priority: _priority,
          attachment: MessageAttachment(
            id: 'ATT-${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            kind: kind,
            sizeLabel: size,
          ),
        );
    _scrollToBottom();
  }

  Future<void> _toggleRecording() async {
    setState(() => _recording = !_recording);
    if (_recording) return;

    await ref.read(threadsProvider.notifier).send(
          widget.conversationId,
          '',
          priority: _priority,
          attachment: const MessageAttachment(
            id: 'ATT-VOICE',
            name: 'Voice note',
            kind: 'voice',
            sizeLabel: '0:08',
          ),
        );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Conversation? conversation =
        ref.watch(conversationByIdProvider(widget.conversationId));
    final List<ChatMessage> messages =
        ref.watch(threadByIdProvider(widget.conversationId));
    final NetworkStatus network = ref.watch(networkStatusProvider);

    if (conversation == null) {
      return const Scaffold(
        body: SafeArea(
          child: ErrorState(message: 'This conversation is no longer available.'),
        ),
      );
    }

    return Scaffold(
      appBar: SumpayAppBar(
        title: conversation.title,
        subtitle: conversation.isGroup
            ? '${conversation.participants} members • ${conversation.transport.label}'
            : conversation.transport.label,
        actions: <Widget>[
          RoundIconButton(
            icon: Symbols.info_rounded,
            tooltip: 'Conversation details',
            onPressed: () => AppDialogs.sheet<void>(
              context,
              title: conversation.title,
              subtitle: conversation.subtitle,
              child: Column(
                children: <Widget>[
                  DetailRow(
                    label: 'Transport',
                    value: conversation.transport.label,
                    icon: conversation.transport.icon,
                  ),
                  DetailRow(
                    label: 'Participants',
                    value: '${conversation.participants}',
                    icon: Symbols.group_rounded,
                  ),
                  DetailRow(
                    label: 'Last activity',
                    value: Formatters.dateTime(conversation.lastActivity),
                    icon: Symbols.schedule_rounded,
                  ),
                  DetailRow(
                    label: 'Messages stored',
                    value: '${messages.length}',
                    icon: Symbols.chat_rounded,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (network.isOffline)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: OfflineBanner(
                  message:
                      'Offline — messages will be queued until a connection is available.',
                  color: AppColors.danger,
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? const EmptyState(
                      title: 'No messages yet',
                      message: 'Send the first message in this conversation.',
                      icon: Symbols.chat_bubble_rounded,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: messages.length,
                      itemBuilder: (BuildContext context, int index) {
                        final ChatMessage message = messages[index];
                        final bool showSender = index == 0 ||
                            messages[index - 1].senderName !=
                                message.senderName;
                        return MessageBubble(
                          message: message,
                          showSender: showSender && conversation.isGroup,
                        );
                      },
                    ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: DummyMessages.quickReplies
                    .map((String r) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(r),
                            onPressed: () {
                              _composer.text = r;
                              _send();
                            },
                            backgroundColor: theme.colorScheme.surface,
                            side: BorderSide(color: theme.dividerColor),
                            labelStyle: theme.textTheme.labelMedium,
                          ),
                        ))
                    .toList(),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                MediaQuery.viewInsetsOf(context).bottom + 12,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text('Priority', style: theme.textTheme.labelSmall),
                      const SizedBox(width: 8),
                      ...PriorityLevel.values.map(
                        (PriorityLevel p) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _priority = p),
                            child: StatusChip(
                              label: p.label,
                              color: p.color,
                              dense: true,
                              filled: _priority == p,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      IconButton(
                        onPressed: _attachmentSheet,
                        icon: const Icon(Symbols.attach_file_rounded),
                        iconSize: 24,
                        tooltip: 'Attach',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _composer,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: 'Write a message…',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: theme.dividerColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: theme.dividerColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        onPressed: _toggleRecording,
                        icon: Icon(
                          _recording
                              ? Symbols.stop_circle_rounded
                              : Symbols.mic_rounded,
                        ),
                        iconSize: 24,
                        tooltip: _recording ? 'Stop recording' : 'Voice note',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(50, 50),
                          backgroundColor: _recording
                              ? AppColors.emergency.withValues(alpha: 0.15)
                              : null,
                          foregroundColor: _recording ? AppColors.emergency : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        onPressed: _send,
                        icon: const Icon(Symbols.send_rounded),
                        iconSize: 24,
                        tooltip: 'Send',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(50, 50),
                          backgroundColor: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, size: 22, color: theme.colorScheme.primary),
      ),
      title: Text(label, style: theme.textTheme.titleSmall),
      subtitle: Text(detail, style: theme.textTheme.bodySmall),
      contentPadding: EdgeInsets.zero,
    );
  }
}
