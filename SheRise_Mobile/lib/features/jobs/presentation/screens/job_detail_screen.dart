import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/job_model.dart';
import '../providers/jobs_provider.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final JobModel job;

  const JobDetailScreen({super.key, required this.job});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _isApplying = false;
  String? _translatedDesc;
  bool _isTranslating = false;

  void _apply() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first')),
      );
      return;
    }

    setState(() => _isApplying = true);
    final ok = await ref.read(jobsProvider.notifier).applyToJob(widget.job.id, user.id);
    setState(() => _isApplying = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok ? AppTheme.emeraldGreen : AppTheme.errorRed,
          content: Text(
            ok
                ? 'Application submitted to ${widget.job.customerName}!'
                : 'Could not apply. You might have already applied.',
          ),
        ),
      );
    }
  }

  Future<void> _translateDetails() async {
    final langState = ref.read(languageProvider);
    if (langState.currentLanguage.code == 'en') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an Indic language from the top bar to translate.')),
      );
      return;
    }

    setState(() => _isTranslating = true);
    try {
      final translated = await ref
          .read(languageProvider.notifier)
          .translateText(widget.job.description);
      if (mounted) {
        setState(() {
          _translatedDesc = translated;
          _isTranslating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final langState = ref.watch(languageProvider);
    final isOwner = widget.job.creatorId == user?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFB),
      appBar: AppBar(
        title: Text(widget.job.category, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing work details with WhatsApp contacts...')),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppTheme.cardBorder)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Chat button
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.purplePrimary,
                    side: const BorderSide(color: AppTheme.purplePrimary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    context.push('/chat/${widget.job.id}', extra: widget.job.title);
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Apply or Status Button
              Expanded(
                flex: 2,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: isOwner ? null : AppTheme.heroGradient,
                    color: isOwner ? Colors.grey.shade200 : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isOwner ? null : AppTheme.softShadow,
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isOwner || _isApplying ? null : _apply,
                    child: _isApplying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            isOwner ? 'Your Work Post' : 'Apply for this Work',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isOwner ? Colors.grey : Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category & Urgency Badges
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: AppTheme.rosePinkGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.job.category,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, size: 14, color: AppTheme.amberGold),
                      const SizedBox(width: 3),
                      Text(
                        widget.job.urgency.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.amberGold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              widget.job.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 14),

            // Budget Highlight
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD1FAE5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.currency_rupee, color: AppTheme.emeraldGreen, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fair Budget Range',
                        style: TextStyle(color: Color(0xFF047857), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '₹${widget.job.minAmount} — ₹${widget.job.maxAmount}',
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Details section with AI Translation Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Work Description',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.purplePrimary,
                  ),
                  icon: _isTranslating
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.purplePrimary),
                        )
                      : const Icon(Icons.translate, size: 14),
                  label: Text('Translate (${langState.currentLanguage.code.toUpperCase()})'),
                  onPressed: _isTranslating ? null : _translateDetails,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Text(
                _translatedDesc ??
                    (widget.job.description.isEmpty
                        ? 'No additional description provided.'
                        : widget.job.description),
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),

            // Location & Logistics Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: [
                  _infoRow(Icons.location_on, 'Location', widget.job.location),
                  const Divider(height: 20),
                  _infoRow(Icons.local_shipping, 'Delivery Mode', widget.job.deliveryType),
                  const Divider(height: 20),
                  _infoRow(Icons.person, 'Posted By', widget.job.customerName),
                  const Divider(height: 20),
                  _infoRow(Icons.calendar_today, 'Posted At', widget.job.postedAt),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.rosePrimary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
      ],
    );
  }
}
