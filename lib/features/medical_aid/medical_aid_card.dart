import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

const otherScheme = 'OTHER';

class MedicalAidCard {
  MedicalAidCard({
    required this.schemeName,
    required this.planOption,
    required this.membershipNumber,
    required this.dependantCode,
    required this.mainMemberName,
    required this.mainMemberIdNumber,
    required this.hasPhoto,
    required this.current,
    this.validTo,
  });

  final String schemeName;
  final String planOption;
  final String membershipNumber;
  final String dependantCode;
  final String mainMemberName;
  final String mainMemberIdNumber;
  final bool hasPhoto;
  final bool current;
  final String? validTo;

  factory MedicalAidCard.fromJson(Map<String, dynamic> j) => MedicalAidCard(
    schemeName: firstString(j, ['schemeName']),
    planOption: firstString(j, ['planOption']),
    membershipNumber: firstString(j, ['membershipNumber']),
    dependantCode: firstString(j, ['dependantCode']),
    mainMemberName: firstString(j, ['mainMemberName']),
    mainMemberIdNumber: firstString(j, ['mainMemberIdNumber']),
    hasPhoto: asBool(j['hasPhoto']),
    current: j['current'] == null ? true : asBool(j['current']),
    validTo: j['validTo']?.toString(),
  );
}

class MedicalAidState {
  MedicalAidState(this.current, this.history);
  final MedicalAidCard? current;
  final List<MedicalAidCard> history;

  factory MedicalAidState.fromJson(Map<String, dynamic> j) {
    final cur = j['current'];
    return MedicalAidState(
      cur == null ? null : MedicalAidCard.fromJson(asMap(cur)),
      asList(j['history']).map(asMap).map(MedicalAidCard.fromJson).toList(),
    );
  }
}

/// Returns an error message, or null when the form is fine. Mirrors the server rules.
String? validateMedicalAid({
  required String scheme,
  required String schemeOther,
  required String membershipNumber,
  required String dependantCode,
  required String mainMemberIdNumber,
}) {
  if (scheme.isEmpty) return 'Choose your scheme.';
  if (scheme == otherScheme && schemeOther.trim().isEmpty) return 'Type the scheme name.';
  if (membershipNumber.trim().isEmpty) return 'Enter your membership number.';
  if (dependantCode.trim().isNotEmpty && !RegExp(r'^\d{1,3}$').hasMatch(dependantCode.trim())) {
    return 'Dependant code must be digits, for example 00.';
  }
  if (mainMemberIdNumber.trim().isNotEmpty && !RegExp(r'^[A-Za-z0-9]{6,20}$').hasMatch(mainMemberIdNumber.trim())) {
    return 'Main member ID must be 6 to 20 letters or digits.';
  }
  return null;
}

class MedicalAidRepository {
  MedicalAidRepository(this._api);
  final ApiClient _api;

  Future<List<String>> schemes() async {
    final data = await _api.get('/public/medical-aids');
    return asList(data).map(asMap).map((m) => firstString(m, ['name'])).where((s) => s.isNotEmpty).toList();
  }

  Future<MedicalAidState> mine() async => MedicalAidState.fromJson(asMap(await _api.get('/patients/me/medical-aid')));

  Future<MedicalAidState> save(Map<String, dynamic> body) async =>
      MedicalAidState.fromJson(asMap(await _api.put('/patients/me/medical-aid', data: body)));
}

final medicalAidRepositoryProvider = Provider<MedicalAidRepository>(
  (ref) => MedicalAidRepository(ref.watch(apiClientProvider)),
);

class MedicalAidSection extends ConsumerStatefulWidget {
  const MedicalAidSection({super.key});

  @override
  ConsumerState<MedicalAidSection> createState() => _MedicalAidSectionState();
}

class _MedicalAidSectionState extends ConsumerState<MedicalAidSection> {
  final _other = TextEditingController();
  final _plan = TextEditingController();
  final _member = TextEditingController();
  final _dependant = TextEditingController(text: '00');
  final _mainName = TextEditingController();
  final _mainId = TextEditingController();
  List<String> _schemes = [];
  String _scheme = '';
  MedicalAidState? _state;
  bool _loading = true;
  bool _editing = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    for (final c in [_other, _plan, _member, _dependant, _mainName, _mainId]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(medicalAidRepositoryProvider);
    try {
      List<String> schemes;
      try {
        schemes = await repo.schemes();
      } on ApiException {
        schemes = [];
      }
      final state = await repo.mine();
      if (!mounted) return;
      setState(() {
        _schemes = schemes;
        _state = state;
        _loading = false;
      });
      _fill(state.current);
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    }
  }

