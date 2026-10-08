import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../providers/language_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/notifications/presentation/providers/notifications_provider.dart';

class SheRiseTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final VoidCallback? onBack;

  const SheRiseTopBar({
    super.key,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

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
                  Text(
                    'Select Indic Language',
                    style: AppTheme.serifTitle(fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Text(
                'Translate job postings and chat instantly into your mother tongue',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: kSupportedLanguages.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final lang = kSupportedLanguages[index];
                    final isSelected = lang.code == currentLang.code;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: CircleAvatar(
                        backgroundColor: isSelected ? AppTheme.deepRose : AppTheme.pinkSoft,
                        child: Text(
                          lang.code.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppTheme.deepRose,
                          ),
                        ),
                      ),
                      title: Text(
                        lang.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppTheme.deepRose : AppTheme.darkSlate,
                        ),
                      ),
                      subtitle: Text(
                        '${lang.nativeName} (${lang.scriptSample})',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppTheme.deepRose)
                          : null,
                      onTap: () {
                        ref.read(languageProvider.notifier).setLanguage(lang);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final langState = ref.watch(languageProvider);
    final notifsState = ref.watch(notificationsProvider);
    final unreadCount = notifsState.unreadCount;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 8,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          if (showBackButton) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.darkSlate),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 4),
          ],

          // SheRise Indian Women Circular Logo
          GestureDetector(
            onTap: () => context.go('/'),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/logo.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Serif Brand Name: "She" (Dark Slate) + "Rise" (Magenta)
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'She',
                        style: TextStyle(color: AppTheme.darkSlate),
                      ),
                      TextSpan(
                        text: 'Rise',
                        style: TextStyle(color: AppTheme.brandRise),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Language Indicator Pill
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showLanguageSelector(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.backgroundCream,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.language, size: 14, color: AppTheme.deepRose),
                  const SizedBox(width: 4),
                  Text(
                    langState.currentLanguage.code.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.darkSlate,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Notification Bell with Badge
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/notifications'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: AppTheme.darkSlate,
                    size: 24,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.deepRose,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Exact Web Sharp LOGIN Button or Profile Avatar
          if (user == null)
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => context.push('/login'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.darkSlate, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LOGIN',
                  style: TextStyle(
                    color: AppTheme.darkSlate,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            )
          else
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/profile'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.deepRose, width: 2),
                  color: AppTheme.pinkSoft,
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: AppTheme.deepRose,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
