import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../data/translations.dart';
import '../data/game_packs.dart';
import '../services/data_loader.dart';
import '../services/auth_service.dart';

class UserProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  
  UserModel? _user;
  UserModel? get user => _user;
  
  bool _isInitialized = false;
  final AudioPlayer _uiPlayer = AudioPlayer();
  bool get isInitialized => _isInitialized;
  bool get isAnonymous => _authService.isAnonymous;

  static const String _nameKey = 'user_name';
  static const String _avatarKey = 'user_avatar';
  static const String _musicVolumeKey = 'app_music_volume';
  static const String _effectsVolumeKey = 'app_effects_volume';
  static const String _languageKey = 'app_language';
  static const String _darkModeKey = 'app_dark_mode';
  static const String _lastRoomIdKey = 'last_room_id';
  
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;
  
  double _musicVolume = 0.3;
  double get musicVolume => _musicVolume;
  
  double _effectsVolume = 1.0;
  double get effectsVolume => _effectsVolume;
  
  String _language = 'it';
  String get language => _language;

  String? _lastRoomId;
  String? get lastRoomId => _lastRoomId;

  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('1. Cerco SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      _musicVolume = prefs.getDouble(_musicVolumeKey) ?? 0.3;
      _effectsVolume = prefs.getDouble(_effectsVolumeKey) ?? 1.0;
      _language = prefs.getString(_languageKey) ?? 'it';
      _lastRoomId = prefs.getString(_lastRoomIdKey);
      _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
      
      final savedName = prefs.getString(_nameKey);
      final savedAvatar = prefs.getString(_avatarKey);
      debugPrint('2. SharedPreferences caricate. Utente salvato: $savedName');
      
      debugPrint('3. Controllo Auth Firebase...');
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        debugPrint('4. Nessun utente, provo Login Anonimo (timeout 5s)...');
        try {
          final credential = await _auth.signInAnonymously().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('TIMEOUT: Firebase Auth non risponde.');
              throw 'Timeout Firebase Auth';
            },
          );
          firebaseUser = credential.user;
          debugPrint('5. Login Anonimo riuscito: ${firebaseUser?.uid}');
        } catch (e) {
          debugPrint('ERRORE/TIMEOUT Auth: $e');
        }
      } else {
        debugPrint('4. Utente Firebase già loggato: ${firebaseUser.uid}');
      }

      if (firebaseUser != null && savedName != null) {
        debugPrint('6. Sincronizzo profilo Firebase (timeout 5s)...');
        try {
          await _syncProfile(firebaseUser.uid, savedName, savedAvatar).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('TIMEOUT: Sincronizzazione profilo non risponde.');
              // Carico profilo locale per non bloccare
              _loadLocalFallback(firebaseUser!.uid, savedName, savedAvatar);
            },
          );
        } catch (e) {
          debugPrint('ERRORE Sync Profile: $e');
          _loadLocalFallback(firebaseUser.uid, savedName, savedAvatar);
        }
      } else if (firebaseUser == null && savedName != null) {
        debugPrint('6. Firebase non disponibile, uso profilo locale Guest.');
        _loadLocalFallback('local_user', savedName, savedAvatar);
      } else {
        debugPrint('6. Nessun dato locale trovato, attendo Setup iniziale.');
      }
    } catch (e) {
      debugPrint('ERRORE CRITICO Inizializzazione: $e');
    } finally {
      debugPrint('7. Caricamento dati di gioco (JSON)...');
      try {
        final loadedPacks = await DataLoader.loadGamePacks();
        GamePacksData.initialize(loadedPacks);
      } catch (e) {
        debugPrint('ERRORE Caricamento Dati: $e');
      }
      
      debugPrint('8. Inizializzazione completata.');
      _isInitialized = true;
      notifyListeners();
    }
  }

  void playClickSound() {
    if (_effectsVolume > 0) {
      _uiPlayer.play(AssetSource('audio/ding.wav'), volume: _effectsVolume);
    }
  }

  void _loadLocalFallback(String uid, String name, String? avatar) {
    _user = UserModel(
      uid: uid,
      name: name,
      avatarUrl: avatar ?? _getDefaultAvatar(name),
    );
  }

  Future<void> _syncProfile(String uid, String name, String? avatar) async {
    final profile = await _firebaseService.getUserProfile(uid);
    if (profile != null) {
      _user = UserModel.fromMap(uid, profile);
    } else {
      _user = UserModel(
        uid: uid,
        name: name,
        avatarUrl: avatar ?? _getDefaultAvatar(name),
      );
      await _firebaseService.updateUserProfile(uid, _user!.toMap());
    }
    notifyListeners();
  }

  Future<void> setupProfile(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    
    String uid = 'local_user';
    try {
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        final credential = await _auth.signInAnonymously();
        firebaseUser = credential.user;
      }
      if (firebaseUser != null) {
        uid = firebaseUser.uid;
      }
    } catch (e) {
      debugPrint('Firebase sign-in failed: $e. Using local UID.');
    }
    
    final avatar = _getDefaultAvatar(name);
    await prefs.setString(_avatarKey, avatar);
    
    _user = UserModel(
      uid: uid,
      name: name,
      avatarUrl: avatar,
    );
    
    try {
      await _firebaseService.updateUserProfile(uid, _user!.toMap());
      await _auth.currentUser?.updateDisplayName(name);
    } catch (e) {
      debugPrint('Firebase profile update failed: $e');
    }
    
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    if (_user == null) {
      await setupProfile(name);
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    
    _user = _user!.copyWith(name: name);
    
    try {
      await _firebaseService.updateUserProfile(_user!.uid, {'name': name});
      await _auth.currentUser?.updateDisplayName(name);
    } catch (e) {
      debugPrint('Firebase updateName failed: $e');
    }
    
    notifyListeners();
  }

  Future<void> updateAvatar(String avatarUrl) async {
    if (_user == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey, avatarUrl);
    
    _user = _user!.copyWith(avatarUrl: avatarUrl);
    
    try {
      await _firebaseService.updateUserProfile(_user!.uid, {'avatarUrl': avatarUrl});
    } catch (e) {
      debugPrint('Firebase updateAvatar failed: $e');
    }
    
    notifyListeners();
  }

  Future<void> incrementWins() async {
    if (_user == null) return;
    
    await _firebaseService.incrementGamesWon(_user!.uid);
    final profile = await _firebaseService.getUserProfile(_user!.uid);
    if (profile != null) {
      _user = UserModel.fromMap(_user!.uid, profile);
      notifyListeners();
    }
  }

  Future<void> updateMusicVolume(double value) async {
    _musicVolume = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_musicVolumeKey, value);
    notifyListeners();
  }

  Future<void> updateEffectsVolume(double value) async {
    _effectsVolume = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_effectsVolumeKey, value);
    notifyListeners();
  }

  Future<void> updateLanguage(String value) async {
    _language = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value);
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, _isDarkMode);
    notifyListeners();
  }

  Future<void> setLastRoomId(String? roomId) async {
    _lastRoomId = roomId;
    final prefs = await SharedPreferences.getInstance();
    if (roomId == null) {
      await prefs.remove(_lastRoomIdKey);
    } else {
      await prefs.setString(_lastRoomIdKey, roomId);
    }
    notifyListeners();
  }

  String _getDefaultAvatar(String name) {
    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&size=256&background=random';
  }

  String t(String key, {Map<String, String>? args}) {
    return AppTranslations.translate(key, _language, args: args);
  }

  void resetInitializationFlag() {
    _isInitialized = false;
    notifyListeners();
  }

  Future<bool> linkAccountWithGoogle() async {
    try {
      final user = await _authService.linkWithGoogle();
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final existingName = _user?.name;
        final name = (existingName != null && existingName.isNotEmpty && existingName != 'Giocatore')
            ? existingName
            : (user.displayName ?? 'Giocatore');
        final photo = user.photoURL ?? _user?.avatarUrl ?? _getDefaultAvatar(name);
        await prefs.setString(_nameKey, name);
        await prefs.setString(_avatarKey, photo);
        await _syncProfile(user.uid, name, photo);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Errore durante linkAccountWithGoogle: $e');
      rethrow;
    }
  }

  Future<bool> linkAccountWithCredential(AuthCredential credential) async {
    try {
      final user = await _authService.linkWithProviderCredential(credential);
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final existingName = _user?.name;
        final name = (existingName != null && existingName.isNotEmpty && existingName != 'Giocatore')
            ? existingName
            : (user.displayName ?? 'Giocatore');
        final photo = user.photoURL ?? _user?.avatarUrl ?? _getDefaultAvatar(name);
        await prefs.setString(_nameKey, name);
        await prefs.setString(_avatarKey, photo);
        await _syncProfile(user.uid, name, photo);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Errore durante linkAccountWithCredential: $e');
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final existingName = _user?.name;
        final name = (existingName != null && existingName.isNotEmpty && existingName != 'Giocatore')
            ? existingName
            : (user.displayName ?? 'Giocatore');
        final photo = user.photoURL ?? _getDefaultAvatar(name);
        await prefs.setString(_nameKey, name);
        await prefs.setString(_avatarKey, photo);
        resetInitializationFlag();
        await init();
      }
    } catch (e) {
      debugPrint('Errore in signInWithGoogle: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_nameKey);
      await prefs.remove(_avatarKey);
      _user = null;
      resetInitializationFlag();
      await init();
    } catch (e) {
      debugPrint('Errore in signOut: $e');
      rethrow;
    }
  }
}
