/// Message shown when a clinic staff account tries to use the patient app.
const String staffWebAppMessage =
    'This app is for patients. Clinic staff should sign in on the DigiMed Connect web app.';

/// Returns [staffWebAppMessage] when [role] is not a patient account.
String? staffLoginBlock(String? role) {
  if (role != null && role.toUpperCase() == 'PATIENT') return null;
  return staffWebAppMessage;
}

class StaffAccessRejected implements Exception {
  const StaffAccessRejected();

  @override
  String toString() => staffWebAppMessage;
}
