import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';
import '../core/config/api_keys.dart';

/// YouTube Data API v3 Service
class YouTubeService {
  static const int _maxResults = 15;

  Future<List<MediaItem>> fetchVideosByInterests(
    List<String> interests, {
    bool shortsOnly = false,
  }) async {
    if (interests.isEmpty) return [];

    final query = interests.take(3).join(' ');
    return shortsOnly
        ? await _fetchShorts(query)
        : await _fetchVideos(query);
  }

  Future<List<MediaItem>> _fetchVideos(String query) async {
    try {
      final searchUrl = Uri.parse(
        '${ApiKeys.youtubeBaseUrl}/search'
        '?part=snippet'
        '&q=${Uri.encodeComponent(query)}'
        '&type=video'
        '&videoDuration=medium'
        '&maxResults=$_maxResults'
        '&order=relevance'
        '&key=${ApiKeys.youtubeApiKey}',
      );

      final response = await http.get(searchUrl).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return _getFallbackVideos();

      final data = json.decode(response.body);
      final items = data['items'] as List? ?? [];

      if (items.isEmpty) return _getFallbackVideos();

      final videoIds = items
          .map((item) => item['id']['videoId'] as String?)
          .where((id) => id != null)
          .join(',');

      final detailsUrl = Uri.parse(
        '${ApiKeys.youtubeBaseUrl}/videos'
        '?part=contentDetails,statistics,snippet'
        '&id=$videoIds'
        '&key=${ApiKeys.youtubeApiKey}',
      );

      final detailsResponse = await http.get(detailsUrl).timeout(
        const Duration(seconds: 10),
      );

      if (detailsResponse.statusCode != 200) {
        return _parseSearchItems(items, 'video');
      }

      final detailsData = json.decode(detailsResponse.body);
      final videoDetails = detailsData['items'] as List? ?? [];

      return videoDetails.map((video) {
        return MediaItem(
          id: video['id'] ?? '',
          title: video['snippet']['title'] ?? '',
          thumbnail: _getThumbnail(video['snippet']['thumbnails']),
          source: 'youtube',
          description: video['snippet']['description'],
          publishedAt: DateTime.tryParse(
                video['snippet']['publishedAt'] ?? '',
              ) ??
              DateTime.now(),
          url: 'https://www.youtube.com/watch?v=${video['id']}',
          videoType: 'video',
          durationMinutes: _parseDuration(
            video['contentDetails']['duration'] ?? '',
          ),
          likes: int.tryParse(
                video['statistics']?['likeCount']?.toString() ?? '0',
              ) ??
              0,
          channelName: video['snippet']['channelTitle'],
        );
      }).toList();
    } catch (_) {
      return _getFallbackVideos();
    }
  }

  Future<List<MediaItem>> _fetchShorts(String query) async {
    try {
      final url = Uri.parse(
        '${ApiKeys.youtubeBaseUrl}/search'
        '?part=snippet'
        '&q=${Uri.encodeComponent('$query #shorts')}'
        '&type=video'
        '&videoDuration=short'
        '&maxResults=10'
        '&key=${ApiKeys.youtubeApiKey}',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final items = data['items'] as List? ?? [];

      return _parseSearchItems(items, 'short');
    } catch (_) {
      return [];
    }
  }

  List<MediaItem> _parseSearchItems(List items, String type) {
    return items.map((item) {
      final snippet = item['snippet'] ?? {};
      final videoId = item['id']?['videoId'] ?? '';
      return MediaItem(
        id: videoId,
        title: snippet['title'] ?? '',
        thumbnail: _getThumbnail(snippet['thumbnails']),
        source: 'youtube',
        description: snippet['description'],
        publishedAt:
            DateTime.tryParse(snippet['publishedAt'] ?? '') ?? DateTime.now(),
        url: 'https://www.youtube.com/watch?v=$videoId',
        videoType: type,
        durationMinutes: type == 'short' ? 1 : 5,
        channelName: snippet['channelTitle'],
      );
    }).toList();
  }

  String _getThumbnail(dynamic thumbnails) {
    if (thumbnails == null) return '';
    return thumbnails['high']?['url'] ??
        thumbnails['medium']?['url'] ??
        thumbnails['default']?['url'] ??
        '';
  }

  int _parseDuration(String iso8601) {
    // PT4M13S → 4 minutes
    final match = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?')
        .firstMatch(iso8601);
    if (match == null) return 0;
    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    return hours * 60 + minutes + (minutes == 0 ? 1 : 0);
  }

  List<MediaItem> _getFallbackVideos() {
    return [
      MediaItem(
        id: 'fallback_1',
        title: 'Explore trending content on YouTube',
        thumbnail: 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        source: 'youtube',
        publishedAt: DateTime.now(),
        url: 'https://www.youtube.com/trending',
        videoType: 'video',
        durationMinutes: 10,
      ),
    ];
  }
}
