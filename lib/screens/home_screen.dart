import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../widgets/custom_button.dart';
import 'lobby_screen.dart';
import 'qr_scanner_screen.dart';
import '../providers/user_provider.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/debug_logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final volume = context.read<UserProvider>().musicVolume;
      context.read<GameProvider>().playLobbyMusic(volume);
    });
  }

  void _createRoom() async {
    final _log = DebugLogger.instance;
    final userProvider = context.read<UserProvider>();
    String? name = userProvider.user?.name;
    
    if (name == null || name.isEmpty) {
      name = _nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userProvider.t('enter_name_error'))),
        );
        return;
      }
      await userProvider.setupProfile(name);
    }
    
    try {
      _log.log('HOME', '_createRoom: calling gameProvider.createRoom...');
      await context.read<GameProvider>().createRoom(
        name, 
        userProvider.user!.uid, 
        avatarUrl: userProvider.user?.avatarUrl
      );
      _log.log('HOME', '_createRoom: createRoom returned. mounted=$mounted, currentRoom=${context.read<GameProvider>().currentRoom?.id}');
      if (mounted) {
        _log.log('HOME', '_createRoom: saving room id and navigating to lobby...');
        await context.read<GameProvider>().saveRoomId(context.read<GameProvider>().currentRoom?.id, userProvider);
        _log.log('HOME', '_createRoom: Navigator.pushReplacement to LobbyScreen NOW');
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
      }
    } catch (e) {
      _log.log('HOME', '_createRoom EXCEPTION: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${userProvider.t('create_room_error')}: $e')),
        );
      }
    }
  }

  void _joinRoom() async {
    final userProvider = context.read<UserProvider>();
    String? name = userProvider.user?.name;

    if (name == null || name.isEmpty) {
      name = _nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userProvider.t('enter_name_error'))),
        );
        return;
      }
      await userProvider.setupProfile(name);
    }

    if (_roomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userProvider.t('enter_room_error'))),
      );
      return;
    }
    
    String roomId = _roomController.text.trim().toUpperCase();
    bool success = await context.read<GameProvider>().joinRoom(
      roomId, 
      name, 
      userProvider.user!.uid,
      avatarUrl: userProvider.user?.avatarUrl
    );
    if (!mounted) return;
    
    if (success) {
      await context.read<GameProvider>().saveRoomId(roomId, userProvider);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
    } else {
      await userProvider.setLastRoomId(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userProvider.t('room_not_found')),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
      }
    }
  }

  void _showInstructions() {
    final userProvider = context.read<UserProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(userProvider.t('how_to_play'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(userProvider.t('game_instructions'), style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(userProvider.t('close'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isLoading = context.watch<GameProvider>().isLoading;
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    return GestureDetector(
      onTap: () {
        // Resume/Play music on first interaction for browser compatibility
        final volume = context.read<UserProvider>().musicVolume;
        context.read<GameProvider>().playLobbyMusic(volume);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.info_outline, size: 28),
            onPressed: _showInstructions,
          ),
          actions: [
            IconButton(
              icon: Icon(
                userProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                size: 28,
              ),
              onPressed: () => userProvider.toggleDarkMode(),
            ),
            IconButton(
              icon: const Icon(Icons.settings, size: 32),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      userProvider.t('app_title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 46),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (user != null) ...[
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      ),
                      child: Container(
                        width: 100,
                        height: 100,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 3),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: user.avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Icon(Icons.person),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userProvider.t('welcome', args: {'name': user.name}),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (userProvider.lastRoomId != null && !isLoading) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: userProvider.t('rejoin_room'),
                        color: Colors.orangeAccent,
                        onPressed: () {
                          _roomController.text = userProvider.lastRoomId!;
                          _joinRoom();
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  if (isLoading)
                    const CircularProgressIndicator()
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: userProvider.t('create_room'),
                        onPressed: _createRoom,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Divider(color: Colors.white54),
                    const SizedBox(height: 40),
                    TextField(
                      controller: _roomController,
                      maxLength: 6,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: "",
                        filled: true,
                        fillColor: Colors.white,
                        labelText: userProvider.t('room_code'),
                        labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        prefixIcon: const Icon(Icons.meeting_room, color: Colors.black),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: userProvider.t('join_room'),
                            onPressed: _joinRoom,
                            isSecondary: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomButton(
                            text: userProvider.t('qr_scan'),
                            onPressed: () async {
                              final scannedCode = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                              );
                              if (scannedCode != null && scannedCode is String) {
                                _roomController.text = scannedCode;
                                _joinRoom();
                              }
                            },
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
