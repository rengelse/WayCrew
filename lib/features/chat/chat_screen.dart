import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_system/app_widgets.dart';
import '../../data/mock/mock_data.dart';
import '../../data/mock/providers.dart';
import '../../data/supabase/providers.dart';
import '../auth/auth_controller.dart';
import '../../domain/models/activity_models.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String title;
  final String entityId;
  final bool isGroup;
  const ChatScreen({super.key, required this.title, required this.entityId, required this.isGroup});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final controller = TextEditingController();
  bool important = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncMessages = ref.watch(widget.isGroup ? groupMessagesProvider(widget.entityId) : activityMessagesProvider(widget.entityId));
    final demo = ref.watch(localDemoModeProvider);
    final remoteName = ref.watch(supabaseProfileControllerProvider).valueOrNull?.name;
    final currentName = demo ? ref.watch(mockProfileStoreProvider).name : (remoteName ?? 'Meg');
    final currentUserId = ref.watch(currentActivityUserIdProvider);
    final activity = widget.isGroup ? null : ref.watch(activityByIdProvider(widget.entityId)).valueOrNull;
    final group = widget.isGroup ? ref.watch(groupByIdProvider(widget.entityId)).valueOrNull : null;
    final isLeader = activity?.participants.any((p) => p.user.id == currentUserId && p.role == ParticipantRole.leader) ?? false;
    final resolvedTitle = widget.isGroup ? (group?.name ?? widget.title) : (activity?.title ?? widget.title);

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(fallbackLocation: widget.isGroup ? '/group/${widget.entityId}' : '/activity/${widget.entityId}'),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(resolvedTitle),
          Text(widget.isGroup ? 'Gruppechat' : 'Aktivitetschat', style: Theme.of(context).textTheme.bodySmall),
        ]),
        actions: [
          if (!widget.isGroup && isLeader)
            IconButton(
              onPressed: () => setState(() => important = !important),
              tooltip: 'Viktig melding',
              icon: Icon(important ? Icons.priority_high_rounded : Icons.priority_high_outlined),
            ),
        ],
      ),
      body: Column(children: [
        if (important)
          Material(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [Icon(Icons.campaign_outlined), SizedBox(width: 8), Expanded(child: Text('Neste melding sendes som viktig turledermelding.'))]),
            ),
          ),
        Expanded(
          child: asyncMessages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (messages) => messages.isEmpty
                ? const Center(child: Text('Ingen meldinger ennå'))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index];
                      return _MessageBubble(message: message, currentName: currentName, currentUserId: currentUserId);
                    },
                  ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconButton(onPressed: _attachments, icon: const Icon(Icons.add_circle_outline)),
              Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Skriv en melding...'))),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
            ]),
          ),
        ),
      ]),
    );
  }

  void _attachments() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Del posisjon'),
            subtitle: Text(ref.read(localDemoModeProvider)
                ? 'Sender et demo-posisjonspunkt'
                : 'Aktiveres sammen med ekte GPS/live tracking'),
            onTap: () async {
              Navigator.pop(sheetContext);
              if (!ref.read(localDemoModeProvider)) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posisjonsdeling kobles på i Live Tracking-fasen. Ingen dummy-posisjon sendes.')));
                }
                return;
              }
              final repo = ref.read(chatRepositoryProvider);
              if (widget.isGroup) {
                await repo.sendGroupMessage(widget.entityId, '📍 Demo-posisjon', senderName: _senderName());
              } else {
                await repo.sendActivityMessage(widget.entityId, '📍 Demo-posisjon', senderName: _senderName());
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_outlined),
            title: const Text('Legg ved bilde'),
            subtitle: const Text('Medievelger kobles på senere'),
            onTap: () {
              Navigator.pop(sheetContext);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bildevedlegg krever kamera/galleri-integrasjonen som kommer senere.')));
            },
          ),
        ]),
      ),
    );
  }


  String _senderName() {
    final demo = ref.read(localDemoModeProvider);
    if (demo) return ref.read(mockProfileStoreProvider).name;
    return ref.read(supabaseProfileControllerProvider).valueOrNull?.name ?? 'Meg';
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    final repo = ref.read(chatRepositoryProvider);
    try {
      if (widget.isGroup) {
        await repo.sendGroupMessage(widget.entityId, text, senderName: _senderName());
      } else {
        await repo.sendActivityMessage(widget.entityId, text, important: important, senderName: _senderName());
      }
      controller.clear();
      if (mounted) setState(() => important = false);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kunne ikke sende meldingen: $error')));
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String currentName;
  final String? currentUserId;
  const _MessageBubble({required this.message, required this.currentName, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final mine = (currentUserId != null && message.senderId == currentUserId) || message.sender == currentName || message.sender == currentUser.name;
    return Align(
      alignment: message.system ? Alignment.center : mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 310),
        decoration: BoxDecoration(
          color: message.important
              ? Theme.of(context).colorScheme.tertiaryContainer
              : message.system
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : mine
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!message.system)
            Text(message.important ? 'Viktig · ${message.sender}' : message.sender, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          Text(message.text),
          const SizedBox(height: 3),
          Text(
            message.pending ? 'Venter på sending' : '${message.sentAt.hour.toString().padLeft(2, '0')}:${message.sentAt.minute.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ]),
      ),
    );
  }
}
