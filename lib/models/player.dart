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
  });

  factory Player.fromMap(String id, Map<dynamic, dynamic> map) {
    return Player(
      id: id,
      name: map['name'] ?? '',
      isSaved: map['isSaved'] ?? false,
      savedAt: map['savedAt'],
      identityName: map['identityName'],
      identityImageUrl: map['identityImageUrl'],
      avatarUrl: map['avatarUrl'],
      remainingChanges: map['remainingChanges'] ?? 0,
      score: map['score'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isSaved': isSaved,
      'savedAt': savedAt,
      'identityName': identityName,
      'identityImageUrl': identityImageUrl,
      'avatarUrl': avatarUrl,
      'remainingChanges': remainingChanges,
      'score': score,
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
    );
  }
}
