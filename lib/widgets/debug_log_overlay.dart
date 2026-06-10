import 'package:flutter/material.dart';
import '../services/debug_logger.dart';

/// A draggable, collapsible overlay that shows debug logs in real time.
/// Tap the floating button to expand/collapse. Works in release mode.
class DebugLogOverlay extends StatefulWidget {
  const DebugLogOverlay({super.key});

  @override
  State<DebugLogOverlay> createState() => _DebugLogOverlayState();
}

class _DebugLogOverlayState extends State<DebugLogOverlay> {
  bool _expanded = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Refresh every 500ms to show new logs
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return false;
      setState(() {});
      if (_expanded && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
      return true;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = DebugLogger.instance.logs;
    
    if (!_expanded) {
      return Positioned(
        bottom: 20,
        right: 20,
        child: FloatingActionButton(
          mini: true,
          backgroundColor: Colors.red.withOpacity(0.8),
          onPressed: () => setState(() => _expanded = true),
          child: Text('${logs.length}', style: const TextStyle(fontSize: 12, color: Colors.white)),
        ),
      );
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: MediaQuery.of(context).size.height * 0.4,
      child: Material(
        color: Colors.black.withOpacity(0.9),
        child: Column(
          children: [
            Container(
              color: Colors.red.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Text('DEBUG LOG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                    onPressed: () {
                      DebugLogger.instance.clear();
                      setState(() {});
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => setState(() => _expanded = false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: logs.length,
                padding: const EdgeInsets.all(4),
                itemBuilder: (context, index) {
                  return Text(
                    logs[index],
                    style: TextStyle(
                      color: _getLogColor(logs[index]),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLogColor(String log) {
    if (log.contains('FAIL') || log.contains('ERROR') || log.contains('EXCEPTION')) return Colors.red;
    if (log.contains('NULL')) return Colors.orange;
    if (log.contains('NAVIGATING')) return Colors.yellow;
    if (log.contains('OK') || log.contains('completed') || log.contains('done')) return Colors.green;
    return Colors.white70;
  }
}
