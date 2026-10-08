import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme.dart';
import '../../../../core/widgets/she_rise_top_bar.dart';
import '../../data/models/worker_model.dart';
import '../providers/jobs_provider.dart';

class NearMeScreen extends ConsumerStatefulWidget {
  const NearMeScreen({super.key});

  @override
  ConsumerState<NearMeScreen> createState() => _NearMeScreenState();
}

class _NearMeScreenState extends ConsumerState<NearMeScreen> {
  final _searchController = TextEditingController();
  String _selectedDistance = '5 km';
  String _selectedCategory = 'All';

  final List<String> _distanceOptions = ['5 km', '10 km', '25 km', 'All'];
  final List<String> _categories = [
    'All',
    'Tailoring',
    'Cooking',
    'Pickles',
    'Kid Care',
    'Tuition',
    'Handicrafts',
    'Cleaning',
    'Beauty',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobsProvider);

    // Filter workers based on local criteria
    final workers = jobsState.nearbyWorkers.where((w) {
      final matchesCategory = _selectedCategory == 'All' ||
          w.skills.any((s) => s.toLowerCase().contains(_selectedCategory.toLowerCase()));
      final query = _searchController.text.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          w.name.toLowerCase().contains(query) ||
          w.location.toLowerCase().contains(query) ||
          w.skills.any((s) => s.toLowerCase().contains(query));
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: const SheRiseTopBar(),
      body: RefreshIndicator(
        color: AppTheme.deepRose,
        onRefresh: () async {
          await ref.read(jobsProvider.notifier).loadNearbyWorkers();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Distance Radius Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _distanceOptions.map((dist) {
                          final isSelected = _selectedDistance == dist;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => setState(() => _selectedDistance = dist),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.darkSlate : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.darkSlate : AppTheme.cardBorder,
                                  ),
                                ),
                                child: Text(
                                  'Within $dist',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppTheme.darkSlate,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Serif Title & Subtitle
                    Text('Near Me', style: AppTheme.serifTitle(fontSize: 32)),
                    const SizedBox(height: 4),
                    const Text(
                      'Discover verified local women artisans, cooks, tutors & tailors',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 16),

                    // Rounded Search Input
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
                          hintText: 'Search by name, skill (e.g. stitching, tutor)...',
                          hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          prefixIcon: const Icon(Icons.search, color: AppTheme.deepRose, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category Chips
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategory == cat;
                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => setState(() => _selectedCategory = cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.deepRose : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppTheme.deepRose : AppTheme.cardBorder,
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppTheme.darkSlate,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // White Curved Container with Worker Cards
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
                    if (jobsState.isWorkersLoading && jobsState.nearbyWorkers.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: CircularProgressIndicator(color: AppTheme.deepRose),
                        ),
                      );
                    }

                    if (workers.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  color: AppTheme.pinkSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.people_outline, size: 36, color: AppTheme.deepRose),
                              ),
                              const SizedBox(height: 18),
                              Text('No workers found nearby', style: AppTheme.serifTitle(fontSize: 22)),
                              const SizedBox(height: 8),
                              const Text(
                                'Try widening your distance radius or searching for a different skill.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: workers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final worker = workers[index];
                        return _buildWorkerCard(context, worker);
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

  Widget _buildWorkerCard(BuildContext context, WorkerModel worker) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.pinkSoft,
                child: Text(
                  worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'W',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepRose,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            worker.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkSlate,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (worker.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 16, color: AppTheme.emeraldGreen),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppTheme.amberGold),
                        const SizedBox(width: 3),
                        Text(
                          '${worker.rating.toStringAsFixed(1)} (${worker.reviewCount} reviews)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textMuted),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            worker.location,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Hourly Fee Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldGreen.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '₹${worker.hourlyRate.toInt()} / hr',
                  style: const TextStyle(
                    color: AppTheme.emeraldGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Skill Chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: worker.skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundCream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Text(
                  skill,
                  style: const TextStyle(fontSize: 11, color: AppTheme.darkSlate, fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.deepRose,
                    side: const BorderSide(color: AppTheme.primaryRose),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => context.push('/chat/${worker.id}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkSlate,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.phone_outlined, size: 16),
                  label: const Text('Hire Worker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => context.push('/worker/${worker.id}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
