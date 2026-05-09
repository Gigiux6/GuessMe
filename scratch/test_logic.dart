void main() {
  int targetPoints = 3;
  int turnIndex = 1;
  int characterChangesLimit = 3;
  List<String> turnOrder = ['P1', 'P2'];
  String currentPlayerId = 'P2';
  bool isCorrect = true;

  Map<String, dynamic> playersData = {
    'P1': {'id': 'P1', 'score': 3, 'isSaved': false},
    'P2': {'id': 'P2', 'score': 2, 'isSaved': false},
  };

  int newScore = playersData[currentPlayerId]['score'] + (isCorrect ? 1 : 0);
  
  Set<String> eliminatedIds = {};
  
  int currentCycle = turnIndex ~/ turnOrder.length;
  int tempNextIndex = turnIndex + 1;
  while (true) {
    String nextId = turnOrder[tempNextIndex % turnOrder.length];
    if (!eliminatedIds.contains(nextId)) break;
    tempNextIndex++;
  }
  
  int nextCycle = tempNextIndex ~/ turnOrder.length;
  bool roundEnded = nextCycle > currentCycle;
  
  Map<String, dynamic> roomUpdates = {};
  Map<String, dynamic> playersUpdates = {};

  if (roundEnded) {
    int maxScore = 0;
    
    for (var p in playersData.values) {
       if (!eliminatedIds.contains(p['id'])) {
          int pScore = (p['id'] == currentPlayerId) ? newScore : p['score'];
          if (pScore > maxScore) maxScore = pScore;
       }
    }
    
    if (maxScore >= targetPoints) {
       List<dynamic> tiedLeaders = playersData.values.where((p) {
           int pScore = (p['id'] == currentPlayerId) ? newScore : p['score'];
           return pScore == maxScore;
       }).toList();
       
       if (tiedLeaders.length == 1) {
           roomUpdates['status'] = 'finished';
           print('Game Over! Winner: ${tiedLeaders.first['id']}');
       } else {
           for (var p in playersData.values) {
               int pScore = (p['id'] == currentPlayerId) ? newScore : p['score'];
               if (pScore < maxScore) {
                   playersUpdates['${p['id']}/isSaved'] = true;
                   eliminatedIds.add(p['id']);
               }
           }
           roomUpdates['isOvertime'] = true;
           roomUpdates['currentRound'] = 1;
       }
    } else {
       roomUpdates['currentRound'] = 2; // Hardcoded for test
    }
  }
  
  int finalNextIndex = turnIndex + 1;
  while (true) {
    String nextId = turnOrder[finalNextIndex % turnOrder.length];
    if (!eliminatedIds.contains(nextId)) break;
    finalNextIndex++;
  }
  
  String nextPlayerId = turnOrder[finalNextIndex % turnOrder.length];
  playersUpdates['$nextPlayerId/remainingChanges'] = characterChangesLimit;

  print('Final Next Index: $finalNextIndex');
  print('Next Player Id: $nextPlayerId');
  print('Room Updates: $roomUpdates');
  print('Players Updates: $playersUpdates');
}
