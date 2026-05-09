import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../models/player.dart';
import '../models/room.dart';
import '../widgets/custom_button.dart';
import 'lobby_screen.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  int _calculateMyRank(Room room, String myId) {
    if (room.mode == GameMode.timed) {
      // In timed mode, rank is based on points
      final myScore = room.players[myId]?.score ?? 0;
      final higherScores = room.players.values.where((p) => p.score > myScore).length;
      return higherScores + 1;
    }
    var savedPlayers = room.players.values.where((p) => p.isSaved && p.savedAt != null).toList();
    savedPlayers.sort((a, b) => a.savedAt!.compareTo(b.savedAt!));
    int index = savedPlayers.indexWhere((p) => p.id == myId);
    return index >= 0 ? index + 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final userProvider = context.watch<UserProvider>();
    final room = gameProvider.currentRoom;
    final effectsVolume = userProvider.effectsVolume;
    final me = room?.players[gameProvider.currentPlayerId];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (room?.status == RoomStatus.lobby && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
      }
    });

    if (room == null || me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final int rank = _calculateMyRank(room, me.id);
    final bool hasGuessed = room.mode == GameMode.timed 
        ? me.score >= room.targetPoints 
        : me.isSaved;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    userProvider.t('game_over'),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: isDark ? Colors.white : Colors.black
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                
                // Player's Result
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: hasGuessed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: hasGuessed ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        hasGuessed ? Icons.emoji_events : Icons.mood_bad,
                        size: 48,
                        color: hasGuessed ? Colors.amber : Colors.redAccent,
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          room.mode == GameMode.timed
                            ? '${userProvider.t('your_score', args: {'score': me.score.toString()})} (${rank}°)'
                            : hasGuessed 
                              ? userProvider.t('saved_rank', args: {'rank': rank.toString()})
                              : userProvider.t('not_guessed'),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                if (room.mode == GameMode.timed) ...[
                  // Final Ranking Section (Timed Mode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          userProvider.t('final_ranking'),
                          style: const TextStyle(
                            fontSize: 22, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.orange
                          ),
                        ),
                        const SizedBox(height: 15),
                        ...(room.players.values.toList()
                          ..sort((a, b) => b.score.compareTo(a.score)))
                          .map((p) {
                            final bool isMe = p.id == gameProvider.currentPlayerId;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: isMe ? Border.all(color: Colors.orange, width: 1) : null,
                              ),
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.grey.shade200,
                                  child: ClipOval(
                                    child: p.avatarUrl != null 
                                      ? Image.network(p.avatarUrl!, fit: BoxFit.cover)
                                      : const Icon(Icons.person, size: 20),
                                  ),
                                ),
                                title: Text(
                                  p.name, 
                                  style: TextStyle(
                                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                    color: Colors.black87
                                  )
                                ),
                                trailing: Text(
                                  '${p.score} ${userProvider.t('points')}',
                                  style: const TextStyle(
                                    color: Colors.orange, 
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                ] else ...[
                  // Identity Section (Classic/Custom Mode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        Text(
                          userProvider.t('your_identity_was'),
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: me.identityImageUrl != null
                              ? Image.network(me.identityImageUrl!, fit: BoxFit.contain)
                              : _buildPlaceholder(context, me.identityName),
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildCharacterName(context, userProvider, me.identityName),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 30),
                
                if (gameProvider.isHost)
                  CustomButton(
                    text: userProvider.t('back_to_lobby'),
                    onPressed: () => gameProvider.returnToLobby(effectsVolume),
                    color: Theme.of(context).primaryColor,
                  )
                else
                  Text(
                    userProvider.t('waiting_host_lobby'), 
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, String? name) {
    return Center(
      child: Text(
        (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : '?',
        style: Theme.of(context).textTheme.displayLarge,
      ),
    );
  }

  Widget _buildCharacterName(BuildContext context, UserProvider userProvider, String? identityName) {
    if (identityName == null) return const SizedBox.shrink();

    if (identityName.contains('(') && identityName.contains(')')) {
      final parts = identityName.split('(');
      final name = parts[0].trim();
      final franchise = '(${parts[1].trim()}';

      return Column(
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            franchise,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Text(
      identityName,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        color: Theme.of(context).colorScheme.secondary,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }
}
