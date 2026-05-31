import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_button.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  void _submit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Per favore, inserisci un nickname!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    await context.read<UserProvider>().setupProfile(_nameController.text.trim());
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Benvenuto!',
                  style: Theme.of(context).textTheme.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Come vuoi farti chiamare dagli altri giocatori?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 60),
                TextField(
                  controller: _nameController,
                  maxLength: 15,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: "",
                    labelText: 'Il tuo Nickname',
                    labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    prefixIcon: const Icon(Icons.face, color: Colors.black),
                    filled: true,
                    fillColor: Colors.white,
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
                const SizedBox(height: 40),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: 'COMINCIAMO!',
                      onPressed: _submit,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
