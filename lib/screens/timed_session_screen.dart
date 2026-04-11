import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../core/config/app_theme.dart';

/// Session time picker screen shown before browsing
class TimedSessionScreen extends StatefulWidget {
  final VoidCallback? onSkip;
  final Function(int)? onStart;

  const TimedSessionScreen({super.key, this.onSkip, this.onStart});

  @override
  State<TimedSessionScreen> createState() => _TimedSessionScreenState();
}

class _TimedSessionScreenState extends State<TimedSessionScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  int _selectedHours = 0;
  int _selectedMinutes = 30;
  bool _dontAskAgain = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _hourController =
        FixedExtentScrollController(initialItem: _selectedHours);
    _minuteController =
        FixedExtentScrollController(initialItem: _selectedMinutes ~/ 5);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      final totalMinutes = (_selectedHours * 60) + _selectedMinutes;

      if (user != null && _dontAskAgain) {
        await _firestoreService.updateSkipSessionSelection(user.uid, true);
      }

      widget.onStart?.call(totalMinutes < 1 ? 30 : totalMinutes);
    } catch (_) {
      widget.onStart?.call(30);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final firstName = user?.displayName?.split(' ').first ?? 'there';

    return Container(
      color: AppTheme.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Skip
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onSkip,
                  child: const Text('Skip',
                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                ),
              ),
              const SizedBox(height: 24),

              // Greeting
              Text(
                'Hello, $firstName.',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'How long would you like to browse today?',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 48),

              // Time picker
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPicker(
                        controller: _hourController,
                        count: 24,
                        label: 'hr',
                        onChanged: (i) =>
                            setState(() => _selectedHours = i),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          ':',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary.withOpacity(0.4),
                          ),
                        ),
                      ),
                      _buildPicker(
                        controller: _minuteController,
                        count: 12,
                        label: 'min',
                        onChanged: (i) =>
                            setState(() => _selectedMinutes = i * 5),
                        format: (i) =>
                            (i * 5).toString().padLeft(2, '0'),
                      ),
                    ],
                  ),
                ),
              ),

              // Selected time summary
              const SizedBox(height: 24),
              Center(
                child: Text(
                  _buildSummary(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const Spacer(),

              // Don't ask again
              GestureDetector(
                onTap: () =>
                    setState(() => _dontAskAgain = !_dontAskAgain),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _dontAskAgain,
                        onChanged: (v) =>
                            setState(() => _dontAskAgain = v ?? false),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        side: const BorderSide(color: AppTheme.border),
                        activeColor: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Don't show this again",
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Start button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startSession,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text("Let's Begin"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPicker({
    required FixedExtentScrollController controller,
    required int count,
    required String label,
    required Function(int) onChanged,
    String Function(int)? format,
  }) {
    return Column(
      children: [
        SizedBox(
          width: 72,
          height: 160,
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: 52,
            onSelectedItemChanged: onChanged,
            selectionOverlay: Container(
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            children: List.generate(
              count,
              (i) => Center(
                child: Text(
                  format != null ? format(i) : i.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _buildSummary() {
    final total = (_selectedHours * 60) + _selectedMinutes;
    if (total == 0) return 'Select a duration above';
    if (_selectedHours == 0) return '$_selectedMinutes minutes';
    if (_selectedMinutes == 0) {
      return '$_selectedHours hour${_selectedHours > 1 ? 's' : ''}';
    }
    return '$_selectedHours hr $_selectedMinutes min';
  }
}
