import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/job_model.dart';
import '../providers/jobs_provider.dart';

class MyWorkScreen extends ConsumerStatefulWidget {
  const MyWorkScreen({super.key});

  @override
  ConsumerState<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends ConsumerState<MyWorkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<JobModel> _applications = [];
  List<JobModel> _postings = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _isLoading = true);
    final repo = ref.read(jobRepositoryProvider);

    final apps = await repo.getMyApplications(user.id);
    final posts = await repo.getMyPostings(user.id);

    if (mounted) {
      setState(() {
        _applications = apps;
        _postings = posts;
        _isLoading = false;
      });
    }
  }

  void _showCompleteJobRatingDialog(BuildContext context, JobModel job) {
    double selectedRating = 5.0;
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Complete Work & Review', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How was your experience working on "${job.title}" with ${job.customerName}?'),
              const SizedBox(height: 16),
              const Center(
                child: Text('Rate Experience', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    icon: Icon(
                      starIndex <= selectedRating ? Icons.star : Icons.star_border,
                      color: AppTheme.amberGold,
                      size: 32,
                    ),
                    onPressed: () {
                      setModalState(() => selectedRating = starIndex.toDouble());
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feedbackController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share feedback (e.g. Prompt payment, clear requirements)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.emeraldGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final repo = ref.read(jobRepositoryProvider);
                final ok = await repo.completeJob(
                  jobId: job.id,
                  rating: selectedRating,
                  feedback: feedbackController.text.trim(),
                );
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: ok ? AppTheme.emeraldGreen : AppTheme.errorRed,
                      content: Text(ok
                          ? 'Work marked as completed and feedback submitted!'
                          : 'Failed to record completion. Please retry.'),
                    ),
                  );
                  _loadData();
                }
              },
              child: const Text('Submit Completion'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFB),
      appBar: AppBar(
        title: const Text('My Work & Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.rosePrimary,
          indicatorWeight: 3,
          labelColor: AppTheme.rosePrimary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'Applied Work (${_applications.length})'),
            Tab(text: 'My Postings (${_postings.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.rosePrimary))
          : RefreshIndicator(
              color: AppTheme.rosePrimary,
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildApplicationsList(),
                  _buildPostingsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildApplicationsList() {
    if (_applications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.pinkSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_outlined, size: 48, color: AppTheme.rosePrimary),
            ),
            const SizedBox(height: 14),
            const Text('No job applications yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Browse the Work feed to find local micro-jobs',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _applications.length,
      itemBuilder: (context, index) {
        final job = _applications[index];
        final status = job.myApplicationStatus ?? 'pending';

        Color statusColor;
        switch (status) {
          case 'accepted':
            statusColor = AppTheme.emeraldGreen;
            break;
          case 'rejected':
            statusColor = AppTheme.errorRed;
            break;
          default:
            statusColor = AppTheme.amberGold;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.pinkSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        job.category,
                        style: const TextStyle(
                          color: AppTheme.rosePrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  '₹${job.minAmount} - ₹${job.maxAmount} • ${job.location}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Text('Employer: ${job.customerName}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    const Spacer(),
                    if (status == 'accepted') ...[
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppTheme.emeraldGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showCompleteJobRatingDialog(context, job),
                        child: const Text('Complete & Rate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppTheme.purplePrimary,
                        side: const BorderSide(color: AppTheme.purplePrimary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 14),
                      label: const Text('Chat', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        context.push('/chat/${job.id}', extra: job.title);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostingsList() {
    if (_postings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.pinkSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.post_add, size: 48, color: AppTheme.rosePrimary),
            ),
            const SizedBox(height: 14),
            const Text('You have not posted any work yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Tap "Post Work" on the Work tab to hire women workers',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _postings.length,
      itemBuilder: (context, index) {
        final job = _postings[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: AppTheme.rosePinkGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        job.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      '${job.applicationsCount} Applicant(s)',
                      style: const TextStyle(
                        color: AppTheme.purplePrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  '₹${job.minAmount} - ₹${job.maxAmount} • Status: ${job.status}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Text('Posted: ${job.postedAt}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    const Spacer(),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppTheme.purplePrimary,
                        side: const BorderSide(color: AppTheme.purplePrimary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.chat, size: 14),
                      label: const Text('Applicants Chat', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        context.push('/chat/${job.id}', extra: job.title);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
