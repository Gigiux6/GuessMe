import 'player.dart';

enum RoomStatus { lobby, setup, playing, finished }

enum GameMode { preset, timed, custom }

class Room {
  final String id;
  final String hostId;
  final RoomStatus status;
  final GameMode mode;
  final int turnIndex;
  final List<String> turnOrder;
  final Map<String, Player> players;
  final String presetPack;
  final String? lastSystemMessage;
  final int characterChangesLimit;
  final int timeLimit;
  final int targetPoints;
  final int currentRound;
  final bool isOvertime;
  final int? timerEndTime;
  final String? timerType; // 'countdown' or 'active'

  Room({
    required this.id,
    required this.hostId,
    required this.status,
    required this.mode,
    required this.turnIndex,
    required this.turnOrder,
    required this.players,
    this.presetPack = 'cinema',
    this.lastSystemMessage,
    this.characterChangesLimit = 0,
    this.timeLimit = 60,
    this.targetPoints = 3,
    this.currentRound = 1,
    this.isOvertime = false,
    this.timerEndTime,
    this.timerType,
  });

  factory Room.fromMap(String id, Map<String, dynamic> map) {
    final statusStr = map['status'] ?? 'lobby';
    final modeStr = map['mode'] ?? 'preset';
    
    final playersMap = map['players'] as Map<dynamic, dynamic>? ?? {};
    
    return Room(
      id: id,
      hostId: map['hostId'] ?? '',
      status: RoomStatus.values.firstWhere((e) => e.name == statusStr, orElse: () => RoomStatus.lobby),
      mode: GameMode.values.firstWhere((e) => e.name == modeStr, orElse: () => GameMode.preset),
      turnIndex: map['turnIndex'] ?? 0,
      turnOrder: List<String>.from(map['turnOrder'] ?? []),
      players: {
        for (final entry in playersMap.entries)
          if (entry.value != null)
            entry.key.toString(): Player.fromMap(entry.key.toString(), Map<String, dynamic>.from(entry.value as Map))
      },
      presetPack: map['presetPack'] ?? 'cinema',
      lastSystemMessage: map['lastSystemMessage'],
      characterChangesLimit: map['characterChangesLimit'] ?? 0,
      timeLimit: map['timeLimit'] ?? 60,
      targetPoints: map['targetPoints'] ?? 3,
      currentRound: map['currentRound'] ?? 1,
      isOvertime: map['isOvertime'] ?? false,
      timerEndTime: map['timerEndTime'],
      timerType: map['timerType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'status': status.name,
      'mode': mode.name,
      'turnIndex': turnIndex.toDouble(), // FIXED: Cast to double for web int64 pigeon crash
      'turnOrder': turnOrder,
      'players': players.map((key, value) => MapEntry(key, value.toMap())),
      'presetPack': presetPack,
      'lastSystemMessage': lastSystemMessage,
      'characterChangesLimit': characterChangesLimit.toDouble(), // FIXED
      'timeLimit': timeLimit.toDouble(), // FIXED
      'targetPoints': targetPoints.toDouble(), // FIXED
      'currentRound': currentRound.toDouble(), // FIXED
      'isOvertime': isOvertime,
      'timerEndTime': timerEndTime?.toDouble(), // FIXED
      'timerType': timerType,
    };
  }

  Room copyWith({
    String? id,
    String? hostId,
    RoomStatus? status,
    GameMode? mode,
    int? turnIndex,
    List<String>? turnOrder,
    Map<String, Player>? players,
    String? presetPack,
    String? lastSystemMessage,
    int? characterChangesLimit,
    int? timeLimit,
    int? targetPoints,
    int? currentRound,
    bool? isOvertime,
    int? timerEndTime,
    String? timerType,
  }) {
    return Room(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      turnIndex: turnIndex ?? this.turnIndex,
      turnOrder: turnOrder ?? this.turnOrder,
      players: players ?? this.players,
      presetPack: presetPack ?? this.presetPack,
      lastSystemMessage: lastSystemMessage ?? this.lastSystemMessage,
      characterChangesLimit: characterChangesLimit ?? this.characterChangesLimit,
      timeLimit: timeLimit ?? this.timeLimit,
      targetPoints: targetPoints ?? this.targetPoints,
      currentRound: currentRound ?? this.currentRound,
      isOvertime: isOvertime ?? this.isOvertime,
      timerEndTime: timerEndTime ?? this.timerEndTime,
      timerType: timerType ?? this.timerType,
    );
  }
}
