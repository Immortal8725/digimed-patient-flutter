import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_client.dart';
import '../care/paystack.dart';
import 'appointment_models.dart';

class CopayAttempt {
  const CopayAttempt({
    this.checkoutUrl,
    this.invoiceId = '',
    this.message = '',
  });

  final String? checkoutUrl;
  final String invoiceId;
  final String message;
}

class AppointmentsRepository {
  AppointmentsRepository(this._api);

  final ApiClient _api;

  Future<List<Appointment>> mine({bool detailed = false}) async {
    final data = await _api.get(
      detailed ? '/appointments/my/detailed' : '/appointments/my',
    );
    return asList(data).map(asMap).map(Appointment.fromJson).toList();
  }

  Future<void> checkIn(String id) async {
    await _api.put('/appointments/my/$id/check-in');
  }

  Future<void> cancel(String id) async {
    await _api.put('/appointments/my/$id/cancel');
  }

  Future<void> reschedule({
    required String id,
    required String date,
    required String startTime,
  }) async {
    await _api.put(
      '/appointments/my/$id/reschedule',
      data: {'appointmentDate': date, 'startTime': startTime},
    );
  }

  Future<List<ChatLine>> chat(String id, String myUserId) async {
    final data = await _api.get('/appointments/$id/chat');
    return asList(data)
        .map(asMap)
        .map((row) => ChatLine.fromJson(row, myUserId))
        .toList();
  }

  Future<ChatLine> sendChat(String id, String text, String myUserId) async {
    final data = await _api.post('/appointments/$id/chat', data: {'text': text});
    final map = asMap(data);
    if (map.isEmpty) {
      return ChatLine(id: '', text: text, mine: true);
    }
    return ChatLine.fromJson(map, myUserId);
  }

  Future<CopayAttempt> startCopay(String appointmentId) async {
    final invoice = asMap(
      await _api.post(
        '/api/copay/invoices',
        data: {'appointmentId': int.tryParse(appointmentId) ?? appointmentId},
      ),
    );
    final invoiceId = firstString(invoice, ['id']);
    if (invoiceId.isEmpty) {
      return const CopayAttempt(
        message: 'The clinic did not return a co-pay invoice.',
      );
    }
    final payment = await _api.post('/api/copay/invoices/$invoiceId/pay');
    final url = paystackCheckoutUrl(payment);
    if (url == null) {
      return CopayAttempt(
        invoiceId: invoiceId,
        message:
            'No Paystack checkout was returned. Nothing has been charged.',
      );
    }
    return CopayAttempt(checkoutUrl: url, invoiceId: invoiceId);
  }

  Future<String> confirmCopay(String invoiceId, {String? reference}) async {
    final data = await _api.post(
      '/api/copay/invoices/$invoiceId/confirm',
      data: {
        if (reference != null && reference.trim().isNotEmpty)
          'reference': reference.trim(),
      },
    );
    if (cardWasCharged(data)) return 'Card payment received.';
    return 'The clinic has not confirmed a card charge yet.';
  }
}

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>(
  (ref) => AppointmentsRepository(ref.watch(apiClientProvider)),
);
