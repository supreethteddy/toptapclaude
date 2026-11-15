import 'package:flutter/material.dart';
import 'package:toptap/common/manager/logger.dart';

class RestartWidget extends StatefulWidget {
  const RestartWidget({super.key, required this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    final state = context.findAncestorStateOfType<_RestartWidgetState>();
    
    if (state == null) {
      Loggers.error('❌ [RESTART] RestartWidget state not found in widget tree!');
      Loggers.error('   ⚠️ Ensure RestartWidget wraps MyApp in main.dart');
      Loggers.error('   Expected: runApp(const RestartWidget(child: MyApp()));');
      return;
    }
    
    Loggers.info('🔄 [RESTART] RestartWidget found, triggering app restart...');
    state.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    Loggers.info('♻️ [RESTART] Generating new UniqueKey to force full widget tree rebuild...');
    setState(() {
      key = UniqueKey();
    });
    Loggers.success('✅ [RESTART] App restarted successfully with new key: $key');
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: key, child: widget.child);
  }
}
