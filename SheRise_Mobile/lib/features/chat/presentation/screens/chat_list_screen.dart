import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../jobs/data/models/job_model.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  List<JobModel> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _isLoading = true);
    final repo = ref.read(jobRepositoryProvider);

    final apps = await repo.getMyApplications(user.id);
    final posts = await repo.getMyPostings(user.id);

    // Merge distinct jobs
    final Map<String, JobModel> unique = {};
    for (var j in [...apps, ...posts]) {
      unique[j.id] = j;
    }

    if (mounted) {
      setState(() {
        _conversations = unique.values.toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFB),
      appBar: AppBar(
        title: const Text('Messages & Coordinates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.rosePrimary))
          : RefreshIndicator(
              color: AppTheme.rosePrimary,
              onRefresh: _loadConversations,
              child: _conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.pinkSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.forum_outlined, size: 48, color: AppTheme.rosePrimary),
                          ),
                          const SizedBox(height: 14),
                          const Text('No conversations yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text(
                            'When you post or apply for work, 1-on-1 chats appear here',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final job = _conversations[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.heroGradient,
                              ),
                              child: const CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.work, color: AppTheme.rosePrimary, size: 20),
                              ),
                            ),
                            title: Text(
                              job.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${job.category} • ${job.customerName}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                            onTap: () {
                              context.push('/chat/${job.id}', extra: job.title);
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
