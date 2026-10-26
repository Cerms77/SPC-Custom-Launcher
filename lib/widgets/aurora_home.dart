// Custom aurora home screen for the SPC monitor.
// Based on LTvLauncher. This screen does not display sponsored content.
import 'dart:async';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/tv_input.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/tv_inputs_service.dart';
import 'package:flauncher/widgets/settings/inputs_panel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

const _mint = Color(0xFFAEF5D4);
const _lavender = Color(0xFFCEB9FF);
const _snow = Color(0xFFF4F7FF);
const _night = Color(0xFF101426);

class AuroraHome extends StatefulWidget {
  const AuroraHome({super.key});

  @override
  State<AuroraHome> createState() => _AuroraHomeState();
}

class _AuroraHomeState extends State<AuroraHome> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _now = DateTime.now();

  static const _firstRow = [
    _AppShortcut('Netflix', 'N', ['Netflix'], ['com.netflix.ninja', 'com.netflix.mediaclient']),
    _AppShortcut('HBO Max', 'max', ['HBO Max', 'Max'], ['com.wbd.stream', 'com.hbo.hbonow']),
    _AppShortcut('Apple TV', 'tv+', ['Apple TV', 'Apple TV+'], ['com.apple.atve.androidtv.appletv']),
    _AppShortcut('Peacock', 'P', ['Peacock'], ['com.peacocktv.peacockandroid']),
  ];

  static const _secondRow = [
    _AppShortcut('YouTube', '▶', ['YouTube'], ['com.google.android.youtube.tv']),
    _AppShortcut('Prime Video', 'prime', ['Prime Video', 'Amazon Prime Video'], ['com.amazon.amazonvideo.livingroom']),
    _AppShortcut('Disney+', 'Disney+', ['Disney+', 'Disney Plus'], ['com.disney.disneyplus']),
    _AppShortcut('Hulu', 'hulu', ['Hulu'], ['com.hulu.livingroomplus']),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _now = DateTime.now());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  App? _findApp(AppsService service, _AppShortcut shortcut) {
    for (final package in shortcut.packages) {
      for (final app in service.applications) {
        if (app.packageName.toLowerCase() == package.toLowerCase()) return app;
      }
    }
    for (final name in shortcut.names) {
      for (final app in service.applications) {
        if (app.name.trim().toLowerCase() == name.toLowerCase()) return app;
      }
    }
    return null;
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _night,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _launch(_AppShortcut shortcut) async {
    final service = context.read<AppsService>();
    final app = _findApp(service, shortcut);
    if (app == null) {
      _notice(shortcut.name + ' is not installed or is not visible to this launcher.');
      return;
    }
    try {
      await service.launchApp(app);
    } catch (_) {
      _notice('Unable to open ' + shortcut.name + '.');
    }
  }

  Future<void> _nordVpn() async {
    final service = context.read<AppsService>();
    App? nord;
    for (final app in service.applications) {
      if (app.packageName.toLowerCase().contains('nordvpn') ||
          app.name.toLowerCase().contains('nordvpn')) {
        nord = app;
        break;
      }
    }
    try {
      if (nord != null) {
        await service.launchApp(nord);
      } else {
        await FLauncherChannel().openVpnSettings();
        _notice('Install NordVPN on the monitor to open it directly.');
      }
    } catch (_) {
      _notice('Could not open NordVPN. Check the app installation.');
    }
  }

  Future<void> _hdmiOne() async {
    final inputService = context.read<TvInputsService>();
    await inputService.refreshInputs();
    final hdmi = inputService.inputs.where((input) => input.type == TvInputType.hdmi).toList();
    TvInput? target;
    for (final input in hdmi) {
      final label = input.label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final id = input.id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (label.contains('hdmi1') || label.contains('hdmione') || id.contains('hdmi1')) {
        target = input;
        break;
      }
    }
    // If the device exposes exactly one HDMI input without a number, try it.
    if (target == null && hdmi.length == 1) target = hdmi.first;

    if (target != null) {
      final switched = await inputService.switchInput(target.id);
      if (switched) return;
    }
    if (!mounted) return;
    if (inputService.hasInputs) {
      // OEM firmware may not permit direct third-party input switching.
      await showDialog<void>(
        context: context,
        builder: (_) => const InputsPanel(),
      );
    } else {
      _notice('HDMI 1 is not exposed to Android. Use the SPC remote Input/Source button.');
    }
  }

  Widget _timeZoneLine(String name, String zone) {
    final localTime = tz.TZDateTime.from(_now.toUtc(), tz.getLocation(zone));
    final timeText = DateFormat('h:mm a').format(localTime);
    final zoneName = localTime.timeZoneName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name + ' · ' + zoneName,
              style: const TextStyle(fontSize: 15, color: _snow, letterSpacing: 0.5)),
          const SizedBox(width: 18),
          SizedBox(
            width: 106,
            child: Text(timeText, textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 19, color: _mint, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _appRow(List<_AppShortcut> shortcuts, double tileSize, double gap) {
    return Row(
      textDirection: TextDirection.rtl, // User-requested right-to-left ordering.
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < shortcuts.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _AppCircle(
            key: ValueKey(shortcuts[i].name),
            shortcut: shortcuts[i],
            size: tileSize,
            onTap: () => _launch(shortcuts[i]),
            autofocus: i == 0 && identical(shortcuts, _firstRow),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _night,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final tileSize = (screenWidth / 12).clamp(66.0, 110.0).toDouble();
          final tileGap = (screenWidth / 36).clamp(12.0, 32.0).toDouble();
          final compact = screenWidth < 900;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/aurora_wallpaper.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.12),
                errorBuilder: (context, error, stack) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_night, Color(0xFF246C67), Color(0xFF504477)],
                    ),
                  ),
                ),
              ),
              // Darken the snowfield, leaving the northern lights visible.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.42, 0.77, 1],
                    colors: [
                      Color(0x770A1021),
                      Color(0x200A1021),
                      Color(0xAA101426),
                      Color(0xEE101426),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      left: compact ? 15 : 34,
                      top: 26,
                      child: Row(children: [
                        _ControlCircle(
                          icon: Icons.wifi_rounded,
                          label: 'Wi-Fi',
                          onTap: () => FLauncherChannel().openWifiSettings(),
                        ),
                        const SizedBox(width: 12),
                        _ControlCircle(
                          icon: Icons.shield_outlined,
                          label: 'NordVPN',
                          onTap: _nordVpn,
                        ),
                        const SizedBox(width: 12),
                        _ControlCircle(
                          icon: Icons.sports_esports_outlined,
                          label: 'Xbox · HDMI 1',
                          onTap: _hdmiOne,
                        ),
                      ]),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: compact ? 98 : 34),
                        child: Text(
                          DateFormat('EEEE, MMMM d, y').format(
                            tz.TZDateTime.from(_now.toUtc(), tz.getLocation('Europe/Prague')),
                          ),
                          style: TextStyle(
                            color: _snow,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                            fontSize: compact ? 15 : 20,
                            shadows: const [Shadow(color: Colors.black87, blurRadius: 12)],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: compact ? 15 : 34,
                      top: 25,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _timeZoneLine('PRAGUE', 'Europe/Prague'),
                          _timeZoneLine('NEW YORK', 'America/New_York'),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: compact ? 16 : constraints.maxHeight * 0.045,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _appRow(_firstRow, tileSize, tileGap),
                          SizedBox(height: compact ? 12 : 27),
                          _appRow(_secondRow, tileSize, tileGap),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppShortcut {
  final String name;
  final String glyph;
  final List<String> names;
  final List<String> packages;
  const _AppShortcut(this.name, this.glyph, this.names, this.packages);
}

class _AppCircle extends StatelessWidget {
  final _AppShortcut shortcut;
  final double size;
  final VoidCallback onTap;
  final bool autofocus;

  const _AppCircle({
    super.key,
    required this.shortcut,
    required this.size,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AuroraCircle(
            size: size,
            onTap: onTap,
            autofocus: autofocus,
            semanticLabel: shortcut.name,
            child: _AppLogo(shortcut: shortcut, size: size),
          ),
          const SizedBox(height: 9),
          Text(
            shortcut.name,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _snow, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  final _AppShortcut shortcut;
  final double size;

  const _AppLogo({required this.shortcut, required this.size});

  Widget _fallback() => Text(
        shortcut.glyph,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _snow,
          fontWeight: FontWeight.w700,
          fontSize: shortcut.glyph.length >= 6 ? size * 0.19 : size * 0.29,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AppsService>();
    App? app;
    for (final package in shortcut.packages) {
      for (final installed in service.applications) {
        if (installed.packageName.toLowerCase() == package.toLowerCase()) {
          app = installed;
          break;
        }
      }
      if (app != null) break;
    }
    if (app == null) {
      for (final name in shortcut.names) {
        for (final installed in service.applications) {
          if (installed.name.trim().toLowerCase() == name.toLowerCase()) {
            app = installed;
            break;
          }
        }
        if (app != null) break;
      }
    }
    if (app == null) return _fallback();
    return FutureBuilder(
      future: service.getAppIcon(app.packageName),
      builder: (context, snapshot) {
        final iconBytes = snapshot.data;
        if (iconBytes == null || iconBytes.isEmpty) return _fallback();
        return ClipOval(
          child: Image.memory(
            iconBytes,
            width: size * 0.55,
            height: size * 0.55,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        );
      },
    );
  }
}

class _ControlCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ControlCircle({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: _AuroraCircle(
        size: 47,
        semanticLabel: label,
        onTap: onTap,
        child: Icon(icon, color: _snow, size: 25),
      ),
    );
  }
}

class _AuroraCircle extends StatefulWidget {
  final double size;
  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool autofocus;

  const _AuroraCircle({
    required this.size,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.autofocus = false,
  });

  @override
  State<_AuroraCircle> createState() => _AuroraCircleState();
}

class _AuroraCircleState extends State<_AuroraCircle> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: widget.onTap,
          autofocus: widget.autofocus,
          onFocusChange: (focus) => setState(() => _focused = focus),
          customBorder: const CircleBorder(),
          splashColor: _mint.withOpacity(0.12),
          child: AnimatedScale(
            scale: _focused ? 1.10 : 1,
            duration: const Duration(milliseconds: 170),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xE72C6F70), Color(0xEA293D62), Color(0xDF594979)],
                ),
                border: Border.all(
                  color: _focused ? _mint : _lavender.withOpacity(0.70),
                  width: _focused ? 3 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_focused ? _mint : _night).withOpacity(_focused ? 0.55 : 0.30),
                    blurRadius: _focused ? 24 : 12,
                    spreadRadius: _focused ? 2 : 0,
                  )
                ],
              ),
              alignment: Alignment.center,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
