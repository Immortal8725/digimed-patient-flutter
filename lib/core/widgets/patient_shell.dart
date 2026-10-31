import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PatientShell extends StatelessWidget {
  const PatientShell({super.key, required this.child});

  final Widget child;

  int _index(String location) {
    if (location.startsWith('/find-care') ||
        location.startsWith('/clinic') ||
        location.startsWith('/book')) {
      return 1;
    }
    if (location.startsWith('/appointments')) return 2;
    if (location.startsWith('/care') ||
        location.startsWith('/medications') ||
        location.startsWith('/intake') ||
        location.startsWith('/notifications') ||
        location.startsWith('/privacy') ||
        location.startsWith('/consent') ||
        location.startsWith('/research') ||
        location.startsWith('/rights') ||
        location.startsWith('/profile') ||
        location.startsWith('/clinics') ||
        location.startsWith('/mission') ||
        location.startsWith('/telehealth')) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    // The home dashboard shows its own icon rail on wide screens, so the
    // bottom bar is hidden there to avoid doubled navigation.
    final railShows = location == '/home' && MediaQuery.sizeOf(context).width >= 760;
    final hideNav = railShows || location.contains('/chat') || location.startsWith('/telehealth');
    final index = _index(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: hideNav
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) {
                switch (value) {
                  case 1:
                    context.go('/find-care');
                  case 2:
                    context.go('/appointments');
                  case 3:
                    context.go('/care');
                  default:
                    context.go('/home');
                }
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.search), label: 'Find care'),
                NavigationDestination(icon: Icon(Icons.event_outlined), label: 'Visits'),
                NavigationDestination(icon: Icon(Icons.favorite_outline), label: 'Care'),
              ],
            ),
    );
  }
}
