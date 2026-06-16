import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';

/// A shared ref-number chip with clipboard copy on tap.
///
/// Tapping the chip copies the ref to clipboard and shows a brief
/// "COPIED" snackbar. When [query] is provided and matches, the
/// matched portion is highlighted in yellow (used in search results).
class RefChip extends StatelessWidget {
  final String ref;
  final String query;

  const RefChip({super.key, required this.ref, this.query = ''});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: ref));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('COPIED: $ref'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.black,
            duration: const Duration(milliseconds: 600),
          ),
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.grey.withValues(alpha: 0.2)),
        ),
        child: query.isNotEmpty && ref.toLowerCase().contains(query.toLowerCase())
            ? _HighlightedText(text: ref, query: query)
            : Text(ref,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.black)),
      ),
    );
  }
}

/// Renders [text] with the matching [query] portion highlighted in yellow.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;

  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index < 0) {
      return Text(text,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.black));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.black),
        children: [
          if (index > 0)
            TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: const TextStyle(
              backgroundColor: AppColors.highlightYellow,
            ),
          ),
          if (index + query.length < text.length)
            TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }
}
