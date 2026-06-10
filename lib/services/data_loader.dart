import 'dart:convert';
import 'package:flutter/services.dart';
import '../data/game_packs.dart';

class DataLoader {
  static Future<List<GamePack>> loadGamePacks() async {
    try {
      final String response = await rootBundle.loadString('assets/data/characters.json');
      final Map<String, dynamic> data = json.decode(response);
      final List<dynamic> rawPacks = data['packs'] ?? [];
      
      return rawPacks.map((packData) {
        final List<dynamic> rawIdentities = packData['identities'] ?? [];
        
        return GamePack(
          id: packData['id'],
          name: packData['name'],
          icon: packData['icon'],
          identities: rawIdentities.map((idData) => GameIdentity(
            name: idData['name'],
            imageUrl: idData['imageUrl'],
          )).toList(),
        );
      }).toList();
    } catch (e) {
      print('Error loading characters.json: $e');
      return []; // Fallback empty list
    }
  }
}
