import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../shared/models/settings_models.dart';
import '../shared/services/local_ui_state_service.dart';
import '../shared/services/local_settings_store.dart';
import 'demo_home_page.dart';

class VoiceNavigatorDemoApp extends StatefulWidget {
  const VoiceNavigatorDemoApp({super.key});

  @override
  State<VoiceNavigatorDemoApp> createState() => _VoiceNavigatorDemoAppState();
}

class _VoiceNavigatorDemoAppState extends State<VoiceNavigatorDemoApp>
    with WidgetsBindingObserver {
  AppSettings _settings = AppSettings.defaults();
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    LocalUiStateService.instance.setAppFocused(true);
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

  Future<void> _loadSettings() async {
    final loaded = await LocalSettingsStore.instance.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = loaded;
      _settingsLoaded = true;
    });
  }

  Future<void> _saveSettings(AppSettings settings) async {
    await LocalSettingsStore.instance.save(settings);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navi: Voice Navigator Demo',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(display: _settings.display),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final scale = _settings.display.largeText ? 1.32 : 1.0;
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
          ? DemoHomePage(
              initialSettings: _settings,
              onSettingsChanged: (settings) {
                setState(() => _settings = settings);
              },
              onSettingsSaved: (settings) {
                setState(() => _settings = settings);
                _saveSettings(settings);
              },
            )
          : const _DemoBootstrapScreen(),
    );
  }
}

class _DemoBootstrapScreen extends StatelessWidget {
  const _DemoBootstrapScreen();

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
