import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../models/room.dart';
import '../widgets/custom_button.dart';
import 'game_over_screen.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final TextEditingController _notesController = TextEditingController();
  late ConfettiController _confettiController;
  int? _lastTurnIndex;
  final Set<String> _previouslySavedPlayers = {};
  String? _lastShownSystemMessage;
  
  // Timed mode state
  Timer? _turnTimer;
  int _countdown = 3;
  int _gameTimeLeft = 0;
  bool _isStarting = false;
  bool _timerRunning = false;
  bool _startRequested = false;
  bool _showingFeedback = false;
  String? _feedbackIdentity;
  String? _feedbackImageUrl;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final volume = context.read<UserProvider>().musicVolume;
      context.read<GameProvider>().playLobbyMusic(volume);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gameProvider = Provider.of<GameProvider>(context);
    final room = gameProvider.currentRoom;
    final isMyTurn = gameProvider.isMyTurn;
    final me = room?.players[gameProvider.currentPlayerId];

    if (room != null && isMyTurn && me != null && !me.isSaved) {
      if (_lastTurnIndex == null || _lastTurnIndex != room.turnIndex) {
        _lastTurnIndex = room.turnIndex;
        
        // Reset Timed Mode states
        _startRequested = false;
        _isStarting = false;
        _timerRunning = false;
        _turnTimer?.cancel();
        
        // Play turn notification sound
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        gameProvider.playTurnNotification(userProvider.effectsVolume);
        
        // Add a new line with a bullet point for the current turn
        String prefix = "\n• ";
        if (_notesController.text.isEmpty) {
          prefix = "• ";
        }
        
        // Use addPostFrameCallback to modify controller outside of build/didChangeDependencies cycle
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _notesController.text += prefix;
              _notesController.selection = TextSelection.fromPosition(
                TextPosition(offset: _notesController.text.length),
              );
            });
          }
        });
      }
    }

    // Shared timer refresh for everyone
    if (room?.mode == GameMode.timed && room?.timerEndTime != null) {
      if (_turnTimer == null || !_turnTimer!.isActive) {
        _turnTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          
          final gp = context.read<GameProvider>();
          final currentRoom = gp.currentRoom;
          final isMyTurn = gp.isMyTurn;
          
          setState(() {}); // Trigger rebuild to update timer display
          
          // If I am the active player and timer reached 0, handle transition/end
          if (isMyTurn && currentRoom != null && currentRoom.timerEndTime != null) {
            final now = gp.synchronizedTime;
            if (now >= currentRoom.timerEndTime!) {
              if (currentRoom.timerType == 'countdown') {
                _beginGameTimer(currentRoom.timeLimit);
              } else if (currentRoom.timerType == 'active' && !_showingFeedback) {
                timer.cancel();
                _guess(false); // Time's up!
              }
            }
          }
        });
      }
    } else if (room?.timerEndTime == null) {
      _turnTimer?.cancel();
      _turnTimer = null;
    }

    // Listen for system messages
    if (room?.lastSystemMessage != null && room?.lastSystemMessage != _lastShownSystemMessage) {
      _lastShownSystemMessage = room!.lastSystemMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(room!.lastSystemMessage!),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _notesController.dispose();
    _turnTimer?.cancel();
    super.dispose();
  }

  void _startTimedTurn(int initialTime) async {
    final gp = context.read<GameProvider>();
    final now = gp.synchronizedTime;
    await gp.syncTimer(now + 3000, 'countdown');
  }

  void _beginGameTimer(int seconds) async {
    final gp = context.read<GameProvider>();
    final now = gp.synchronizedTime;
    await gp.syncTimer(now + (seconds * 1000), 'active');
  }

  void _guess(bool correct) async {
    final effectsVolume = context.read<UserProvider>().effectsVolume;
    _turnTimer?.cancel();
    
    final room = context.read<GameProvider>().currentRoom;
    final me = room?.players[context.read<GameProvider>().currentPlayerId];
    
    // Always show confetti if correct
    if (correct) {
      _confettiController.play();
      context.read<UserProvider>().incrementWins();
    }

    if (room?.mode == GameMode.timed || correct) {
      // Show feedback for 3 seconds before advancing if it's Timed mode OR if the player guessed correctly
      setState(() {
        _timerRunning = false;
        _isStarting = false;
        _showingFeedback = true;
        _feedbackIdentity = me?.identityName;
        _feedbackImageUrl = me?.identityImageUrl;
      });

      await Future.delayed(const Duration(seconds: 3));
      
      if (mounted) {
        setState(() {
          _showingFeedback = false;
        });
        context.read<GameProvider>().guessIdentity(correct, effectsVolume);
      }
    } else {
      // Just pass/fail immediately for non-timed modes when not guessed
      setState(() {
        _timerRunning = false;
        _isStarting = false;
      });
      
      context.read<GameProvider>().guessIdentity(correct, effectsVolume);
    }
  }

  int _calculateMyRank(Room room, String myId) {
    var savedPlayers = room.players.values.where((p) => p.isSaved && p.savedAt != null).toList();
    savedPlayers.sort((a, b) => a.savedAt!.compareTo(b.savedAt!));
    int index = savedPlayers.indexWhere((p) => p.id == myId);
    return index >= 0 ? index + 1 : 0;
  }

  void _showModeInfo(BuildContext context, GameMode mode) {
    final userProvider = context.read<UserProvider>();
    String title = '';
    String instructions = '';

    switch (mode) {
      case GameMode.preset:
        title = userProvider.t('preset_mode');
        instructions = userProvider.t('classic_instructions');
        break;
      case GameMode.timed:
        title = userProvider.t('timed_mode');
        instructions = userProvider.t('timed_instructions');
        break;
      case GameMode.custom:
        title = userProvider.t('custom_mode');
        instructions = userProvider.t('custom_instructions');
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(instructions),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(userProvider.t('close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final userProvider = context.watch<UserProvider>();
    final room = gameProvider.currentRoom;
    final isMyTurn = gameProvider.isMyTurn;
    final activePlayer = gameProvider.activePlayer;
    final me = room?.players[gameProvider.currentPlayerId];

    if (room?.status == RoomStatus.finished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GameOverScreen()));
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (room == null) {
      if (gameProvider.currentPlayerId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ModalRoute.of(context)?.isCurrent == true) {
            context.read<UserProvider>().setLastRoomId(null);
            Navigator.of(context).popUntil((route) => route.isFirst);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.read<UserProvider>().t('room_closed_host'))),
            );
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (activePlayer == null || me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Notifica quando qualcuno indovina
    if (room != null) {
      if (room.lastSystemMessage != null && room.lastSystemMessage!.startsWith('DEBUG ERROR:')) {
         WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(room.lastSystemMessage!),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
         });
      }

      for (var player in room.players.values) {
        if (player.isSaved && !_previouslySavedPlayers.contains(player.id)) {
          _previouslySavedPlayers.add(player.id);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(userProvider.t('player_saved', args: {'name': player.name})),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
        }
      }
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final userProvider = context.read<UserProvider>();
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(userProvider.t('leave_game')),
            content: Text(gameProvider.isHost ? userProvider.t('exit_warning_game') : userProvider.t('exit_warning_player_game')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(userProvider.t('cancel'))),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(userProvider.t('exit'), style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (shouldPop == true) {
          final name = userProvider.user?.name;
          await gameProvider.leaveRoom(name: name, language: userProvider.language);
          await userProvider.setLastRoomId(null);
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            isMyTurn && !me.isSaved 
              ? context.read<UserProvider>().t('your_turn') 
              : context.read<UserProvider>().t('active_turn', args: {'name': activePlayer.name}), 
            style: Theme.of(context).textTheme.titleLarge
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showModeInfo(context, room.mode),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0, top: me.isSaved ? 70.0 : 24.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final isIncoming = child.key == ValueKey(room.turnIndex);
                    final offsetAnimation = Tween<Offset>(
                      begin: isIncoming ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
                    
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(room.turnIndex),
                    child: (_showingFeedback) 
                      ? _buildFeedbackView(context)
                      : (isMyTurn && !me.isSaved ? _buildActivePlayerView(context) : _buildOtherPlayerView(context, activePlayer)),
                  ),
                ),
              ),
              if (me.isSaved || room.mode == GameMode.timed)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: (me.isSaved ? Colors.green : Colors.orange).withOpacity(0.9),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        if (me.isSaved)
                          Text(
                            '${context.read<UserProvider>().t('saved_rank', args: {'rank': _calculateMyRank(room, me.id).toString()})}\n${context.read<UserProvider>().t('wait_finish')}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        if (room.mode == GameMode.timed)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              userProvider.t('your_score', args: {'score': me.score.toString()}),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: pi / 2, // downwards
                  maxBlastForce: 5,
                  minBlastForce: 2,
                  emissionFrequency: 0.05,
                  numberOfParticles: 30,
                  gravity: 0.2,
                  colors: const [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.purple],
                ),
              ),
              if (room.mode == GameMode.timed && room.timerEndTime != null)
                Positioned(
                  top: 10,
                  right: 20,
                  child: Builder(
                    builder: (context) {
                      final now = context.read<GameProvider>().synchronizedTime;
                      int timeLeft = ((room.timerEndTime! - now) / 1000).ceil();
                      if (timeLeft < 0) timeLeft = 0;
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: room.timerType == 'countdown' ? Colors.red : Colors.black,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          room.timerType == 'countdown' ? '$timeLeft' : '${timeLeft}s',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                        ),
                      );
                    }
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivePlayerView(BuildContext context) {
    final gameProvider = context.read<GameProvider>();
    final userProvider = context.read<UserProvider>();
    final room = gameProvider.currentRoom!;
    final me = room.players[gameProvider.currentPlayerId!];

    String roundText = room.isOvertime 
        ? userProvider.t('overtime_round', args: {'round': room.currentRound.toString()})
        : userProvider.t('round_number', args: {'round': room.currentRound.toString()});

    return Stack(
      children: [
        Column(
          key: const ValueKey('active_view'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (room.mode == GameMode.timed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: room.isOvertime ? Colors.orange : Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Text(
                      roundText,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Center(
                child: (me != null && me.remainingChanges > 0 && room.mode == GameMode.preset)
                  ? ElevatedButton.icon(
                      onPressed: gameProvider.isLoading 
                        ? null 
                        : () => gameProvider.changeCharacter(userProvider.language),
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        '${userProvider.t('change_character_btn')} (${userProvider.t('remaining_changes', args: {'count': me.remainingChanges.toString()})})',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    )
                  : const SizedBox(height: 48), // Placeholder
              ),
            ),
            Text(
              context.read<UserProvider>().t('guess_instructions'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).primaryColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TextField(
                controller: _notesController,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: context.read<UserProvider>().t('notes_hint'),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: CustomButton(
                      text: context.read<UserProvider>().t('guessed'),
                      color: Theme.of(context).colorScheme.secondary,
                      onPressed: () => _guess(true),
                      playSound: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomButton(
                      text: room.mode == GameMode.timed 
                        ? userProvider.t('not_guessed')
                        : context.read<UserProvider>().t('pass'),
                      isSecondary: true,
                      color: Theme.of(context).primaryColor,
                      onPressed: (room.mode == GameMode.timed && (_timerRunning || _isStarting)) 
                        ? null 
                        : () => _guess(false),
                      playSound: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (room.mode == GameMode.timed && room.timerEndTime == null)
          Positioned.fill(
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          child: CustomButton(
                            text: userProvider.t('start_game'),
                            onPressed: () => _startTimedTurn(room.timeLimit),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: (gameProvider.isLoading || (me != null && me.remainingChanges <= 0)) 
                            ? null 
                            : () => gameProvider.changeCharacter(userProvider.language),
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            '${userProvider.t('change_character_btn')} (${userProvider.t('remaining_changes', args: {'count': me?.remainingChanges.toString() ?? '0'})})'
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOtherPlayerView(BuildContext context, dynamic activePlayer) {
    final gameProvider = context.read<GameProvider>();
    final userProvider = context.read<UserProvider>();
    final room = gameProvider.currentRoom!;

    String roundText = room.isOvertime 
        ? userProvider.t('overtime_round', args: {'round': room.currentRound.toString()})
        : userProvider.t('round_number', args: {'round': room.currentRound.toString()});

    return SingleChildScrollView(
      child: Column(
        key: const ValueKey('other_view'),
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        if (room.mode == GameMode.timed)
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: room.isOvertime ? Colors.orange : Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Text(
                  roundText,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              userProvider.t('identity_is', args: {'name': activePlayer.name}),
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 40),
        if (room.mode == GameMode.timed)
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Text(
              context.read<UserProvider>().t('player_score', args: {
                'name': activePlayer.name,
                'score': activePlayer.score.toString(),
              }),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
              textAlign: TextAlign.center,
            ),
          ),
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white.withOpacity(0.05) 
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white24 
                  : Colors.black26, 
              width: 2
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: activePlayer.identityImageUrl != null
              ? Image.network(
                  activePlayer.identityImageUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        (activePlayer.identityName?.isNotEmpty ?? false) ? activePlayer.identityName![0].toUpperCase() : '?',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                    );
                  },
                )
              : Icon(Icons.help_outline, size: 120, color: Theme.of(context).colorScheme.secondary),
          ),
        ),
        const SizedBox(height: 20),
        _buildCharacterName(context, activePlayer.identityName),
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              context.read<UserProvider>().t('yes_no_instructions'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      ],
    ));
  }

  Widget _buildFeedbackView(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          userProvider.t('your_identity_was'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange, width: 3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _feedbackImageUrl != null
              ? Image.network(
                  _feedbackImageUrl!,
                  fit: BoxFit.contain,
                )
              : Center(
                  child: Text(
                    (_feedbackIdentity?.isNotEmpty ?? false) ? _feedbackIdentity![0].toUpperCase() : '?',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
          ),
        ),
        const SizedBox(height: 20),
        _buildCharacterName(context, _feedbackIdentity),
        const SizedBox(height: 40),
        const CircularProgressIndicator(color: Colors.orange),
      ],
    );
  }

  Widget _buildCharacterName(BuildContext context, String? identityName) {
    if (identityName == null) {
      return Text(
        context.read<UserProvider>().language == 'it' ? 'Caricamento...' : 'Loading...',
        style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Theme.of(context).colorScheme.secondary),
        textAlign: TextAlign.center,
      );
    }

    if (identityName.contains('(') && identityName.contains(')')) {
      final parts = identityName.split('(');
      final name = parts[0].trim();
      final franchise = '(${parts[1].trim()}';

      return Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              franchise,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        identityName,
        style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Theme.of(context).colorScheme.secondary),
        textAlign: TextAlign.center,
      ),
    );
  }
}
