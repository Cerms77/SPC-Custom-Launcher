// Aurora Launcher V1.0 — launch directly with a recoverable startup fallback.
// Keep the recovery screen available if a platform/service initialization fails.
import 'dart:async';
import 'dart:ui';

import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flauncher/database.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/brightness_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/providers/tv_inputs_service.dart';
import 'package:flauncher/providers/notifications_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/providers/weather_service.dart';
import 'package:flauncher/providers/backup_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'flauncher_app.dart';
import 'widgets/aurora_backdrop.dart';

final ValueNotifier<String?> auroraRuntimeError = ValueNotifier<String?>(null);

void _showFatalError(Object error, StackTrace stack) {
  debugPrint('Aurora diagnostic: $error\n$stack');
  // Expose a readable error on the screen in case logcat is unavailable.
  auroraRuntimeError.value = '$error\n\n$stack';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _showFatalError(details.exception, details.stack ?? StackTrace.current);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _showFatalError(error, stack);
    return true;
  };

  // Draw the Aurora startup layer immediately while its services initialize.
  runApp(const AuroraBoot());
}

class AuroraBoot extends StatefulWidget {
  const AuroraBoot({super.key});

  @override
  State<AuroraBoot> createState() => _AuroraBootState();
}

class _AuroraBootState extends State<AuroraBoot> {
  bool _launching = false;
  bool _autoStartPending = true;
  Widget? _fullLauncher;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    // Automatic startup; users should never have to press a diagnostic button.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startFullLauncher();
    });
  }

  Future<void> _startFullLauncher() async {
    if (_launching) return;
    auroraRuntimeError.value = null;
    setState(() {
      _autoStartPending = false;
      _launching = true;
      _fullLauncher = null;
      _startupError = null;
    });

    try {
      await initializeDateFormatting('en_US');
      tzdata.initializeTimeZones();
      PaintingBinding.instance.imageCache.maximumSizeBytes = 35 * 1024 * 1024;
      PaintingBinding.instance.imageCache.maximumSize = 80;

      final sharedPreferences = await SharedPreferences.getInstance();
      final fLauncherChannel = FLauncherChannel();
      final fLauncherDatabase = FLauncherDatabase(connect());

      final app = MultiProvider(
        providers: [
          Provider<BackupService>(
            create: (_) => BackupService(fLauncherDatabase, sharedPreferences),
          ),
          ChangeNotifierProvider(
            create: (_) => SettingsService(sharedPreferences),
            lazy: false,
          ),
          ChangeNotifierProvider(
            create: (_) => AppsService(fLauncherChannel, fLauncherDatabase),
          ),
          ChangeNotifierProvider(create: (_) => LauncherState()),
          ChangeNotifierProvider(
            create: (_) => NetworkService(fLauncherChannel),
          ),
          ChangeNotifierProvider(
            create: (context) {
              final settings = Provider.of<SettingsService>(context, listen: false);
              return WallpaperService(fLauncherChannel, settings);
            },
          ),
          ChangeNotifierProvider(
            create: (_) => BrightnessService(sharedPreferences),
            lazy: false,
          ),
          ChangeNotifierProvider(
            create: (_) => TvInputsService(fLauncherChannel),
          ),
          ChangeNotifierProvider(
            create: (_) => NotificationsService(fLauncherChannel),
          ),
          ChangeNotifierProvider(
            create: (_) => WatchNextService(fLauncherChannel),
          ),
          ChangeNotifierProvider(
            create: (_) => WeatherService(fLauncherChannel),
          ),
        ],
        child: const FLauncherApp(),
      );

      if (!mounted) return;
      setState(() => _fullLauncher = app);
    } catch (error, stack) {
      debugPrint('Aurora startup failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _startupError = '$error\n\n$stack';
        _launching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: auroraRuntimeError,
      builder: (context, runtimeError, _) {
        if (runtimeError != null) return _recoveryScreen(runtimeError);
        if (_fullLauncher != null) return _fullLauncher!;
        return _recoveryScreen(_startupError);
      },
    );
  }

  Widget _recoveryScreen(String? error) {
    const textColor = Color(0xFFF4F7FF);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF101426),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AuroraBackdrop(),
            const ColoredBox(color: Color(0xAA101426)),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'AURORA LAUNCHER',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        error == null
                            ? 'Starting your home screen…'
                            : 'Aurora could not start. You can retry, or use your original launcher.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: textColor, fontSize: 18),
                      ),
                      const SizedBox(height: 26),
                      if (error != null)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xDD250C17),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SelectableText(
                            error.length > 1500 ? error.substring(0, 1500) : error,
                            style: const TextStyle(
                              color: Color(0xFFFFDAD8),
                              fontSize: 14,
                            ),
                          ),
                        )
                      else if (_launching || _autoStartPending)
                        const Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 14),
                            Text(
                              'Loading Aurora…',
                              style: TextStyle(color: textColor, fontSize: 17),
                            ),
                          ],
                        )
                      else
                        ElevatedButton(
                          autofocus: true,
                          onPressed: _startFullLauncher,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 17),
                            backgroundColor: const Color(0xFFAEF5D4),
                            foregroundColor: const Color(0xFF101426),
                          ),
                          child: const Text(
                            'RETRY AURORA',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Text(
                        'Your original LTvLauncher remains installed as a backup.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFE2D6FF), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
