import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/json/json_values.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/heart_ui.dart';

export '../../core/widgets/heart_ui.dart';
import '../appointments/appointment_models.dart';

String _pad(int n) => n.toString().padLeft(2, '0');

/// Same rule as the website (src/utils/appointmentStatus.js): an active
/// status and a local date and time that has not passed yet.
bool isUpcomingAt(Appointment appt, DateTime now) {
  const active = {'BOOKED', 'PENDING', 'CONFIRMED', 'ARRIVED', 'IN_PROGRESS'};
  final status = (appt.status.isEmpty ? 'BOOKED' : appt.status).toUpperCase();
  if (!active.contains(status) || appt.date.length < 10) return false;
  final today = '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
  final date = appt.date.substring(0, 10);
  if (date.compareTo(today) > 0) return true;
  if (date.compareTo(today) < 0) return false;
  if (status == 'ARRIVED' || status == 'IN_PROGRESS') return true;
  final until = (appt.endTime.isNotEmpty ? appt.endTime : (appt.startTime.isNotEmpty ? appt.startTime : '23:59'));
  final hhmm = until.length >= 5 ? until.substring(0, 5) : until;
  return hhmm.compareTo('${_pad(now.hour)}:${_pad(now.minute)}') >= 0;
}

List<Appointment> upcomingAppointments(List<Appointment> list, DateTime now) =>
    list.where((a) => isUpcomingAt(a, now)).toList()
      ..sort((a, b) => '${a.date}${a.startTime}'.compareTo('${b.date}${b.startTime}'));

class DashboardData {
  const DashboardData({
    this.profile = const {},
    this.appointments = const [],
    this.vitals = const [],
    this.clinicName = '',
    this.connected = false,
    this.consentAccepted,
    this.error,
    this.dosesToday = 0,
  });

  final Map<String, dynamic> profile;
  final List<Appointment> appointments;
  final List<Map<String, dynamic>> vitals;
  final String clinicName;
  final bool connected;
  final bool? consentAccepted;
  final String? error;
  final int dosesToday;
}

class DrawerLink {
  const DrawerLink(this.label, this.icon, this.route, {this.section = 'CLINICAL'});
  final String label;
  final IconData icon;
  final String route;
  final String section;
}

/// Same order and sections as the website patient menu.
const patientMenu = <DrawerLink>[
  DrawerLink('Patient Dashboard', Icons.dashboard_outlined, '/home'),
  DrawerLink('Find Care', Icons.search, '/find-care'),
  DrawerLink('Book Appointment', Icons.event_available_outlined, '/book'),
  DrawerLink('My Appointments', Icons.schedule, '/appointments'),
  DrawerLink('My Medications', Icons.medication_outlined, '/medications'),
  DrawerLink('Intake Form', Icons.description_outlined, '/intake'),
  DrawerLink('Dialysis lifts and meals', Icons.water_drop_outlined, '/mission'),
  DrawerLink('My reviews', Icons.reviews_outlined, '/reviews'),
  DrawerLink('My data rights', Icons.shield_outlined, '/rights'),
  DrawerLink('Paperless Notifications', Icons.notifications_outlined, '/notifications', section: 'OPS'),
  DrawerLink('Paperless Consent', Icons.verified_user_outlined, '/consent', section: 'OPS'),
  DrawerLink('My Research', Icons.science_outlined, '/research', section: 'RESEARCH'),
];

class PatientDrawer extends StatelessWidget {
  const PatientDrawer({super.key, this.clinicName = '', this.current = '/home'});
  final String clinicName;
  final String current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    String? section;
    for (final link in patientMenu) {
      if (link.section != section) {
        section = link.section;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              section,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        );
      }
      children.add(
        ListTile(
          dense: true,
          leading: Icon(link.icon),
          title: Text(link.label),
          selected: link.route == current,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onTap: () {
            Navigator.of(context).maybePop();
            if (link.route != current) {
              link.route == '/home' ? context.go(link.route) : context.push(link.route);
            }
          },
        ),
      );
    }
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: DigimedLogo(size: 30, subtitle: clinicName.isEmpty ? 'Patient' : '$clinicName · Patient'),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Accent sampled from the website "My Heart" dashboard.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
}

class PatientDashboardView extends StatelessWidget {
  const PatientDashboardView({super.key, required this.data, required this.now, this.onRefresh, this.onToggleTheme});

