import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/widgets/she_rise_top_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out?'),
        content: const Text('Are you sure you want to log out of your SheRise account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final currentLang = ref.watch(languageProvider).currentLanguage;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Indic Language',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: kSupportedLanguages.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final lang = kSupportedLanguages[index];
                    final isSelected = lang.code == currentLang.code;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected ? AppTheme.rosePrimary : AppTheme.pinkSoft,
                        child: Text(
                          lang.code.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppTheme.rosePrimary,
                          ),
                        ),
                      ),
                      title: Text(
                        lang.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppTheme.rosePrimary : AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text('${lang.nativeName} (${lang.scriptSample})'),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppTheme.rosePrimary)
                          : null,
                      onTap: () {
                        ref.read(languageProvider.notifier).setLanguage(lang);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubscriptionModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.heroGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SheRise Empowerment Plans',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Boost your earnings & connect with verified local clients',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildPlanTile(
                ctx,
                ref,
                title: 'Free Community',
                price: '₹0 / forever',
                benefit: '10 monthly work application credits',
                badge: 'Active Default',
                isCurrent: true,
                color: Colors.grey.shade700,
                planKey: 'free',
              ),
              const SizedBox(height: 10),
              _buildPlanTile(
                ctx,
                ref,
                title: 'Starter Shakti',
                price: '₹99 / month',
                benefit: '50 credits + Verified badge boost + Urgent work alerts',
                badge: 'Most Popular',
                isCurrent: false,
                color: AppTheme.rosePrimary,
                planKey: 'starter',
              ),
              const SizedBox(height: 10),
              _buildPlanTile(
                ctx,
                ref,
                title: 'Pro Empower',
                price: '₹299 / month',
                benefit: '150 credits + Priority search ranking + 0% platform fee',
                badge: 'Unlimited Growth',
                isCurrent: false,
                color: AppTheme.purplePrimary,
                planKey: 'pro',
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanTile(
    BuildContext ctx,
    WidgetRef ref, {
    required String title,
    required String price,
    required String benefit,
    required String badge,
    required bool isCurrent,
    required Color color,
    required String planKey,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.grey.shade50 : AppTheme.pinkSoft.withAlpha(50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? Colors.grey.shade300 : color.withAlpha(60),
          width: isCurrent ? 1 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  benefit,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (!isCurrent)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final repo = ref.read(jobRepositoryProvider);
                final ok = await repo.subscribePlan(planKey);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      backgroundColor: ok ? Colors.green : Colors.red,
                      content: Text(ok
                          ? 'Plan upgraded successfully to $title!'
                          : 'Payment simulation completed.'),
                    ),
                  );
                }
              },
              child: const Text('Upgrade', style: TextStyle(fontSize: 12)),
            )
          else
            const Icon(Icons.check_circle_outline, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final currentLang = ref.watch(languageProvider).currentLanguage;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.rosePrimary),
            onPressed: () => context.go('/login'),
            child: const Text('Log In to SheRise'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: const SheRiseTopBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          children: [
            // User Header Hero Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: AppTheme.heroGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                children: [
                  // Avatar with glowing white ring
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.pinkSoft,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'S',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.rosePrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (user.phone?.isNotEmpty == true) ? user.phone! : user.email,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  // DigiLocker / Aadhaar Verification Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          user.isVerified ? Icons.verified : Icons.verified_user_outlined,
                          size: 16,
                          color: user.isVerified ? Colors.greenAccent : Colors.amberAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          user.isVerified ? 'eAadhaar Verified Worker' : 'DigiLocker KYC Pending',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Membership & Coins Balance Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.cardSoftGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.cardBorder),
                boxShadow: AppTheme.softShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('🪙', style: TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${user.credits} Coins & Credits',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Used for posting work & contacting skilled workers',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.rosePrimary,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showSubscriptionModal(context, ref),
                    child: const Text('Plans', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats Row: Rating, Reviews, Verified Status
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    title: 'Worker Rating',
                    value: '${user.rating.toStringAsFixed(1)} ★',
                    subtitle: '${user.reviewCount} reviews',
                    color: AppTheme.amberGold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    title: 'Marketplace Trust',
                    value: user.isVerified ? '100%' : '85%',
                    subtitle: 'DigiLocker Verified',
                    color: AppTheme.emeraldGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Skills Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18, color: AppTheme.rosePrimary),
                      SizedBox(width: 8),
                      Text(
                        'My Specialized Skills',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  user.skills.isEmpty
                      ? const Text(
                          'No skills registered yet. Add tailoring, cooking, tuition, etc.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: user.skills
                              .map(
                                (s) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.pinkSoft,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.cardBorder),
                                  ),
                                  child: Text(
                                    s,
                                    style: const TextStyle(
                                      color: AppTheme.rosePrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Settings & Actions Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language, color: AppTheme.purplePrimary),
                    title: const Text('App Language (Mother Tongue)'),
                    subtitle: Text('${currentLang.name} (${currentLang.nativeName})',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showLanguageSelector(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined, color: AppTheme.emeraldGreen),
                    title: const Text('DigiLocker Aadhaar Verification'),
                    subtitle: const Text('Official Gov KYC for safety badge',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Aadhaar XML verification is active and secured via DigiLocker.'),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined, color: AppTheme.rosePrimary),
                    title: const Text('Notifications & Alerts'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/notifications'),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline, color: Colors.grey),
                    title: Text('SheRise Version'),
                    subtitle: Text('1.0.0 (Pure Native Flutter)',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Logout full-width button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                  side: const BorderSide(color: AppTheme.errorRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Log Out of SheRise', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showLogoutDialog(context, ref),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}
