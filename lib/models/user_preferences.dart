/// User Preferences Model
class UserPreferences {
  final String userId;
  final List<String> interests;
  final Map<String, bool> linkedAccounts;
  final List<String> favoriteSubreddits;
  final DateTime updatedAt;

  UserPreferences({
    required this.userId,
    required this.interests,
    this.linkedAccounts = const {
      'youtube': true,
      'reddit': true,
      'google': true,
    },
    this.favoriteSubreddits = const [],
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'interests': interests,
      'linkedAccounts': linkedAccounts,
      'favoriteSubreddits': favoriteSubreddits,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    // Handle both old 'contentSources' key and new 'linkedAccounts' key
    Map<String, bool> accounts;
    if (map.containsKey('linkedAccounts')) {
      accounts = Map<String, bool>.from(map['linkedAccounts']);
    } else if (map.containsKey('contentSources')) {
      accounts = Map<String, bool>.from(map['contentSources']);
    } else {
      accounts = {'youtube': true, 'reddit': true, 'google': true};
    }

    return UserPreferences(
      userId: map['userId'] ?? '',
      interests: List<String>.from(map['interests'] ?? []),
      linkedAccounts: accounts,
      favoriteSubreddits: List<String>.from(map['favoriteSubreddits'] ?? []),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  UserPreferences copyWith({
    List<String>? interests,
    Map<String, bool>? linkedAccounts,
    List<String>? favoriteSubreddits,
  }) {
    return UserPreferences(
      userId: userId,
      interests: interests ?? this.interests,
      linkedAccounts: linkedAccounts ?? this.linkedAccounts,
      favoriteSubreddits: favoriteSubreddits ?? this.favoriteSubreddits,
      updatedAt: DateTime.now(),
    );
  }

  // Available interest categories
  static const List<String> availableInterests = [
    'Technology',
    'Entertainment',
    'Gaming',
    'Music',
    'Sports',
    'News',
    'Education',
    'Science',
    'Health & Fitness',
    'Cooking',
    'Travel',
    'Art & Design',
    'Finance',
    'Programming',
    'Nature',
    'History',
  ];

  // Subreddits mapped to interests
  static const Map<String, List<String>> interestToSubreddits = {
    'Technology': ['technology', 'gadgets', 'programming'],
    'Entertainment': ['movies', 'television', 'entertainment'],
    'Gaming': ['gaming', 'pcgaming', 'ps5'],
    'Music': ['music', 'listentothis', 'hiphopheads'],
    'Sports': ['sports', 'nba', 'soccer'],
    'News': ['news', 'worldnews', 'UpliftingNews'],
    'Education': ['learnprogramming', 'educationalgifs', 'todayilearned'],
    'Science': ['science', 'space', 'biology'],
    'Health & Fitness': ['fitness', 'nutrition', 'bodyweightfitness'],
    'Cooking': ['cooking', 'recipes', 'foodporn'],
    'Travel': ['travel', 'earthporn', 'solotravel'],
    'Art & Design': ['art', 'design', 'streetart'],
    'Finance': ['personalfinance', 'investing', 'financialindependence'],
    'Programming': ['learnprogramming', 'webdev', 'reactjs'],
    'Nature': ['nature', 'EarthPorn', 'NatureIsFuckingLit'],
    'History': ['history', 'AskHistorians', 'HistoryMemes'],
  };
}
