import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final String name;
  final String avatarUrl;
  final int gamesWon;

  const UserModel({
    required this.uid,
    required this.name,
    required this.avatarUrl,
    this.gamesWon = 0,
  });

  /// Factory robusta per gestire i tipi in modo più sicuro
  factory UserModel.fromMap(String uid, Map<dynamic, dynamic> map) {
    return UserModel(
      uid: uid,
      // Usiamo .toString() per assicurarci che sia sempre una Stringa
      name: map['name']?.toString() ?? '',
      avatarUrl: map['avatarUrl']?.toString() ?? '',
      // Parsing sicuro: se per errore è una stringa nel DB, la convertiamo
      gamesWon: _parseInt(map['gamesWon']),
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

  /// Metodo helper privato per gestire il parsing sicuro degli interi
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// L'override di Equatable per ottimizzare rebuild della UI
  @override
  List<Object?> get props => [uid, name, avatarUrl, gamesWon];
}
