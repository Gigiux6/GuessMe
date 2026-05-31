import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../models/room.dart';
import '../models/player.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int _serverTimeOffset = 0;
  int get serverTimeOffset => _serverTimeOffset;

  FirebaseService();

  int get synchronizedTime => DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;

  Stream<Room?> getRoomStream(String roomId) {
    final roomDocStream = _firestore.collection('rooms').doc(roomId).snapshots();
    final playersColStream = _firestore.collection('rooms').doc(roomId).collection('players').snapshots();

    return Rx.combineLatest2<DocumentSnapshot<Map<String, dynamic>>, QuerySnapshot<Map<String, dynamic>>, Room?>(
      roomDocStream,
      playersColStream,
      (roomDoc, playersCol) {
        if (!roomDoc.exists) return null;
        
        final roomData = roomDoc.data() ?? {};
        
        // Build players map
        Map<String, Map<String, dynamic>> playersMaps = {};
        for (var doc in playersCol.docs) {
          playersMaps[doc.id] = doc.data();
        }
        
        // Construct Room object from the map
        final Map<String, dynamic> fullRoomMap = Map<String, dynamic>.from(roomData);
        fullRoomMap['players'] = playersMaps;

        return Room.fromMap(roomId, fullRoomMap);
      },
    );
  }

  Future<void> createRoom(Room room) async {
    final batch = _firestore.batch();
    
    final roomRef = _firestore.collection('rooms').doc(room.id);
    final roomData = room.toMap();
    roomData.remove('players'); // players go to subcollection
    
    batch.set(roomRef, roomData);
    
    room.players.forEach((playerId, player) {
      final playerRef = roomRef.collection('players').doc(playerId);
      batch.set(playerRef, player.toMap());
    });
    
    await batch.commit();
  }

  Future<bool> joinRoom(String roomId, Player player) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists || roomSnap.data()?['hostId'] == null) {
      return false;
    }

    final playerRef = roomRef.collection('players').doc(player.id);
    final playerSnap = await playerRef.get();
    if (playerSnap.exists) {
      await playerRef.update({
        'name': player.name,
        'avatarUrl': player.avatarUrl,
      });
    } else {
      await playerRef.set(player.toMap());
    }
    
    final List<dynamic>? currentTurnOrder = roomSnap.data()?['turnOrder'];
    List<String> turnOrder = currentTurnOrder != null ? List<String>.from(currentTurnOrder) : [];
    if (!turnOrder.contains(player.id)) {
      turnOrder.add(player.id);
      await roomRef.update({'turnOrder': turnOrder});
    }
    return true;
  }

  Future<void> updateRoomStatus(String roomId, RoomStatus status, [GameMode? mode, String? presetPack]) async {
    Map<String, dynamic> updates = {'status': status.name};
    if (mode != null) updates['mode'] = mode.name;
    if (presetPack != null) updates['presetPack'] = presetPack;
    await _firestore.collection('rooms').doc(roomId).update(updates);
  }

  Future<void> updateRoomSettings(String roomId, Map<String, dynamic> settings) async {
    await _firestore.collection('rooms').doc(roomId).update(settings);
  }

  Future<void> updatePlayer(String roomId, String playerId, Map<String, dynamic> updates) async {
    await _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId).update(updates);
  }

  Future<void> submitCustomIdentity(String roomId, String playerId, Map<String, dynamic> submission) async {
    await _firestore.collection('rooms').doc(roomId).collection('submissions').doc(playerId).set(submission);
  }

  Future<Map<String, dynamic>> getSubmissions(String roomId) async {
    final snapshot = await _firestore.collection('rooms').doc(roomId).collection('submissions').get();
    Map<String, dynamic> submissions = {};
    for (var doc in snapshot.docs) {
      submissions[doc.id] = doc.data();
    }
    return submissions;
  }

  Future<void> savePlayer(String roomId, String playerId) async {
    await _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId).update({
      'isSaved': true,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> passTurn(String roomId, int newTurnIndex) async {
    await _firestore.collection('rooms').doc(roomId).update({'turnIndex': newTurnIndex});
  }

  Future<void> executeTimedTurnEnd(
    String roomId, 
    int nextTurnIndex, 
    Map<String, dynamic> playersUpdates, 
    Map<String, dynamic> roomUpdates
  ) async {
    final batch = _firestore.batch();
    
    final roomRef = _firestore.collection('rooms').doc(roomId);
    Map<String, dynamic> finalRoomUpdates = Map<String, dynamic>.from(roomUpdates);
    finalRoomUpdates['turnIndex'] = nextTurnIndex;
    finalRoomUpdates['timerEndTime'] = null;
    finalRoomUpdates['timerType'] = null;
    batch.update(roomRef, finalRoomUpdates);
    
    Map<String, Map<String, dynamic>> groupedPlayerUpdates = {};
    playersUpdates.forEach((key, value) {
      final parts = key.split('/');
      final playerId = parts[0];
      final field = parts[1];
      groupedPlayerUpdates.putIfAbsent(playerId, () => {})[field] = value;
    });
    
    groupedPlayerUpdates.forEach((playerId, fields) {
      final playerRef = roomRef.collection('players').doc(playerId);
      batch.update(playerRef, fields);
    });
    
    await batch.commit();
  }

  Future<void> syncTimer(String roomId, int? endTime, String? type) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'timerEndTime': endTime,
      'timerType': type,
    });
  }

  Future<void> assignIdentities(String roomId, Map<String, Map<String, dynamic>> assignments, {int initialChanges = 0}) async {
    final batch = _firestore.batch();
    final roomRef = _firestore.collection('rooms').doc(roomId);
    
    assignments.forEach((playerId, data) {
      final playerRef = roomRef.collection('players').doc(playerId);
      Map<String, dynamic> updates = {
        'identityName': data['identityName'],
        'remainingChanges': initialChanges,
      };
      if (data['identityImageUrl'] != null) {
        updates['identityImageUrl'] = data['identityImageUrl'];
      }
      batch.update(playerRef, updates);
    });
    
    await batch.commit();
  }

  Future<void> resetRoomForNewGame(String roomId) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final playersSnap = await roomRef.collection('players').get();
    
    final batch = _firestore.batch();
    
    for (var doc in playersSnap.docs) {
      batch.update(doc.reference, {
        'identityName': null,
        'identityImageUrl': null,
        'isSaved': false,
        'savedAt': null,
        'remainingChanges': 0,
        'score': 0,
      });
    }
    
    final submissionsSnap = await roomRef.collection('submissions').get();
    for (var doc in submissionsSnap.docs) {
      batch.delete(doc.reference);
    }
    
    batch.update(roomRef, {
      'status': RoomStatus.lobby.name,
      'turnIndex': 0,
      'currentRound': 1,
      'isOvertime': false,
      'timerEndTime': null,
      'timerType': null,
    });
    
    await batch.commit();
  }

  Future<void> removePlayer(String roomId, String playerId) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    await roomRef.collection('players').doc(playerId).delete();
    
    final roomSnap = await roomRef.get();
    if (roomSnap.exists) {
      final List<dynamic>? currentTurnOrder = roomSnap.data()?['turnOrder'];
      if (currentTurnOrder != null) {
        List<String> turnOrder = List<String>.from(currentTurnOrder);
        turnOrder.remove(playerId);
        await roomRef.update({'turnOrder': turnOrder});
      }
    }
  }

  Future<void> deleteRoom(String roomId) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    
    final playersSnap = await roomRef.collection('players').get();
    final submissionsSnap = await roomRef.collection('submissions').get();
    
    final batch = _firestore.batch();
    for (var doc in playersSnap.docs) {
      batch.delete(doc.reference);
    }
    for (var doc in submissionsSnap.docs) {
      batch.delete(doc.reference);
    }
    
    batch.delete(roomRef);
    await batch.commit();
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<Map<dynamic, dynamic>?> getUserProfile(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    return snap.data();
  }

  Future<void> incrementGamesWon(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(userRef);
      int current = 0;
      if (snap.exists) {
        current = snap.data()?['gamesWon'] ?? 0;
      }
      transaction.set(userRef, {'gamesWon': current + 1}, SetOptions(merge: true));
    });
  }

  Future<void> sendSystemMessage(String roomId, String text) async {
    await _firestore.collection('rooms').doc(roomId).update({'lastSystemMessage': text});
  }

  Future<void> cancelOnDisconnect(String roomId, String playerId) async {
    // Placeholder for Firestore presence
  }
}
