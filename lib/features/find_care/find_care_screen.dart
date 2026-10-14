import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import 'find_care_repository.dart';

class FindCareScreen extends ConsumerStatefulWidget {
  const FindCareScreen({super.key});

  @override
  ConsumerState<FindCareScreen> createState() => _FindCareScreenState();
}

class _FindCareScreenState extends ConsumerState<FindCareScreen> {
  final _place = TextEditingController();
  String _province = '';
  String _city = '';
  String _service = '';
  String _aid = '';
  late String _date;
  bool _public = false;
  bool _loadingLists = true;
  bool _searching = false;
  String? _error;
  String? _info;
  List<String> _provinces = [];
  List<String> _cities = [];
  List<String> _services = [];
  List<String> _aids = [];
  List<CareProvider> _providers = [];
  List<FacilityHit> _facilities = [];
  double? _lat;
  double? _lng;
  bool _consent = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now().toIso8601String().substring(0, 10);
    Future.microtask(_loadLists);
  }

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    final repo = ref.read(findCareRepositoryProvider);
    try {
      final locations = await repo.locations();
      final services = await repo.services();
      final aids = await repo.medicalAids();
      if (!mounted) return;
      setState(() {
        _provinces = locations.provinces;
        _cities = locations.cities;
        _services = services;
        _aids = aids;
        _loadingLists = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLists = false);
    }
  }

  Future<void> _useLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(
          () => _error = 'Location permission was not granted. Search by city or province.',
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _info = 'Using your location for this search.';
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Location is unavailable. Search by city or province.');
    }
  }

  Future<void> _search() async {
    if (!_public && _date.isEmpty) {
      setState(() => _error = 'Select a date.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _info = null;
    });
    final repo = ref.read(findCareRepositoryProvider);
    try {
      if (_public) {
        final rows = await repo.governmentFacilities(
          province: _province,
          query: _place.text,
        );
        if (!mounted) return;
        setState(() {
          _facilities = rows;
          _providers = [];
          _searching = false;
        });
      } else {
        final rows = await repo.search(
          FindCareFilters(
            place: _place.text,
            province: _province,
            city: _city,
            service: _service,
            medicalAid: _aid,
            date: _date,
            lat: _lat,
            lng: _lng,
          ),
        );
        if (!mounted) return;
        setState(() {
          _providers = rows;
          _facilities = [];
          _searching = false;
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = error.message;
      });
    }
  }

  Future<void> _book(CareProvider provider, String start) async {
    if (provider.providerId.isEmpty) {
      if (provider.subdomain.isNotEmpty) {
        context.push('/clinic/${provider.subdomain}');
      }
      return;
    }
    var accepted = _consent;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Check your booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${provider.name}\n$start on $_date\nVisit type: in person'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: accepted,
                onChanged: (value) => setLocal(() => accepted = value ?? false),
                title: const Text('I accept the data-processing and privacy notice (POPIA).'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
            FilledButton(
              onPressed: accepted ? () => Navigator.pop(context, true) : null,
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    _consent = true;
    try {
      await ref.read(findCareRepositoryProvider).book(
        doctorId: provider.providerId,
        date: _date,
        startTime: start.length >= 5 ? start.substring(0, 5) : start,
      );
      if (!mounted) return;
      setState(() => _info = 'Visit booked. You can review it under Appointments.');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find care'),
        actions: [
          TextButton(
            onPressed: () => context.push('/book'),
            child: const Text('Book'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Search private practices, or public clinics and hospitals, across South Africa.',
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Private')),
              ButtonSegment(value: true, label: Text('Public')),
            ],
            selected: {_public},
            onSelectionChanged: (value) => setState(() => _public = value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _place,
            decoration: const InputDecoration(
              labelText: 'Suburb, town or clinic',
            ),
          ),
          const SizedBox(height: 12),
          _dropdown('Province', _province, _provinces, (value) => setState(() => _province = value ?? '')),
          const SizedBox(height: 12),
          if (!_public) ...[
            _dropdown('City', _city, _cities, (value) => setState(() => _city = value ?? '')),
            const SizedBox(height: 12),
            _dropdown('Service', _service, _services, (value) => setState(() => _service = value ?? '')),
            const SizedBox(height: 12),
            _dropdown('Medical aid', _aid, _aids, (value) => setState(() => _aid = value ?? '')),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(_date),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(const Duration(days: 0)),
                  lastDate: DateTime.now().add(const Duration(days: 180)),
                  initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _date = picked.toIso8601String().substring(0, 10));
                }
              },
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _useLocation,
            icon: const Icon(Icons.my_location),
            label: Text(_lat == null ? 'Use my location' : 'Location set'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _searching ? null : _search,
            child: Text(_searching ? 'Searching...' : 'Search'),
          ),
          if (_loadingLists) const LinearProgressIndicator(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_info != null) ...[
            const SizedBox(height: 12),
            Text(_info!),
          ],
          const SizedBox(height: 12),
          if (_public)
            for (final facility in _facilities)
              Card(
                child: ListTile(
                  title: Text(facility.name.isEmpty ? 'Facility' : facility.name),
                  subtitle: Text(
                    [facility.address, facility.city, facility.province, facility.phone]
                        .where((part) => part.isNotEmpty)
                        .join(', '),
                  ),
                ),
              )
          else
            for (var index = 0; index < _providers.length; index++)
              _providerCard(_providers[index], index == 0),
          if (!_searching && _providers.isEmpty && _facilities.isEmpty && _info == null)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text('Search to see clinics and open slots.'),
            ),
        ],
      ),
    );
  }

  Widget _dropdown(
    String label,
    String current,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: current,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('Any')),
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: onChanged,
    );
  }

  Widget _providerCard(CareProvider provider, bool best) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (best) const Text('Best match'),
            Text(provider.name, style: Theme.of(context).textTheme.titleMedium),
            Text(provider.specialty.isEmpty ? 'General practitioner' : provider.specialty),
            if (provider.clinicName.isNotEmpty) Text('Clinic: ${provider.clinicName}'),
            Text(
              [provider.address, provider.city, provider.province]
                  .where((part) => part.isNotEmpty)
                  .join(', '),
            ),
            if (provider.distanceKm != null && provider.distanceKm! > 0)
              Text('${provider.distanceKm!.toStringAsFixed(1)} km away'),
            if (provider.services.isNotEmpty)
              Text('Services: ${provider.services.join(', ')}'),
            if (provider.medicalAids.isNotEmpty)
              Text('Medical aids: ${provider.medicalAids.join(', ')}'),
            const SizedBox(height: 8),
            if (provider.slots.isEmpty)
              const Text('No open slots were returned for this date.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in provider.slots)
                    OutlinedButton(
                      onPressed: () => _book(provider, slot),
                      child: Text(slot),
                    ),
                ],
              ),
            if (provider.subdomain.isNotEmpty)
              TextButton(
                onPressed: () => context.push('/clinic/${provider.subdomain}'),
                child: const Text('View clinic page'),
              ),
          ],
        ),
      ),
    );
  }
}
