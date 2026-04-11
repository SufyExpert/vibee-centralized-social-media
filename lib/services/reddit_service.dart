import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';
import '../core/config/api_keys.dart';

/// Reddit Public API Service (no auth required)
class RedditService {
  Future<List<MediaItem>> fetchPostsBySubreddits(
    List<String> subreddits,
  ) async {
    if (subreddits.isEmpty) return [];

    final results = <MediaItem>[];

    // Fetch from up to 3 subreddits
    for (final subreddit in subreddits.take(3)) {
      try {
        final posts = await _fetchSubreddit(subreddit);
        results.addAll(posts);
      } catch (_) {
        // Skip failed subreddit
      }
    }

    results.shuffle();
    return results.take(20).toList();
  }

  Future<List<MediaItem>> _fetchSubreddit(String subreddit) async {
    final url = Uri.parse(
      '${ApiKeys.redditBaseUrl}/r/$subreddit/hot.json?limit=8&raw_json=1',
    );

    final response = await http.get(
      url,
      headers: {'User-Agent': 'Vibee/1.0'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final data = json.decode(response.body);
    final posts = data['data']?['children'] as List? ?? [];

    return posts
        .where((p) {
          final post = p['data'] ?? {};
          return !(post['stickied'] ?? false) &&
              !(post['is_video'] ?? false);
        })
        .map((p) {
          final post = p['data'] ?? {};
          final thumbnail = _getThumbnail(post);
          return MediaItem(
            id: post['id'] ?? '',
            title: post['title'] ?? '',
            thumbnail: thumbnail,
            source: 'reddit',
            description: post['selftext']?.toString().isNotEmpty == true
                ? post['selftext']
                : null,
            publishedAt: DateTime.fromMillisecondsSinceEpoch(
              ((post['created_utc'] ?? 0) * 1000).toInt(),
            ),
            url: 'https://www.reddit.com${post['permalink'] ?? ''}',
            videoType: 'post',
            durationMinutes: 3,
            likes: (post['score'] ?? 0) as int,
            subreddit: subreddit,
          );
        })
        .toList();
  }

  String _getThumbnail(Map post) {
    // Try preview images first
    try {
      final preview = post['preview'];
      if (preview != null) {
        final images = preview['images'] as List?;
        if (images != null && images.isNotEmpty) {
          final source = images[0]['source'];
          if (source != null && source['url'] != null) {
            return (source['url'] as String).replaceAll('&amp;', '&');
          }
        }
      }
    } catch (_) {}

    // Fall back to thumbnail
    final thumb = post['thumbnail']?.toString() ?? '';
    if (thumb.startsWith('http')) return thumb;

    return 'https://www.redditstatic.com/icon.png';
  }
}
