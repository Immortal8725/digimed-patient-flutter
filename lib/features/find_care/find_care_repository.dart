import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_client.dart';

class CareProvider {
  const CareProvider({
    required this.name,
    this.clinicName = '',
    this.specialty = '',
    this.city = '',
    this.province = '',
    this.address = '',
    this.providerId = '',
    this.tenantId = '',
    this.subdomain = '',
    this.distanceKm,
    this.slots = const [],
    this.services = const [],
    this.medicalAids = const [],
  });

  final String name;
  final String clinicName;
  final String specialty;
  final String city;
  final String province;
  final String address;
  final String providerId;
  final String tenantId;
  final String subdomain;
  final double? distanceKm;
  final List<String> slots;
  final List<String> services;
  final List<String> medicalAids;

  factory CareProvider.fromJson(Map<String, dynamic> json) {
    final slots = asList(json['availableSlots'] ?? json['slots'])
        .map((slot) {
          if (slot is String) return slot;
          final map = asMap(slot);
          return firstString(map, ['startTime', 'time', 'label']);
        })
        .where((slot) => slot.isNotEmpty)
        .toList();
    return CareProvider(
      name: firstString(json, ['name', 'fullName', 'clinicName', 'providerName']),
      clinicName: firstString(json, ['clinicName', 'facilityName']),
      specialty: firstString(json, ['specialty', 'service']),
      city: firstString(json, ['city']),
      province: firstString(json, ['province']),
      address: firstString(json, ['address', 'street']),
      providerId: firstString(json, ['providerId', 'doctorId', 'id']),
      tenantId: firstString(json, ['tenantId', 'clinicId']),
      subdomain: firstString(json, ['subdomain']),
      distanceKm: json['distanceKm'] is num
          ? (json['distanceKm'] as num).toDouble()
          : double.tryParse(str(json['distanceKm'])),
      slots: slots,
      services: asList(json['offeredServices']).map((item) => str(item)).toList(),
      medicalAids: asList(
        json['supportedMedicalAids'],
      ).map((item) => str(item)).where((item) => item.isNotEmpty).toList(),
    );
  }
}

class FacilityHit {
  const FacilityHit({
    required this.name,
    this.city = '',
    this.province = '',
    this.address = '',
    this.phone = '',
  });

  final String name;
  final String city;
  final String province;
  final String address;
  final String phone;

  factory FacilityHit.fromJson(Map<String, dynamic> json) {
    return FacilityHit(
      name: firstString(json, ['name', 'facilityName', 'clinicName']),
      city: firstString(json, ['city', 'town']),
      province: firstString(json, ['province']),
      address: firstString(json, ['address', 'street']),
      phone: firstString(json, ['phone', 'telephone', 'contactNumber']),
    );
  }
}

class BookingReceipt {
  const BookingReceipt({
    required this.modalityLabel,
    required this.modalityDropped,
    required this.notes,
    required this.notesDropped,
    required this.service,
    required this.serviceDropped,
  });

  final String modalityLabel;
  final bool modalityDropped;
  final String notes;
  final bool notesDropped;
  final String service;
  final bool serviceDropped;

  String describe() {
    return [
      'Visit type: $modalityLabel',
      if (modalityDropped)
        'The visit type you chose was not stored. This booking is in person.',
      notesDropped
          ? 'Notes were not stored on this booking.'
          : 'Notes: ${notes.isEmpty ? 'None' : notes}',
      serviceDropped
          ? 'Preferred service was not stored on this booking.'
          : 'Preferred service: ${service.isEmpty ? 'None' : service}',
    ].join('\n');
  }
}

class ClinicSlot {
  const ClinicSlot({required this.start, required this.end});

  final String start;
  final String end;

  String get label => '$start - $end';
}

int minutesOfDay(String clock) {
  final parts = clock.split(':');
  if (parts.length < 2) return 0;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  return hour * 60 + minute;
}

