import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/job_model.dart';
import '../../data/models/worker_model.dart';
import '../../data/repositories/job_repository.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return JobRepository(dio: dioClient.dio);
});

class JobsState {
  final List<JobModel> allJobs;
  final List<WorkerModel> nearbyWorkers;
  final bool isLoading;
  final bool isWorkersLoading;
  final String? error;
  final String selectedCategory;
  final String searchQuery;
  final int activeTab; // 0 = Work Feed, 1 = Nearby Women Workers

  const JobsState({
    this.allJobs = const [],
    this.nearbyWorkers = const [],
    this.isLoading = false,
    this.isWorkersLoading = false,
    this.error,
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.activeTab = 0,
  });

  List<JobModel> get filteredJobs {
    return allJobs.where((job) {
      final matchesCategory = selectedCategory == 'All' ||
          job.category.toLowerCase().contains(selectedCategory.toLowerCase());
      final matchesSearch = searchQuery.isEmpty ||
          job.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          job.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
          job.location.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  List<WorkerModel> get filteredWorkers {
    return nearbyWorkers.where((worker) {
      final matchesCategory = selectedCategory == 'All' ||
          worker.skills.any((s) => s.toLowerCase().contains(selectedCategory.toLowerCase()));
      final matchesSearch = searchQuery.isEmpty ||
          worker.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          worker.location.toLowerCase().contains(searchQuery.toLowerCase()) ||
          worker.skills.any((s) => s.toLowerCase().contains(searchQuery.toLowerCase()));
      return matchesCategory && matchesSearch;
    }).toList();
  }

  JobsState copyWith({
    List<JobModel>? allJobs,
    List<WorkerModel>? nearbyWorkers,
    bool? isLoading,
    bool? isWorkersLoading,
    String? error,
    String? selectedCategory,
    String? searchQuery,
    int? activeTab,
  }) {
    return JobsState(
      allJobs: allJobs ?? this.allJobs,
      nearbyWorkers: nearbyWorkers ?? this.nearbyWorkers,
      isLoading: isLoading ?? this.isLoading,
      isWorkersLoading: isWorkersLoading ?? this.isWorkersLoading,
      error: error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      activeTab: activeTab ?? this.activeTab,
    );
  }
}

class JobsNotifier extends StateNotifier<JobsState> {
  final JobRepository _repository;

  JobsNotifier({required JobRepository repository})
      : _repository = repository,
        super(const JobsState()) {
    loadJobs();
    loadNearbyWorkers();
  }

  Future<void> loadJobs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final jobs = await _repository.getJobs();
      state = state.copyWith(allJobs: jobs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadRecommendedJobs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final jobs = await _repository.getRecommendedJobs();
      state = state.copyWith(allJobs: jobs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadNearbyWorkers() async {
    state = state.copyWith(isWorkersLoading: true);
    try {
      final workers = await _repository.getNearbyWorkers();
      state = state.copyWith(nearbyWorkers: workers, isWorkersLoading: false);
    } catch (_) {
      state = state.copyWith(isWorkersLoading: false);
    }
  }

  void setActiveTab(int tab) {
    state = state.copyWith(activeTab: tab);
  }

  void selectCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<bool> applyToJob(String jobId, String workerId) async {
    final success = await _repository.applyJob(jobId: jobId, workerId: workerId);
    if (success) {
      await loadJobs();
    }
    return success;
  }
}

final jobsProvider = StateNotifierProvider<JobsNotifier, JobsState>((ref) {
  final repository = ref.watch(jobRepositoryProvider);
  return JobsNotifier(repository: repository);
});
