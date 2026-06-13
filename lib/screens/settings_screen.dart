import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/user_provider.dart';
import '../providers/game_provider.dart';
import '../widgets/custom_button.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    
    final pink = Theme.of(context).primaryColor;
    final cyan = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(userProvider.t('settings')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              userProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              size: 28,
            ),
            onPressed: () => userProvider.toggleDarkMode(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Edit Profile Button (First)
            _buildNeubrutalistCard(
              color: pink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(userProvider.t('profile'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[300],
                        ),
                        child: ClipOval(
                          child: (user?.avatarUrl != null && user!.avatarUrl.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: user!.avatarUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.black),
                                )
                              : const Icon(Icons.person, color: Colors.grey, size: 40),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          user?.name ?? userProvider.t('your_name'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: userProvider.t('edit_profile'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    ),
                    color: cyan,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Stats Card
            _buildNeubrutalistCard(
              color: cyan,
              child: Column(
                children: [
                  Text(userProvider.t('stats'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                  const SizedBox(height: 10),
                  Text(userProvider.t('games_won', args: {'count': (user?.gamesWon ?? 0).toString()}), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Sound Card
            _buildNeubrutalistCard(
              color: pink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(userProvider.t('music_volume'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                  const SizedBox(height: 10),
                  Slider(
                    value: userProvider.musicVolume,
                    min: 0,
                    max: 1,
                    onChanged: (value) {
                      userProvider.updateMusicVolume(value);
                      context.read<GameProvider>().playLobbyMusic(value);
                    },
                    activeColor: Colors.black,
                    inactiveColor: Colors.black26,
                  ),
                  const SizedBox(height: 20),
                  Text(userProvider.t('effects_volume'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                  const SizedBox(height: 10),
                  Slider(
                    value: userProvider.effectsVolume,
                    min: 0,
                    max: 1,
                    onChanged: (value) => userProvider.updateEffectsVolume(value),
                    activeColor: Colors.black,
                    inactiveColor: Colors.black26,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Language Card (Dropdown)
            _buildNeubrutalistCard(
              color: cyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(userProvider.t('language'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: userProvider.language,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                        dropdownColor: Colors.white,
                        items: const [
                          DropdownMenuItem(value: 'it', child: Text('Italiano 🇮🇹', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DropdownMenuItem(value: 'en', child: Text('English 🇺🇸', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DropdownMenuItem(value: 'es', child: Text('Español 🇪🇸', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DropdownMenuItem(value: 'de', child: Text('Deutsch 🇩🇪', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DropdownMenuItem(value: 'fr', child: Text('Français 🇫🇷', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                        ],
                        onChanged: (value) {
                          if (value != null) userProvider.updateLanguage(value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeubrutalistCard({required Widget child, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(8, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
