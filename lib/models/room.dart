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
  final String? presetPack;
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
    this.presetPack,
    this.lastSystemMessage,
    this.characterChangesLimit = 0,
    this.timeLimit = 60,
    this.targetPoints = 3,
    this.currentRound = 1,
    this.isOvertime = false,
    this.timerEndTime,
    this.timerType,
  });

  factory Room.fromMap(String id, Map<dynamic, dynamic> map) {
    var statusStr = map['status'] ?? 'lobby';
    var modeStr = map['mode'] ?? 'preset';
    
    var playersMap = map['players'] as Map<dynamic, dynamic>? ?? {};
    Map<String, Player> players = {};
    playersMap.forEach((key, value) {
      if (value != null) {
        players[key.toString()] = Player.fromMap(key.toString(), value as Map<dynamic, dynamic>);
      }
    });

    return Room(
      id: id,
      hostId: map['hostId'] ?? '',
      status: RoomStatus.values.firstWhere((e) => e.name == statusStr, orElse: () => RoomStatus.lobby),
      mode: GameMode.values.firstWhere((e) => e.name == modeStr, orElse: () => GameMode.preset),
      turnIndex: map['turnIndex'] ?? 0,
      turnOrder: map['turnOrder'] != null ? List<String>.from(map['turnOrder'] as List<dynamic>) : [],
      players: players,
      presetPack: map['presetPack'],
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
      'turnIndex': turnIndex,
      'turnOrder': turnOrder,
      'players': players.map((key, value) => MapEntry(key, value.toMap())),
      'presetPack': presetPack,
      'lastSystemMessage': lastSystemMessage,
      'characterChangesLimit': characterChangesLimit,
      'timeLimit': timeLimit,
      'targetPoints': targetPoints,
      'currentRound': currentRound,
      'isOvertime': isOvertime,
      'timerEndTime': timerEndTime,
      'timerType': timerType,
    };
  }
}
