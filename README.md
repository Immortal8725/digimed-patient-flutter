# DigiMed Connect patient app

Flutter app for **patients** of [DigiMed Connect](https://www.digimed-connect.co.za), the South African outpatient platform. Clinic staff, doctors, and reception stay on the DigiMed web app. If a staff account signs in here, the app stops and asks them to use the website.

The screens follow the patient routes on the DigiMed website: sign in and signup with clinic choice, POPIA consent, and SMS OTP; home; Find Care; appointments; medications; intake; notices; privacy; paperless consent; research and eConsent; data rights; profile; clinics; and the telehealth consent gate. Co-pay opens Paystack only when the API returns a real checkout URL.

## Requirements

- Flutter 3.x (this project was built with Flutter 3.47)
- Android Studio or Xcode for a device or emulator

## Run

From the project root:

```bash
flutter pub get
flutter run
```

The API base URL defaults to the live DigiMed backend:

`https://healthcare-backend-production-9a4a.up.railway.app`

Override it, and optionally turn on Socket.IO, with `--dart-define`:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://healthcare-backend-production-9a4a.up.railway.app \
  --dart-define=REALTIME_URL=https://node-realtime-service-production-610c.up.railway.app
```

Leave `REALTIME_URL` unset to keep chat and notices on normal HTTP. When it is set, the app connects with `auth.token` set to the patient JWT and uses `chat:join`, `chat:message`, `chat:leave`, `notify:subscribe`, and `notify:event`.

### Android

```bash
flutter run -d android
```

### iOS

```bash
cd ios && pod install && cd ..
flutter run -d ios
```

### Web preview

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 43123
```

## Checks

```bash
flutter analyze
flutter test
```

## What patients can do

- Sign in, or create an account with clinic, medical aid, consent, and SMS OTP
- Home: profile, clinics, next visit, co-pay estimate, today's doses, vitals and tasks when the API returns them
- Find Care: province, city, service, medical aid, your location, public facilities, and booking an open slot
- Book appointment: the clinic booking portal, with visit type, notes, preferred service, and POPIA consent
- Appointments: upcoming, past, and cancelled, plus same-day check-in, cancel, reschedule, chat, intake, and co-pay
- Care: doses, privacy notice, access requests, paperless consent (grant and withdraw), research offers and eConsent, data export and erasure request, profile, and clinic switch
- Video visits stay closed until the clinic record has the patient, the doctor, the practice number, and suitability. After that, the room uses the same session, signal, and ICE calls as the website

Staff desks (claims, hiring, super admin, practice dashboards) are not in this app.
