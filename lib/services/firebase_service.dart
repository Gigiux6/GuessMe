import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/room.dart';
import '../models/player.dart';
import 'dart:async';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  
  final int _serverTimeOffset = 0;
  int get serverTimeOffset => _serverTimeOffset;

  FirebaseService();

  int get synchronizedTime => DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;

  Stream<Room?> getRoomStream(String roomId) {
    return _rtdb.ref('rooms/$roomId').onValue.map((event) {
      if (event.snapshot.value == null) return null;
      
      final rawData = event.snapshot.value as Map;
      final fullRoomMap = rawData.map((key, value) => MapEntry(key.toString(), value));
      
      // Ensure players map has string keys
      if (fullRoomMap['players'] != null) {
        final rawPlayers = fullRoomMap['players'] as Map;
        fullRoomMap['players'] = rawPlayers.map((k, v) => MapEntry(k.toString(), v));
      }
      
      return Room.fromMap(roomId, fullRoomMap);
    });
  }

  Future<void> createRoom(Room room) async {
    final roomData = room.toMap();
    await _rtdb.ref('rooms/${room.id}').set(roomData);
  }

  Future<bool> joinRoom(String roomId, Player player) async {
    final roomRef = _rtdb.ref('rooms/$roomId');
    final roomSnap = await roomRef.get();
    
    if (!roomSnap.exists) return false;
    
    final data = roomSnap.value as Map?;
    if (data == null || data['hostId'] == null) return false;

    final playerRef = roomRef.child('players/${player.id}');
    final playerSnap = await playerRef.get();
    
    if (playerSnap.exists) {
      await playerRef.update({
        'name': player.name,
        'avatarUrl': player.avatarUrl,
      });
    } else {
      await playerRef.set(player.toMap());
    }
    
    return true;
  }

  Future<void> syncTurnOrder(String roomId, List<String> turnOrder) async {
    await _rtdb.ref('rooms/$roomId/turnOrder').set(turnOrder);
  }

  Future<void> updateRoomStatus(String roomId, RoomStatus status, [GameMode? mode, String? presetPack]) async {
    Map<String, dynamic> updates = {'status': status.name};
    if (mode != null) updates['mode'] = mode.name;
    if (presetPack != null) updates['presetPack'] = presetPack;
    await _rtdb.ref('rooms/$roomId').update(updates);
  }

  Future<void> updateRoomSettings(String roomId, Map<String, dynamic> settings) async {
    await _rtdb.ref('rooms/$roomId').update(settings);
  }

  Future<void> updatePlayer(String roomId, String playerId, Map<String, dynamic> updates) async {
    await _rtdb.ref('rooms/$roomId/players/$playerId').update(updates);
  }

  Future<void> submitCustomIdentity(String roomId, String playerId, Map<String, dynamic> submission) async {
    await _rtdb.ref('rooms/$roomId/submissions/$playerId').set(submission);
  }

  Future<Map<String, dynamic>> getSubmissions(String roomId) async {
    final snap = await _rtdb.ref('rooms/$roomId/submissions').get();
    if (snap.exists && snap.value != null) {
      final rawData = snap.value as Map;
      return rawData.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  Future<void> savePlayer(String roomId, String playerId) async {
    await _rtdb.ref('rooms/$roomId/players/$playerId').update({
      'isSaved': true,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> passTurn(String roomId, int newTurnIndex) async {
    await _rtdb.ref('rooms/$roomId').update({'turnIndex': newTurnIndex});
  }

  Future<void> executeTimedTurnEnd(
    String roomId, 
    int nextTurnIndex, 
    Map<String, dynamic> playersUpdates, 
    Map<String, dynamic> roomUpdates
  ) async {
    Map<String, dynamic> updates = {};
    
    roomUpdates.forEach((key, value) {
      updates['rooms/$roomId/$key'] = value;
    });
    updates['rooms/$roomId/turnIndex'] = nextTurnIndex;
    updates['rooms/$roomId/timerEndTime'] = null;
    updates['rooms/$roomId/timerType'] = null;
    
    playersUpdates.forEach((key, value) {
      updates['rooms/$roomId/players/$key'] = value;
    });
    
    await _rtdb.ref().update(updates);
  }

  Future<void> syncTimer(String roomId, int? endTime, String? type) async {
    await _rtdb.ref('rooms/$roomId').update({
      'timerEndTime': endTime,
      'timerType': type,
    });
  }

  Future<void> assignIdentities(String roomId, Map<String, Map<String, dynamic>> assignments, {int initialChanges = 0}) async {
    Map<String, dynamic> updates = {};
    assignments.forEach((playerId, data) {
      updates['rooms/$roomId/players/$playerId/identityName'] = data['identityName'];
      updates['rooms/$roomId/players/$playerId/remainingChanges'] = initialChanges;
      if (data['identityImageUrl'] != null) {
        updates['rooms/$roomId/players/$playerId/identityImageUrl'] = data['identityImageUrl'];
      }
    });
    await _rtdb.ref().update(updates);
  }

  Future<void> resetRoomForNewGame(String roomId) async {
    final roomSnap = await _rtdb.ref('rooms/$roomId/players').get();
    Map<String, dynamic> updates = {};
    
    if (roomSnap.exists && roomSnap.value != null) {
      final players = roomSnap.value as Map;
      players.keys.forEach((playerId) {
        updates['rooms/$roomId/players/$playerId/identityName'] = null;
        updates['rooms/$roomId/players/$playerId/identityImageUrl'] = null;
        updates['rooms/$roomId/players/$playerId/isSaved'] = false;
        updates['rooms/$roomId/players/$playerId/savedAt'] = null;
        updates['rooms/$roomId/players/$playerId/remainingChanges'] = 0;
        updates['rooms/$roomId/players/$playerId/score'] = 0;
      });
    }
    
    updates['rooms/$roomId/submissions'] = null;
    updates['rooms/$roomId/status'] = RoomStatus.lobby.name;
    updates['rooms/$roomId/turnIndex'] = 0;
    updates['rooms/$roomId/currentRound'] = 1;
    updates['rooms/$roomId/isOvertime'] = false;
    updates['rooms/$roomId/timerEndTime'] = null;
    updates['rooms/$roomId/timerType'] = null;
    
    await _rtdb.ref().update(updates);
  }

  Future<void> removePlayer(String roomId, String playerId) async {
    await _rtdb.ref('rooms/$roomId/players/$playerId').remove();
  }

  Future<void> deleteRoom(String roomId) async {
    await _rtdb.ref('rooms/$roomId').remove();
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<Map<dynamic, dynamic>?> getUserProfile(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    return snap.data();
  }

  Future<void> sendSystemMessage(String roomId, String text) async {
    await _rtdb.ref('rooms/$roomId').update({'lastSystemMessage': text});
  }

  Future<void> cancelOnDisconnect(String roomId, String playerId) async {
    final playerRef = _rtdb.ref('rooms/$roomId/players/$playerId/isOnline');
    await playerRef.onDisconnect().set(false);
    await playerRef.set(true);
  }
  
  Future<void> finalizeGameAndSyncStats(String roomId, List<String> winners, List<String> allPlayers) async {
    try {
      final batch = _firestore.batch();

      for (String playerId in allPlayers) {
        final userRef = _firestore.collection('users').doc(playerId);
        bool isWinner = winners.contains(playerId);
        
        batch.set(userRef, {
          'gamesPlayed': FieldValue.increment(1),
          if (isWinner) 'gamesWon': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      // NOTA: Non eliminiamo la stanza da RTDB qui per permettere ai client di vedere la schermata dei risultati.
      // La stanza verrà eliminata quando l'host premerà il tasto "Esci" o "Gioca Ancora".
      
    } catch (e) {
      debugPrint("Errore durante la sincronizzazione finale: $e");
      rethrow;
    }
  }

  // Deprecated - handled by finalizeGameAndSyncStats
  Future<void> incrementGamesWon(String uid) async {}
}
