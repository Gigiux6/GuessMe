class Player {
  final String id;
  final String name;
  final bool isSaved;
  final int? savedAt;
  final String? identityName;
  final String? identityImageUrl;
  final String? avatarUrl;
  final int remainingChanges;
  final int score;
  final bool isOnline;

  Player({
    required this.id,
    required this.name,
    this.isSaved = false,
    this.savedAt,
    this.identityName,
    this.identityImageUrl,
    this.avatarUrl,
    this.remainingChanges = 0,
    this.score = 0,
    this.isOnline = true,
  });

  factory Player.fromMap(String id, Map<String, dynamic> map) {
    final savedAtVal = map['savedAt'];
    int? savedAtMs;
    if (savedAtVal != null) {
      if (savedAtVal is int) {
        savedAtMs = savedAtVal;
      } else {
        try {
          savedAtMs = (savedAtVal as dynamic).millisecondsSinceEpoch;
        } catch (_) {}
      }
    }

    return Player(
      id: id,
      name: map['name'] ?? '',
      isSaved: map['isSaved'] ?? false,
      savedAt: savedAtMs,
      identityName: map['identityName'],
      identityImageUrl: map['identityImageUrl'],
      avatarUrl: map['avatarUrl'],
      remainingChanges: map['remainingChanges'] ?? 0,
      score: map['score'] ?? 0,
      isOnline: map['isOnline'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isSaved': isSaved,
      'savedAt': savedAt?.toDouble(), // FIXED: Cast to double for web int64 pigeon crash
      'identityName': identityName,
      'identityImageUrl': identityImageUrl,
      'avatarUrl': avatarUrl,
      'remainingChanges': remainingChanges.toDouble(), // FIXED
      'score': score.toDouble(), // FIXED
      'isOnline': isOnline,
    };
  }

  Player copyWith({
    String? id,
    String? name,
    bool? isSaved,
    int? savedAt,
    String? identityName,
    String? identityImageUrl,
    String? avatarUrl,
    int? remainingChanges,
    int? score,
    bool? isOnline,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      isSaved: isSaved ?? this.isSaved,
      savedAt: savedAt ?? this.savedAt,
      identityName: identityName ?? this.identityName,
      identityImageUrl: identityImageUrl ?? this.identityImageUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      remainingChanges: remainingChanges ?? this.remainingChanges,
      score: score ?? this.score,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
