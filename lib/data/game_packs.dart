class GameIdentity {
  final String name;
  final String imageUrl;

  const GameIdentity({required this.name, required this.imageUrl});
}

class GamePack {
  final String id;
  final String name;
  final String icon;
  final List<GameIdentity> identities;

  const GamePack({required this.id, required this.name, required this.icon, required this.identities});
}

class GamePacksData {
  static List<GamePack> packs = [];
  
  // Metodo per inizializzare i dati (chiamato all'avvio)
  static void initialize(List<GamePack> loadedPacks) {
    packs = loadedPacks;
  }
}
