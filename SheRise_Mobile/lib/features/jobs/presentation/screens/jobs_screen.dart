import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/jobs_provider.dart';
import '../../data/models/job_model.dart';
import '../../../../core/widgets/she_rise_top_bar.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final _searchController = TextEditingController();

  // Full 12 Indian Micro-Job Categories matching Web App
  final List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': Icons.auto_awesome, 'label': 'All Work'},
    {'name': 'Stitching', 'icon': Icons.content_cut, 'label': 'Stitching & Tailoring'},
    {'name': 'Cooking', 'icon': Icons.restaurant, 'label': 'Cooking & Catering'},
    {'name': 'Pickles', 'icon': Icons.kitchen, 'label': 'Pickles & Snacks'},
    {'name': 'Kid Care', 'icon': Icons.child_care, 'label': 'Baby & Kid Care'},
    {'name': 'Tuition', 'icon': Icons.school, 'label': 'Tuition & Teaching'},
    {'name': 'Handicrafts', 'icon': Icons.brush, 'label': 'Handicrafts & Arts'},
    {'name': 'Cleaning', 'icon': Icons.cleaning_services, 'label': 'Cleaning & Housekeeping'},
    {'name': 'Beauty', 'icon': Icons.face_retouching_natural, 'label': 'Beauty & Mehendi'},
    {'name': 'Data Entry', 'icon': Icons.computer, 'label': 'Data Entry & Digital'},
    {'name': 'Storytelling', 'icon': Icons.menu_book, 'label': 'Storytelling & Care'},
    {'name': 'Baking', 'icon': Icons.cake, 'label': 'Baking & Sweets'},
    {'name': 'Packaging', 'icon': Icons.inventory_2, 'label': 'Packaging & Assembly'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showVoiceSearchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'AI Voice Assistant',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Speak in Hindi, Telugu, Tamil, or English to find work',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              // Glowing Mic Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.heroGradient,
                  boxShadow: AppTheme.glowPurpleShadow,
                ),
                child: const Icon(Icons.mic, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'Listening for keywords...\n(e.g., "blouse stitching", "home tiffin", "pickle maker")',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('🧵 Blouse Tailoring'),
                    onPressed: () {
                      _searchController.text = 'Tailoring';
                      ref.read(jobsProvider.notifier).setSearchQuery('Tailoring');
                      Navigator.pop(ctx);
                    },
                  ),
                  ActionChip(
                    label: const Text('🍲 Tiffin Service'),
                    onPressed: () {
                      _searchController.text = 'Cooking';
                      ref.read(jobsProvider.notifier).setSearchQuery('Cooking');
                      Navigator.pop(ctx);
                    },
                  ),
                  ActionChip(
                    label: const Text('👶 Babysitting'),
                    onPressed: () {
                      _searchController.text = 'Care';
                      ref.read(jobsProvider.notifier).setSearchQuery('Care');
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobsProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: const SheRiseTopBar(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.darkSlate,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_circle_outline, color: AppTheme.deepRose),
        label: const Text('Post Work', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => context.push('/post-job'),
      ),
      body: RefreshIndicator(
        color: AppTheme.rosePrimary,
        onRefresh: () async {
          await ref.read(jobsProvider.notifier).loadJobs();
          await ref.read(jobsProvider.notifier).loadNearbyWorkers();
        },
        child: CustomScrollView(
          slivers: [
            // Top Section (Pills, Serif Headline, Search, Categories)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row of Action Pills: [ ✨ AI Recommended ] [ Show All Jobs ] [ ⚙️ Filters ]
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              ref.read(jobsProvider.notifier).loadRecommendedJobs();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.primaryRose, width: 1.2),
                              ),
                              child: const Row(
                                children: [
                                  Text('✨', style: TextStyle(fontSize: 12)),
                                  SizedBox(width: 4),
                                  Text(
                                    'AI Recommended',
                                    style: TextStyle(
                                      color: AppTheme.deepRose,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              ref.read(jobsProvider.notifier).loadJobs();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppTheme.darkSlate,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Show All Jobs',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              _searchController.clear();
                              ref.read(jobsProvider.notifier).setSearchQuery('');
                              ref.read(jobsProvider.notifier).selectCategory('All');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.cardBorder, width: 1.2),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.tune, size: 14, color: AppTheme.darkSlate),
                                  SizedBox(width: 4),
                                  Text(
                                    'Filters',
                                    style: TextStyle(
                                      color: AppTheme.darkSlate,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Exact Web Serif Title & Subtitle
                    Text(
                      'Take Work',
                      style: AppTheme.serifTitle(fontSize: 32),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Showing all available jobs',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rounded Search Input matching Web App
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.inputBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 14, color: AppTheme.darkSlate),
                        decoration: InputDecoration(
                          hintText: 'Search for work (e.g., stitching, cooking)...',
                          hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          prefixIcon: const Icon(Icons.search, color: AppTheme.deepRose, size: 20),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(jobsProvider.notifier).setSearchQuery('');
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.mic, color: AppTheme.deepRose, size: 20),
                                tooltip: 'AI Voice Search',
                                onPressed: () => _showVoiceSearchModal(context),
                              ),
                            ],
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (val) {
                          ref.read(jobsProvider.notifier).setSearchQuery(val);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Horizontal Category Chips with Underline Indicator on Active
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = jobsState.selectedCategory.toLowerCase() ==
                              (cat['name'] as String).toLowerCase();
                          return GestureDetector(
                            onTap: () {
                              ref.read(jobsProvider.notifier).selectCategory(cat['name'] as String);
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.deepRose : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.deepRose : AppTheme.cardBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      if (isSelected)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                                        ),
                                      Text(
                                        cat['name'] as String,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : AppTheme.darkSlate,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    width: 16,
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      color: AppTheme.deepRose,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // White Curved Sheet Container (BorderRadius.vertical(top: Radius.circular(32)))
            SliverToBoxAdapter(
              child: Container(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
                child: Builder(
                  builder: (context) {
                    if (jobsState.isLoading && jobsState.allJobs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: CircularProgressIndicator(color: AppTheme.deepRose),
                        ),
                      );
                    }

                    if (jobsState.filteredJobs.isEmpty) {
                      // Exact Web Empty State Clone
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  color: AppTheme.pinkSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.filter_alt_outlined,
                                  size: 36,
                                  color: AppTheme.deepRose,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'No tasks found',
                                style: AppTheme.serifTitle(fontSize: 22),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Try adjusting your search or category filters to find available opportunities',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.darkSlate,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(jobsProvider.notifier).setSearchQuery('');
                                  ref.read(jobsProvider.notifier).selectCategory('All');
                                },
                                child: const Text(
                                  'Clear Filters',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Job Cards List
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: jobsState.filteredJobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final job = jobsState.filteredJobs[index];
                        return _buildJobCard(context, job, user?.id);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, JobModel job, String? currentUserId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.rosePrimary.withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/job/${job.id}', extra: job),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Badge & Budget Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppTheme.rosePinkGradient,
                      borderRadius: BorderRadius.circular(10),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldGreen.withAlpha(18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₹${job.minAmount} - ₹${job.maxAmount}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.emeraldGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                job.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              // Description
              Text(
                job.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 12),

              // Badges Row
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    job.location,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.bolt, size: 14, color: AppTheme.amberGold),
                  const SizedBox(width: 2),
                  Text(
                    job.urgency,
                    style: const TextStyle(
                      color: AppTheme.amberGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (job.creatorId != currentUserId)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.darkSlate,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () => context.push('/job/${job.id}', extra: job),
                      child: const Text('Apply Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.pinkSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Your Posting',
                        style: TextStyle(
                          color: AppTheme.rosePrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

