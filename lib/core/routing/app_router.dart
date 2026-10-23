import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/appointment_detail_screen.dart';
import '../../features/appointments/appointments_screen.dart';
import '../../features/appointments/chat_screen.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/care/care_hub_screen.dart';
import '../../features/care/clinics_screen.dart';
import '../../features/care/consent_screen.dart';
import '../../features/care/intake_screen.dart';
import '../../features/care/medications_screen.dart';
import '../../features/care/notifications_screen.dart';
import '../../features/care/privacy_screen.dart';
import '../../features/care/profile_screen.dart';
import '../../features/care/research_screen.dart';
import '../../features/care/rights_screen.dart';
import '../../features/care/telehealth_screen.dart';
import '../../features/find_care/book_screen.dart';
import '../../features/find_care/clinic_screen.dart';
import '../../features/find_care/find_care_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/mission_screen.dart';
import '../../features/renal/meals_screen.dart';
import '../../features/renal/transport_screen.dart';
import '../../features/reviews/my_reviews_screen.dart';
import '../network/api_client.dart';
import '../widgets/patient_shell.dart';
import '../widgets/status_views.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.uri.path;
      final isPublic = path == '/login' || path == '/signup';
      if (auth.isLoading) {
        return path == '/boot' ? null : '/boot';
      }
      final session = auth.value;
      if (session == null) return isPublic ? null : '/login';
      if (isPublic || path == '/boot') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/boot',
        builder: (context, state) => const Scaffold(
          body: LoadingView(label: 'Opening DigiMed Connect'),
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      ShellRoute(
        builder: (context, state, child) => PatientShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/find-care',
            builder: (context, state) => const FindCareScreen(),
          ),
          GoRoute(path: '/book', builder: (context, state) => const BookScreen()),
          GoRoute(
            path: '/clinic/:subdomain',
            builder: (context, state) =>
                ClinicScreen(subdomain: state.pathParameters['subdomain']!),
          ),
          GoRoute(
            path: '/appointments',
            builder: (context, state) => const AppointmentsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    AppointmentDetailScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'chat',
                    builder: (context, state) => ChatScreen(
                      appointmentId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(path: '/care', builder: (context, state) => const CareHubScreen()),
          GoRoute(path: '/mission', builder: (context, state) => const MissionScreen()),
          GoRoute(
            path: '/medications',
            builder: (context, state) => const MedicationsScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(path: '/privacy', builder: (context, state) => const PrivacyScreen()),
          GoRoute(path: '/consent', builder: (context, state) => const ConsentScreen()),
          GoRoute(path: '/research', builder: (context, state) => const ResearchScreen()),
          GoRoute(path: '/rights', builder: (context, state) => const RightsScreen()),
          GoRoute(path: '/transport', builder: (context, state) => const TransportScreen()),
          GoRoute(path: '/meals', builder: (context, state) => const MealsScreen()),
          GoRoute(path: '/reviews', builder: (context, state) => const MyReviewsScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          GoRoute(path: '/clinics', builder: (context, state) => const ClinicsScreen()),
          GoRoute(
            path: '/intake',
            builder: (context, state) => IntakeScreen(
              appointmentId: state.uri.queryParameters['appointmentId'],
              tenantId: state.uri.queryParameters['tenantId'],
            ),
          ),
          GoRoute(
            path: '/telehealth/room/:code',
            builder: (context, state) => TelehealthScreen(
              appointmentId: '',
              roomCode: state.pathParameters['code'],
            ),
          ),
          GoRoute(
            path: '/telehealth/:appointmentId',
            builder: (context, state) => TelehealthScreen(
              appointmentId: state.pathParameters['appointmentId']!,
            ),
          ),
        ],
      ),
    ],
  );
});

class SessionListener extends ConsumerWidget {
  const SessionListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(unauthorizedTickProvider, (previous, next) {
      if (previous != next && next > 0) {
        ref.read(authControllerProvider.notifier).sessionExpired();
      }
    });
    return child;
  }
}
