import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../models/message_models.dart';
import '../providers/community_chat_provider.dart';
import '../widgets/message_bubble.dart';

/// Mesh-wide community chat shared by everyone connected to the network.
///
/// Messages are broadcast across the multi-hop mesh, so every connected device
/// receives them, and are persisted locally so they survive restarts. Any role
/// can post.
class CommunityChatScreen extends ConsumerStatefulWidget {
  const CommunityChatScreen({
    super.key,
    this.provider,
    this.title = 'Community chat',
    this.subtitle = 'Everyone in the barangay',
  });

  /// The chat provider to drive this screen. Defaults to the community chat;
  /// the area chat passes [areaChatProvider] to reuse this same screen.
  final StateNotifierProvider<CommunityChatController, CommunityChatState>?
      provider;
  final String title;
  final String subtitle;

  @override
  ConsumerState<CommunityChatScreen> createState() =>
      _CommunityChatScreenState();
}

class _CommunityChatScreenState extends ConsumerState<CommunityChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// Message the composer is currently replying to (null = not replying).
  ChatMessage? _replyTo;

  /// The active chat provider (community by default, or area when supplied).
  StateNotifierProvider<CommunityChatController, CommunityChatState>
      get _provider => widget.provider ?? communityChatProvider;

  @override
  void initState() {
    super.initState();
    // Opening the community chat marks everything read on this device.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_provider.notifier).markAllRead();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final String text = _input.text;
    if (text.trim().isEmpty) return;
    ref.read(_provider.notifier).send(text, replyTo: _replyTo);
    _input.clear();
    setState(() => _replyTo = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _startReply(ChatMessage m) => setState(() => _replyTo = m);
  void _cancelReply() => setState(() => _replyTo = null);

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _confirmClear() async {
    final bool ok = await AppDialogs.confirm(
      context,
      title: 'Clear community chat?',
      message: 'All community messages on this device will be deleted.',
      confirmLabel: 'Clear',
      icon: Symbols.delete_sweep_rounded,
      destructive: true,
    );
    if (ok) ref.read(_provider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final CommunityChatState chat = ref.watch(_provider);

    ref.listen<CommunityChatState>(_provider, (
      CommunityChatState? prev,
      CommunityChatState next,
    ) {
      if (prev != null && next.messages.length > prev.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
      }
    });

    return Scaffold(
      appBar: SumpayAppBar(
        title: widget.title,
        subtitle: widget.subtitle,
        actions: <Widget>[
          RoundIconButton(
            icon: Symbols.delete_sweep_rounded,
            tooltip: 'Clear chat',
            onPressed: _confirmClear,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _ConnectionBanner(count: chat.connectedCount),
            if (chat.pinnedMessages.isNotEmpty)
              _PinnedBar(
                pinned: chat.pinnedMessages,
                onUnpin: (String id) =>
                    ref.read(_provider.notifier).togglePin(id),
              ),
            Expanded(
              child: chat.isLoading
                  ? const LoadingState(message: 'Loading community chat…')
                  : chat.messages.isEmpty
                      ? const EmptyState(
                          title: 'No messages yet',
                          message:
                              'Start the conversation. Everyone connected will see it.',
                          icon: Symbols.forum_rounded,
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          itemCount: chat.messages.length,
                          itemBuilder: (BuildContext context, int i) {
                            final ChatMessage m = chat.messages[i];
                            return GestureDetector(
                              onLongPress: () => _showMessageActions(m),
                              child: MessageBubble(
                                message: m,
                                showSender: !m.isMine,
                              ),
                            );
                          },
                        ),
            ),
            if (_replyTo != null)
              _ReplyPreview(message: _replyTo!, onCancel: _cancelReply),
            _Composer(controller: _input, onSend: _send),
          ],
        ),
      ),
    );
  }

  /// Long-press actions on a message: reply or pin/unpin.
  Future<void> _showMessageActions(ChatMessage m) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Symbols.reply_rounded),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.of(context).pop();
                  _startReply(m);
                },
              ),
              ListTile(
                leading: Icon(m.isPinned
                    ? Symbols.keep_off_rounded
                    : Symbols.keep_rounded),
                title: Text(m.isPinned ? 'Unpin announcement' : 'Pin as announcement'),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(_provider.notifier).togglePin(m.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final bool connected = count > 0;
    final Color color = connected ? AppColors.success : AppColors.textSecondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: color.withValues(alpha: 0.10),
      child: Row(
        children: <Widget>[
          Icon(
            connected ? Symbols.lan_rounded : Symbols.cloud_off_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              connected
                  ? '$count device${count == 1 ? '' : 's'} connected'
                  : 'No devices connected — messages send when the network is reachable',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Message the community…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onSend,
            style: FilledButton.styleFrom(
              minimumSize: const Size(52, 48),
              padding: EdgeInsets.zero,
            ),
            child: const Icon(Symbols.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/// A bar of pinned announcements shown above the message list.
class _PinnedBar extends StatelessWidget {
  const _PinnedBar({required this.pinned, required this.onUnpin});

  final List<ChatMessage> pinned;
  final void Function(String id) onUnpin;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ChatMessage top = pinned.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.warning.withValues(alpha: 0.10),
      child: Row(
        children: <Widget>[
          const Icon(Symbols.keep_rounded, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  pinned.length == 1
                      ? 'Pinned announcement'
                      : '${pinned.length} pinned announcements',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${top.senderName}: ${top.body}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.close_rounded, size: 18),
            tooltip: 'Unpin',
            onPressed: () => onUnpin(top.id),
          ),
        ],
      ),
    );
  }
}

/// Preview of the message being replied to, shown above the composer.
class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.message, required this.onCancel});

  final ChatMessage message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Replying to ${message.senderName}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  message.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.close_rounded, size: 18),
            tooltip: 'Cancel reply',
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
