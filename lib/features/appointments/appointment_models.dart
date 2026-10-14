import '../../core/json/json_values.dart';

class Appointment {
  const Appointment({
    required this.id,
    required this.status,
    this.date = '',
    this.startTime = '',
    this.endTime = '',
    this.doctorName = '',
    this.clinicName = '',
    this.modality = '',
    this.doctorId = '',
    this.tenantId = '',
    this.roomCode = '',
    this.canCheckIn,
    this.intakeNeeded = false,
    this.intakeCompleted = false,
    this.intakeMode = '',
    this.intakeCtaLabel = '',
    this.arriveByTime = '',
    this.arriveMinutesEarly = 15,
    this.checkedInAt = '',
    required this.raw,
  });

  final String id;
  final String status;
  final String date;
  final String startTime;
  final String endTime;
  final String doctorName;
  final String clinicName;
  final String modality;
  final String doctorId;
  final String tenantId;
  final String roomCode;
  final bool? canCheckIn;
  final bool intakeNeeded;
  final bool intakeCompleted;
  final String intakeMode;
  final String intakeCtaLabel;
  final String arriveByTime;
  final int arriveMinutesEarly;
  final String checkedInAt;
  final Map<String, dynamic> raw;

  bool get isReturnVisit => intakeMode.toUpperCase() == 'RETURN_VISIT';

  String get intakeButtonLabel {
    if (intakeCtaLabel.isNotEmpty) return intakeCtaLabel;
    return isReturnVisit ? 'Update visit reason' : 'Complete intake';
  }

  String get intakeHint {
    if (intakeCompleted && !intakeNeeded) {
      return isReturnVisit ? 'Visit update submitted' : 'Intake submitted';
    }
    if (!intakeNeeded) return '';
    return isReturnVisit
        ? 'Tell the clinic why you are visiting today. Your details are already on file.'
        : 'Complete your clinic intake before the visit so staff are ready for you.';
  }

  /// Same-day check-in: open, closed, already, or hidden.
  String checkInState(String today) {
    final upper = status.toUpperCase();
    if (isCancelled || upper == 'COMPLETED') return 'hidden';
    final here = upper == 'ARRIVED' || upper == 'IN_PROGRESS' || checkedInAt.isNotEmpty;
    if (here) return 'already';
    if (date != today) return 'hidden';
    if (canCheckIn == false) return 'closed';
    return 'open';
  }

  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  bool get isVideo => statusAwareModality.toUpperCase() == 'VIDEO';

  String get statusAwareModality => modality;

  bool isUpcomingOn(String today) {
    if (isCancelled) return false;
    const open = {
      'BOOKED',
      'PENDING',
      'CONFIRMED',
      'ARRIVED',
      'IN_PROGRESS',
    };
    if (!open.contains(status.toUpperCase())) return false;
    if (date.isEmpty) return true;
    return date.compareTo(today) >= 0;
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final doctor = asMap(json['doctor']);
    final clinic = asMap(json['clinic'] ?? json['tenant']);
    return Appointment(
      id: firstString(json, ['id', 'appointmentId']),
      status: firstString(json, ['status']).isEmpty
          ? 'BOOKED'
          : firstString(json, ['status']),
      date: firstString(json, ['appointmentDate', 'date']).length >= 10
          ? firstString(json, ['appointmentDate', 'date']).substring(0, 10)
          : firstString(json, ['appointmentDate', 'date']),
      startTime: firstString(json, ['startTime']),
      endTime: firstString(json, ['endTime']),
      doctorName: firstString(json, ['doctorName']).isNotEmpty
          ? firstString(json, ['doctorName'])
          : firstString(doctor, ['fullName', 'name']),
      clinicName: firstString(json, ['clinicName', 'tenantName']).isNotEmpty
          ? firstString(json, ['clinicName', 'tenantName'])
          : firstString(clinic, ['name']),
      modality: firstString(json, ['modality', 'visitType']),
      doctorId: firstString(json, ['doctorId']).isNotEmpty
          ? firstString(json, ['doctorId'])
          : firstString(doctor, ['id', 'userId']),
      tenantId: firstString(json, ['tenantId', 'clinicId']),
      roomCode: firstString(json, ['roomCode', 'videoRoomCode']),
      canCheckIn: json.containsKey('canCheckIn') ? asBool(json['canCheckIn']) : null,
      intakeNeeded: asBool(json['intakeNeeded']),
      intakeCompleted: asBool(json['intakeCompleted']),
      intakeMode: firstString(json, ['intakeMode']),
      intakeCtaLabel: firstString(json, ['intakeCtaLabel']),
      arriveByTime: firstString(json, ['arriveByTime']),
      arriveMinutesEarly: asInt(json['arriveMinutesEarly']) ?? 15,
      checkedInAt: firstString(json, ['checkedInAt']),
      raw: json,
    );
  }
}

class ChatLine {
  const ChatLine({
    required this.id,
    required this.text,
    this.at = '',
    this.sender = '',
    this.mine = false,
  });

  final String id;
  final String text;
  final String at;
  final String sender;
  final bool mine;

  factory ChatLine.fromJson(Map<String, dynamic> json, String myUserId) {
    final senderId = firstString(json, ['senderId', 'userId', 'fromUserId']);
    final role = firstString(json, ['senderRole', 'role']).toUpperCase();
    return ChatLine(
      id: firstString(json, ['id']),
      text: firstString(json, ['text', 'message', 'body']),
      at: firstString(json, ['at', 'createdAt', 'sentAt']),
      sender: firstString(json, ['senderName', 'fromName', 'author']),
      mine: (myUserId.isNotEmpty && senderId == myUserId) || role == 'PATIENT',
    );
  }
}