  final DashboardData data;
  final DateTime now;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 760;
        final upcoming = upcomingAppointments(data.appointments, now);
        final latest = data.vitals.isEmpty ? const <String, dynamic>{} : data.vitals.first;
        final hr = firstString(latest, ['heartRate']);
        final main = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(clinic: data.clinicName, name: firstString(data.profile, ['fullName', 'name'])),
            const SizedBox(height: 16),
            _Greeting(data: data),
            if (data.error != null) ...[
              const SizedBox(height: 8),
              Text(data.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: HeartSection('Heart Conditions', _HeartTiles(latest: latest))),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: HeartSection(
                      'My Schedule',
                      _ScheduleCard(upcoming: upcoming, total: data.appointments.length),
                    ),
                  ),
                ],
              )
            else ...[
              HeartSection('Heart Conditions', _HeartTiles(latest: latest)),
              const SizedBox(height: 16),
              HeartSection('My Schedule', _ScheduleCard(upcoming: upcoming, total: data.appointments.length)),
              const SizedBox(height: 16),
              _HeartRateCard(value: hr),
            ],
            const SizedBox(height: 16),
            _BodyCarousel(data: data, heartRate: hr),
            const SizedBox(height: 16),
            HeartSection('My Information', _InfoCard(profile: data.profile)),
            const SizedBox(height: 16),
            HeartSection('Paperless Care', _ConsentCard(accepted: data.consentAccepted)),
          ],
        );
        final panel = Container(
          decoration: BoxDecoration(
            color: HeartColors.panel(dark),
            borderRadius: BorderRadius.circular(wide ? 28 : 20),
            border: Border.all(color: dark ? Colors.white10 : Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: dark ? Colors.black54 : const Color(0x22000000),
                blurRadius: 18,
                offset: const Offset(6, 6),
              ),
              if (!dark) const BoxShadow(color: Colors.white, blurRadius: 18, offset: Offset(-6, -6)),
            ],
          ),
          padding: EdgeInsets.all(wide ? 20 : 14),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconRail(onToggleTheme: onToggleTheme),
                    const SizedBox(width: 20),
                    Expanded(child: main),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 260,
                      child: _Rings(child: _HeartRateCard(value: hr)),
                    ),
                  ],
                )
              : main,
        );
        final list = ListView(padding: EdgeInsets.all(wide ? 24 : 12), children: [panel]);
        return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.clinic, required this.name});
  final String clinic;
  final String name;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = HeartColors.accentOf(context);
    final badge = clinic.isEmpty ? 'DM' : initialsOf(clinic);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HeartColors.card(dark),
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6)],
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: badge,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                TextSpan(
                  text: '+',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: accent),
                ),
              ],
            ),
            semanticsLabel: 'Clinic $clinic',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/find-care'),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: HeartColors.card(dark), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Search care...',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                  const Icon(Icons.search, size: 18),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        HeartIconChip(Icons.notifications_none, tooltip: 'Notifications', onTap: () => context.push('/notifications')),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => context.push('/profile'),
          customBorder: const CircleBorder(),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: accent.withValues(alpha: 0.14),
            child: Text(
              initialsOf(name),
              style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = firstString(data.profile, ['fullName', 'name']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Heart', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(name.isEmpty ? 'Welcome Back!' : 'Welcome Back, $name!', style: theme.textTheme.bodyMedium),
            if (data.clinicName.isNotEmpty)
              Text(
                data.clinicName,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            _StatusChip(data.connected ? 'Connected' : 'Offline', good: data.connected),
          ],
        ),
      ],
    );
  }
}

class _IconRail extends StatelessWidget {
  const _IconRail({this.onToggleTheme});
  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.grid_view, 'Dashboard', '/home'),
      (Icons.favorite_border, 'My Heart', ''),
      (Icons.chat_bubble_outline, 'My Appointments', '/appointments'),
      (Icons.description_outlined, 'Intake Form', '/intake'),
      (Icons.person_outline, 'Profile', '/profile'),
    ];
    return Column(
      children: [
        const SizedBox(height: 70),
        for (final i in items) ...[
          HeartIconChip(
            i.$1,
            active: i.$3.isEmpty,
            tooltip: i.$2,
            onTap: i.$3.isEmpty ? null : () => i.$3 == '/home' ? context.go('/home') : context.push(i.$3),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(width: 24, child: Divider()),
        const SizedBox(height: 12),
        HeartIconChip(Icons.speed, tooltip: 'Mission control', onTap: () => context.push('/mission')),
        const SizedBox(height: 12),
        HeartIconChip(Icons.light_mode_outlined, tooltip: 'Theme', onTap: onToggleTheme),
      ],
    );
  }
}

class _HeartTiles extends StatelessWidget {
  const _HeartTiles({required this.latest});
  final Map<String, dynamic> latest;

