/// In-app debug logger that works in release mode.
/// Collects timestamped log entries that can be displayed
/// in an overlay to diagnose web-release-only bugs.
class DebugLogger {
  DebugLogger._();
  static final DebugLogger instance = DebugLogger._();

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  /// Max entries kept in memory.
  static const int _maxEntries = 200;

  void log(String tag, String message) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    final entry = '[$ts] $tag: $message';
    _logs.add(entry);
    if (_logs.length > _maxEntries) _logs.removeAt(0);
    // Also print to console for DevTools
    // ignore: avoid_print
    print(entry);
  }

  void clear() => _logs.clear();
}
