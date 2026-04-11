import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/youtube_service.dart';
import '../services/reddit_service.dart';
import '../services/news_service.dart';
import '../services/firestore_service.dart';
import '../models/media_item.dart';
import '../models/user_preferences.dart';
import '../widgets/media_card.dart';
import '../widgets/skeleton_loader.dart';
import '../core/config/app_theme.dart';
import 'timed_session_screen.dart';
import 'interests_screen.dart';
import 'settings_screen.dart';
import 'library_screen.dart';
import 'account_screen.dart';

class HomeScreen extends StatefulWidget {
  final int sessionMinutes;
  final bool showTimePicker;

  const HomeScreen({
    super.key,
    this.sessionMinutes = 30,
    this.showTimePicker = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final YouTubeService _youtubeService = YouTubeService();
  final RedditService _redditService = RedditService();
  final NewsService _newsService = NewsService();
  final FirestoreService _firestoreService = FirestoreService();

  int _selectedIndex = 0;
  bool _showTimePicker = false;

  List<MediaItem> _youtubeContent = [];
  List<MediaItem> _redditContent = [];
  List<MediaItem> _newsContent = [];
  bool _isLoading = false;
  String? _error;

  // Timer
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _sessionEnded = false;

  @override
  void initState() {
    super.initState();
    _showTimePicker = widget.showTimePicker;
    if (!_showTimePicker) {
      _initTimer(widget.sessionMinutes);
    }
    _loadContent();
  }

  void _initTimer(int minutes) {
    _secondsRemaining = minutes * 60;
    _timer?.cancel();
    if (_secondsRemaining > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timer?.cancel();
            _sessionEnded = true;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final user = _authService.currentUser;
      UserPreferences? prefs;

      if (user != null) {
        prefs = await _firestoreService.getUserPreferences(user.uid);
      }

      final interests = prefs?.interests ?? ['Technology', 'Entertainment'];
      final subreddits = prefs?.favoriteSubreddits ??
          ['technology', 'entertainment', 'popular'];

      final showYoutube = prefs?.linkedAccounts['youtube'] ?? true;
      final showReddit = prefs?.linkedAccounts['reddit'] ?? true;
      final showNews = prefs?.linkedAccounts['google'] ?? true;

      final results = await Future.wait([
        showYoutube
            ? _youtubeService.fetchVideosByInterests(interests)
            : Future.value(<MediaItem>[]),
        showReddit
            ? _redditService.fetchPostsBySubreddits(subreddits)
            : Future.value(<MediaItem>[]),
        showNews
            ? _newsService.fetchNewsByInterests(interests)
            : Future.value(<MediaItem>[]),
      ]);

      if (mounted) {
        setState(() {
          _youtubeContent = results[0];
          _redditContent = results[1];
          _newsContent = results[2];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isLoading = false; });
      }
    }
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showTimerEditDialog() {
    int tempMinutes = _secondsRemaining ~/ 60;
    final controller = TextEditingController(text: tempMinutes.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Session Timer',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(_secondsRemaining),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: AppTheme.accent,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Set new duration (minutes):',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  hintText: 'e.g. 30', suffixText: 'min'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final mins = int.tryParse(controller.text) ?? 30;
              _initTimer(mins);
              setState(() => _sessionEnded = false);
              Navigator.pop(ctx);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show session ended banner if needed
    if (_sessionEnded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Your session time is up. Time for a break!'),
              backgroundColor: AppTheme.warning,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Extend',
                textColor: Colors.white,
                onPressed: _showTimerEditDialog,
              ),
            ),
          );
          setState(() => _sessionEnded = false);
        }
      });
    }

    // Show time picker overlay
    if (_showTimePicker && _selectedIndex == 0) {
      return Scaffold(
        body: TimedSessionScreen(
          onSkip: () => setState(() {
            _showTimePicker = false;
            _initTimer(30);
          }),
          onStart: (minutes) => setState(() {
            _showTimePicker = false;
            _initTimer(minutes);
          }),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildFeedTab(),
          _buildLibraryTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedItemColor: AppTheme.accent,
          unselectedItemColor: AppTheme.textMuted,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Feed'),
            BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), activeIcon: Icon(Icons.bookmark), label: 'Saved'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  // ─── Feed Tab ─────────────────────────────────────────

  Widget _buildFeedTab() {
    return RefreshIndicator(
      onRefresh: _loadContent,
      color: AppTheme.accent,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppTheme.surface,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            shadowColor: Colors.black12,
            titleSpacing: 20,
            title: const Text('Vibee',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                )),
            actions: [
              // Timer
              GestureDetector(
                onTap: _showTimerEditDialog,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _secondsRemaining > 0
                        ? AppTheme.accentLight
                        : AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: _secondsRemaining > 0
                            ? AppTheme.accent
                            : AppTheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(_secondsRemaining),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _secondsRemaining > 0
                              ? AppTheme.accent
                              : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune_outlined,
                    color: AppTheme.textSecondary, size: 22),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InterestsScreen(isEditing: true),
                  ),
                ).then((_) => _loadContent()),
                tooltip: 'Edit interests',
              ),
            ],
          ),
          SliverToBoxAdapter(child: _buildFeedBody()),
        ],
      ),
    );
  }

  Widget _buildFeedBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              const Icon(Icons.signal_wifi_off_outlined,
                  size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              const Text('Could not load content',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              const Text('Pull down to refresh',
                  style:
                      TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadContent,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            title: 'Videos',
            icon: Icons.play_circle_outline,
            iconColor: AppTheme.youtubeColor,
            items: _youtubeContent,
          ),
          _buildSection(
            title: 'News',
            icon: Icons.article_outlined,
            iconColor: AppTheme.newsColor,
            items: _newsContent,
          ),
          _buildSection(
            title: 'Posts',
            icon: Icons.forum_outlined,
            iconColor: AppTheme.redditColor,
            items: _redditContent,
          ),
          if (!_isLoading &&
              _youtubeContent.isEmpty &&
              _newsContent.isEmpty &&
              _redditContent.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.content_paste_off_outlined,
                        size: 48, color: AppTheme.textMuted),
                    const SizedBox(height: 12),
                    const Text('No content yet',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    const Text('Try editing your interests',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const InterestsScreen(isEditing: true),
                        ),
                      ).then((_) => _loadContent()),
                      child: const Text('Edit Interests'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<MediaItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (_isLoading)
          ...List.generate(3, (_) => const SkeletonCard())
        else if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.link_off_outlined,
                    size: 16, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Text(
                  'No $title available. Pull down to refresh.',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          )
        else
          ...items.map((item) => MediaCard(item: item)),
      ],
    );
  }

  // ─── Library / Saved Tab ──────────────────────────────

  Widget _buildLibraryTab() {
    return const LibraryScreen();
  }

  // ─── Profile Tab ──────────────────────────────────────

  Widget _buildProfileTab() {
    final user = _authService.currentUser;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          shadowColor: Colors.black12,
          titleSpacing: 20,
          floating: true,
          snap: true,
          title: Text('Profile',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.accentLight,
                        child: Text(
                          (user?.displayName?.isNotEmpty == true
                                  ? user!.displayName![0]
                                  : user?.email?[0] ?? 'U')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? 'Vibee User',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats
                const SizedBox(height: 20),
                StreamBuilder<UserProfile?>(
                  stream: user != null
                      ? _firestoreService.watchUserProfile(user.uid)
                      : Stream.value(null),
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    return Row(
                      children: [
                        _buildStatCard('Content Viewed',
                            '${profile?.totalContentViewed ?? 0}'),
                        const SizedBox(width: 12),
                        _buildStatCard('Minutes Watched',
                            '${profile?.totalMinutesWatched ?? 0}'),
                      ],
                    );
                  },
                ),

                // Menu items
                const SizedBox(height: 24),
                _buildMenuSection('Content', [
                  _buildMenuItem(
                    icon: Icons.bookmark_border,
                    label: 'Saved Items',
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                  _buildMenuItem(
                    icon: Icons.interests_outlined,
                    label: 'My Interests',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const InterestsScreen(isEditing: true),
                      ),
                    ).then((_) => _loadContent()),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildMenuSection('Account', [
                  _buildMenuItem(
                    icon: Icons.person_outline,
                    label: 'Account Settings',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AccountScreen()),
                    ),
                  ),
                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    label: 'App Settings',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  _buildMenuItem(
                    icon: Icons.timer_outlined,
                    label: 'Edit Session Timer',
                    onTap: _showTimerEditDialog,
                  ),
                ]),
                const SizedBox(height: 16),
                _buildMenuSection('', [
                  _buildMenuItem(
                    icon: Icons.logout,
                    label: 'Sign Out',
                    color: AppTheme.error,
                    onTap: () async {
                      await _authService.signOut();
                    },
                  ),
                ]),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.accent,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ...items.map((w) => Column(children: [
                w,
                if (w != items.last)
                  const Divider(height: 1, indent: 52),
              ])),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppTheme.textPrimary,
  }) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: (color == AppTheme.textPrimary
                  ? AppTheme.accent
                  : color)
              .withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: color == AppTheme.textPrimary ? AppTheme.accent : color,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      trailing: const Icon(Icons.chevron_right,
          size: 18, color: AppTheme.textMuted),
      dense: true,
      onTap: onTap,
    );
  }
}
