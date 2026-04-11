/// Base class for all media items (YouTube, Reddit, News)
class MediaItem {
  final String id;
  final String title;
  final String thumbnail;
  final String source; // 'youtube', 'reddit', 'news'
  final String? description;
  final DateTime publishedAt;
  final String url;
  final String videoType; // 'short', 'video', 'post', 'article'
  final int? durationMinutes;
  final bool isSaved;
  final int likes;
  final List<String> tags;
  final String? channelName;
  final String? subreddit;

  MediaItem({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.source,
    this.description,
    required this.publishedAt,
    required this.url,
    this.videoType = 'video',
    this.durationMinutes,
    this.isSaved = false,
    this.likes = 0,
    this.tags = const [],
    this.channelName,
    this.subreddit,
  });

  String get sourceLabel {
    switch (source.toLowerCase()) {
      case 'youtube':
        return channelName ?? 'YouTube';
      case 'reddit':
        return subreddit != null ? 'r/$subreddit' : 'Reddit';
      case 'news':
        return 'News';
      default:
        return source;
    }
  }

  String get timeEstimate {
    if (durationMinutes == null) return '';
    if (durationMinutes! < 1) return '< 1 min';
    if (source.toLowerCase() == 'youtube' ||
        videoType == 'video' ||
        videoType == 'short') {
      return '${durationMinutes}m watch';
    }
    return '${durationMinutes}m read';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'thumbnail': thumbnail,
      'source': source,
      'description': description,
      'publishedAt': publishedAt.toIso8601String(),
      'url': url,
      'videoType': videoType,
      'durationMinutes': durationMinutes,
      'isSaved': isSaved,
      'likes': likes,
      'tags': tags,
      'channelName': channelName,
      'subreddit': subreddit,
    };
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      thumbnail: map['thumbnail'] ?? '',
      source: map['source'] ?? '',
      description: map['description'],
      publishedAt: DateTime.tryParse(map['publishedAt'] ?? '') ?? DateTime.now(),
      url: map['url'] ?? '',
      videoType: map['videoType'] ?? 'video',
      durationMinutes: map['durationMinutes'],
      isSaved: map['isSaved'] ?? false,
      likes: map['likes'] ?? 0,
      tags: List<String>.from(map['tags'] ?? []),
      channelName: map['channelName'],
      subreddit: map['subreddit'],
    );
  }

  MediaItem copyWith({
    bool? isSaved,
    int? likes,
  }) {
    return MediaItem(
      id: id,
      title: title,
      thumbnail: thumbnail,
      source: source,
      description: description,
      publishedAt: publishedAt,
      url: url,
      videoType: videoType,
      durationMinutes: durationMinutes,
      isSaved: isSaved ?? this.isSaved,
      likes: likes ?? this.likes,
      tags: tags,
      channelName: channelName,
      subreddit: subreddit,
    );
  }
}
