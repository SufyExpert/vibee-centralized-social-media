import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';
import '../core/config/api_keys.dart';

/// NewsAPI Service
class NewsService {
  Future<List<MediaItem>> fetchNewsByInterests(
    List<String> interests,
  ) async {
    if (interests.isEmpty) return [];

    try {
      final query = interests.take(3).join(' OR ');
      final url = Uri.parse(
        '${ApiKeys.newsBaseUrl}/everything'
        '?q=${Uri.encodeComponent(query)}'
        '&language=en'
        '&sortBy=publishedAt'
        '&pageSize=15'
        '&apiKey=${ApiKeys.newsApiKey}',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return _getFallbackNews();

      final data = json.decode(response.body);
      final articles = data['articles'] as List? ?? [];

      return articles
          .where((a) =>
              a['title'] != null &&
              a['title'] != '[Removed]' &&
              a['url'] != null)
          .map((article) {
        return MediaItem(
          id: article['url'] ?? DateTime.now().toString(),
          title: article['title'] ?? '',
          thumbnail: article['urlToImage'] ??
              'https://placehold.co/400x200/0EA5E9/white?text=News',
          source: 'news',
          description: article['description'],
          publishedAt:
              DateTime.tryParse(article['publishedAt'] ?? '') ?? DateTime.now(),
          url: article['url'] ?? '',
          videoType: 'article',
          durationMinutes: 4,
          channelName: article['source']?['name'],
        );
      }).toList();
    } catch (_) {
      return _getFallbackNews();
    }
  }

  Future<List<MediaItem>> fetchTopHeadlines() async {
    try {
      final url = Uri.parse(
        '${ApiKeys.newsBaseUrl}/top-headlines'
        '?language=en'
        '&pageSize=10'
        '&apiKey=${ApiKeys.newsApiKey}',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final articles = data['articles'] as List? ?? [];

      return articles
          .where((a) =>
              a['title'] != null && a['title'] != '[Removed]')
          .map((article) {
        return MediaItem(
          id: article['url'] ?? DateTime.now().toString(),
          title: article['title'] ?? '',
          thumbnail: article['urlToImage'] ??
              'https://placehold.co/400x200/0EA5E9/white?text=News',
          source: 'news',
          description: article['description'],
          publishedAt:
              DateTime.tryParse(article['publishedAt'] ?? '') ?? DateTime.now(),
          url: article['url'] ?? '',
          videoType: 'article',
          durationMinutes: 4,
          channelName: article['source']?['name'],
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  List<MediaItem> _getFallbackNews() {
    return [];
  }
}
