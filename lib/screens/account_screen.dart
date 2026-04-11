import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../core/config/app_theme.dart';

/// Account Screen - change display name and password
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AuthService _auth = AuthService();
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isUpdatingName = false;
  bool _isUpdatingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _nameController.text =
        _auth.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _updateName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMsg('Name cannot be empty.', isError: true);
      return;
    }
    setState(() => _isUpdatingName = true);
    try {
      await _auth.updateDisplayName(name);
      if (mounted) _showMsg('Display name updated.');
    } catch (e) {
      if (mounted) _showMsg(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingName = false);
    }
  }

  Future<void> _updatePassword() async {
    final current = _currentPasswordController.text.trim();
    final newPwd = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (current.isEmpty || newPwd.isEmpty || confirm.isEmpty) {
      _showMsg('Please fill in all password fields.', isError: true);
      return;
    }
    if (newPwd.length < 6) {
      _showMsg('New password must be at least 6 characters.', isError: true);
      return;
    }
    if (newPwd != confirm) {
      _showMsg('Passwords do not match.', isError: true);
      return;
    }

    setState(() => _isUpdatingPassword = true);
    try {
      // Re-authenticate, then update password
      final email = _auth.currentUser?.email ?? '';
      await _auth.signIn(email: email, password: current);
      await _auth.updatePassword(newPwd);
      if (mounted) {
        _showMsg('Password updated successfully.');
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      if (mounted) _showMsg(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingPassword = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'This will permanently delete your account and all data. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _auth.deleteAccount();
      } catch (e) {
        if (mounted) _showMsg(e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Account Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile info (read-only)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.accentLight,
                    child: Text(
                      (user?.displayName?.isNotEmpty == true
                              ? user!.displayName![0]
                              : user?.email?[0] ?? 'U')
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'No name set',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Change display name
            const SizedBox(height: 24),
            _buildSectionLabel('Display Name'),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Your display name',
                prefixIcon: Icon(Icons.person_outline, size: 18,
                    color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isUpdatingName ? null : _updateName,
                child: _isUpdatingName
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Update Name'),
              ),
            ),

            // Change password
            const SizedBox(height: 28),
            _buildSectionLabel('Change Password'),
            const SizedBox(height: 10),
            TextField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                hintText: 'Current password',
                prefixIcon: const Icon(Icons.lock_outline, size: 18,
                    color: AppTheme.textMuted),
                suffixIcon: _visibilityToggle(
                    _obscureCurrent,
                    () => setState(() => _obscureCurrent = !_obscureCurrent)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                hintText: 'New password (min 6 characters)',
                prefixIcon: const Icon(Icons.lock_outline, size: 18,
                    color: AppTheme.textMuted),
                suffixIcon: _visibilityToggle(
                    _obscureNew,
                    () => setState(() => _obscureNew = !_obscureNew)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                hintText: 'Confirm new password',
                prefixIcon: const Icon(Icons.lock_outline, size: 18,
                    color: AppTheme.textMuted),
                suffixIcon: _visibilityToggle(
                    _obscureConfirm,
                    () => setState(
                        () => _obscureConfirm = !_obscureConfirm)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isUpdatingPassword ? null : _updatePassword,
                child: _isUpdatingPassword
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Update Password'),
              ),
            ),

            // Danger zone
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.error.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Danger Zone',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.error,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Permanently delete your account and all associated data.',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _confirmDeleteAccount,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                    ),
                    child: const Text('Delete Account'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _visibilityToggle(bool obscure, VoidCallback toggle) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 18,
        color: AppTheme.textMuted,
      ),
      onPressed: toggle,
    );
  }
}
