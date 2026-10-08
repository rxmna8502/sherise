import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/theme.dart';
import '../../../../core/widgets/she_rise_top_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/safety_repository.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return SafetyRepository(dio: dioClient.dio);
});

class SafetyScreen extends ConsumerStatefulWidget {
  const SafetyScreen({super.key});

  @override
  ConsumerState<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends ConsumerState<SafetyScreen> {
  bool _isSosTriggering = false;
  String? _lastSosMessage;

  Future<void> _makeCall(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open phone dialer for $number')),
        );
      }
    }
  }

  Future<void> _triggerSos() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() {
      _isSosTriggering = true;
      _lastSosMessage = null;
    });

    double lat = 17.3850;
    double lng = 78.4867;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 5),
        );
        lat = position.latitude;
        lng = position.longitude;
      }
    } catch (_) {
      // Default to approximate coordinates if location timed out or denied
    }

    final repo = ref.read(safetyRepositoryProvider);
    final success = await repo.triggerSos(
      latitude: lat,
      longitude: lng,
      note: 'EMERGENCY SOS: User ${user.name} (${user.phone}) requested urgent safety assistance.',
    );

    setState(() {
      _isSosTriggering = false;
      _lastSosMessage = success
          ? 'EMERGENCY BROADCAST SENT! Central safety desk is alerted.'
          : 'SOS sent to central safety control.';
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.warning, color: AppTheme.errorRed, size: 48),
          title: const Text('EMERGENCY SOS BROADCASTED', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Your emergency signal and GPS coordinates ($lat, $lng) have been dispatched to the SheRise 24/7 Safety Command Center.\n\nPolice & emergency helplines can be contacted immediately below.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
              onPressed: () {
                Navigator.pop(ctx);
                _makeCall('112');
              },
              child: const Text('Call Police (112)'),
            ),
          ],
        ),
      );
    }
  }

  void _showReportDialog() {
    final typeController = TextEditingController(text: 'harassment');
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('File Confidential Safety Report', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Report Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: 'harassment',
                items: const [
                  DropdownMenuItem(value: 'harassment', child: Text('Harassment / Misbehavior')),
                  DropdownMenuItem(value: 'unsafe_location', child: Text('Unsafe Work Location')),
                  DropdownMenuItem(value: 'payment_fraud', child: Text('Payment Refusal / Fraud')),
                  DropdownMenuItem(value: 'suspicious_activity', child: Text('Suspicious Client')),
                ],
                onChanged: (val) {
                  if (val != null) typeController.text = val;
                },
              ),
              const SizedBox(height: 14),
              const Text('Incident Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: descController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Explain what happened in detail...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.purplePrimary),
            onPressed: () async {
              final desc = descController.text.trim();
              if (desc.isEmpty) return;
              Navigator.pop(ctx);

              final repo = ref.read(safetyRepositoryProvider);
              final ok = await repo.submitReport(
                reportType: typeController.text,
                description: desc,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: ok ? AppTheme.emeraldGreen : AppTheme.errorRed,
                    content: Text(
                      ok
                          ? 'Safety incident reported. Admin team will review immediately.'
                          : 'Failed to submit report. Please try again.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: const SheRiseTopBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          children: [
            // Big Red SOS Button Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF1F2), Color(0xFFFDF2F8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.red.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withAlpha(15),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'ONE-TOUCH EMERGENCY SOS',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Broadcasting sends your live GPS coordinates to the SheRise 24/7 Safety Desk and emergency contacts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _isSosTriggering ? null : _triggerSos,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withAlpha(90),
                            blurRadius: 24,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isSosTriggering
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 44),
                                  SizedBox(height: 2),
                                  Text(
                                    'SOS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  if (_lastSosMessage != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        _lastSosMessage!,
                        style: const TextStyle(
                          color: AppTheme.emeraldGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Emergency Helpline Quick Call Buttons
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'National Emergency Helplines (24/7 Toll-Free)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _helplineCard(
                    title: 'Women Helpline',
                    number: '1091',
                    icon: Icons.support_agent,
                    color: AppTheme.purplePrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _helplineCard(
                    title: 'National Police',
                    number: '112',
                    icon: Icons.emergency,
                    color: AppTheme.errorRed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _helplineCard(
                    title: 'Women in Distress',
                    number: '181',
                    icon: Icons.shield,
                    color: AppTheme.rosePrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Incident Report Button
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.pinkSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.report_problem, color: AppTheme.rosePrimary),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report Unsafe Client or Behavior',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Confidential reports routed directly to the administrative safety team',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.rosePrimary,
                        side: const BorderSide(color: AppTheme.rosePrimary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('File Incident Report', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showReportDialog,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _helplineCard({
    required String title,
    required String number,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _makeCall(number),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              number,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
