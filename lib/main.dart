import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/game_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

import 'screens/profile_setup_screen.dart';
import 'providers/user_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final userProvider = UserProvider();
  userProvider.init(); // Inizializzazione in background

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider.value(value: userProvider),
      ],
      child: const GuessMeApp(),
    ),
  );
}

class GuessMeApp extends StatefulWidget {
  const GuessMeApp({super.key});

  @override
  State<GuessMeApp> createState() => _GuessMeAppState();
}

class _GuessMeAppState extends State<GuessMeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final gameProvider = context.read<GameProvider>();
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      gameProvider.pauseLobbyMusic();
    } else if (state == AppLifecycleState.resumed) {
      gameProvider.resumeLobbyMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    
    Widget home;
    if (!userProvider.isInitialized) {
      home = const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (userProvider.user == null) {
      home = const ProfileSetupScreen();
    } else {
      home = const HomeScreen();
    }

    return MaterialApp(
      key: const ValueKey('AppRoot'),
      title: 'Guess Me',
      theme: AppTheme.getTheme(userProvider.isDarkMode),
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}
