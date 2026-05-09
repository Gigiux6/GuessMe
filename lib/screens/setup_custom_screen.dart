import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_button.dart';
import '../models/room.dart';
import 'game_screen.dart';

class SetupCustomScreen extends StatefulWidget {
  const SetupCustomScreen({super.key});

  @override
  State<SetupCustomScreen> createState() => _SetupCustomScreenState();
}

class _SetupCustomScreenState extends State<SetupCustomScreen> {
  final TextEditingController _identityController = TextEditingController();
  bool _submitted = false;

  void _submit() async {
    if (_identityController.text.trim().isEmpty) return;
    
    setState(() => _submitted = true);
    await context.read<GameProvider>().submitCustomIdentity(_identityController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final room = gameProvider.currentRoom;
    final isHost = gameProvider.isHost;

    if (room?.status == RoomStatus.playing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GameScreen()));
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.read<UserProvider>().t('prepare_identities')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_submitted) ...[
                Text(
                  context.read<UserProvider>().t('choose_identity_hint'),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _identityController,
                  decoration: InputDecoration(
                    labelText: context.read<UserProvider>().t('identity_name'),
                    prefixIcon: const Icon(Icons.person_pin),
                  ),
                ),
                const Spacer(),
                if (gameProvider.isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  CustomButton(
                    text: context.read<UserProvider>().t('confirm'),
                    onPressed: _submit,
                  ),
              ] else ...[
                Expanded(
                  child: Center(
                    child: Text(
                      context.read<UserProvider>().t('identity_sent'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                if (isHost)
                  CustomButton(
                    text: context.read<UserProvider>().t('start_game_now'),
                    onPressed: () {
                      gameProvider.assignCustomIdentities();
                    },
                  ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
