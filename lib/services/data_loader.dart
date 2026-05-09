import 'dart:convert';
import 'package:flutter/services.dart';
import '../data/game_packs.dart';

class DataLoader {
  static Future<List<GamePack>> loadGamePacks() async {
    try {
      final String response = await rootBundle.loadString('assets/data/characters.json');
      final data = await json.decode(response);
      
      List<GamePack> packs = [];
      for (var packData in data['packs']) {
        List<GameIdentity> identities = [];
        for (var idData in packData['identities']) {
          identities.add(GameIdentity(
            name: idData['name'],
            imageUrl: idData['imageUrl'],
          ));
        }
        
        packs.add(GamePack(
          id: packData['id'],
          name: packData['name'],
          icon: packData['icon'],
          identities: identities,
        ));
      }
      return packs;
    } catch (e) {
      print('Error loading characters.json: $e');
      return []; // Fallback empty list
    }
  }
}
