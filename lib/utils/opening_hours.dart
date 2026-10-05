/// Works out whether a branch is open from its free-text opening hours, e.g.
/// "7:00 AM – 11:00 PM (closed during prayer times)" or "09:00 - 23:00".
/// Returns null when the text can't be understood (the hours are shown as-is).
bool? isOpenAt(String? hours, DateTime now) {
  final text = (hours ?? '').trim();
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();
  if (lower.contains('24 hours') || lower.contains('24/7')) return true;

  final range = _parseRange(text);
  if (range == null) return null;
  final (open, close) = range;
  final minute = now.hour * 60 + now.minute;
  if (open == close) return true;
  // Overnight hours such as 6 PM – 2 AM.
  return open < close
      ? minute >= open && minute < close
      : minute >= open || minute < close;
}

/// Opening and closing time in minutes after midnight.
(int, int)? _parseRange(String text) {
  final ampm = RegExp(r'(\d{1,2})(?:[:.](\d{2}))?\s*([ap])\.?\s*m\b',
          caseSensitive: false)
      .allMatches(text)
      .toList();
  if (ampm.length >= 2) {
    int toMinutes(RegExpMatch m) {
      var h = int.parse(m.group(1)!) % 12;
      if (m.group(3)!.toLowerCase() == 'p') h += 12;
      return h * 60 + int.parse(m.group(2) ?? '0');
    }

    return (toMinutes(ampm[0]), toMinutes(ampm[1]));
  }
  final clock = RegExp(r'\b(\d{1,2}):(\d{2})\b').allMatches(text).toList();
  if (clock.length >= 2) {
    int toMinutes(RegExpMatch m) =>
        (int.parse(m.group(1)!) % 24) * 60 + int.parse(m.group(2)!);
    return (toMinutes(clock[0]), toMinutes(clock[1]));
  }
  return null;
}
