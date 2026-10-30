import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/json/json_values.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
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
  });

  final Map<String, dynamic> profile;
  final List<Appointment> appointments;
  final List<Map<String, dynamic>> vitals;
  final String clinicName;
  final bool connected;
  final bool? consentAccepted;
  final String? error;
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
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(section, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ));
      }
      children.add(ListTile(
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
      ));
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

class PatientDashboardView extends StatelessWidget {
  const PatientDashboardView({super.key, required this.data, required this.now, this.onRefresh});

  final DashboardData data;
  final DateTime now;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    final name = firstString(p, ['fullName', 'name']);
    final upcoming = upcomingAppointments(data.appointments, now);
    final list = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WelcomeCard(name: name, clinic: data.clinicName, connected: data.connected),
        if (data.error != null) ...[
          const SizedBox(height: 12),
          Text(data.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 12),
        _InfoCard(profile: p),
        const SizedBox(height: 12),
        _VitalsCard(vitals: data.vitals),
        const SizedBox(height: 12),
        _AppointmentsCard(upcoming: upcoming, total: data.appointments.length),
        const SizedBox(height: 12),
        _ConsentCard(accepted: data.consentAccepted),
      ],
    );
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child, this.trailing});
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
              ?trailing,
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
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
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.name, required this.clinic, required this.connected});
  final String name;
  final String clinic;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? DigimedBrand.darkSurface : DigimedBrand.patient,
        borderRadius: BorderRadius.circular(8),
        border: dark ? Border.all(color: theme.colorScheme.outlineVariant) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? 'Welcome Back!' : 'Welcome Back, $name!',
            style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.local_hospital_outlined, color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(clinic.isEmpty ? 'No clinic selected' : clinic,
                  style: const TextStyle(color: Colors.white70)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 8, color: connected ? const Color(0xFF86EFAC) : Colors.white54),
                const SizedBox(width: 6),
                Text(connected ? 'Connected' : 'Offline',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ],
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: 104,
          child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]),
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
    return _Panel(
      title: 'My Information',
      icon: Icons.verified_user_outlined,
      trailing: TextButton(onPressed: () => context.push('/profile'), child: const Text('Edit')),
      child: Column(children: [
        _Row('Name', v(['fullName', 'name']).isEmpty ? 'Not on file' : v(['fullName', 'name'])),
        _Row(
          'Medical aid',
          aid.isEmpty ? 'N/A' : aid,
          trailing: level.isEmpty
              ? null
              : _StatusChip(level == 'FULL' ? 'Full cover' : level == 'PARTIAL' ? 'Partial cover' : 'No cover',
                  good: level == 'FULL'),
        ),
        if (v(['planClass', 'planName']).isNotEmpty) _Row('Plan', v(['planClass', 'planName'])),
        _Row('Email', v(['email']).isEmpty ? 'Not on file' : v(['email'])),
        _Row(
          'Phone',
          phone.isEmpty ? 'Not on file' : phone,
          trailing: phone.isEmpty ? null : _StatusChip(verified ? 'Verified' : 'Not verified', good: verified),
        ),
      ]),
    );
  }
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.vitals});
  final List<Map<String, dynamic>> vitals;

  @override
  Widget build(BuildContext context) {
    final latest = vitals.isEmpty ? const <String, dynamic>{} : vitals.first;
    String g(String k) => firstString(latest, [k]);
    final sys = g('bloodPressureSystolic'), dia = g('bloodPressureDiastolic');
    final tiles = <(String, IconData, String, String)>[
      ('Blood Pressure', Icons.water_drop_outlined, sys.isNotEmpty && dia.isNotEmpty ? '$sys/$dia mmHg' : '', 'No blood pressure recorded yet'),
      ('Heart Rate', Icons.favorite_outline, g('heartRate').isEmpty ? '' : '${g('heartRate')} bpm', 'No heart rate recorded yet'),
      ('Weight', Icons.monitor_weight_outlined, g('weight').isEmpty ? '' : '${g('weight')} kg', 'No weight recorded yet'),
      ('O₂ Saturation', Icons.air, g('oxygenSaturation').isEmpty ? '' : '${g('oxygenSaturation')}%', 'No oxygen reading yet'),
      ('Temperature', Icons.thermostat_outlined, g('temperature').isEmpty ? '' : '${g('temperature')} °C', 'No temperature recorded yet'),
      ('Blood Sugar', Icons.bloodtype_outlined,
          firstString(latest, ['bloodGlucose', 'bloodSugar', 'glucose']).isEmpty ? '' : '${firstString(latest, ['bloodGlucose', 'bloodSugar', 'glucose'])} mmol/L',
          'No blood sugar recorded yet'),
    ];
    return _Panel(
      title: 'Vitals',
      icon: Icons.monitor_heart_outlined,
      trailing: vitals.isEmpty ? null : Text('${vitals.length} recorded', style: Theme.of(context).textTheme.bodySmall),
      child: LayoutBuilder(builder: (context, box) {
        final w = (box.maxWidth - 8) / 2;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in tiles) SizedBox(width: w, child: _VitalTile(t.$1, t.$2, t.$3, t.$4)),
        ]);
      }),
    );
  }
}

class _VitalTile extends StatelessWidget {
  const _VitalTile(this.label, this.icon, this.value, this.empty);
  final String label;
  final IconData icon;
  final String value;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 92,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: theme.textTheme.labelMedium, overflow: TextOverflow.ellipsis)),
        ]),
        const Spacer(),
        value.isEmpty
            ? Text(empty, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
            : Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _AppointmentsCard extends StatelessWidget {
  const _AppointmentsCard({required this.upcoming, required this.total});
  final List<Appointment> upcoming;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      title: 'Appointments',
      icon: Icons.event_outlined,
      trailing: Text('${upcoming.length} upcoming · $total total', style: theme.textTheme.bodySmall),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (upcoming.isEmpty)
          Text("No upcoming appointments. Book one whenever you're ready.",
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else
          for (final a in upcoming.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(a.isVideo ? Icons.videocam_outlined : Icons.medical_services_outlined,
                    color: theme.colorScheme.primary),
              ),
              title: Text(a.doctorName.isEmpty ? 'Visit' : a.doctorName),
              subtitle: Text([a.date, a.startTime.length >= 5 ? a.startTime.substring(0, 5) : a.startTime, a.clinicName]
                  .where((s) => s.isNotEmpty)
                  .join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/appointments/${a.id}'),
            ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FilledButton(onPressed: () => context.push('/book'), child: const Text('Book appointment'))),
          const SizedBox(width: 8),
          TextButton(onPressed: () => context.go('/appointments'), child: const Text('View all')),
        ]),
      ]),
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
    return _Panel(
      title: 'Paperless Care',
      icon: Icons.eco_outlined,
      trailing: accepted == null ? null : _StatusChip(accepted! ? 'Consent given' : 'Not given', good: accepted!),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text),
        TextButton(onPressed: () => context.push('/consent'), child: const Text('Manage consent')),
      ]),
    );
  }
}