  @override
  Widget build(BuildContext context) {
    String g(String k) => firstString(latest, [k]);
    final sys = g('bloodPressureSystolic'), dia = g('bloodPressureDiastolic');
    final tiles = <(String, IconData, String, String, bool)>[
      (
        'Blood Pressure',
        Icons.water_drop_outlined,
        sys.isNotEmpty && dia.isNotEmpty ? '$sys/$dia mmHg' : '',
        'No blood pressure recorded yet',
        false,
      ),
      (
        'Heart Rate',
        Icons.favorite_border,
        g('heartRate').isEmpty ? '' : '${g('heartRate')} bpm',
        'No heart rate recorded yet',
        true,
      ),
      ('Weight', Icons.bar_chart, g('weight').isEmpty ? '' : '${g('weight')} kg', 'No weight recorded yet', false),
      (
        'O₂ Saturation',
        Icons.dns_outlined,
        g('oxygenSaturation').isEmpty ? '' : '${g('oxygenSaturation')}%',
        'No oxygen reading yet',
        false,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in tiles)
              SizedBox(
                width: w,
                child: _HeartTile(t.$1, t.$2, t.$3, t.$4, active: t.$5),
              ),
          ],
        );
      },
    );
  }
}

class _HeartTile extends StatelessWidget {
  const _HeartTile(this.label, this.icon, this.value, this.empty, {this.active = false});
  final String label;
  final IconData icon;
  final String value;
  final String empty;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return HeartCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeartIconChip(icon, active: active),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      value.isEmpty ? '—' : value,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 64,
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: HeartColors.inner(dark), borderRadius: BorderRadius.circular(10)),
            child: value.isEmpty
                ? Text(
                    empty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  )
                : Text(
                    'Latest clinic reading',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: active ? HeartColors.accentOf(context) : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatefulWidget {
  const _ScheduleCard({required this.upcoming, required this.total});
  final List<Appointment> upcoming;
  final int total;

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = widget.upcoming;
    final i = list.isEmpty ? 0 : _i.clamp(0, list.length - 1);
    final a = list.isEmpty ? null : list[i];
    final doctors = {
      for (final x in list)
        if (x.doctorName.isNotEmpty) x.doctorName,
    };
    final when = a == null
        ? 'Nothing booked'
        : [
            a.date,
            a.startTime.length >= 5 ? a.startTime.substring(0, 5) : a.startTime,
          ].where((s) => s.isNotEmpty).join(' · ');
    return HeartCard(
      onTap: a == null ? null : () => context.push('/appointments/${a.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HeartIconChip(Icons.calendar_today_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Check-up',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    Text(when, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous',
                icon: const Icon(Icons.arrow_back, size: 18),
                onPressed: i > 0 ? () => setState(() => _i = i - 1) : null,
              ),
              Expanded(
                child: Text(
                  a == null ? '—' : (a.doctorName.isEmpty ? 'Visit' : a.doctorName),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Next',
                icon: const Icon(Icons.arrow_forward, size: 18),
                onPressed: i < list.length - 1 ? () => setState(() => _i = i + 1) : null,
              ),
            ],
          ),
          Center(
            child: Text(
              doctors.isEmpty ? 'No doctors linked yet' : doctors.join(', '),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '${list.length} upcoming · ${widget.total} total',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: HeartColors.accentOf(context),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () => context.push('/book'),
              child: const Row(
                children: [
                  Expanded(child: Text('Consult Now')),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartRateCard extends StatelessWidget {
  const _HeartRateCard({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = HeartColors.accentOf(context);
    return HeartCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: accent),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Heart Rate',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    value.isEmpty ? 'No reading yet' : '$value bpm',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            width: double.infinity,
            child: CustomPaint(painter: _TracePainter(accent)),
          ),
          Text(
            'Illustrative trace',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height, w = size.width, mid = h / 2;
    final path = Path()..moveTo(0, mid);
    const pts = [0.30, 0.34, 0.37, 0.40, 0.43, 0.47, 0.62, 0.66, 0.69, 0.72, 0.75, 0.79];
    const ys = [0.5, 0.35, 0.95, 0.0, 0.7, 0.5, 0.5, 0.35, 0.95, 0.0, 0.7, 0.5];
    for (var i = 0; i < pts.length; i++) {
      path.lineTo(w * pts[i], h * ys[i]);
    }
    path.lineTo(w, mid);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TracePainter old) => old.color != color;
}

class _Rings extends StatelessWidget {
  const _Rings({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget ring(double s) => Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HeartColors.panel(dark),
        border: Border.all(color: dark ? Colors.white10 : Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: dark ? Colors.black45 : const Color(0x18000000), blurRadius: 16, offset: const Offset(4, 4)),
        ],
      ),
    );
    return SizedBox(
      height: 520,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 120, child: ring(250)),
          Positioned(top: 150, child: ring(190)),
          Positioned(bottom: 0, left: 0, right: 0, child: child),
        ],
      ),
    );
  }
}

class _BodyCarousel extends StatefulWidget {
  const _BodyCarousel({required this.data, required this.heartRate});
  final DashboardData data;
  final String heartRate;

  @override
  State<_BodyCarousel> createState() => _BodyCarouselState();
}

class _BodyCarouselState extends State<_BodyCarousel> {
  final _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _step(double by) {
    if (!_ctrl.hasClients) return;
    _ctrl.animateTo(
      (_ctrl.offset + by).clamp(0, _ctrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final cards = <(String, String, IconData, String)>[
      ('My Records', 'Paperless care', Icons.folder_open_outlined, '/notifications'),
      (
        'My Heart',
        widget.heartRate.isEmpty ? 'No reading yet' : '${widget.heartRate} bpm',
        Icons.favorite_border,
        '/mission',
      ),
      (
        'My Medications',
        d.dosesToday > 0 ? '${d.dosesToday} doses due today' : "Today's doses",
        Icons.medication_outlined,
        '/medications',
      ),
      ('My Kidneys', 'Dialysis lifts and meals', Icons.water_drop_outlined, '/mission'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.circle, size: 7, color: HeartColors.accentOf(context)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'My Body Condition',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            HeartIconChip(Icons.arrow_back, tooltip: 'Scroll left', onTap: () => _step(-160)),
            const SizedBox(width: 6),
            HeartIconChip(Icons.arrow_forward, tooltip: 'Scroll right', onTap: () => _step(160)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ListView.separated(
            controller: _ctrl,
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            padding: const EdgeInsets.only(bottom: 6, right: 4),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => SizedBox(width: 140, child: _BodyCard(cards[i])),
          ),
        ),
      ],
    );
  }
}

class _BodyCard extends StatelessWidget {
  const _BodyCard(this.c);
  final (String, String, IconData, String) c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = HeartColors.accentOf(context);
    return HeartCard(
      padding: const EdgeInsets.all(6),
      onTap: () => context.push(c.$4),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: HeartColors.inner(dark), borderRadius: BorderRadius.circular(10)),
              child: Icon(c.$3, size: 30, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.$1,
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      c.$2,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.north_east, size: 14, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label, {required this.good});
  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = good
        ? (dark ? DigimedBrand.darkPrimary : DigimedBrand.patient)
        : (dark ? const Color(0xFFFBBF24) : const Color(0xFF92400E));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg),
        color: fg.withValues(alpha: 0.08),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.trailing});
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    String v(List<String> keys) => firstString(profile, keys);
    final aid = v(['medicalAid', 'medicalAidProvider']);
    final level = v(['coverageLevel']).toUpperCase();
    final phone = v(['phone']);
    final verified = phone.isNotEmpty && asBool(profile['phoneVerified']);
    return HeartCard(
      onTap: () => context.push('/profile'),
      child: Column(
        children: [
          _Row('Name', v(['fullName', 'name']).isEmpty ? 'Not on file' : v(['fullName', 'name'])),
          _Row(
            'Medical aid',
            aid.isEmpty ? 'N/A' : aid,
            trailing: level.isEmpty
                ? null
                : _StatusChip(
                    level == 'FULL'
                        ? 'Full cover'
                        : level == 'PARTIAL'
                        ? 'Partial cover'
                        : 'No cover',
                    good: level == 'FULL',
                  ),
          ),
          if (v(['planClass', 'planName']).isNotEmpty) _Row('Plan', v(['planClass', 'planName'])),
          _Row('Email', v(['email']).isEmpty ? 'Not on file' : v(['email'])),
          _Row(
            'Phone',
            phone.isEmpty ? 'Not on file' : phone,
            trailing: phone.isEmpty ? null : _StatusChip(verified ? 'Verified' : 'Not verified', good: verified),
          ),
        ],
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.accepted});
  final bool? accepted;

  @override
  Widget build(BuildContext context) {
    final text = switch (accepted) {
      true => 'You have given consent for your clinic to keep your records paperless.',
      false => 'You have not given paperless consent yet.',
      null => 'Consent status could not be loaded.',
    };
    return HeartCard(
      onTap: () => context.push('/consent'),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          if (accepted != null) _StatusChip(accepted! ? 'Consent given' : 'Not given', good: accepted!),
        ],
      ),
    );
  }
}
