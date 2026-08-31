import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';

class CustomInputField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool isPassword;
  final Widget? suffixIcon;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;

  const CustomInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.isPassword = false,
    this.suffixIcon,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.autofocus = false,
    this.onFieldSubmitted,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: isPassword,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: maxLines,
          autofocus: autofocus,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon:
                Icon(prefixIcon, color: Colors.grey.shade400, size: 20),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
