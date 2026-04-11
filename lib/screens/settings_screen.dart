import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../core/config/app_theme.dart';
import 'interests_screen.dart';
import 'account_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();
  final FirestoreService _db = FirestoreService();

  // Content source toggles
  Map<String, bool> _sources = {
    'youtube': true,
    'reddit': true,
    'google': true,
  };
  bool _loadingSources = true;

  @override
  void initState() {
    super.initState();
    _loadSourceSettings();
  }

  Future<void> _loadSourceSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final prefs = await _db.getUserPreferences(user.uid);
    if (prefs != null && mounted) {
      setState(() {
        _sources = Map<String, bool>.from(prefs.linkedAccounts);
        _loadingSources = false;
      });
    } else {
      setState(() => _loadingSources = false);
    }
  }

  Future<void> _toggleSource(String key, bool value) async {
    setState(() => _sources[key] = value);
    final user = _auth.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('user_preferences')
        .doc(user.uid)
        .set({'linkedAccounts': _sources}, SetOptions(merge: true));
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('About Vibee',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.0.0',
                style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
            Text(
              'Vibee brings YouTube, Reddit, and News together in one clean feed — personalized to your interests.',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Content Sources
          _buildLabel('Content Sources'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: _loadingSources
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()))
                : Column(
                    children: [
                      _buildToggle(
                        icon: Icons.play_circle_outline,
                        iconColor: AppTheme.youtubeColor,
                        label: 'YouTube Videos',
                        subtitle: 'Show YouTube content in feed',
                        value: _sources['youtube'] ?? true,
                        onChanged: (v) => _toggleSource('youtube', v),
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildToggle(
                        icon: Icons.forum_outlined,
                        iconColor: AppTheme.redditColor,
                        label: 'Reddit Posts',
                        subtitle: 'Show Reddit community posts',
                        value: _sources['reddit'] ?? true,
                        onChanged: (v) => _toggleSource('reddit', v),
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildToggle(
                        icon: Icons.article_outlined,
                        iconColor: AppTheme.newsColor,
                        label: 'News Articles',
                        subtitle: 'Show news from NewsAPI',
                        value: _sources['google'] ?? true,
                        onChanged: (v) => _toggleSource('google', v),
                      ),
                    ],
                  ),
          ),

          // Preferences
          const SizedBox(height: 24),
          _buildLabel('Preferences'),
          const SizedBox(height: 8),
          _buildMenuGroup([
            _buildMenuTile(
              icon: Icons.interests_outlined,
              iconColor: AppTheme.accent,
              label: 'Edit Interests',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const InterestsScreen(isEditing: true)),
              ),
            ),
          ]),

          // Account
          const SizedBox(height: 24),
          _buildLabel('Account'),
          const SizedBox(height: 8),
          _buildMenuGroup([
            _buildMenuTile(
              icon: Icons.person_outline,
              iconColor: AppTheme.accent,
              label: 'Account Settings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              ),
            ),
          ]),

          // General
          const SizedBox(height: 24),
          _buildLabel('General'),
          const SizedBox(height: 8),
          _buildMenuGroup([
            _buildMenuTile(
              icon: Icons.info_outline,
              iconColor: AppTheme.accent,
              label: 'About Vibee',
              onTap: () => _showAbout(context),
            ),
          ]),

          // Sign out
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () async => await _auth.signOut(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildMenuGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.accent,
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing:
          const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
      onTap: onTap,
    );
  }
}