  void _fill(MedicalAidCard? c) {
    final name = c?.schemeName ?? '';
    final match = _schemes.where((s) => s.toLowerCase() == name.toLowerCase());
    _scheme = match.isNotEmpty ? match.first : (name.isEmpty ? '' : otherScheme);
    _other.text = match.isNotEmpty ? '' : name;
    _plan.text = c?.planOption ?? '';
    _member.text = c?.membershipNumber ?? '';
    _dependant.text = (c?.dependantCode.isNotEmpty ?? false) ? c!.dependantCode : '00';
    _mainName.text = c?.mainMemberName ?? '';
    _mainId.text = c?.mainMemberIdNumber ?? '';
  }

  Future<void> _save() async {
    final msg = validateMedicalAid(
      scheme: _scheme,
      schemeOther: _other.text,
      membershipNumber: _member.text,
      dependantCode: _dependant.text,
      mainMemberIdNumber: _mainId.text,
    );
    if (msg != null) {
      setState(() => _error = msg);
      return;
    }
    setState(() { _busy = true; _error = null; _info = null; });
    try {
      final state = await ref.read(medicalAidRepositoryProvider).save({
        'scheme': _scheme,
        'schemeOther': _other.text.trim(),
        'planOption': _plan.text.trim(),
        'membershipNumber': _member.text.trim(),
        'dependantCode': _dependant.text.trim(),
        'mainMemberName': _mainName.text.trim(),
        'mainMemberIdNumber': _mainId.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _state = state;
        _editing = false;
        _info = 'Saved. Your old details are kept in the history.';
      });
      _fill(state.current);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
    final cur = _state?.current;
    final history = (_state?.history ?? []).where((h) => !h.current).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Medical aid card', style: Theme.of(context).textTheme.titleMedium),
        const Text('Only you and the practices treating you can see these details.'),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_info != null) Text(_info!),
        const SizedBox(height: 8),
        if (!_editing) ...[
          if (cur == null)
            const Text('No medical aid details yet.')
          else ...[
            Text('Scheme: ${cur.schemeName}'),
            Text('Plan/option: ${cur.planOption.isEmpty ? 'Not set' : cur.planOption}'),
            Text('Membership number: ${cur.membershipNumber.isEmpty ? 'Not set' : cur.membershipNumber}'),
            Text('Dependant code: ${cur.dependantCode.isEmpty ? 'Not set' : cur.dependantCode}'),
            Text('Main member: ${cur.mainMemberName.isEmpty ? 'Not set' : cur.mainMemberName}'),
            Text('Card photo: ${cur.hasPhoto ? 'Saved' : 'None (add it on the website)'}'),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => setState(() { _editing = true; _info = null; }),
            child: Text(cur == null ? 'Add details' : 'Change details'),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            key: const Key('scheme-dropdown'),
            initialValue: _scheme.isEmpty ? null : _scheme,
            decoration: const InputDecoration(labelText: 'Scheme'),
            items: [
              for (final s in _schemes) DropdownMenuItem(value: s, child: Text(s)),
              const DropdownMenuItem(value: otherScheme, child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _scheme = v ?? ''),
          ),
          if (_scheme == otherScheme)
            TextField(controller: _other, decoration: const InputDecoration(labelText: 'Scheme name')),
          TextField(controller: _plan, decoration: const InputDecoration(labelText: 'Plan/option')),
          TextField(controller: _member, decoration: const InputDecoration(labelText: 'Membership number')),
          TextField(controller: _dependant, decoration: const InputDecoration(labelText: 'Dependant code')),
          TextField(controller: _mainName, decoration: const InputDecoration(labelText: 'Main member name')),
          TextField(controller: _mainId, decoration: const InputDecoration(labelText: 'Main member ID number')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
            TextButton(
              onPressed: _busy ? null : () { _fill(cur); setState(() { _editing = false; _error = null; }); },
              child: const Text('Cancel'),
            ),
          ]),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Previous details'),
          for (final h in history)
            Text('${h.schemeName}${h.planOption.isEmpty ? '' : ', ${h.planOption}'}'
                '${h.validTo == null ? '' : ' until ${h.validTo!.split('T').first}'}'),
        ],
      ],
    );
  }
}
