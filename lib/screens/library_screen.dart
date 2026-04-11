import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/media_item.dart';
import '../core/config/app_theme.dart';
import '../widgets/skeleton_loader.dart';

/// Library Screen - displays saved/bookmarked items
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final db = FirestoreService();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Saved'),
        titleSpacing: 20,
      ),
      body: user == null
          ? const Center(
              child: Text('Sign in to see saved items.',
                  style: TextStyle(color: AppTheme.textSecondary)))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: db.watchSavedItems(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: List.generate(4, (_) => const SkeletonCard()),
                    ),
                  );
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.accentLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.bookmark_border,
                              color: AppTheme.accent, size: 30),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nothing saved yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap the bookmark icon on any card\nto save it here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final map = items[index];
                    final item = MediaItem.fromMap(map);
                    return _SavedItemCard(
                      item: item,
                      onRemove: () => db.unsaveItem(user.uid, item.id),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _SavedItemCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onRemove;

  const _SavedItemCard({required this.item, required this.onRemove});

  Color get _sourceColor {
    switch (item.source.toLowerCase()) {
      case 'youtube': return AppTheme.youtubeColor;
      case 'reddit': return AppTheme.redditColor;
      default: return AppTheme.newsColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(item.url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 80,
                height: 60,
                child: item.thumbnail.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnail,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: AppTheme.border),
                        errorWidget: (_, __, ___) =>
                            Container(color: AppTheme.border),
                      )
                    : Container(color: AppTheme.border),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _sourceColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.source.toUpperCase(),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _sourceColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.bookmark,
                  color: AppTheme.accent, size: 20),
              onPressed: onRemove,
              tooltip: 'Remove from saved',
            ),
          ],
        ),
      ),
    );
  }
}
