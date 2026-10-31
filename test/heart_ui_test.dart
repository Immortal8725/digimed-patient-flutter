import 'package:digimed_connect/core/theme/app_theme.dart';
import 'package:digimed_connect/core/widgets/heart_ui.dart';
import 'package:digimed_connect/core/widgets/patient_shell.dart';
import 'package:digimed_connect/core/widgets/status_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget wrap(Widget child, {Brightness b = Brightness.light}) =>
    MaterialApp(theme: buildDigimedTheme(b), home: Scaffold(body: child));

Widget shellAt(String path) => MaterialApp.router(
      theme: buildDigimedTheme(Brightness.light),
      routerConfig: GoRouter(initialLocation: path, routes: [
        ShellRoute(
          builder: (c, s, child) => PatientShell(child: child),
          routes: [
            GoRoute(path: '/home', builder: (c, s) => const Text('home')),
            GoRoute(path: '/care', builder: (c, s) => const Text('care')),
          ],
        ),
      ]),
    );

void main() {
  testWidgets('section, tile and CTA render and respond', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(ListView(children: [
      HeartSection('My Care', HeartTile(title: 'Medications', subtitle: 'Today', onTap: () => taps++)),
      HeartCta('Consult Now', onPressed: () => taps++),
    ])));
    expect(find.text('My Care'), findsOneWidget);
    await tester.tap(find.text('Medications'));
    await tester.tap(find.text('Consult Now'));
    expect(taps, 2);
  });

  testWidgets('empty view uses the grey empty box in dark mode too', (tester) async {
    await tester.pumpWidget(wrap(const EmptyView(title: 'No notices yet.', detail: 'Later'), b: Brightness.dark));
    expect(find.byType(HeartEmptyBox), findsOneWidget);
    expect(find.byType(HeartCard), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets('section card uses bullet header and soft card', (tester) async {
    await tester.pumpWidget(wrap(const SectionCard(title: 'Requests', child: Text('x'))));
    expect(find.byType(HeartHeader), findsOneWidget);
    expect(find.byType(HeartCard), findsOneWidget);
  });

  testWidgets('bottom bar hides on wide home where the rail shows', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpWidget(shellAt('/home'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    await tester.pumpWidget(shellAt('/care'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('bottom bar stays on phone home', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(412, 900);
    await tester.pumpWidget(shellAt('/home'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
