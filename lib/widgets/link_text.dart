import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class LinkText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Function(String) onNoteLinkTap;

  // Regular expression to match links in the format [text](note:id)
  static final RegExp _linkPattern = RegExp(r'\[(.+?)\]\(note:([a-f0-9-]+)\)');

  const LinkText({
    Key? key,
    required this.text,
    this.style,
    required this.onNoteLinkTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ?? Theme.of(context).textTheme.bodyMedium!;
    final spans = _buildTextSpans(context, defaultStyle);
    
    return SelectableText.rich(
      TextSpan(children: spans),
      style: defaultStyle,
    );
  }

  List<InlineSpan> _buildTextSpans(BuildContext context, TextStyle defaultStyle) {
    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    // Find all links in the text
    for (final match in _linkPattern.allMatches(text)) {
      // Add text before the link
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      // Extract link text and note ID
      final linkText = match.group(1)!;
      final noteId = match.group(2)!;

      // Add the link as a clickable span
      spans.add(
        TextSpan(
          text: linkText,
          style: defaultStyle.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onNoteLinkTap(noteId),
        ),
      );

      lastIndex = match.end;
    }

    // Add any remaining text after the last link
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return spans;
  }
}