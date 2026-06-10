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

  String _roomPath(String roomId) => 'rooms/$roomId';
  String _playersPath(String roomId) => '${_roomPath(roomId)}/players';
  String _playerPath(String roomId, String playerId) => '${_playersPath(roomId)}/$playerId';
  String _submissionsPath(String roomId) => '${_roomPath(roomId)}/submissions';

  Stream<Room?> getRoomStream(String roomId) {
    return _rtdb.ref(_roomPath(roomId)).onValue.map((event) {
      if (event.snapshot.value == null) return null;
      
      final rawData = event.snapshot.value as Map;
      final fullRoomMap = rawData.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
      
      // Ensure players map has string keys
      if (fullRoomMap['players'] != null) {
        final rawPlayers = fullRoomMap['players'] as Map;
        fullRoomMap['players'] = rawPlayers.map<String, dynamic>((k, v) => MapEntry(k.toString(), v));
      }
      
      return Room.fromMap(roomId, fullRoomMap);
    });
  }

  Future<void> createRoom(Room room) async {
    final roomData = room.toMap();
    await _rtdb.ref(_roomPath(room.id)).set(roomData);
  }

  Future<bool> joinRoom(String roomId, Player player) async {
    final roomRef = _rtdb.ref(_roomPath(roomId));
    final roomSnap = await roomRef.get();
    
    if (!roomSnap.exists) return false;
    
    final data = roomSnap.value as Map?;
    if (data == null || data['hostId'] == null) return false;

    final playerRef = _rtdb.ref(_playerPath(roomId, player.id));
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
    await _rtdb.ref('${_roomPath(roomId)}/turnOrder').set(turnOrder);
  }

  Future<void> updateRoomStatus(String roomId, RoomStatus status, [GameMode? mode, String? presetPack]) async {
    Map<String, dynamic> updates = {'status': status.name};
    if (mode != null) updates['mode'] = mode.name;
    if (presetPack != null) updates['presetPack'] = presetPack;
    await _rtdb.ref(_roomPath(roomId)).update(updates);
  }

  Future<void> updateRoomSettings(String roomId, Map<String, dynamic> settings) async {
    await _rtdb.ref(_roomPath(roomId)).update(settings);
  }

  Future<void> updatePlayer(String roomId, String playerId, Map<String, dynamic> updates) async {
    await _rtdb.ref(_playerPath(roomId, playerId)).update(updates);
  }

  Future<void> submitCustomIdentity(String roomId, String playerId, Map<String, dynamic> submission) async {
    await _rtdb.ref('${_submissionsPath(roomId)}/$playerId').set(submission);
  }

  Future<Map<String, dynamic>> getSubmissions(String roomId) async {
    final snap = await _rtdb.ref(_submissionsPath(roomId)).get();
    if (snap.exists && snap.value != null) {
      final rawData = snap.value as Map;
      return rawData.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  Future<void> savePlayer(String roomId, String playerId) async {
    await _rtdb.ref(_playerPath(roomId, playerId)).update({
      'isSaved': true,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> passTurn(String roomId, int newTurnIndex) async {
    await _rtdb.ref(_roomPath(roomId)).update({'turnIndex': newTurnIndex});
  }

  Future<void> executeTimedTurnEnd(
    String roomId, 
    int nextTurnIndex, 
    Map<String, dynamic> playersUpdates, 
    Map<String, dynamic> roomUpdates
  ) async {
    Map<String, dynamic> updates = {};
    
    final rPath = _roomPath(roomId);
    roomUpdates.forEach((key, value) {
      updates['$rPath/$key'] = value;
    });
    updates['$rPath/turnIndex'] = nextTurnIndex;
    updates['$rPath/timerEndTime'] = null;
    updates['$rPath/timerType'] = null;
    
    final pPath = _playersPath(roomId);
    playersUpdates.forEach((key, value) {
      updates['$pPath/$key'] = value;
    });
    
    await _rtdb.ref().update(updates);
  }

  Future<void> syncTimer(String roomId, int? endTime, String? type) async {
    await _rtdb.ref(_roomPath(roomId)).update({
      'timerEndTime': endTime,
      'timerType': type,
    });
  }

  Future<void> assignIdentities(String roomId, Map<String, Map<String, dynamic>> assignments, {int initialChanges = 0}) async {
    Map<String, dynamic> updates = {};
    assignments.forEach((playerId, data) {
      final pPath = _playerPath(roomId, playerId);
      updates['$pPath/identityName'] = data['identityName'];
      updates['$pPath/remainingChanges'] = initialChanges;
      if (data['identityImageUrl'] != null) {
        updates['$pPath/identityImageUrl'] = data['identityImageUrl'];
      }
    });
    await _rtdb.ref().update(updates);
  }

  Future<void> resetRoomForNewGame(String roomId) async {
    final roomSnap = await _rtdb.ref(_playersPath(roomId)).get();
    Map<String, dynamic> updates = {};
    
    if (roomSnap.exists && roomSnap.value != null) {
      final players = roomSnap.value as Map;
      players.keys.forEach((playerId) {
        final pPath = _playerPath(roomId, playerId.toString());
        updates['$pPath/identityName'] = null;
        updates['$pPath/identityImageUrl'] = null;
        updates['$pPath/isSaved'] = false;
        updates['$pPath/savedAt'] = null;
        updates['$pPath/remainingChanges'] = 0;
        updates['$pPath/score'] = 0;
      });
    }
    
    final rPath = _roomPath(roomId);
    updates[_submissionsPath(roomId)] = null;
    updates['$rPath/status'] = RoomStatus.lobby.name;
    updates['$rPath/turnIndex'] = 0;
    updates['$rPath/currentRound'] = 1;
    updates['$rPath/isOvertime'] = false;
    updates['$rPath/timerEndTime'] = null;
    updates['$rPath/timerType'] = null;
    
    await _rtdb.ref().update(updates);
  }

  Future<void> removePlayer(String roomId, String playerId) async {
    await _rtdb.ref(_playerPath(roomId, playerId)).remove();
  }

  Future<void> deleteRoom(String roomId) async {
    await _rtdb.ref(_roomPath(roomId)).remove();
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<Map<dynamic, dynamic>?> getUserProfile(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    return snap.data();
  }

  Future<void> sendSystemMessage(String roomId, String text) async {
    await _rtdb.ref(_roomPath(roomId)).update({'lastSystemMessage': text});
  }

  Future<void> setupRoomDisconnectHook(String roomId) async {
    final roomRef = _rtdb.ref(_roomPath(roomId));
    // On web release, keep the connection alive to prevent spurious
    // onDisconnect triggers during page transitions.
    if (kIsWeb) {
      roomRef.keepSynced(true);
      _rtdb.goOnline();
    }
    await roomRef.onDisconnect().remove();
  }

  Future<void> setupPlayerDisconnectHook(String roomId, String playerId) async {
    final playerRef = _rtdb.ref(_playerPath(roomId, playerId));
    if (kIsWeb) {
      playerRef.keepSynced(true);
      _rtdb.goOnline();
    }
    await playerRef.onDisconnect().remove();
  }

  Future<void> cancelRoomDisconnectHook(String roomId) async {
    final roomRef = _rtdb.ref(_roomPath(roomId));
    await roomRef.onDisconnect().cancel();
    if (kIsWeb) {
      roomRef.keepSynced(false);
    }
  }

  Future<void> cancelPlayerDisconnectHook(String roomId, String playerId) async {
    final playerRef = _rtdb.ref(_playerPath(roomId, playerId));
    await playerRef.onDisconnect().cancel();
    if (kIsWeb) {
      playerRef.keepSynced(false);
    }
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
}
