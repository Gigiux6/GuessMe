import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../models/room.dart';
import '../models/player.dart';
import '../widgets/custom_button.dart';
import 'setup_custom_screen.dart';
import 'game_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/game_packs.dart';
import 'home_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String? _lastShownSystemMessage;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final volume = context.read<UserProvider>().musicVolume;
      context.read<GameProvider>().playLobbyMusic(volume);
    });
  }

  void _handleBackPress(BuildContext context, GameProvider gameProvider, bool isHost) async {
    final userProvider = context.read<UserProvider>();
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(userProvider.t('are_you_sure')),
        content: Text(isHost ? userProvider.t('exit_warning_host') : userProvider.t('exit_warning_player')),
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
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
    }
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
    final room = gameProvider.currentRoom;
    final isHost = gameProvider.isHost;

    if (room == null) {
      // Se siamo qui e il room è null, aspettiamo un attimo prima di dare errore,
      // a meno che non sappiamo per certo che la stanza non esiste più (es. host uscito).
      if (gameProvider.currentPlayerId == null) {
         WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ModalRoute.of(context)?.isCurrent == true) {
            context.read<UserProvider>().setLastRoomId(null);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => HomeScreen()),
              (route) => false,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.read<UserProvider>().t('room_closed_host'))),
            );
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (room.status == RoomStatus.setup && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SetupCustomScreen()));
      } else if (room.status == RoomStatus.playing && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GameScreen()));
      }
      
      if (room.lastSystemMessage != null && room.lastSystemMessage != _lastShownSystemMessage) {
        _lastShownSystemMessage = room.lastSystemMessage;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(room.lastSystemMessage!),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        _handleBackPress(context, gameProvider, isHost);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('${context.read<UserProvider>().t('room')}: ${room.id}'),
          centerTitle: true,
          leadingWidth: 110,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _handleBackPress(context, gameProvider, isHost),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showModeInfo(context, room.mode),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(context.watch<UserProvider>().isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => context.read<UserProvider>().toggleDarkMode(),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return Row(
                    children: [
                      Expanded(flex: 1, child: _buildQRView(context, room.id)),
                      const VerticalDivider(color: Colors.white54, width: 40),
                      Expanded(flex: 2, child: _buildMainLobbyView(context, room, gameProvider, isHost)),
                    ],
                  );
                } else {
                  return _buildMainLobbyView(context, room, gameProvider, isHost);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRView(BuildContext context, String roomId) {
    final userProvider = context.read<UserProvider>();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(userProvider.t('invita_amici', args: {}), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black, width: 4),
          ),
          child: QrImageView(
            data: roomId,
            version: QrVersions.auto,
            size: 200.0,
          ),
        ),
        const SizedBox(height: 20),
        Text('${userProvider.t('code_label')}: $roomId', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildMainLobbyView(BuildContext context, Room room, GameProvider gameProvider, bool isHost) {
    final userProvider = context.watch<UserProvider>();
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              if (MediaQuery.of(context).size.width <= 800) ...[
                _buildQRView(context, room.id),
                const SizedBox(height: 40),
              ],
              Text(
                userProvider.t('players', args: {'count': room.players.length.toString()}),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ...room.players.values.map((player) => Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: player.avatarUrl ?? '',
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                            placeholder: (context, url) => const CircularProgressIndicator(),
                            errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.black),
                          ),
                        ),
                      ),
                      title: Text(
                        player.name, 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)
                      ),
                      trailing: player.id == room.hostId ? const Icon(Icons.star, color: Colors.amber) : null,
                    ),
                  )),
              const Divider(color: Colors.white54, height: 40),
              _buildHostSettings(context, gameProvider, isHost),
            ],
          ),
        ),
        if (isHost)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              children: [
                if (room.players.length < 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      userProvider.t('min_players_error'),
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                CustomButton(
                  text: userProvider.t('start_game'),
                  onPressed: room.players.length < 2 
                    ? null 
                    : () {
                        gameProvider.startGame();
                      },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHostSettings(BuildContext context, GameProvider gameProvider, bool isHost) {
    final userProvider = context.read<UserProvider>();
    final room = gameProvider.currentRoom;
    
    final segmentedButtonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.black;
        }
        return Colors.white;
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return Colors.black;
      }),
      side: WidgetStateProperty.all(const BorderSide(color: Colors.black, width: 2)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(userProvider.t('host_settings'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 20),
        Text(userProvider.t('character_changes')),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: room?.characterChangesLimit ?? 0,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              iconEnabledColor: Colors.black,
              iconDisabledColor: Colors.black,
              selectedItemBuilder: (BuildContext context) {
                return [0, 1, 2, 3].map<Widget>((int value) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value.toString(),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList();
              },
              items: [0, 1, 2, 3].map((val) => DropdownMenuItem(
                value: val,
                child: Text(val.toString(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              )).toList(),
              onChanged: isHost ? (val) {
                if (val != null) {
                  gameProvider.updateCharacterChangesLimit(val);
                }
              } : null,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(userProvider.t('game_mode')),
        const SizedBox(height: 10),
        SegmentedButton<GameMode>(
          style: segmentedButtonStyle,
          segments: [
            ButtonSegment(value: GameMode.preset, label: Text(userProvider.t('preset_mode'), style: const TextStyle(fontSize: 12))),
            ButtonSegment(value: GameMode.timed, label: Text(userProvider.t('timed_mode'), style: const TextStyle(fontSize: 12))),
            ButtonSegment(value: GameMode.custom, label: Text(userProvider.t('custom_mode'), style: const TextStyle(fontSize: 12))),
          ],
          selected: {room?.mode ?? GameMode.preset},
          onSelectionChanged: isHost ? (Set<GameMode> newSelection) {
            gameProvider.updateRoomSettings(mode: newSelection.first);
          } : null,
        ),
        if ((room?.mode ?? GameMode.preset) == GameMode.timed) ...[
          const SizedBox(height: 20),
          Text(userProvider.t('time_limit')),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            style: segmentedButtonStyle,
            segments: const [
              ButtonSegment(value: 60, label: Text('1 min')),
              ButtonSegment(value: 90, label: Text('1.5 min')),
              ButtonSegment(value: 120, label: Text('2 min')),
            ],
            selected: {room?.timeLimit ?? 60},
            onSelectionChanged: isHost ? (newSelection) => gameProvider.updateRoomSettings(timeLimit: newSelection.first) : null,
          ),
          const SizedBox(height: 20),
          Text(userProvider.t('target_points')),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            style: segmentedButtonStyle,
            segments: const [
              ButtonSegment(value: 3, label: Text('3')),
              ButtonSegment(value: 5, label: Text('5')),
              ButtonSegment(value: 7, label: Text('7')),
            ],
            selected: {room?.targetPoints ?? 3},
            onSelectionChanged: isHost ? (newSelection) => gameProvider.updateRoomSettings(targetPoints: newSelection.first) : null,
          ),
        ],
        if ((room?.mode ?? GameMode.preset) != GameMode.custom) ...[
          const SizedBox(height: 20),
          Text(userProvider.t('select_pack')),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: GamePacksData.packs.map((pack) {
              final isSelected = (room?.presetPack ?? 'cinema') == pack.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ChoiceChip(
                  backgroundColor: Colors.white,
                  selectedColor: Colors.black,
                  disabledColor: isSelected ? Colors.black : Colors.white,
                  side: const BorderSide(color: Colors.black, width: 2),
                  label: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Text(
                      '${pack.icon} ${userProvider.t(pack.id).toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  selected: isSelected,
                  onSelected: isHost ? (selected) {
                    if (selected) {
                      gameProvider.updateRoomSettings(presetPack: pack.id);
                    }
                  } : null,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
