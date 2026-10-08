import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ChatRepository(dio: dioClient.dio);
});

class ChatScreen extends ConsumerStatefulWidget {
  final String jobId;
  final String jobTitle;

  const ChatScreen({
    super.key,
    required this.jobId,
    this.jobTitle = 'Chat',
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final repo = ref.read(chatRepositoryProvider);
    final msgs = await repo.getMessages(widget.jobId);
    if (mounted) {
      final wasAtBottom = _scrollController.hasClients &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 50;
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      if (wasAtBottom || !silent) {
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    _messageController.clear();
    final repo = ref.read(chatRepositoryProvider);

    final tempMsg = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      jobId: widget.jobId,
      senderId: user.id,
      senderName: user.name,
      content: text,
      timestamp: 'Just now',
    );

    setState(() => _messages.add(tempMsg));
    _scrollToBottom();

    await repo.sendMessage(
      jobId: widget.jobId,
      senderId: user.id,
      content: text,
    );
    _fetchMessages(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.jobTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Row(
              children: [
                CircleAvatar(radius: 3.5, backgroundColor: AppTheme.emeraldGreen),
                SizedBox(width: 4),
                Text(
                  'End-to-End SheRise Messaging',
                  style: TextStyle(fontSize: 11, color: AppTheme.emeraldGreen, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppTheme.rosePrimary))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppTheme.pinkSoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.purplePrimary),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Start coordinating work details',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Discuss measurements, timings, materials or delivery',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId == currentUser?.id;
                          return _buildBubble(msg, isMe);
                        },
                      ),
          ),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppTheme.cardBorder)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type message or requirement...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.rosePrimary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.heroGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(MessageModel msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        decoration: BoxDecoration(
          gradient: isMe ? AppTheme.heroGradient : null,
          color: isMe ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: AppTheme.cardBorder),
          boxShadow: [
            BoxShadow(
              color: isMe ? AppTheme.rosePrimary.withAlpha(20) : Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && msg.senderName.isNotEmpty)
              Text(
                msg.senderName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppTheme.purplePrimary,
                ),
              ),
            Text(
              msg.content,
              style: TextStyle(
                color: isMe ? Colors.white : AppTheme.textPrimary,
                fontSize: 14,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg.timestamp.isEmpty ? '' : msg.timestamp,
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
