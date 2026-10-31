import 'package:flutter/material.dart';

import '../../core/widgets/heart_ui.dart';

import 'package:go_router/go_router.dart';

import '../../core/widgets/account_menu.dart';

const _icons = <String, IconData>{
  '/book': Icons.event_available_outlined,
  '/medications': Icons.medication_outlined,
  '/intake': Icons.description_outlined,
  '/notifications': Icons.notifications_none,
  '/privacy': Icons.privacy_tip_outlined,
  '/consent': Icons.verified_user_outlined,
  '/research': Icons.science_outlined,
  '/reviews': Icons.star_border,
  '/rights': Icons.gavel_outlined,
  '/profile': Icons.person_outline,
  '/clinics': Icons.local_hospital_outlined,
  '/mission': Icons.speed,
};

class CareHubScreen extends StatelessWidget {
  const CareHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Book appointment', '/book', 'Book at your clinic, in person or by video'),
      ('Medications', '/medications', 'Today\'s doses, taken, snooze, or skip'),
      ('Dialysis transport', '/transport', 'Lifts, pickup time, driver ETA and GPS pin'),
      ('Dialysis meals', '/meals', 'Allergies, diet and meal choice'),
      ('Intake form', '/intake', 'Tell the clinic why you are coming'),
      ('Notices', '/notifications', 'Approve or deny record access'),
      ('Privacy notice', '/privacy', 'Confirm you have seen the notice'),
      ('Paperless consent', '/consent', 'Grant or withdraw data-processing consent'),
      ('Research and eConsent', '/research', 'Offers, profile, and study consent'),
      ('My reviews', '/reviews', 'Rate your visit, go anonymous or delete'),
      ('My data rights', '/rights', 'Export a copy or ask about erasure'),
      ('Profile', '/profile', 'Email and verified phone'),
      ('Clinics', '/clinics', 'Choose the clinic on this account'),
      ('Mission control', '/mission', 'Next visit, wait, and offers'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Care'), actions: const [AccountMenu()]),
      body: HeartPage(
        children: [
          HeartSection(
            'My Care',
            Column(
              children: [
                for (final item in items)
                  HeartTile(
                    title: item.$1,
                    subtitle: item.$3,
                    icon: _icons[item.$2] ?? Icons.favorite_border,
                    active: item.$2 == '/book',
                    onTap: () => context.push(item.$2),
                  ),
              ],
            ),
            subtitle: 'The same patient tools as the DigiMed website. Staff desks stay on the web app.',
          ),
        ],
      ),
    );
  }
}
