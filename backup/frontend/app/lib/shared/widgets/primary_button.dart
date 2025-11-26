import 'package:flutter/cupertino.dart';
import 'package:app/core/theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
  });

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onPressed,
      color: AppColors.primary,
      child: Text(text, style: const TextStyle(color: AppColors.white)),
    );
  }
}
