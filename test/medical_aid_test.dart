import 'package:digimed_connect/core/network/api_client.dart';
import 'package:digimed_connect/core/storage/token_store.dart';
import 'package:digimed_connect/features/medical_aid/medical_aid_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApi implements ApiClient {
  final calls = <String>[];
  Object? lastData;
  Object? Function(String method, String path)? reply;

  @override
  TokenStore get store => throw UnimplementedError();
  @override
  void Function()? onUnauthorized;

  Future<Object?> _go(String m, String p, [Object? d]) async {
    calls.add('$m $p');
    if (d != null) lastData = d;
    return reply?.call(m, p);
  }

  @override
  Future<Object?> get(String path, {Map<String, dynamic>? query}) => _go('GET', path);
  @override
  Future<Object?> post(String path, {Object? data, Map<String, dynamic>? query}) => _go('POST', path, data);
  @override
  Future<Object?> put(String path, {Object? data, Map<String, dynamic>? query}) => _go('PUT', path, data);
  @override
  Future<Object?> delete(String path) => _go('DELETE', path);
}

final cardJson = {
  'current': {
    'schemeName': 'Tiny Fund', 'planOption': 'Basic', 'membershipNumber': '777',
    'dependantCode': '02', 'mainMemberName': 'Sipho', 'hasPhoto': false, 'current': true,
  },
  'history': [
    {'schemeName': 'Tiny Fund', 'current': true},
    {'schemeName': 'Bonitas', 'planOption': 'BonCap', 'validTo': '2026-03-01T08:00:00Z', 'current': false},
  ],
};

Object? replies(String m, String p) {
  if (p == '/public/medical-aids') return [{'id': 1, 'name': 'Discovery Health'}, {'id': 2, 'name': 'Bonitas'}];
  return cardJson;
}

Widget wrap(FakeApi api) => ProviderScope(
  overrides: [medicalAidRepositoryProvider.overrideWithValue(MedicalAidRepository(api))],
  child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: MedicalAidSection()))),
);

void main() {
  test('validation mirrors the server rules', () {
    String? v({String s = 'Bonitas', String o = '', String m = '1', String d = '00', String id = ''}) =>
        validateMedicalAid(scheme: s, schemeOther: o, membershipNumber: m, dependantCode: d, mainMemberIdNumber: id);
    expect(v(), isNull);
    expect(v(s: ''), contains('scheme'));
    expect(v(s: otherScheme), contains('scheme name'));
    expect(v(m: ' '), contains('membership'));
    expect(v(d: 'x'), contains('Dependant'));
    expect(v(id: '12'), contains('ID'));
  });

  test('state parses current and history', () {
    final s = MedicalAidState.fromJson(cardJson);
    expect(s.current!.schemeName, 'Tiny Fund');
    expect(s.history.where((h) => !h.current).single.schemeName, 'Bonitas');
    expect(MedicalAidState.fromJson({'current': null, 'history': []}).current, isNull);
  });

  testWidgets('shows details, history, and edits with Other prefilled', (tester) async {
    final api = FakeApi()..reply = replies;
    await tester.pumpWidget(wrap(api));
    await tester.pumpAndSettle();
    expect(api.calls, ['GET /public/medical-aids', 'GET /patients/me/medical-aid']);
    expect(find.text('Scheme: Tiny Fund'), findsOneWidget);
    expect(find.text('Previous details'), findsOneWidget);
    expect(find.text('Bonitas, BonCap until 2026-03-01'), findsOneWidget);

    await tester.tap(find.text('Change details'));
    await tester.pumpAndSettle();
    expect(find.text('Other'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Scheme name'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.calls.last, 'PUT /patients/me/medical-aid');
    final body = api.lastData as Map<String, dynamic>;
    expect(body['scheme'], otherScheme);
    expect(body['schemeOther'], 'Tiny Fund');
    expect(body['dependantCode'], '02');
    expect(find.textContaining('old details are kept'), findsOneWidget);
  });

  testWidgets('scheme dropdown lists the catalogue then Other', (tester) async {
    final api = FakeApi()..reply = (m, p) => p == '/public/medical-aids' ? replies(m, p) : {'current': null, 'history': []};
    await tester.pumpWidget(wrap(api));
    await tester.pumpAndSettle();
    expect(find.text('No medical aid details yet.'), findsOneWidget);
    await tester.tap(find.text('Add details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scheme-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('Discovery Health'), findsWidgets);
    expect(find.text('Bonitas'), findsWidgets);
    expect(find.text('Other'), findsWidgets);
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Type the scheme name.'), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('PUT')), isEmpty);
  });
}
