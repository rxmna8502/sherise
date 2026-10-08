import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../config/theme.dart';
import '../../../../core/widgets/she_rise_top_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/jobs_provider.dart';

class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _minBudgetController = TextEditingController(text: '500');
  final _maxBudgetController = TextEditingController(text: '1200');
  final _locationController = TextEditingController(text: 'Madhapur, Hyderabad');

  String _selectedCategory = 'Tailoring';
  String _selectedPaymentMode = 'online'; // 'online' (Escrow) or 'cod' (Cash on Delivery)
  String _selectedUrgency = 'Medium'; // Low, Medium, High, Immediate
  bool _isSubmitting = false;
  bool _isAnalyzingImage = false;
  String? _aiNotice;

  final List<String> _categories = [
    'Tailoring',
    'Handicrafts',
    'Cooking & Catering',
    'Pickles & Snacks',
    'Baby & Kid Care',
    'Tuition & Teaching',
    'Cleaning & Housekeeping',
    'Beauty & Mehendi',
    'Data Entry & Digital',
    'Elderly Care',
    'Gardening',
    'Pet Care',
    'Baking & Sweets',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _minBudgetController.dispose();
    _maxBudgetController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyzeImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (pickedFile == null) return;

    setState(() {
      _isAnalyzingImage = true;
      _aiNotice = null;
    });

    try {
      final repo = ref.read(jobRepositoryProvider);
      final aiResult = await repo.analyzeImage(pickedFile.path);

      if (aiResult != null && mounted) {
        setState(() {
          if (aiResult['title'] != null && aiResult['title'].toString().isNotEmpty) {
            _titleController.text = aiResult['title'].toString();
          }
          if (aiResult['description'] != null && aiResult['description'].toString().isNotEmpty) {
            _descController.text = aiResult['description'].toString();
          }
          if (aiResult['tags'] != null && aiResult['tags'] is List) {
            final tags = (aiResult['tags'] as List).map((t) => t.toString().toLowerCase()).toList();
            for (final cat in _categories) {
              if (tags.any((t) => cat.toLowerCase().contains(t))) {
                _selectedCategory = cat;
                break;
              }
            }
          }
          _aiNotice = '✨ AI analyzed your photo and auto-filled work details!';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _aiNotice = 'Could not analyze photo automatically. Please enter details.';
        });
      }
    } finally {
      if (mounted) setState(() => _isAnalyzingImage = false);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.darkSlate,
          content: Text('Please login to post work requirements.'),
        ),
      );
      context.push('/login');
      return;
    }

    setState(() => _isSubmitting = true);
    final repo = ref.read(jobRepositoryProvider);

    final job = await repo.createJob(
      title: _titleController.text.trim(),
      category: _selectedCategory,
      description: _descController.text.trim(),
      minAmount: int.tryParse(_minBudgetController.text.trim()) ?? 500,
      maxAmount: int.tryParse(_maxBudgetController.text.trim()) ?? 1200,
      location: _locationController.text.trim(),
      deliveryType: _selectedPaymentMode,
      urgency: _selectedUrgency,
      customerName: user.name,
      creatorId: user.id,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (job != null) {
        ref.read(jobsProvider.notifier).loadJobs();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.emeraldGreen,
            content: Text('Work posted successfully to SheRise!'),
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.errorRed,
            content: Text('Failed to post work. Please try again.'),
          ),
        );
      }
    }
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppTheme.pinkSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.deepRose, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkSlate,
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: const SheRiseTopBar(showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exact Web Serif Headline
              Text(
                'Give Work',
                style: AppTheme.serifTitle(fontSize: 32),
              ),
              const SizedBox(height: 4),
              const Text(
                'Post a task or project for talented women',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),

              // CARD 1: Work Details
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.description_outlined,
                      title: 'Work Details',
                    ),
                    const SizedBox(height: 16),

                    // AI Scan Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.deepRose,
                        side: const BorderSide(color: AppTheme.primaryRose),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: _isAnalyzingImage
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.deepRose),
                            )
                          : const Icon(Icons.add_a_photo, size: 16),
                      label: Text(
                        _isAnalyzingImage ? 'Analyzing with AI...' : '✨ Scan Photo with AI to Auto-fill',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isAnalyzingImage ? null : _pickAndAnalyzeImage,
                    ),
                    if (_aiNotice != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _aiNotice!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.deepRose, fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Task Title
                    const Text('Task Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Need someone to stitch 2 blouses',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Please enter a task title' : null,
                    ),
                    const SizedBox(height: 14),

                    // Category Dropdown
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: _categories
                          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 14))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Task Description
                    const Text('Task Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Describe the task in detail...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Please describe the task' : null,
                    ),
                    const SizedBox(height: 14),

                    // Location / Address
                    const Text('Location / Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Kukatpally, Hyderabad',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.deepRose, size: 20),
                        filled: true,
                        fillColor: AppTheme.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CARD 2: Budget
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.currency_rupee,
                      title: 'Budget',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Min ₹', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _minBudgetController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '500',
                                  filled: true,
                                  fillColor: AppTheme.inputBg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppTheme.inputBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppTheme.inputBorder),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Max ₹', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _maxBudgetController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '1200',
                                  filled: true,
                                  fillColor: AppTheme.inputBg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppTheme.inputBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppTheme.inputBorder),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CARD 3: Mode of Payment
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Mode of Payment',
                    ),
                    const SizedBox(height: 12),

                    // Option 1: Escrow
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedPaymentMode = 'online'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedPaymentMode == 'online' ? AppTheme.pinkSoft.withAlpha(80) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedPaymentMode == 'online' ? AppTheme.deepRose : AppTheme.cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: 'online',
                              groupValue: _selectedPaymentMode,
                              activeColor: AppTheme.deepRose,
                              onChanged: (val) => setState(() => _selectedPaymentMode = val!),
                            ),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Online Payment (Escrow)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'Funds held securely until task completion',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Option 2: Cash on Delivery
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedPaymentMode = 'cod'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedPaymentMode == 'cod' ? AppTheme.pinkSoft.withAlpha(80) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedPaymentMode == 'cod' ? AppTheme.deepRose : AppTheme.cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: 'cod',
                              groupValue: _selectedPaymentMode,
                              activeColor: AppTheme.deepRose,
                              onChanged: (val) => setState(() => _selectedPaymentMode = val!),
                            ),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cash on Delivery',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'Pay directly upon task completion',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CARD 4: Urgency
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.timer_outlined,
                      title: 'Urgency',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: ['Low', 'Medium', 'High', 'Immediate'].map((level) {
                        final isSelected = _selectedUrgency == level;
                        return ChoiceChip(
                          label: Text(level),
                          selected: isSelected,
                          selectedColor: AppTheme.deepRose,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.darkSlate,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: isSelected ? AppTheme.deepRose : AppTheme.cardBorder,
                          ),
                          onSelected: (_) => setState(() => _selectedUrgency = level),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Button: Solid Dark Slate Pill Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkSlate,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Post Work',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
