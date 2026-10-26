// SPC Aurora Home: ten customized TV shortcuts and live world clocks.
// Layout and styling are based on the user's approved Aurora mockup.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/tv_input.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/tv_inputs_service.dart';
import 'package:flauncher/widgets/settings/inputs_panel.dart';
import 'aurora_backdrop.dart';

const _night = Color(0xFF06132E);
const _snow = Color(0xFFF0F6FF);
const _purple = Color(0xFFD78BFF);
const _cyan = Color(0xFF7CEAFF);
const _mint = Color(0xFF24EFDE);

class _Shortcut {
  final String name;
  final String logo;
  final Color color;
  final List<String> names;
  final List<String> packages;
  const _Shortcut(this.name, this.logo, this.color, this.names, this.packages);
}

const _shortcuts = <_Shortcut>[
  _Shortcut('NETFLIX', 'netflix', _purple,
      ['Netflix'], ['com.netflix.ninja', 'com.netflix.mediaclient']),
  _Shortcut('HBO MAX', 'max', _cyan,
      ['HBO Max', 'Max'], ['com.wbd.stream', 'com.hbo.hbonow']),
  _Shortcut('APPLE TV', 'apple', Color(0xFFF0B4FF),
      ['Apple TV', 'Apple TV+'], ['com.apple.atve.androidtv.appletv']),
  _Shortcut('HULU', 'hulu', _mint,
      ['Hulu'], ['com.hulu.livingroomplus']),
  _Shortcut('DISNEY+', 'disney', _cyan,
      ['Disney+', 'Disney Plus'], ['com.disney.disneyplus']),
  _Shortcut('PEACOCK', 'peacock', Color(0xFFCBA2FF),
      ['Peacock'], ['com.peacocktv.peacockandroid']),
  _Shortcut('PRIME VIDEO', 'prime', _cyan,
      ['Prime Video', 'Amazon Prime Video'], ['com.amazon.amazonvideo.livingroom']),
  _Shortcut('YOUTUBE', 'youtube', Color(0xFFFF87E6),
      ['YouTube'], ['com.google.android.youtube.tv']),
  _Shortcut('SPOTIFY', 'spotify', Color(0xFF3CF0BC),
      ['Spotify'], ['com.spotify.tv.android', 'com.spotify.music']),
  _Shortcut('HDMI 1', 'controller', Color(0xFFD9A2FF), [], []),
];

class AuroraHome extends StatefulWidget {
  const AuroraHome({super.key});

  @override
  State<AuroraHome> createState() => _AuroraHomeState();
}

