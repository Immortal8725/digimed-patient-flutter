import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/account_menu.dart';

class CareHubScreen extends StatelessWidget {
  const CareHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Book appointment', '/book', 'Book at your clinic, in person or by video'),
      ('Medications', '/medications', 'Today\'s doses, taken, snooze, or skip'),
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
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'The same patient tools as the DigiMed website. Staff desks stay on the web app.',
            ),
          ),
          for (final item in items)
            ListTile(
              title: Text(item.$1),
              subtitle: Text(item.$3),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(item.$2),
            ),
        ],
      ),
    );
  }
}
