import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isSecondary;
  final bool playSound;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.isSecondary = false,
    this.playSound = false,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? (widget.isSecondary ? AppTheme.secondaryColor : AppTheme.primaryColor);
    
    final hsl = HSLColor.fromColor(baseColor);
    final darkerShadow = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();

    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) {
          if (widget.playSound) {
            context.read<UserProvider>().playClickSound();
          }
          setState(() => _isPressed = true);
        }
      },
      onTapUp: (_) {
        if (widget.onPressed != null) {
          setState(() => _isPressed = false);
          widget.onPressed!();
        }
      },
      onTapCancel: () {
        if (widget.onPressed != null) {
          setState(() => _isPressed = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(top: _isPressed ? 6 : 0),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!_isPressed && widget.onPressed != null)
              BoxShadow(
                color: darkerShadow,
                offset: const Offset(0, 6),
                blurRadius: 0,
              ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.text,
              style: GoogleFonts.luckiestGuy(
                fontSize: 24,
                color: (baseColor == Colors.black || hsl.lightness < 0.3) ? Colors.white : Colors.black,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
