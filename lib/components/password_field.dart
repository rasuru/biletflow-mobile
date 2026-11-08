import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {
  final void Function(String)? onChanged;
  final Widget? label;
  final Widget? error;
  final String? errorText;

  const new({
    super.key,
    required this.onChanged,
    this.label,
    this.error,
    this.errorText,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: _obscureText,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        label: widget.label,
        border: OutlineInputBorder(),
        error: widget.error,
        errorText: widget.errorText,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscureText = !_obscureText),
          icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}