class _AuroraHomeState extends State<AuroraHome> with WidgetsBindingObserver {
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clockTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted && state == AppLifecycleState.resumed) {
      setState(() => _now = DateTime.now());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    super.dispose();
  }

  App? _findApp(AppsService service, _Shortcut shortcut) {
    for (final package in shortcut.packages) {
      for (final app in service.applications) {
        if (app.packageName.toLowerCase() == package.toLowerCase()) return app;
      }
    }
    for (final name in shortcut.names) {
      for (final app in service.applications) {
        if (app.name.toLowerCase().trim() == name.toLowerCase()) return app;
      }
    }
    return null;
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF18254A),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _launch(_Shortcut shortcut) async {
    if (shortcut.logo == 'controller') return _hdmiOne();
    final service = context.read<AppsService>();
    final app = _findApp(service, shortcut);
    if (app == null) {
      _notice('${shortcut.name} is not installed or is not visible to Aurora.');
      return;
    }
    try {
      await service.launchApp(app);
    } catch (_) {
      _notice('Unable to open ${shortcut.name}.');
    }
  }

  Future<void> _nordVpn() async {
    final service = context.read<AppsService>();
    App? installed;
    for (final app in service.applications) {
      if (app.packageName.toLowerCase().contains('nordvpn') ||
          app.name.toLowerCase().contains('nordvpn')) {
        installed = app;
        break;
      }
    }
    try {
      if (installed != null) {
        await service.launchApp(installed);
      } else {
        await FLauncherChannel().openVpnSettings();
        _notice('Install NordVPN on the monitor to launch it directly.');
      }
    } catch (_) {
      _notice('NordVPN is unavailable on this monitor.');
    }
  }

  Future<void> _hdmiOne() async {
    try {
      final service = context.read<TvInputsService>();
      await service.refreshInputs();
      final inputs = service.inputs.where((i) => i.type == TvInputType.hdmi).toList();
      TvInput? first;
      for (final input in inputs) {
        final n = '${input.id} ${input.label}'.toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (n.contains('hdmi1') || n.contains('hdmione')) {
          first = input;
          break;
        }
      }
      if (first == null && inputs.length == 1) first = inputs.first;
      if (first != null && await service.switchInput(first.id)) return;
      if (!mounted) return;
      if (service.hasInputs) {
        await showDialog<void>(
          context: context, builder: (_) => const InputsPanel());
      } else {
        _notice('Use the SPC Input/Source button to select HDMI 1.');
      }
    } catch (_) {
      _notice('Use the SPC Input/Source button to select HDMI 1.');
    }
  }

  tz.TZDateTime _cityTime(String zone) =>
      tz.TZDateTime.from(_now.toUtc(), tz.getLocation(zone));

  Widget _cityCard(String city, String zone, Color accent,
      double width, double timeFont) {
    final local = _cityTime(zone);
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: width < 145 ? 8 : 14,
          vertical: width < 145 ? 8 : 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xC20A1237),
        border: Border.all(color: accent.withOpacity(.61), width: 1.2),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(.08),
              blurRadius: 18, spreadRadius: 1),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [const Color(0xBB23134D), const Color(0xD9081935)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(city, style: TextStyle(color: accent, fontSize: width < 145 ? 13 : 17)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(DateFormat('HH:mm').format(local), style: TextStyle(
              color: accent, fontSize: timeFont, fontWeight: FontWeight.w700,
              letterSpacing: -.7,
            )),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(DateFormat('EEE, MMM d').format(local),
              style: TextStyle(color: accent.withOpacity(.92),
                  fontSize: width < 145 ? 11 : 15)),
          ),
        ],
      ),
    );
  }

  Widget _worldClocks(double screenWidth) {
    final compact = screenWidth < 950;
    final small = screenWidth < 700;
    final cw = small ? 112.0 : compact ? 140.0 : 205.0;
    final titleSize = small ? 13.0 : compact ? 16.0 : 23.0;
    final nowPrague = _cityTime('Europe/Prague');
    return Column(crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_snow, _purple, _cyan],
          ).createShader(bounds),
          child: Text(
            DateFormat('EEEE, MMMM d, y').format(nowPrague),
            textAlign: TextAlign.right,
            style: TextStyle(color: _snow, fontSize: titleSize,
                fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 14),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _cityCard('Prague', 'Europe/Prague', _purple, cw, small ? 24 : compact ? 32 : 50),
          const SizedBox(width: 12),
          _cityCard('New York', 'America/New_York', _cyan, cw,
              small ? 24 : compact ? 32 : 50),
        ]),
      ],
    );
  }

  Widget _topAction(IconData icon, String name,
      Color tint, VoidCallback action, double size) {
    return Tooltip(
      message: name,
      child: _GlassCircle(
        size: size,
        accent: tint,
        label: name,
        onTap: action,
        child: Icon(icon, color: tint, size: size * .48),
      ),
    );
  }

  Widget _shortcutTile(_Shortcut shortcut, double slotWidth,
      double diameter, bool autofocus) {
    final textSize = slotWidth < 80 ? 9.0 : slotWidth < 110 ? 10.5 : 14.0;
    return SizedBox(
      width: slotWidth,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _GlassCircle(
          size: diameter,
          accent: shortcut.color,
          label: shortcut.name,
          onTap: () => _launch(shortcut),
          autofocus: autofocus,
          child: _TintedLogo(shortcut: shortcut, size: diameter),
        ),
        const SizedBox(height: 8),
        Text(shortcut.name,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: _snow, fontSize: textSize,
              letterSpacing: .15, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _night,
      body: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final compact = w < 900;
        final horizontal = compact ? 10.0 : 35.0;
        final slot = (w - horizontal * 2) / _shortcuts.length;
        final diameter = (slot - (compact ? 9 : 20)).clamp(38.0, 126.0).toDouble();
        final topButton = compact ? 45.0 : 78.0;
        return Stack(fit: StackFit.expand, children: [
          const AuroraBackdrop(),
          SafeArea(child: Stack(children: [
            Positioned(
              left: compact ? 15 : 40,
              top: compact ? 16 : 35,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _topAction(Icons.wifi_rounded, 'Wi-Fi', _cyan,
                    () => FLauncherChannel().openWifiSettings(), topButton),
                SizedBox(width: compact ? 9 : 20),
                _topAction(Icons.shield_rounded, 'NordVPN', _purple,
                    _nordVpn, topButton),
                SizedBox(width: compact ? 9 : 20),
                _topAction(Icons.settings_rounded, 'Settings', _cyan,
                    () => FLauncherChannel().openSettings(), topButton),
              ]),
            ),
            Positioned(
              right: compact ? 12 : 35,
              top: compact ? 14 : 32,
              child: _worldClocks(w),
            ),
            Positioned(
              bottom: compact ? 23 : constraints.maxHeight * .07,
              left: horizontal, right: horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < _shortcuts.length; i++)
                    _shortcutTile(_shortcuts[i], slot, diameter, i == 0),
                ],
              ),
            ),
          ])),
        ]);
      }),
    );
  }
}

