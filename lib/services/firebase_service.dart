import 'package:firebase_database/firebase_database.dart';
import '../models/room.dart';
import '../models/player.dart';

class FirebaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  int _serverTimeOffset = 0;
  int get serverTimeOffset => _serverTimeOffset;

  FirebaseService() {
    _db.child('.info/serverTimeOffset').onValue.listen((event) {
      if (event.snapshot.value != null) {
        _serverTimeOffset = (event.snapshot.value as num).toInt();
      }
    });
  }

  int get synchronizedTime => DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;

  Stream<Room?> getRoomStream(String roomId) {
    return _db.child('rooms/$roomId').onValue.map((event) {
      if (event.snapshot.value != null) {
        return Room.fromMap(roomId, event.snapshot.value as Map<dynamic, dynamic>);
      }
      return null;
    });
  }

  Future<void> createRoom(Room room) async {
    await _db.child('rooms/${room.id}').set(room.toMap());
  }

  Future<bool> joinRoom(String roomId, Player player) async {
    final roomSnapshot = await _db.child('rooms/$roomId').get();
    if (!roomSnapshot.exists || roomSnapshot.child('hostId').value == null) {
      return false;
    }

    // Check if player already exists to preserve identity and saved status
    final playerSnapshot = await _db.child('rooms/$roomId/players/${player.id}').get();
    if (playerSnapshot.exists) {
      await _db.child('rooms/$roomId/players/${player.id}').update({
        'name': player.name,
        'avatarUrl': player.avatarUrl,
      });
    } else {
      await _db.child('rooms/$roomId/players/${player.id}').set(player.toMap());
    }
    
    // Removed onDisconnect().remove() to allow rejoining after backgrounding/minimizing app
    
    final snapshot = await _db.child('rooms/$roomId/turnOrder').get();
    List<String> turnOrder = [];
    if (snapshot.value != null) {
      turnOrder = List<String>.from(snapshot.value as List<dynamic>);
    }
    if (!turnOrder.contains(player.id)) {
      turnOrder.add(player.id);
      await _db.child('rooms/$roomId/turnOrder').set(turnOrder);
    }
    return true;
  }

  Future<void> updateRoomStatus(String roomId, RoomStatus status, [GameMode? mode, String? presetPack]) async {
    Map<String, dynamic> updates = {'status': status.name};
    if (mode != null) updates['mode'] = mode.name;
    if (presetPack != null) updates['presetPack'] = presetPack;
    await _db.child('rooms/$roomId').update(updates);
  }

  Future<void> updateRoomSettings(String roomId, Map<String, dynamic> settings) async {
    await _db.child('rooms/$roomId').update(settings);
  }

  Future<void> updatePlayer(String roomId, String playerId, Map<String, dynamic> updates) async {
    await _db.child('rooms/$roomId/players/$playerId').update(updates);
  }

  Future<void> submitCustomIdentity(String roomId, String playerId, Map<String, dynamic> submission) async {
    await _db.child('rooms/$roomId/submissions/$playerId').set(submission);
  }

  Future<Map<String, dynamic>> getSubmissions(String roomId) async {
    final snapshot = await _db.child('rooms/$roomId/submissions').get();
    if (snapshot.value != null) {
      return Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
    }
    return {};
  }

  Future<void> savePlayer(String roomId, String playerId) async {
    await _db.child('rooms/$roomId/players/$playerId').update({
      'isSaved': true,
      'savedAt': ServerValue.timestamp,
    });
  }

  Future<void> passTurn(String roomId, int newTurnIndex) async {
    await _db.child('rooms/$roomId').update({'turnIndex': newTurnIndex});
  }

  Future<void> executeTimedTurnEnd(
    String roomId, 
    int nextTurnIndex, 
    Map<String, dynamic> playersUpdates, 
    Map<String, dynamic> roomUpdates
  ) async {
    Map<String, dynamic> updates = {};
    
    playersUpdates.forEach((path, value) {
      updates['players/$path'] = value;
    });
    
    roomUpdates.forEach((key, value) {
      updates[key] = value;
    });
    
    updates['turnIndex'] = nextTurnIndex;
    updates['timerEndTime'] = null;
    updates['timerType'] = null;
    
    await _db.child('rooms/$roomId').update(updates);
  }

  Future<void> syncTimer(String roomId, int? endTime, String? type) async {
    await _db.child('rooms/$roomId').update({
      'timerEndTime': endTime,
      'timerType': type,
    });
  }

  Future<void> assignIdentities(String roomId, Map<String, Map<String, dynamic>> assignments, {int initialChanges = 0}) async {
    Map<String, dynamic> updates = {};
    assignments.forEach((playerId, data) {
      updates['players/$playerId/identityName'] = data['identityName'];
      updates['players/$playerId/remainingChanges'] = initialChanges;
      if (data['identityImageUrl'] != null) {
        updates['players/$playerId/identityImageUrl'] = data['identityImageUrl'];
      }
    });
    await _db.child('rooms/$roomId').update(updates);
  }

  Future<void> resetRoomForNewGame(String roomId) async {
    final snapshot = await _db.child('rooms/$roomId/players').get();
    if (snapshot.value != null) {
      Map<dynamic, dynamic> players = snapshot.value as Map<dynamic, dynamic>;
      Map<String, dynamic> updates = {};
      
      players.forEach((key, value) {
        updates['players/$key/identityName'] = null;
        updates['players/$key/identityImageUrl'] = null;
        updates['players/$key/isSaved'] = false;
        updates['players/$key/savedAt'] = null;
        updates['players/$key/remainingChanges'] = 0;
        updates['players/$key/score'] = 0;
      });
      
      updates['status'] = RoomStatus.lobby.name;
      updates['turnIndex'] = 0;
      updates['submissions'] = null;
      updates['currentRound'] = 1;
      updates['isOvertime'] = false;
      updates['timerEndTime'] = null;
      updates['timerType'] = null;
      
      await _db.child('rooms/$roomId').update(updates);
    }
  }

  Future<void> removePlayer(String roomId, String playerId) async {
    await _db.child('rooms/$roomId/players/$playerId').remove();
    
    final snapshot = await _db.child('rooms/$roomId/turnOrder').get();
    if (snapshot.value != null) {
      List<String> turnOrder = List<String>.from(snapshot.value as List<dynamic>);
      turnOrder.remove(playerId);
      await _db.child('rooms/$roomId/turnOrder').set(turnOrder);
    }
  }

  Future<void> deleteRoom(String roomId) async {
    await _db.child('rooms/$roomId').remove();
  }

  // User Profile Methods
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.child('users/$uid').update(data);
  }

  Future<Map<dynamic, dynamic>?> getUserProfile(String uid) async {
    final snapshot = await _db.child('users/$uid').get();
    if (snapshot.exists) {
      return snapshot.value as Map<dynamic, dynamic>;
    }
    return null;
  }

  Future<void> incrementGamesWon(String uid) async {
    final ref = _db.child('users/$uid/gamesWon');
    final snapshot = await ref.get();
    int current = 0;
    if (snapshot.exists) {
      current = (snapshot.value as num).toInt();
    }
    await ref.set(current + 1);
  }

  Future<void> sendSystemMessage(String roomId, String text) async {
    await _db.child('rooms/$roomId').update({'lastSystemMessage': text});
  }

  Future<void> cancelOnDisconnect(String roomId, String playerId) async {
    await _db.child('rooms/$roomId/players/$playerId').onDisconnect().cancel();
  }
}
