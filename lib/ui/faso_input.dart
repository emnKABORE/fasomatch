import 'package:flutter/material.dart';
import 'app_colors.dart';

class FasoInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final bool enabled;

  // ✅ paramètres UI pour le rendre réutilisable partout
  final double borderRadius;
  final EdgeInsets contentPadding;
  final double fillOpacity;

  final Color? focusedBorderColor;
  final Color enabledBorderColor;

  final void Function(String)? onChanged;
  final String? Function(String?)? validator;

  const FasoInput({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.enabled = true,
    this.borderRadius = 10,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    this.fillOpacity = 0.75,
    this.focusedBorderColor,
    this.enabledBorderColor = Colors.black54,
    this.onChanged,
    this.validator,
  });

  @override
  State<FasoInput> createState() => _FasoInputState();
}

class _FasoInputState extends State<FasoInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  InputDecoration _deco() {
    final focusColor = widget.focusedBorderColor ?? AppColors.primaryBlue;

    return InputDecoration(
      hintText: widget.hint,
      hintStyle: TextStyle(
        fontWeight: FontWeight.w400, // ✅ hint toujours léger
        color: Colors.black.withOpacity(0.40),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(widget.fillOpacity),
      contentPadding: widget.contentPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide(color: widget.enabledBorderColor, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide(color: widget.enabledBorderColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide(color: focusColor, width: 1.4),
      ),
      suffixIcon: widget.suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.controller.text.trim().isEmpty;

    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: widget.obscure,
      keyboardType: widget.keyboardType,

      // ✅ vide = non gras / rempli = plus gras
      style: TextStyle(
        fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
        color: isEmpty ? Colors.black.withOpacity(0.65) : Colors.black,
      ),

      decoration: _deco(),
      validator: widget.validator,
      onChanged: (v) {
        widget.onChanged?.call(v);
        if (mounted) setState(() {});
      },
    );
  }
}