String clockOf(int minutes) {
  final hour = (minutes ~/ 60) % 24;
  final minute = minutes % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

List<ClinicSlot> clinicHourSlots({
  String opening = '08:00',
  String closing = '17:00',
  int durationMinutes = 30,
}) {
  final start = minutesOfDay(opening.isEmpty ? '08:00' : opening);
  final end = minutesOfDay(closing.isEmpty ? '17:00' : closing);
  final step = durationMinutes <= 0 ? 30 : durationMinutes;
  final slots = <ClinicSlot>[];
  for (var cursor = start; cursor + step <= end; cursor += step) {
    slots.add(ClinicSlot(start: clockOf(cursor), end: clockOf(cursor + step)));
  }
  return slots;
}

bool bookingEnabled(Map<String, dynamic> tenant) {
  if (!tenant.containsKey('bookingEnabled')) return true;
  return asBool(tenant['bookingEnabled']);
}

class FindCareFilters {
  const FindCareFilters({
    this.place = '',
    this.province = '',
    this.city = '',
    this.service = '',
    this.medicalAid = '',
    required this.date,
    this.lat,
    this.lng,
  });

  final String place;
  final String province;
  final String city;
  final String service;
  final String medicalAid;
  final String date;
  final double? lat;
  final double? lng;
}

class FindCareRepository {
  FindCareRepository(this._api);

  final ApiClient _api;

  Future<({List<String> provinces, List<String> cities})> locations() async {
    final data = asMap(await _api.get('/public/locations'));
    List<String> names(Object? value) =>
        asList(value).map(str).where((item) => item.isNotEmpty).toList()..sort();
    return (provinces: names(data['provinces']), cities: names(data['cities']));
  }

  Future<List<String>> medicalAids() async {
    return asList(await _api.get('/public/medical-aids'))
        .map((item) => item is String ? item : firstString(asMap(item), ['name']))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<List<String>> services() async {
    return asList(await _api.get('/public/services'))
        .map((item) => item is String ? item : firstString(asMap(item), ['name']))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<List<CareProvider>> search(FindCareFilters filters) async {
    final params = <String, dynamic>{
      'lat': filters.lat ?? 0,
      'lng': filters.lng ?? 0,
      'date': filters.date,
      'limit': 50,
    };
    if (filters.medicalAid.trim().isNotEmpty) {
      params['medicalAid'] = filters.medicalAid.trim();
    }
    if (filters.city.trim().isNotEmpty) params['city'] = filters.city.trim();
    if (filters.province.trim().isNotEmpty) {
      params['province'] = filters.province.trim();
    }
    if (filters.service.trim().isNotEmpty) {
      params['service'] = filters.service.trim();
    }
    final data = await _api.get('/api/findcare/go/search', query: params);
    final rows = asList(data).map(asMap).toList();
    final place = filters.place.trim().toLowerCase();
    return rows
        .map(CareProvider.fromJson)
        .where((provider) {
          if (place.isEmpty) return true;
          final haystack = [
            provider.name,
            provider.clinicName,
            provider.city,
            provider.address,
          ].join(' ').toLowerCase();
          return haystack.contains(place);
        })
        .toList();
  }

  Future<List<FacilityHit>> governmentFacilities({
    String province = '',
    String query = '',
  }) async {
    final params = {
      'province': province,
      'q': query,
      'page': 0,
      'size': 20,
    };
    Object? data;
    try {
      data = await _api.get(
        '/api/findcare/government-facilities',
        query: params,
      );
    } catch (_) {
      data = await _api.get('/public/government-facilities', query: params);
    }
    final map = asMap(data);
    final rows = asList(map.isEmpty ? data : (map['items'] ?? data));
    return rows.map(asMap).map(FacilityHit.fromJson).toList();
  }

  Future<List<String>> slots(String providerId, String date) async {
    final data = await _api.get(
      '/connect/providers/$providerId/slots',
      query: {'date': date},
    );
    return asList(data).map((slot) {
      if (slot is String) return slot;
      return firstString(asMap(slot), ['startTime', 'time']);
    }).where((slot) => slot.isNotEmpty).toList();
  }

  Future<Map<String, dynamic>> tenant(String tenantId) async {
    return asMap(await _api.get('/tenant/$tenantId'));
  }

  Future<BookingReceipt> book({
    required String doctorId,
    required String date,
    required String startTime,
    String? endTime,
    String modality = 'IN_PERSON',
    String? notes,
    String? preferredService,
  }) async {
    final requestedModality = modality.toUpperCase() == 'VIDEO' ? 'VIDEO' : 'IN_PERSON';
    final noteText = (notes ?? '').trim();
    final serviceText = (preferredService ?? '').trim();
    final data = asMap(
      await _api.post(
        '/appointments/book',
        data: {
          'doctorId': int.tryParse(doctorId) ?? doctorId,
          'appointmentDate': date,
          'startTime': startTime,
          'endTime': endTime ?? _plusThirty(startTime),
          'modality': requestedModality,
          'consentAccepted': true,
          if (noteText.isNotEmpty) 'notes': noteText,
          if (serviceText.isNotEmpty) 'preferredService': serviceText,
        },
      ),
    );
    final storedModality = firstString(data, ['modality']).toUpperCase();
    final storedNotes = firstString(data, ['notes']);
    final storedService = firstString(data, [
      'preferredService',
      'service',
      'selectedService',
    ]);
    return BookingReceipt(
      modalityLabel: (storedModality.isEmpty ? requestedModality : storedModality) == 'VIDEO'
          ? 'Video'
          : 'In person',
      modalityDropped: storedModality.isNotEmpty && storedModality != requestedModality,
      notes: storedNotes,
      notesDropped: noteText.isNotEmpty && storedNotes.isEmpty,
      service: storedService,
      serviceDropped: serviceText.isNotEmpty && storedService.isEmpty,
    );
  }

  Future<Map<String, dynamic>> clinicBySubdomain(String subdomain) async {
    return asMap(await _api.get('/tenant/by-subdomain/$subdomain'));
  }

  Future<List<Map<String, dynamic>>> doctors(String tenantId) async {
    try {
      return asList(
        await _api.get('/api/doctors/public', query: {'tenantId': tenantId}),
      ).map(asMap).toList();
    } catch (_) {
      return asList(
        await _api.get('/api/doctors', query: {'tenantId': tenantId}),
      ).map(asMap).toList();
    }
  }

  String _plusThirty(String start) {
    final parts = start.split(':');
    if (parts.length < 2) return start;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final total = hour * 60 + minute + 30;
    final nextHour = (total ~/ 60) % 24;
    final nextMinute = total % 60;
    return '${nextHour.toString().padLeft(2, '0')}:${nextMinute.toString().padLeft(2, '0')}';
  }
}

final findCareRepositoryProvider = Provider<FindCareRepository>(
  (ref) => FindCareRepository(ref.watch(apiClientProvider)),
);
