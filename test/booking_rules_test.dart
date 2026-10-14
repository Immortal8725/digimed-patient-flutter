import 'package:digimed_connect/features/appointments/appointment_models.dart';
import 'package:digimed_connect/features/find_care/find_care_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clinic hours become 30 minute booking slots', () {
    final slots = clinicHourSlots(
      opening: '08:00',
      closing: '09:00',
      durationMinutes: 30,
    );
    expect(slots.map((slot) => slot.label).toList(), ['08:00 - 08:30', '08:30 - 09:00']);
    expect(
      clinicHourSlots(opening: '08:00', closing: '08:20', durationMinutes: 30),
      isEmpty,
    );
  });

  test('booking stays open unless the clinic turns it off', () {
    expect(bookingEnabled({}), isTrue);
    expect(bookingEnabled({'bookingEnabled': false}), isFalse);
    expect(bookingEnabled({'bookingEnabled': true}), isTrue);
  });

  test('check-in is only offered on the day, and closes when the clinic says so', () {
    Appointment visit(Map<String, dynamic> extra) {
      return Appointment.fromJson({
        'id': '1',
        'status': 'CONFIRMED',
        'appointmentDate': '2026-10-07',
        ...extra,
      });
    }

    expect(visit({}).checkInState('2026-10-07'), 'open');
    expect(visit({'canCheckIn': false}).checkInState('2026-10-07'), 'closed');
    expect(visit({}).checkInState('2026-10-08'), 'hidden');
    expect(visit({'status': 'ARRIVED'}).checkInState('2026-10-07'), 'already');
    expect(
      visit({'intakeMode': 'RETURN_VISIT', 'intakeNeeded': true}).intakeButtonLabel,
      'Update visit reason',
    );
  });
}
