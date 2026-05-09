class UserModel {
  final String uid;
  final String name;
  final String avatarUrl;
  final int gamesWon;

  UserModel({
    required this.uid,
    required this.name,
    required this.avatarUrl,
    this.gamesWon = 0,
  });

  factory UserModel.fromMap(String uid, Map<dynamic, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      gamesWon: map['gamesWon'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'avatarUrl': avatarUrl,
      'gamesWon': gamesWon,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? avatarUrl,
    int? gamesWon,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gamesWon: gamesWon ?? this.gamesWon,
    );
  }
}
