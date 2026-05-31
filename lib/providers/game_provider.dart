import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/room.dart';
import '../models/player.dart';
import '../services/firebase_service.dart';
import '../data/game_packs.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'user_provider.dart';
import '../data/translations.dart';
import '../services/profile_storage_service.dart';

class GameProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();

  GameProvider() {
    _initAudio();
  }

  void _initAudio() {
    // Basic setup for web/mobile compatibility
    // Removed platform-specific contexts that were causing build errors
  }

  Room? currentRoom;
  String? currentPlayerId;
  StreamSubscription<Room?>? _roomSubscription;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  int get synchronizedTime => _firebaseService.synchronizedTime;

  bool get isHost => currentRoom != null && currentPlayerId == currentRoom!.hostId;
  bool get isMyTurn {
    if (currentRoom == null || currentRoom!.turnOrder.isEmpty) return false;
    return currentRoom!.turnOrder[currentRoom!.turnIndex % currentRoom!.turnOrder.length] == currentPlayerId;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void listenToRoom(String roomId) {
    _roomSubscription?.cancel();
    _roomSubscription = _firebaseService.getRoomStream(roomId).listen(
      (room) {
        if (room == null) {
          // Se la stanza sparisce ma noi pensavamo di esserci dentro, allora chiudiamo
          if (currentRoom != null) {
            _roomSubscription?.cancel();
            currentRoom = null;
            currentPlayerId = null;
            notifyListeners();
          }
        } else {
          currentRoom = room;
          
          // Se siamo l'host e la partita è in corso, controlliamo se è finita 
          // (es. qualcuno è uscito e ne è rimasto solo uno che deve indovinare)
          if (isHost && room.status == RoomStatus.playing) {
            int unsavedCount = room.players.values.where((p) => !p.isSaved).length;
            if (unsavedCount <= 1) {
              _firebaseService.updateRoomStatus(room.id, RoomStatus.finished);
            }
          }
          
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('Firestore stream error: $error');
        _roomSubscription?.cancel();
        currentRoom = null;
        currentPlayerId = null;
        notifyListeners();
      },
    );
  }

  Future<void> updateRoomSettings({GameMode? mode, String? presetPack, int? characterChangesLimit, int? timeLimit, int? targetPoints}) async {
    if (currentRoom == null) return;
    Map<String, dynamic> settings = {};
    if (mode != null) settings['mode'] = mode.name;
    if (presetPack != null) settings['presetPack'] = presetPack;
    if (characterChangesLimit != null) settings['characterChangesLimit'] = characterChangesLimit;
    if (timeLimit != null) settings['timeLimit'] = timeLimit;
    if (targetPoints != null) settings['targetPoints'] = targetPoints;
    
    if (settings.isNotEmpty) {
      await _firebaseService.updateRoomSettings(currentRoom!.id, settings);
    }
  }

  Future<void> updateCharacterChangesLimit(int limit) async {
    await updateRoomSettings(characterChangesLimit: limit);
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _audioPlayer.dispose();
    _bgmPlayer.dispose();
    super.dispose();
  }

  void playLobbyMusic(double volume) async {
    if (volume <= 0) {
      if (_bgmPlayer.state == PlayerState.playing) {
        await _bgmPlayer.pause();
      }
      return;
    }

    if (_bgmPlayer.state == PlayerState.playing) {
      await _bgmPlayer.setVolume(volume * 0.4);
      return;
    }

    if (_bgmPlayer.state == PlayerState.paused) {
      await _bgmPlayer.resume();
      await _bgmPlayer.setVolume(volume * 0.4);
      return;
    }

    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('audio/lobby_musicPokemon.mp3'), volume: volume * 0.4);
    } catch (e) {
      debugPrint('Error playing lobby music: $e');
    }
  }

  void stopLobbyMusic() async {
    await _bgmPlayer.stop();
  }

  void pauseLobbyMusic() async {
    if (_bgmPlayer.state == PlayerState.playing) {
      await _bgmPlayer.pause();
    }
  }

  void resumeLobbyMusic() async {
    if (_bgmPlayer.state == PlayerState.paused) {
      await _bgmPlayer.resume();
    }
  }

  void playTurnNotification(double volume) async {
    _audioPlayer.play(AssetSource('audio/ding.wav'), volume: volume);
  }

  Future<void> createRoom(String playerName, String uid, {String? avatarUrl}) async {
    _setLoading(true);
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    String roomId = String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    
    currentPlayerId = uid;

    Player host = Player(id: uid, name: playerName, avatarUrl: avatarUrl);
    
    Room room = Room(
      id: roomId,
      hostId: uid,
      status: RoomStatus.lobby,
      mode: GameMode.preset,
      turnIndex: 0,
      turnOrder: [uid],
      players: {uid: host},
    );

    try {
      await _firebaseService.createRoom(room);
    } catch (e) {
      debugPrint('Firebase createRoom failed: $e. Proceeding locally.');
      // Proceed locally for UI testing without Firebase
      currentRoom = room;
      notifyListeners();
    }
    
    try {
      listenToRoom(roomId);
    } catch (e) {
      debugPrint('Firebase listenToRoom failed: $e');
    }
    _setLoading(false);
  }

  Future<void> saveRoomId(String? roomId, UserProvider userProvider) async {
    await userProvider.setLastRoomId(roomId);
  }

  Future<bool> joinRoom(String roomId, String playerName, String uid, {String? avatarUrl}) async {
    _setLoading(true);
    currentPlayerId = uid;
    
    Player player = Player(id: uid, name: playerName, avatarUrl: avatarUrl);
    bool success = await _firebaseService.joinRoom(roomId, player);
    
    if (!success) {
      _setLoading(false);
      currentPlayerId = null;
      return false;
    }
    
    listenToRoom(roomId);
    _setLoading(false);
    return true;
  }

  Future<void> startGame() async {
    if (currentRoom == null) return;
    _setLoading(true);
    
    // Music is now persistent throughout the session

    final mode = currentRoom!.mode;
    final presetPack = currentRoom!.presetPack;

    if (mode == GameMode.preset || mode == GameMode.timed) {
      await _assignPresetIdentities(presetPack);
      await _firebaseService.updateRoomStatus(currentRoom!.id, RoomStatus.playing, mode, presetPack);
    } else {
      await _firebaseService.updateRoomStatus(currentRoom!.id, RoomStatus.setup, mode);
    }
    _setLoading(false);
  }

  Future<void> returnToLobby(double volumeMultiplier) async {
    if (currentRoom == null) return;
    _setLoading(true);
    _audioPlayer.play(AssetSource('audio/whoosh.mp3'), volume: 1.0 * volumeMultiplier);
    // Delete any uploaded custom images for this session
    await ProfileStorageService().deleteCustomRoomImages(currentRoom!.id);
    await _firebaseService.resetRoomForNewGame(currentRoom!.id);
    _setLoading(false);
  }

  Future<void> leaveRoom({String? name, String? language}) async {
    if (currentRoom == null || currentPlayerId == null) return;
    String roomId = currentRoom!.id;
    if (isHost) {
      // Clean up custom images
      await ProfileStorageService().deleteCustomRoomImages(roomId);
      await _firebaseService.deleteRoom(roomId);
    } else {
      await _firebaseService.cancelOnDisconnect(roomId, currentPlayerId!);
      if (name != null && language != null) {
        await sendSystemMessage(roomId, AppTranslations.translate('player_left', language, args: {'name': name}));
      }
      await _firebaseService.removePlayer(roomId, currentPlayerId!);
    }
    
    _roomSubscription?.cancel();
    currentRoom = null;
    currentPlayerId = null;
    notifyListeners();
  }

  Future<void> syncTimer(int? endTime, String? type) async {
    if (currentRoom == null) return;
    await _firebaseService.syncTimer(currentRoom!.id, endTime, type);
  }

  Future<void> sendSystemMessage(String roomId, String text) async {
    await _firebaseService.sendSystemMessage(roomId, text);
  }

  Future<void> _assignPresetIdentities(String packKey) async {
    if (currentRoom == null) return;
    
    final pack = GamePacksData.packs.firstWhere((p) => p.id == packKey, orElse: () => GamePacksData.packs.first);
    List<GameIdentity> identities = List.from(pack.identities);
    identities.shuffle();
    
    Map<String, Map<String, dynamic>> assignments = {};
    int i = 0;
    for (String playerId in currentRoom!.turnOrder) {
      assignments[playerId] = {
        'identityName': identities[i % identities.length].name,
        'identityImageUrl': identities[i % identities.length].imageUrl,
      };
      i++;
    }
    
    await _firebaseService.assignIdentities(
      currentRoom!.id, 
      assignments, 
      initialChanges: currentRoom!.characterChangesLimit
    );
  }

  Future<void> changeCharacter(String language) async {
    if (currentRoom == null || currentPlayerId == null || !isMyTurn) return;
    if (currentRoom!.mode != GameMode.preset && currentRoom!.mode != GameMode.timed) return;
    final me = currentRoom!.players[currentPlayerId!];
    if (me == null || me.remainingChanges <= 0) return;

    _setLoading(true);

    final pack = GamePacksData.packs.firstWhere(
      (p) => p.id == currentRoom!.presetPack, 
      orElse: () => GamePacksData.packs.firstWhere((p) => p.id == 'cinema', orElse: () => GamePacksData.packs.first)
    );
    
    // Get all current identity names to avoid duplicates
    final currentIdentities = currentRoom!.players.values
        .map((p) => p.identityName)
        .whereType<String>()
        .toSet();
    
    final availableIdentities = pack.identities
        .where((id) => !currentIdentities.contains(id.name))
        .toList();
    
    if (availableIdentities.isEmpty) {
       _setLoading(false);
       return;
    }

    final newIdentity = availableIdentities[Random().nextInt(availableIdentities.length)];
    
    await _firebaseService.updatePlayer(currentRoom!.id, currentPlayerId!, {
      'identityName': newIdentity.name,
      'identityImageUrl': newIdentity.imageUrl,
      'remainingChanges': me.remainingChanges - 1,
    });

    await sendSystemMessage(
      currentRoom!.id, 
      AppTranslations.translate('character_changed', language, args: {'name': me.name})
    );

    _setLoading(false);
  }

  Future<void> submitCustomIdentity(String identityName) async {
    if (currentRoom == null || currentPlayerId == null) return;
    _setLoading(true);
    
    await _firebaseService.submitCustomIdentity(currentRoom!.id, currentPlayerId!, {
      'submitterId': currentPlayerId,
      'identityName': identityName,
    });
    
    _setLoading(false);
  }

  Future<void> assignCustomIdentities() async {
    if (currentRoom == null) return;
    _setLoading(true);
    
    Map<String, dynamic> submissions = await _firebaseService.getSubmissions(currentRoom!.id);
    List<Map<String, dynamic>> allSubmissions = submissions.values.map((e) => Map<String, dynamic>.from(e)).toList();
    
    if (allSubmissions.length < currentRoom!.turnOrder.length) {
      _setLoading(false);
      return; // Not everyone submitted
    }

    List<String> players = List.from(currentRoom!.turnOrder);
    Map<String, Map<String, dynamic>> assignments = {};
    
    bool validAssignment = false;
    while (!validAssignment) {
      allSubmissions.shuffle();
      validAssignment = true;
      for (int i = 0; i < players.length; i++) {
        if (allSubmissions[i]['submitterId'] == players[i]) {
          validAssignment = false;
          break;
        }
      }
      if (players.length <= 1) break;
    }

    for (int i = 0; i < players.length; i++) {
      assignments[players[i]] = {
        'identityName': allSubmissions[i]['identityName'],
      };
    }
    
    await _firebaseService.assignIdentities(
      currentRoom!.id, 
      assignments, 
      initialChanges: currentRoom!.characterChangesLimit
    );
    await _firebaseService.updateRoomStatus(currentRoom!.id, RoomStatus.playing);
    _setLoading(false);
  }

  Future<void> passTurn() async {
    if (currentRoom == null) return;
    
    // passTurn now only handles preset mode progression
    int nextIndex = currentRoom!.turnIndex + 1;

    while (true) {
      String nextPlayerId = currentRoom!.turnOrder[nextIndex % currentRoom!.turnOrder.length];
      Player? nextPlayer = currentRoom!.players[nextPlayerId];
      if (nextPlayer != null && !nextPlayer.isSaved) {
        break;
      }
      nextIndex++;
      if (nextIndex > currentRoom!.turnIndex + currentRoom!.turnOrder.length) break;
    }
    
    await _firebaseService.passTurn(currentRoom!.id, nextIndex);
  }

  Map<String, dynamic> _getNewIdentityUpdates(String playerId) {
    if (currentRoom == null) return {};
    
    final pack = GamePacksData.packs.firstWhere(
      (p) => p.id == currentRoom!.presetPack, 
      orElse: () => GamePacksData.packs.firstWhere((p) => p.id == 'cinema', orElse: () => GamePacksData.packs.first)
    );
    
    final currentIdentities = currentRoom!.players.values
        .map((p) => p.identityName)
        .whereType<String>()
        .toSet();
    
    final availableIdentities = pack.identities
        .where((id) => !currentIdentities.contains(id.name))
        .toList();
    
    if (availableIdentities.isNotEmpty) {
      final newIdentity = availableIdentities[Random().nextInt(availableIdentities.length)];
      return {
        'identityName': newIdentity.name,
        'identityImageUrl': newIdentity.imageUrl,
      };
    }
    return {};
  }

  Future<void> guessIdentity(bool isCorrect, double volumeMultiplier) async {
    if (currentRoom == null || currentPlayerId == null) return;
    
    if (currentRoom!.mode == GameMode.timed) {
      if (isCorrect) {
        _audioPlayer.play(AssetSource('audio/success.mp3'), volume: 0.4 * volumeMultiplier);
      } else {
        _audioPlayer.play(AssetSource('audio/whoosh.mp3'), volume: 1.0 * volumeMultiplier);
      }

      final me = currentRoom!.players[currentPlayerId!];
      int newScore = (me?.score ?? 0) + (isCorrect ? 1 : 0);
      
      Map<String, dynamic> identityUpdates = _getNewIdentityUpdates(currentPlayerId!);
      
      Map<String, dynamic> playersUpdates = {};
      playersUpdates['$currentPlayerId/score'] = newScore;
      identityUpdates.forEach((k, v) {
        playersUpdates['$currentPlayerId/$k'] = v;
      });

      Map<String, dynamic> roomUpdates = {};
      
      try {
        Set<String> eliminatedIds = currentRoom!.players.values.where((p) => p.isSaved).map((p) => p.id).toSet();
      
      int currentCycle = currentRoom!.turnIndex ~/ currentRoom!.turnOrder.length;
      int tempNextIndex = currentRoom!.turnIndex + 1;
      while (true) {
        String nextId = currentRoom!.turnOrder[tempNextIndex % currentRoom!.turnOrder.length];
        if (!eliminatedIds.contains(nextId)) break;
        tempNextIndex++;
      }
      
      int nextCycle = tempNextIndex ~/ currentRoom!.turnOrder.length;
      bool roundEnded = nextCycle > currentCycle;
      
      if (roundEnded) {
        int maxScore = 0;
        List<Player> activePlayers = [];
        
        for (var p in currentRoom!.players.values) {
           if (!eliminatedIds.contains(p.id)) {
              int pScore = (p.id == currentPlayerId!) ? newScore : p.score;
              if (pScore > maxScore) maxScore = pScore;
              activePlayers.add(p);
           }
        }
        
        if (maxScore >= currentRoom!.targetPoints) {
           List<Player> tiedLeaders = activePlayers.where((p) {
               int pScore = (p.id == currentPlayerId!) ? newScore : p.score;
               return pScore == maxScore;
           }).toList();
           
           if (tiedLeaders.length == 1) {
               roomUpdates['status'] = RoomStatus.finished.name;
               await _firebaseService.executeTimedTurnEnd(currentRoom!.id, tempNextIndex, playersUpdates, roomUpdates);
               return; // Game over
           } else {
               // Overtime! Eliminate anyone not tied for the lead
               for (var p in activePlayers) {
                   int pScore = (p.id == currentPlayerId!) ? newScore : p.score;
                   if (pScore < maxScore) {
                       playersUpdates['${p.id}/isSaved'] = true;
                       eliminatedIds.add(p.id);
                   }
               }
               
               if (!currentRoom!.isOvertime) {
                   roomUpdates['isOvertime'] = true;
                   roomUpdates['currentRound'] = 1;
               } else {
                   roomUpdates['currentRound'] = currentRoom!.currentRound + 1;
               }
           }
        } else {
           roomUpdates['currentRound'] = currentRoom!.currentRound + 1;
        }
      }
      
      // Recalculate next index with final eliminations
      int finalNextIndex = currentRoom!.turnIndex + 1;
      while (true) {
        String nextId = currentRoom!.turnOrder[finalNextIndex % currentRoom!.turnOrder.length];
        if (!eliminatedIds.contains(nextId)) break;
        finalNextIndex++;
      }
      
      String nextPlayerId = currentRoom!.turnOrder[finalNextIndex % currentRoom!.turnOrder.length];
      playersUpdates['$nextPlayerId/remainingChanges'] = currentRoom!.characterChangesLimit;
      
        await _firebaseService.executeTimedTurnEnd(currentRoom!.id, finalNextIndex, playersUpdates, roomUpdates);
      } catch (e) {
        await sendSystemMessage(currentRoom!.id, 'DEBUG ERROR: $e');
        print('DEBUG ERROR: $e');
      }
      
    } else {
      if (isCorrect) {
        _audioPlayer.play(AssetSource('audio/success.mp3'), volume: 0.4 * volumeMultiplier);
        await _firebaseService.savePlayer(currentRoom!.id, currentPlayerId!);
        
        int unsavedCount = currentRoom!.players.values.where((p) => !p.isSaved && p.id != currentPlayerId).length;
        if (unsavedCount <= 1) { 
          await _firebaseService.updateRoomStatus(currentRoom!.id, RoomStatus.finished);
        } else {
          await passTurn();
        }
      } else {
        _audioPlayer.play(AssetSource('audio/whoosh.mp3'), volume: 1.0 * volumeMultiplier);
        await passTurn();
      }
    }
  }

  Player? get activePlayer {
     if (currentRoom == null) return null;
     String activePlayerId = currentRoom!.turnOrder[currentRoom!.turnIndex % currentRoom!.turnOrder.length];
     return currentRoom!.players[activePlayerId];
  }
}
