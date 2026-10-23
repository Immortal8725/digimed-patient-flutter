import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import 'renal_models.dart';
import 'renal_repository.dart';

/// Upcoming dialysis lifts: pickup time, confirm or cancel, driver ETA and the GPS pins.
class TransportScreen extends ConsumerStatefulWidget {
  const TransportScreen({super.key});

  @override
  ConsumerState<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends ConsumerState<TransportScreen> {
  bool _loading = true;
  String? _error;
  String? _info;
  RenalUpcoming? _data;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(renalRepositoryProvider).upcoming();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _run(Future<String?> Function() action) async {
    try {
      final msg = await action();
      if (!mounted) return;
      setState(() {
        _info = msg;
        _error = null;
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<bool> _ask(String title, String body) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return yes == true;
  }

  Future<Position?> _position() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(
          () => _error =
              'Location permission was not granted, so the pin was not saved.',
        );
      }
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Location is unavailable right now. Try again outside or near a window.',
        );
      }
      return null;
    }
  }

  Future<void> _confirm(RenalTrip trip, bool confirmed) async {
    final ok = await _ask(
      confirmed ? 'Confirm this lift?' : 'Cancel this lift?',
      confirmed
          ? 'The driver will collect you at ${trip.pickupTime.isEmpty ? 'the planned time' : trip.pickupTime}.'
          : 'The unit will be told you do not need this lift.',
    );
    if (!ok) return;
    final repo = ref.read(renalRepositoryProvider);
    await _run(() => repo.confirmTrip(trip.id, confirmed: confirmed));
  }

  Future<void> _pinHere(RenalTrip trip) async {
    final ok = await _ask(
      'Pin this spot for pickup?',
      'Your current GPS position is sent to the unit and the driver for this lift only.',
    );
    if (!ok) return;
    final pos = await _position();
    if (pos == null) return;
    final repo = ref.read(renalRepositoryProvider);
    await _run(() async {
      await repo.setTripPin(
        trip.id,
        pos.latitude,
        pos.longitude,
        accuracy: pos.accuracy,
      );
      return 'Pickup pin saved';
    });
  }

  Future<void> _clearTripPin(RenalTrip trip) async {
    if (!await _ask(
      'Clear the pickup pin?',
      'The driver will use the address only.',
    )) {
      return;
    }
    final repo = ref.read(renalRepositoryProvider);
    await _run(() async {
      await repo.clearTripPin(trip.id);
      return 'Pickup pin cleared';
    });
  }

  Future<void> _homePin() async {
    final ok = await _ask(
      'Save this spot as your home pin?',
      'Stand at your gate or front door. Your GPS position is saved so drivers find you on every lift.',
    );
    if (!ok) return;
    final pos = await _position();
    if (pos == null) return;
    final repo = ref.read(renalRepositoryProvider);
    await _run(() async {
      await repo.setHomePin(
        pos.latitude,
        pos.longitude,
        accuracy: pos.accuracy,
      );
      return 'Home pin saved';
    });
  }

  Future<void> _clearHomePin() async {
    if (!await _ask(
      'Clear your home pin?',
      'Drivers will use your street address only.',
    )) {
      return;
    }
    final repo = ref.read(renalRepositoryProvider);
    await _run(() async {
      await repo.clearHomePin();
      return 'Home pin cleared';
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Dialysis transport')),
      body: _loading && data == null
          ? const LoadingView(label: 'Loading your lifts')
          : data == null
          ? ErrorView(
              message: _error ?? 'Could not load your lifts',
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_error != null) _Banner(text: _error!, error: true),
                  if (_info != null) _Banner(text: _info!),
                  SectionCard(
                    title: 'Home pickup point',
                    subtitle: data.homeAddress.isEmpty
                        ? 'No home address on file'
                        : data.homeAddress,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            data.homePinSet
                                ? 'GPS home pin saved'
                                : 'No GPS home pin',
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _homePin,
                          icon: const Icon(Icons.my_location),
                          label: Text(
                            data.homePinSet ? 'Update home pin' : 'Pin my home',
                          ),
                        ),
                        if (data.homePinSet)
                          OutlinedButton(
                            onPressed: _clearHomePin,
                            child: const Text('Clear home pin'),
                          ),
                      ],
                    ),
                  ),
                  if (data.sessions.every((s) => s.trips.isEmpty))
                    const EmptyView(
                      title: 'No lifts booked',
                      detail: 'Lifts the unit books for you will show here.',
                    ),
                  for (final day in data.sessions)
                    for (final trip in day.trips) _tripCard(day, trip),
                ],
              ),
            ),
    );
  }

  Widget _tripCard(RenalSessionDay day, RenalTrip trip) {
    final eta = trip.etaLabel;
    return SectionCard(
      title: '${trip.directionLabel} - ${day.date}',
      subtitle:
          'Session ${day.startTime}${day.endTime.isEmpty ? '' : ' to ${day.endTime}'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pickup time: ${trip.pickupTime.isEmpty ? 'to be confirmed' : trip.pickupTime}',
          ),
          if (trip.pickupAddress.isNotEmpty)
            Text('Pickup at: ${trip.pickupAddress}'),
          Text(trip.pinSet ? 'GPS pickup pin set' : 'No GPS pickup pin'),
          Text('Status: ${trip.status.replaceAll('_', ' ').toLowerCase()}'),
          Text(trip.confirmationLabel),
          if (trip.driverFirstName.isNotEmpty)
            Text(
              'Driver: ${trip.driverFirstName}${trip.vehicle.isEmpty ? '' : ', ${trip.vehicle}'}',
            ),
          if (eta != null)
            Text(eta, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (trip.editable && trip.confirmation != 'CONFIRMED')
                FilledButton(
                  onPressed: () => _confirm(trip, true),
                  child: const Text('Confirm lift'),
                ),
              if (trip.editable && trip.confirmation != 'DECLINED')
                OutlinedButton(
                  onPressed: () => _confirm(trip, false),
                  child: const Text('Cancel lift'),
                ),
              if (trip.editable)
                OutlinedButton.icon(
                  onPressed: () => _pinHere(trip),
                  icon: const Icon(Icons.pin_drop),
                  label: Text(
                    trip.pinSet ? 'Move pin here' : 'Pin pickup here',
                  ),
                ),
              if (trip.editable && trip.pinSet)
                TextButton(
                  onPressed: () => _clearTripPin(trip),
                  child: const Text('Clear pin'),
                ),
              if (trip.driverLive)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(mapLink(trip.driverLat!, trip.driverLng!)),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.directions_car),
                  label: const Text('See driver on map'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: error ? scheme.errorContainer : scheme.secondaryContainer,
      child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
    );
  }
}
