import 'package:digimed_connect/core/config/api_config.dart';
import 'package:digimed_connect/features/care/paystack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API base URL defaults to the DigiMed 9a4a Railway host', () {
    expect(
      ApiConfig.defaultApiBaseUrl,
      'https://healthcare-backend-production-9a4a.up.railway.app',
    );
    expect(ApiConfig.normalizedBase, isNot(endsWith('/')));
    expect(ApiConfig.normalizedBase, contains('healthcare-backend-production-9a4a'));
  });

  test('Paystack checkout opens only for a real checkout URL', () {
    expect(paystackCheckoutUrl({'mock': true, 'checkoutUrl': 'https://paystack.com/pay/x'}), isNull);
    expect(paystackCheckoutUrl({'checkoutUrl': ''}), isNull);
    expect(
      paystackCheckoutUrl({
        'paymentProvider': 'paystack',
        'checkoutUrl': 'https://checkout.paystack.com/abc?copayConfirm=1',
      }),
      isNull,
    );
    expect(
      paystackCheckoutUrl({
        'paymentProvider': 'paystack',
        'checkoutUrl': 'https://checkout.paystack.com/abc',
      }),
      'https://checkout.paystack.com/abc',
    );
    expect(cardWasCharged({'mock': true, 'cardCharged': true}), isFalse);
    expect(cardWasCharged({'cardCharged': true}), isTrue);
  });
}
