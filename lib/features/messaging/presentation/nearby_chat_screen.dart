import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../models/message_models.dart';
import '../providers/nearby_chat_provider.dart';
import '../widgets/message_bubble.dart';

/// Direct offline chat with a single connected Nearby peer.
///
/// Sends and receives text messages over the established Bluetooth / Wi-Fi
/// Direct connection, persists them to SQLite, and shows delivery status and
/// live connection status.
class NearbyChatScreen extends ConsumerStatefulWidget {
  const NearbyChatScreen({
    super.key,
    required this.endpointId,
    required this.deviceName,
  });

  final String endpointId;
  final String deviceName;

  @override
  ConsumerState<NearbyChatScreen> createState() => _NearbyChatScreenState();
}

class _NearbyChatScreenState extends ConsumerState<NearbyChatScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  late final NearbyChatArgs _args = NearbyChatArgs(
    endpointId: widget.endpointId,
    deviceName: widget.deviceName,
  );

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
    await ref.read(nearbyChatProvider(_args).notifier).send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final NearbyChatState chat = ref.watch(nearbyChatProvider(_args));

    // Auto-scroll as new messages arrive.
    ref.listen<NearbyChatState>(nearbyChatProvider(_args),
        (NearbyChatState? prev, NearbyChatState next) {
      if (prev != null && next.messages.length != prev.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: SumpayAppBar(
        title: widget.deviceName,
        subtitle: 'Direct mesh chat',
        actions: <Widget>[
          RoundIconButton(
            icon: Symbols.delete_sweep_rounded,
            tooltip: 'Clear history',
            onPressed: () async {
              final bool ok = await AppDialogs.confirm(
                context,
                title: 'Clear this chat?',
                message:
                    'All messages with ${widget.deviceName} on this device will be permanently deleted.',
                confirmLabel: 'Clear',
                icon: Symbols.delete_sweep_rounded,
                destructive: true,
              );
              if (!ok) return;
              await ref.read(nearbyChatProvider(_args).notifier).clearHistory();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _ConnectionBar(
              deviceName: widget.deviceName,
              isConnected: chat.isConnected,
            ),
            Expanded(
              child: chat.isLoading
                  ? const LoadingState(message: 'Loading messages…')
                  : chat.messages.isEmpty
                      ? EmptyState(
                          title: 'No messages yet',
                          message: chat.isConnected
                              ? 'Say hello to ${widget.deviceName}. Messages send directly over the mesh — no internet needed.'
                              : 'You are not connected to this device right now.',
                          icon: Symbols.forum_rounded,
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          itemCount: chat.messages.length,
                          itemBuilder: (BuildContext context, int index) {
                            final ChatMessage message = chat.messages[index];
                            final bool showSender = index == 0 ||
                                chat.messages[index - 1].isMine !=
                                    message.isMine;
                            return MessageBubble(
                              message: message,
                              showSender: showSender && !message.isMine,
                            );
                          },
                        ),
            ),
            _Composer(
              controller: _composer,
              enabled: chat.isConnected,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBar extends StatelessWidget {
  const _ConnectionBar({required this.deviceName, required this.isConnected});

  final String deviceName;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = isConnected ? AppColors.success : AppColors.danger;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: color.withValues(alpha: 0.10),
      child: Row(
        children: <Widget>[
          Container(
            height: 9,
            width: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              isConnected
                  ? 'Connected — messages send directly over the mesh'
                  : 'Disconnected — reconnect from Nearby devices to send',
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          StatusChip(
            label: isConnected ? 'Online' : 'Offline',
            color: color,
            dense: true,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: enabled ? (_) => onSend() : null,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: enabled ? 'Write a message…' : 'Not connected',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
                  borderSide:
                      BorderSide(color: theme.colorScheme.primary, width: 1.8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: enabled ? onSend : null,
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
    );
  }
}
