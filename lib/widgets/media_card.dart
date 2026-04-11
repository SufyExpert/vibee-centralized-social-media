import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/media_item.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../core/config/app_theme.dart';

/// Reusable media card for YouTube, Reddit, and News items
class MediaCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback? onSaveToggle;

  const MediaCard({
    super.key,
    required this.item,
    this.onSaveToggle,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  bool _isSaved = false;
  bool _isCheckingSave = true;

  @override
  void initState() {
    super.initState();
    _checkSaveStatus();
  }

  Future<void> _checkSaveStatus() async {
    final user = _authService.currentUser;
    if (user == null) {
      setState(() => _isCheckingSave = false);
      return;
    }
    final saved = await _firestoreService.isItemSaved(user.uid, widget.item.id);
    if (mounted) setState(() { _isSaved = saved; _isCheckingSave = false; });
  }

  Future<void> _toggleSave() async {
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isSaved = !_isSaved);
    try {
      if (_isSaved) {
        await _firestoreService.saveItem(user.uid, widget.item.toMap());
      } else {
        await _firestoreService.unsaveItem(user.uid, widget.item.id);
      }
      widget.onSaveToggle?.call();
    } catch (_) {
      // Revert on error
      if (mounted) setState(() => _isSaved = !_isSaved);
    }
  }

  Future<void> _openItem() async {
    final uri = Uri.tryParse(widget.item.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Track view
      final user = _authService.currentUser;
      if (user != null) {
        await _firestoreService.incrementContentViewed(user.uid);
      }
    }
  }

  Color get _sourceColor {
    switch (widget.item.source.toLowerCase()) {
      case 'youtube':
        return AppTheme.youtubeColor;
      case 'reddit':
        return AppTheme.redditColor;
      case 'news':
        return AppTheme.newsColor;
      default:
        return AppTheme.accent;
    }
  }

  IconData get _sourceIcon {
    switch (widget.item.source.toLowerCase()) {
      case 'youtube':
        return Icons.play_circle_fill;
      case 'reddit':
        return Icons.forum;
      case 'news':
        return Icons.article;
      default:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openItem,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 110,
                height: 80,
                child: widget.item.thumbnail.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.item.thumbnail,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppTheme.border),
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.border,
                          child: Icon(_sourceIcon, color: _sourceColor, size: 28),
                        ),
                      )
                    : Container(
                        color: AppTheme.border,
                        child: Icon(_sourceIcon, color: _sourceColor, size: 28),
                      ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Source badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _sourceColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_sourceIcon, size: 10, color: _sourceColor),
                              const SizedBox(width: 3),
                              Text(
                                widget.item.sourceLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _sourceColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (widget.item.timeEstimate.isNotEmpty)
                          Text(
                            widget.item.timeEstimate,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Title
                    Text(
                      widget.item.title,
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
            ),

            // Save button
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: GestureDetector(
                onTap: _isCheckingSave ? null : _toggleSave,
                child: Icon(
                  _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  size: 20,
                  color: _isSaved ? AppTheme.accent : AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
