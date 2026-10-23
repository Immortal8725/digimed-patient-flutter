import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/status_views.dart';
import 'renal_models.dart';
import 'renal_repository.dart';

/// Food preferences, allergies, and the meal choice for each upcoming session.
class MealsScreen extends ConsumerStatefulWidget {
  const MealsScreen({super.key});

  @override
  ConsumerState<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends ConsumerState<MealsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _info;
  MealPreferences? _prefs;
  List<RenalSessionDay> _sessions = [];
  final _usual = TextEditingController();
  final _other = TextEditingController();
  final _dislikes = TextEditingController();
  Set<String> _allergies = {};
  Set<String> _restrictions = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _usual.dispose();
    _other.dispose();
    _dislikes.dispose();
    super.dispose();
  }

  void _fill(MealPreferences p) {
    _prefs = p;
    _usual.text = p.usualFoods;
    _other.text = p.otherAllergies;
    _dislikes.text = p.dislikes;
    _allergies = p.allergies.toSet();
    _restrictions = p.restrictions.toSet();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(renalRepositoryProvider);
      final prefs = await repo.mealPreferences();
      final upcoming = await repo.upcoming();
      if (!mounted) return;
      setState(() {
        _fill(prefs);
        _sessions = upcoming.sessions.where((s) => s.offersMeals).toList();
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(renalRepositoryProvider)
          .saveMealPreferences(
            buildMealPreferencePayload(
              usualFoods: _usual.text,
              allergies: _allergies,
              otherAllergies: _other.text,
              dislikes: _dislikes.text,
              restrictions: _restrictions,
            ),
          );
      if (!mounted) return;
      setState(() {
        _fill(saved);
        _info = 'Food preferences saved';
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _choose(RenalSessionDay day, String code) async {
    try {
      await ref.read(renalRepositoryProvider).chooseMeal(day.sessionId, code);
      if (!mounted) return;
      setState(() => _info = 'Meal choice saved for ${day.date}');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    return Scaffold(
      appBar: AppBar(title: const Text('Dialysis meals')),
      body: _loading && prefs == null
          ? const LoadingView(label: 'Loading your meal settings')
          : prefs == null
          ? ErrorView(message: _error ?? 'Could not load meals', onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_error != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!),
                    ),
                  ),
                if (_info != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_info!),
                    ),
                  ),
                SectionCard(
                  title: 'Allergies',
                  subtitle: 'Meals that contain these are blocked for you',
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in prefs.allergenChoices)
                        FilterChip(
                          label: Text(c.label),
                          selected: _allergies.contains(c.code),
                          onSelected: (on) => setState(
                            () => on
                                ? _allergies.add(c.code)
                                : _allergies.remove(c.code),
                          ),
                        ),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Diet',
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in prefs.restrictionChoices)
                        FilterChip(
                          label: Text(c.label),
                          selected: _restrictions.contains(c.code),
                          onSelected: (on) => setState(
                            () => on
                                ? _restrictions.add(c.code)
                                : _restrictions.remove(c.code),
                          ),
                        ),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'More about your food',
                  child: Column(
                    children: [
                      TextField(
                        controller: _other,
                        decoration: const InputDecoration(
                          labelText: 'Other allergies',
                        ),
                      ),
                      TextField(
                        controller: _usual,
                        decoration: const InputDecoration(
                          labelText: 'Foods you usually eat',
                        ),
                      ),
                      TextField(
                        controller: _dislikes,
                        decoration: const InputDecoration(
                          labelText: 'Foods you dislike',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'Saving' : 'Save preferences'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_sessions.isEmpty)
                  const EmptyView(
                    title: 'No meal days coming up',
                    detail: 'Sessions where the unit serves meals show here.',
                  ),
                for (final day in _sessions) _sessionCard(prefs, day),
              ],
            ),
    );
  }

  Widget _sessionCard(MealPreferences prefs, RenalSessionDay day) {
    return SectionCard(
      title: 'Meal on ${day.date}',
      subtitle: day.meal.isEmpty
          ? 'No meal chosen yet'
          : 'Chosen: ${_label(prefs, day.meal)}',
      child: Column(
        children: [
          for (final o in prefs.options)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(o.label),
              subtitle: Text(
                [
                  if (o.description.isNotEmpty) o.description,
                  if (o.blocked)
                    'Not for you: contains ${o.conflicts.join(', ')}',
                  if (!o.blocked && o.mismatches.isNotEmpty)
                    'Check with the dietitian: ${o.mismatches.join(', ')}',
                ].join('\n'),
              ),
              trailing: day.meal == o.code
                  ? const Icon(Icons.check_circle)
                  : TextButton(
                      onPressed: o.blocked ? null : () => _choose(day, o.code),
                      child: const Text('Choose'),
                    ),
            ),
        ],
      ),
    );
  }

  String _label(MealPreferences prefs, String code) =>
      prefs.options
          .where((o) => o.code == code)
          .map((o) => o.label)
          .firstOrNull ??
      code;
}
