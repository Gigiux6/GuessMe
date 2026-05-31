import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_storage_service.dart';
import 'package:image_cropper/image_cropper.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  String? _selectedAvatar;
  bool _isUploading = false;
  bool _isLinking = false;
  final ProfileStorageService _profileStorageService = ProfileStorageService();
  
  // Cartoon/NFT style avatars
  final List<String> _avatars = [
    'https://api.dicebear.com/7.x/adventurer/png?seed=Knight',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Witch',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Wolf',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Mage',
    'https://api.dicebear.com/7.x/adventurer/png?seed=King',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Villager',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Ranger',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Blacksmith',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Healer',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _selectedAvatar = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.user?.uid;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userProvider.t('user_not_authenticated'))),
        );
      }
      return;
    }

    try {
      final XFile? image = await _profileStorageService.pickImageFromGallery();
      if (image == null) return;

      if (!mounted) return;
      final CroppedFile? croppedFile = await _profileStorageService.cropImage(image, context);
      if (croppedFile == null) return;

      setState(() {
        _isUploading = true;
      });

      final String downloadUrl = await _profileStorageService.uploadProfileImage(croppedFile, userId);

      await userProvider.updateAvatar(downloadUrl);

      if (mounted) {
        setState(() {
          _selectedAvatar = downloadUrl;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userProvider.t('photo_updated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userProvider.t('upload_error', args: {'error': e.toString()}))),
        );
      }
    }
  }

  void _signInGoogleAccount() async {
    final userProvider = context.read<UserProvider>();
    setState(() {
      _isLinking = true;
    });
    try {
      await userProvider.signInWithGoogle();
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userProvider.t('sign_in_success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        final String errorMessage = e.toString();
        if (errorMessage.contains('popup-closed-by-user') ||
            errorMessage.contains('canceled') ||
            errorMessage.contains('cancelled') ||
            errorMessage.contains('user-cancelled')) {
          return;
        }
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(userProvider.t('auth_error'), style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _linkGoogleAccount() async {
    final userProvider = context.read<UserProvider>();
    setState(() {
      _isLinking = true;
    });
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final success = await userProvider.linkAccountWithGoogle();
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userProvider.t('link_success'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        
        final String errorMessage = e.toString();
        if (errorMessage.contains('popup-closed-by-user') ||
            errorMessage.contains('canceled') ||
            errorMessage.contains('cancelled') ||
            errorMessage.contains('user-cancelled')) {
          return;
        }
        if (errorMessage.contains('già associato') ||
            errorMessage.contains('già in uso') ||
            errorMessage.contains('already-in-use') ||
            errorMessage.contains('already in use') ||
            errorMessage.contains('credential-already-in-use') ||
            errorMessage.contains('email-already-in-use')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(userProvider.t('account_in_use_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Text(
                userProvider.t('account_in_use_message'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(userProvider.t('cancel'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _signInGoogleAccount();
                  },
                  child: Text(userProvider.t('sign_in'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(userProvider.t('auth_error'), style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Text(errorMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  void _linkWithCredentials(AuthCredential credential) async {
    final userProvider = context.read<UserProvider>();
    setState(() {
      _isLinking = true;
    });
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      await userProvider.linkAccountWithCredential(credential);
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userProvider.t('link_success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        
        final String errorMessage = e.toString();
        if (errorMessage.contains('già associato') ||
            errorMessage.contains('già in uso') ||
            errorMessage.contains('already-in-use') ||
            errorMessage.contains('already in use') ||
            errorMessage.contains('credential-already-in-use') ||
            errorMessage.contains('email-already-in-use')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(userProvider.t('account_in_use_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Text(
                userProvider.t('account_in_use_message'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(userProvider.t('cancel'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _signInWithCredential(credential);
                  },
                  child: Text(userProvider.t('sign_in'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(userProvider.t('auth_error'), style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Text(errorMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  void _signInWithCredential(AuthCredential credential) async {
    final userProvider = context.read<UserProvider>();
    setState(() {
      _isLinking = true;
    });
    try {
      final user = await FirebaseAuth.instance.signInWithCredential(credential);
      if (user.user != null) {
        final prefs = await SharedPreferences.getInstance();
        final existingName = userProvider.user?.name;
        final name = (existingName != null && existingName.isNotEmpty && existingName != 'Giocatore')
            ? existingName
            : (user.user!.displayName ?? 'Giocatore');
        final photo = user.user!.photoURL ?? 'https://api.dicebear.com/7.x/adventurer/png?seed=Knight';
        await prefs.setString('user_name', name);
        await prefs.setString('user_avatar', photo);
        userProvider.resetInitializationFlag();
        await userProvider.init();
      }
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userProvider.t('sign_in_success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(userProvider.t('auth_error'), style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showEmailAuthDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final userProvider = context.read<UserProvider>();
    final isDark = userProvider.isDarkMode;

    String? emailError;
    String? passwordError;
    bool isRegisterMode = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.black, width: 4),
              ),
              backgroundColor: isDark ? const Color(0xFF151B38) : Colors.white,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isRegisterMode ? userProvider.t('register_email') : userProvider.t('sign_in_email'),
                            style: TextStyle(
                              fontFamily: 'LuckiestGuy',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                              letterSpacing: 1.2,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        onChanged: (_) {
                          if (emailError != null) {
                            setStateDialog(() {
                              emailError = null;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: userProvider.t('email_hint'),
                          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                          labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                          prefixIcon: Icon(Icons.email, color: isDark ? Colors.white70 : Colors.black54),
                          errorText: emailError,
                          errorStyle: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal, width: 2),
                          ),
                          errorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.redAccent, width: 2),
                          ),
                          focusedErrorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.redAccent, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        onChanged: (_) {
                          if (passwordError != null) {
                            setStateDialog(() {
                              passwordError = null;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: userProvider.t('password_hint'),
                          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                          labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                          prefixIcon: Icon(Icons.lock, color: isDark ? Colors.white70 : Colors.black54),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                          errorText: passwordError,
                          errorStyle: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal, width: 2),
                          ),
                          errorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.redAccent, width: 2),
                          ),
                          focusedErrorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.redAccent, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: isRegisterMode ? userProvider.t('register') : userProvider.t('sign_in'),
                        color: Colors.teal,
                        onPressed: () {
                          final email = emailController.text.trim();
                          final password = passwordController.text;
                          
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          
                          bool hasError = false;
                          String? tempEmailError;
                          String? tempPasswordError;
                          
                          if (email.isEmpty || !emailRegex.hasMatch(email)) {
                            tempEmailError = userProvider.t('invalid_email');
                            hasError = true;
                          }
                          
                          final hasUppercase = password.contains(RegExp(r'[A-Z]'));
                          final hasDigits = password.contains(RegExp(r'[0-9]'));
                          if (password.length < 8 || !hasUppercase || !hasDigits) {
                            tempPasswordError = userProvider.t('invalid_password');
                            hasError = true;
                          }
                          
                          if (hasError) {
                            setStateDialog(() {
                              emailError = tempEmailError;
                              passwordError = tempPasswordError;
                            });
                            return;
                          }
                          
                          Navigator.pop(dialogContext);
                          if (isRegisterMode) {
                            _linkEmailAccount(email, password);
                          } else {
                            _signInEmailAccount(email, password);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setStateDialog(() {
                            isRegisterMode = !isRegisterMode;
                            emailError = null;
                            passwordError = null;
                          });
                        },
                        child: Text(
                          isRegisterMode ? userProvider.t('have_account_hint') : userProvider.t('no_account_hint'),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  void _linkEmailAccount(String email, String password) async {
    final userProvider = context.read<UserProvider>();
    setState(() {
      _isLinking = true;
    });
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      
      final AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      
      await userProvider.linkAccountWithCredential(credential);
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userProvider.t('link_success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        
        final String errorMessage = e.toString();
        if (errorMessage.contains('già associato') ||
            errorMessage.contains('già in uso') ||
            errorMessage.contains('already-in-use') ||
            errorMessage.contains('already in use') ||
            errorMessage.contains('credential-already-in-use') ||
            errorMessage.contains('email-already-in-use')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(userProvider.t('account_in_use_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Text(
                userProvider.t('account_in_use_message'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(userProvider.t('cancel'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _signInEmailAccount(email, password);
                  },
                  child: Text(userProvider.t('sign_in'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(userProvider.t('auth_error'), style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Text(_getFriendlyErrorMessage(e, userProvider)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  void _signInEmailAccount(String email, String password) async {
    final userProvider = context.read<UserProvider>();
    setState(() {
      _isLinking = true;
    });
    try {
      final credential = EmailAuthProvider.credential(email: email, password: password);
      final user = await FirebaseAuth.instance.signInWithCredential(credential);
      if (user.user != null) {
        final prefs = await SharedPreferences.getInstance();
        final existingName = userProvider.user?.name;
        final name = (existingName != null && existingName.isNotEmpty && existingName != 'Giocatore')
            ? existingName
            : (user.user!.displayName ?? 'Giocatore');
        final photo = user.user!.photoURL ?? 'https://api.dicebear.com/7.x/adventurer/png?seed=Knight';
        await prefs.setString('user_name', name);
        await prefs.setString('user_avatar', photo);
        userProvider.resetInitializationFlag();
        await userProvider.init();
      }
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userProvider.t('sign_in_success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(userProvider.t('auth_error'), style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(_getFriendlyErrorMessage(e, userProvider)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _signOut() async {
    final userProvider = context.read<UserProvider>();
    setState(() {
      _isLinking = true;
    });
    try {
      await userProvider.signOut();
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userProvider.t('logout_success'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(userProvider.t('auth_error'), style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showAuthDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final userProvider = Provider.of<UserProvider>(dialogContext, listen: false);
        final isDark = userProvider.isDarkMode;
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.black, width: 4),
          ),
          backgroundColor: isDark ? const Color(0xFF151B38) : Colors.white,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        userProvider.t('unlock_photo'),
                        style: TextStyle(
                          fontFamily: 'LuckiestGuy',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                          letterSpacing: 1.2,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userProvider.t('sign_in_description'),
                    style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: userProvider.t('sign_in_google'),
                    color: Colors.orangeAccent,
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _linkGoogleAccount();
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: userProvider.t('sign_in_apple'),
                    color: Colors.grey[800]!,
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      final OAuthProvider provider = OAuthProvider('apple.com');
                      final AuthCredential credential = provider.credential(
                        idToken: 'apple_mock_id_token',
                        accessToken: 'apple_mock_access_token',
                      );
                      _linkWithCredentials(credential);
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: userProvider.t('sign_in_facebook'),
                    color: const Color(0xFF1877F2),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      final AuthCredential credential = FacebookAuthProvider.credential('facebook_mock_token');
                      _linkWithCredentials(credential);
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: userProvider.t('sign_in_email'),
                    color: Colors.teal,
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _showEmailAuthDialog();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<UserProvider>().t('enter_name_error'))),
      );
      return;
    }
    
    await context.read<UserProvider>().updateName(name);
    
    if (_selectedAvatar != null) {
      await context.read<UserProvider>().updateAvatar(_selectedAvatar!);
    }
    
    if (mounted) {
      Navigator.pop(context);
    }
  }


  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    final pink = Theme.of(context).primaryColor;
    final cyan = Theme.of(context).colorScheme.secondary;
    final isDark = userProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(userProvider.t('edit_profile')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar attuale con pulsante di modifica
            Center(
              child: GestureDetector(
                onTap: () {
                  if (userProvider.isAnonymous) {
                    _showAuthDialog();
                  } else {
                    _pickAndUploadImage();
                  }
                },
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 4),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(4, 4),
                          ),
                        ],
                      ),
                      child: _selectedAvatar != null && _selectedAvatar!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _selectedAvatar!,
                              imageBuilder: (context, imageProvider) => Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: DecorationImage(
                                    image: imageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) => const Center(
                                child: Icon(Icons.person, size: 60, color: Colors.grey),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.person, size: 60, color: Colors.grey),
                            ),
                    ),
                    if (!_isUploading)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: userProvider.isAnonymous ? Colors.orangeAccent : pink,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            userProvider.isAnonymous ? Icons.lock : Icons.camera_alt,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: _isLinking
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: 250,
                      child: userProvider.isAnonymous
                          ? CustomButton(
                              text: userProvider.t('sign_in'),
                              color: Colors.orangeAccent,
                              onPressed: _showAuthDialog,
                            )
                          : CustomButton(
                              text: userProvider.t('logout'),
                              color: Colors.redAccent,
                              onPressed: _signOut,
                            ),
                    ),
            ),
            const SizedBox(height: 30),
            _buildNeubrutalistCard(
              color: pink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(userProvider.t('nickname'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    maxLength: 15,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: "",
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.face, color: Colors.black),
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
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildNeubrutalistCard(
              color: cyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(userProvider.t('choose_avatar'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                    ),
                    itemCount: _avatars.length,
                    itemBuilder: (context, index) {
                      final avatar = _avatars[index];
                      final isSelected = _selectedAvatar == avatar;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _selectedAvatar = avatar;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.transparent,
                              width: 4,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                avatar,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.person),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            CustomButton(
              text: userProvider.t('save_changes'),
              onPressed: _save,
              color: pink,
            ),
          ],
        ),
      ),
    );
  }

  String _getFriendlyErrorMessage(dynamic e, UserProvider userProvider) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return userProvider.t('invalid_credentials');
        case 'email-already-in-use':
          return userProvider.t('email_already_in_use');
        case 'weak-password':
          return userProvider.t('invalid_password');
        case 'invalid-email':
          return userProvider.t('invalid_email');
        default:
          return e.message ?? e.toString();
      }
    }
    final String errStr = e.toString();
    if (errStr.contains('invalid-credential') ||
        errStr.contains('wrong-password') ||
        errStr.contains('user-not-found')) {
      return userProvider.t('invalid_credentials');
    }
    if (errStr.contains('email-already-in-use')) {
      return userProvider.t('email_already_in_use');
    }
    return errStr;
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
