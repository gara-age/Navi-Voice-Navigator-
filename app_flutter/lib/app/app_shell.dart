import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/settings_controller.dart';
import '../shared/services/local_ui_state_service.dart';
import 'mode_launcher_page.dart';
import 'theme/app_theme.dart';

class VoiceNavigatorApp extends ConsumerStatefulWidget {
  const VoiceNavigatorApp({
    super.key,
    this.home,
  });

  final Widget? home;

  @override
  ConsumerState<VoiceNavigatorApp> createState() => _VoiceNavigatorAppState();
}

class _VoiceNavigatorAppState extends ConsumerState<VoiceNavigatorApp>
    with WidgetsBindingObserver {
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await ref.read(settingsControllerProvider.notifier).load();
      await LocalUiStateService.instance.setAppFocused(true);
      if (mounted) {
        setState(() => _settingsLoaded = true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocalUiStateService.instance.setAppFocused(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final focused = switch (state) {
      AppLifecycleState.resumed => true,
      AppLifecycleState.inactive => false,
      AppLifecycleState.hidden => false,
      AppLifecycleState.paused => false,
      AppLifecycleState.detached => false,
    };
    LocalUiStateService.instance.setAppFocused(focused);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    return MaterialApp(
      title: 'Navi: Voice Navigator',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(display: settings.display),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final scale = settings.display.largeText ? 1.32 : 1.0;
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Pretendard'),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: _settingsLoaded
          ? (widget.home ?? const ModeLauncherPage())
          : const _SettingsBootstrapScreen(),
    );
  }
}

class _SettingsBootstrapScreen extends StatelessWidget {
  const _SettingsBootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.8),
        ),
      ),
    );
  }
}
