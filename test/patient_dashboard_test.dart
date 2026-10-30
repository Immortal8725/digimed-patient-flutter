import 'package:digimed_connect/features/appointments/appointment_models.dart';
import 'package:digimed_connect/features/home/patient_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Appointment appt(String id, String date, {String status = 'BOOKED', String start = '09:00', String end = ''}) =>
    Appointment.fromJson({'id': id, 'status': status, 'appointmentDate': date, 'startTime': start, 'endTime': end, 'doctorName': 'Dr $id'});

final now = DateTime(2026, 10, 30, 12, 0);

Widget host(DashboardData data) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (c, s) => Scaffold(
        drawer: PatientDrawer(clinicName: data.clinicName),
        appBar: AppBar(),
        body: PatientDashboardView(data: data, now: now),
      ),
    ),
    for (final l in patientMenu.where((l) => l.route != '/home'))
      GoRoute(path: l.route, builder: (c, s) => Scaffold(body: Text('route ${l.route}'))),
    GoRoute(path: '/home', builder: (c, s) => const Text('home')),
    GoRoute(path: '/profile', builder: (c, s) => const Text('profile')),
  ]);
  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('upcoming rule matches the website', () {
    test('past, cancelled and completed are not upcoming', () {
      expect(isUpcomingAt(appt('a', '2026-10-29'), now), isFalse);
      expect(isUpcomingAt(appt('b', '2026-11-02', status: 'CANCELLED'), now), isFalse);
      expect(isUpcomingAt(appt('c', '2026-11-02', status: 'COMPLETED'), now), isFalse);
      expect(isUpcomingAt(appt('d', ''), now), isFalse);
    });
    test('future and later today are upcoming, earlier today is not', () {
      expect(isUpcomingAt(appt('a', '2026-11-02'), now), isTrue);
      expect(isUpcomingAt(appt('b', '2026-10-30', start: '14:00'), now), isTrue);
      expect(isUpcomingAt(appt('c', '2026-10-30', start: '08:00', end: '08:30'), now), isFalse);
      expect(isUpcomingAt(appt('d', '2026-10-30', start: '08:00', status: 'IN_PROGRESS'), now), isTrue);
    });
    test('sorted soonest first', () {
      final list = upcomingAppointments([appt('late', '2026-12-01'), appt('soon', '2026-11-01')], now);
      expect(list.map((a) => a.id), ['soon', 'late']);
    });
  });

  testWidgets('shows sample data like the web dashboard', (tester) async {
    await tester.pumpWidget(host(DashboardData(
      profile: const {'fullName': 'Siya Sithole', 'medicalAid': 'Discovery', 'coverageLevel': 'FULL', 'email': 's@x.co', 'phone': '0821234567', 'phoneVerified': true},
      appointments: [appt('x', '2026-11-03'), appt('y', '2026-09-01', status: 'COMPLETED')],
      vitals: const [{'bloodPressureSystolic': 120, 'bloodPressureDiastolic': 80, 'heartRate': 72}],
      clinicName: 'Aura Wellness',
      connected: true,
      consentAccepted: true,
    )));
    expect(find.text('Welcome Back, Siya Sithole!'), findsOneWidget);
    expect(find.text('Aura Wellness'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Full cover'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('120/80 mmHg'), findsOneWidget);
    expect(find.text('72 bpm'), findsOneWidget);
    expect(find.text('No weight recorded yet'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('1 upcoming · 2 total'), 200);
    expect(find.text('Dr x'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(host(DashboardData(
      profile: const {'fullName': 'Siya', 'phone': '0821234567'},
      appointments: [appt('old', '2026-01-01')],
      consentAccepted: false,
    )));
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Not verified'), findsOneWidget);
    expect(find.text('N/A'), findsOneWidget);
    expect(find.text('No blood pressure recorded yet'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Not given'), 200);
    expect(find.text('0 upcoming · 1 total'), findsOneWidget);
    expect(find.textContaining('No upcoming appointments'), findsOneWidget);
  });

  testWidgets('drawer lists the web menu and opens screens', (tester) async {
    await tester.pumpWidget(host(const DashboardData(clinicName: 'Aura Wellness')));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    for (final l in patientMenu) {
      await tester.scrollUntilVisible(find.text(l.label), 100, scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)));
      expect(find.text(l.label), findsOneWidget);
    }
    expect(patientMenu.length, 12);
    await tester.tap(find.text('My Research'));
    await tester.pumpAndSettle();
    expect(find.text('route /research'), findsOneWidget);
  });
}
