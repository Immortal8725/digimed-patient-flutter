import '../../core/json/json_values.dart';

/// Returns a Paystack checkout URL only when the API sent a real one.
///
/// Mock invoices, empty URLs, and the web app's own confirm bounce
/// (`copayConfirm`) are ignored so the app never pretends a card was charged.
String? paystackCheckoutUrl(Object? body) {
  final map = asMap(body);
  if (map.isEmpty || map['mock'] == true) return null;
  final url = str(map['checkoutUrl']);
  if (url.isEmpty) return null;
  final provider = str(map['paymentProvider']).toLowerCase();
  final looksLikePaystack =
      provider == 'paystack' || url.toLowerCase().contains('paystack.co');
  if (!looksLikePaystack) return null;
  if (RegExp(r'[?&]copayConfirm=', caseSensitive: false).hasMatch(url)) {
    return null;
  }
  return url;
}

bool cardWasCharged(Object? body) {
  final map = asMap(body);
  return map['mock'] != true && map['cardCharged'] == true;
}
