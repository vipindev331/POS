// Standardised search box used by every list screen. Search icon, a clear (×)
// button that appears once text is entered, and consistent styling from the
// app's input theme.
import 'package:flutter/material.dart';

class AppSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.autofocus = false,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {}); // toggle the clear button

  void _clear() {
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: widget.hintText,
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Clear',
                onPressed: _clear,
              )
            : null,
      ),
    );
  }
}