class _TintedLogo extends StatelessWidget {
  final _Shortcut shortcut;
  final double size;
  const _TintedLogo({required this.shortcut, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = shortcut.color;
    final kind = shortcut.logo;
    Widget logo;
    switch (kind) {
      case 'netflix':
        logo = Text('N', style: TextStyle(
          color: color, fontSize: size * .69, height: 1,
          fontWeight: FontWeight.w900, letterSpacing: -2,
          shadows: [Shadow(color: color.withOpacity(.38), blurRadius: 8)]));
        break;
      case 'max':
        logo = Text('max', style: TextStyle(
          color: color, fontSize: size * .33,
          fontWeight: FontWeight.w800, letterSpacing: -1.7));
        break;
      case 'apple':
        logo = Row(mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, children: [
          Icon(CupertinoIcons.logo_apple, color: color, size: size * .36),
          Text('tv', style: TextStyle(color: color,
              fontSize: size * .34, fontWeight: FontWeight.w600)),
        ]);
        break;
      case 'hulu':
        logo = Text('hulu', style: TextStyle(color: color,
            fontSize: size * .34, fontWeight: FontWeight.w800));
        break;
      case 'disney':
        logo = Text('Disney+', style: TextStyle(color: color,
          fontStyle: FontStyle.italic, fontSize: size * .205,
          fontFamily: 'serif', fontWeight: FontWeight.w700));
        break;
      case 'peacock':
        logo = Row(mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, children: [
          Text('peacock', style: TextStyle(color: _snow,
            fontSize: size * .154, fontWeight: FontWeight.w700)),
          const SizedBox(width: 3),
          Column(mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in [Color(0xFFFFD446), Color(0xFFFE73A2),
                Color(0xFF9F79FF), Color(0xFF49C9FD), Color(0xFF47E4BB)])
                Container(width: size * .036, height: size * .036,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            ],
          )
        ]);
        break;
      case 'prime':
        logo = Column(mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, children: [
          Text('prime', style: TextStyle(color: color,
            fontSize: size * .305, height: 1.02, fontWeight: FontWeight.w700)),
          SizedBox(width: size * .55, height: size * .14,
            child: CustomPaint(painter: _SmilePainter(color))),
        ]);
        break;
      case 'youtube':
        logo = Container(width: size * .49, height: size * .34,
          decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(size * .09),
            boxShadow: [BoxShadow(color: color.withOpacity(.24), blurRadius: 9)]),
          child: Icon(Icons.play_arrow_rounded,
              size: size * .28, color: const Color(0xFF16204B)));
        break;
      case 'spotify':
        logo = CustomPaint(size: Size(size * .60, size * .60),
          painter: _SpotifyPainter(color));
        break;
      case 'controller':
        logo = Icon(Icons.sports_esports_rounded,
            color: color, size: size * .65);
        break;
      default:
        logo = Text(shortcut.name, style: TextStyle(color: color,
          fontSize: size * .19, fontWeight: FontWeight.bold));
    }
    return Center(child: FittedBox(fit: BoxFit.scaleDown, child: logo));
  }
}

class _SpotifyPainter extends CustomPainter {
  final Color color;
  const _SpotifyPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(size.center(Offset.zero), size.shortestSide * .48,
        Paint()..color = color);
    final paint = Paint()
      ..color = const Color(0xFF05233F)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (.33 + i * .15);
      final path = Path()
        ..moveTo(size.width * .20, y)
        ..quadraticBezierTo(size.width * .55, y - size.height * .11,
            size.width * .81, y + size.height * .06);
      paint.strokeWidth = (size.width * (.07 - i * .009)).clamp(2.0, 9.0);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpotifyPainter oldDelegate) => oldDelegate.color != color;
}

class _SmilePainter extends CustomPainter {
  final Color color;
  const _SmilePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = (size.height * .19).clamp(1.2, 5.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final smile = Path()
      ..moveTo(size.width * .10, size.height * .16)
      ..quadraticBezierTo(size.width * .46, size.height * .94,
          size.width * .90, size.height * .17);
    canvas.drawPath(smile, stroke);
  }
  @override
  bool shouldRepaint(covariant _SmilePainter oldDelegate) => oldDelegate.color != color;
}

class _GlassCircle extends StatefulWidget {
  final double size;
  final Widget child;
  final Color accent;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;
  const _GlassCircle({required this.size, required this.child,
    required this.accent, required this.label, required this.onTap,
    this.autofocus = false});

  @override
  State<_GlassCircle> createState() => _GlassCircleState();
}

class _GlassCircleState extends State<_GlassCircle> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Semantics(
      label: widget.label, button: true,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          autofocus: widget.autofocus,
          customBorder: const CircleBorder(),
          onTap: widget.onTap,
          onFocusChange: (v) => setState(() => _focused = v),
          splashColor: accent.withOpacity(.12),
          child: AnimatedScale(
            scale: _focused ? 1.10 : 1.0,
            duration: const Duration(milliseconds: 160),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: widget.size, width: widget.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    const Color(0xD2181048),
                    Color.lerp(const Color(0xE00A163E), accent, .17)!,
                    const Color(0xE6081232),
                  ],
                ),
                border: Border.all(color: accent.withOpacity(_focused ? 1 : .82),
                    width: _focused ? 2.6 : 1.5),
                boxShadow: [
                  BoxShadow(color: accent.withOpacity(_focused ? .49 : .21),
                    blurRadius: _focused ? 25 : 14, spreadRadius: _focused ? 3 : 1),
                  const BoxShadow(color: Color(0x6001061A), blurRadius: 15),
                ],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
