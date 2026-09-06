import 'package:intl/intl.dart';

/// Date, time and unit formatting helpers.
class Formatters {
  const Formatters._();

  static final DateFormat _fullDate = DateFormat('EEEE, d MMMM yyyy');
  static final DateFormat _shortDate = DateFormat('d MMM yyyy');
  static final DateFormat _dayMonth = DateFormat('d MMM');
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy • h:mm a');

  static String fullDate(DateTime value) => _fullDate.format(value);
  static String shortDate(DateTime value) => _shortDate.format(value);
  static String dayMonth(DateTime value) => _dayMonth.format(value);
  static String time(DateTime value) => _time.format(value);
  static String dateTime(DateTime value) => _dateTime.format(value);

  /// Greeting appropriate to the hour of day.
  static String greeting(DateTime value) {
    final int hour = value.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// Compact relative time, e.g. "12m ago".
  static String relative(DateTime value, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final Duration diff = reference.difference(value);

    if (diff.isNegative) return 'Scheduled';
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _dayMonth.format(value);
  }

  /// Conversation-list style timestamp.
  static String listTimestamp(DateTime value, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final bool sameDay = value.year == reference.year &&
        value.month == reference.month &&
        value.day == reference.day;
    if (sameDay) return _time.format(value);

    final DateTime yesterday = reference.subtract(const Duration(days: 1));
    final bool wasYesterday = value.year == yesterday.year &&
        value.month == yesterday.month &&
        value.day == yesterday.day;
    if (wasYesterday) return 'Yesterday';

    return _dayMonth.format(value);
  }

  /// Signal strength in dBm.
  static String rssi(int value) => '$value dBm';

  /// Battery percentage.
  static String percent(double value) => '${value.round()}%';

  /// Distance rendered in metres or kilometres.
  static String distance(double metres) {
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }

  /// Hop count description.
  static String hops(int value) => value == 1 ? '1 hop' : '$value hops';

  /// Human friendly duration, e.g. "1h 20m".
  static String duration(Duration value) {
    if (value.inMinutes < 60) return '${value.inMinutes}m';
    final int hours = value.inHours;
    final int minutes = value.inMinutes.remainder(60);
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  /// Thousands separated integer.
  static String count(int value) => NumberFormat.decimalPattern().format(value);

  /// Two-letter initials from a display name.
  static String initials(String name) {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final String single = parts.first;
      return (single.length == 1 ? single : single.substring(0, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
