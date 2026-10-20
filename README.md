# Callet

Callet is a personal finance app built with Flutter and Supabase. The same
Dart application targets web, iOS, and Android and includes email
authentication, a finance dashboard, an account-scoped transaction ledger, and
loan tracking. PostgreSQL row-level security protects each user's wallets,
transactions, and loans.

## Set up Supabase

1. Run `supabase/migrations/202610190001_create_callet_ledger.sql` in the
   Supabase SQL editor.
2. Run `supabase/migrations/202610190002_add_wallets.sql` in the Supabase SQL
   editor. This adds GCash, bank, and cash wallets and assigns existing
   transactions to a starting wallet.
3. Run `supabase/migrations/202610200001_add_loans.sql` in the Supabase SQL
   editor. This adds account-scoped loan tracking with row-level security.
4. Run `supabase/migrations/202610200002_add_loan_terms_and_budget.sql` in the
   Supabase SQL editor. This adds loan repayment terms and weekly expense limits.
5. Run `supabase/migrations/202610200003_add_sms_import.sql` in the Supabase SQL
   editor. This adds revocable Shortcut tokens and duplicate protection for SMS imports.
6. Link the Supabase CLI to your project, then deploy the SMS import function:

   ```sh
   supabase link --project-ref YOUR_PROJECT_REF
   supabase functions deploy sms-import --no-verify-jwt
   ```

   Supabase supplies the function's server-side service role key. Keep it out of
   the Shortcut and out of the Flutter app.
7. Enable email/password authentication in Supabase Auth.
8. Install the Flutter SDK and fetch dependencies:

   ```sh
   flutter pub get
   ```

## Run the app

Pass the Supabase project URL and public anon key as compile-time defines:

```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-supabase-anon-key
```

Use the same defines with `flutter run` for a connected mobile device or
simulator. Build a static web deployment with:

```sh
flutter build web \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-supabase-anon-key
```

## Deploy to Vercel

Add `SUPABASE_URL` and `SUPABASE_ANON_KEY` in the Vercel project's environment
variables for Production and Preview. The Vercel build configuration downloads
Flutter 3.47.7, builds the web app with those values, and serves `build/web`.

For native builds, generate the platform runner files once if they are not
present:

```sh
flutter create --platforms=android,ios .
```

## Phone notifications

Tap **Reminders → Enable phone notifications** in the installed Android or
iPhone app and allow the system permission. Callet then schedules a local
notification at 9 AM, seven days before each active loan payment. It uses the
phone's default notification sound and display style. The phone stores the
scheduled reminder, so Callet does not need to be open when it fires. The web
build continues to show reminders inside Callet.

The Android and iOS runner folders are not checked into this project. After
generating them, apply the following platform setup before building:

- **Android:** In `android/app/build.gradle` (or `.kts`), enable core library
  desugaring, set Java compatibility to 11, set `multiDexEnabled` to `true`,
  add `com.android.tools:desugar_jdk_libs:2.1.4`, and use Android Gradle Plugin
  8.6.0 or newer with `compileSdk` 35 or newer. In
  `android/app/src/main/AndroidManifest.xml`, add this permission under
  `<manifest>`:

  ```xml
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
  ```

  Add these receivers under `<application>` so scheduled reminders can be
  restored after a reboot:

  ```xml
  <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
  <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
      <intent-filter>
          <action android:name="android.intent.action.BOOT_COMPLETED" />
          <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
          <action android:name="android.intent.action.QUICKBOOT_POWERON" />
          <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
      </intent-filter>
  </receiver>
  ```

  The notification plugin adds the notification and vibration permissions.
  Callet uses inexact scheduling, so it does not request exact alarm access.
- **iOS:** In `ios/Runner/AppDelegate.swift`, set
  `UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate`
  in the application launch method. The app requests alert, sound, and badge
  permission when the user enables notifications.

Amounts are displayed in Philippine pesos and stored as integer centavos.
The Supabase anon key is intended to be public; never include a service-role
key in a client app.

## Loans, reminders, and weekly limit

Loan records include term length, annual interest rate, scheduled monthly
payment, and next due date. Callet shows a reminder exactly seven days before
each loan payment, including its scheduled amount, in the in-app Reminders
panel. The Loans section totals monthly payments across active loans and can
estimate a fixed monthly payment from principal, APR, and term. Weekly expense
limits count Monday
through Sunday and alert in the app when spending reaches 80% of the limit.
Weekly limit reminders appear in the in-app Reminders panel while Callet is
open.

The chat helper answers questions from all finance data loaded for the signed-in
user: wallets and their opening balances, transactions and descriptions, loan
terms and payment dates, and the weekly expense limit. It can show a full
summary and transaction history. It does not send financial data to an external
AI service.

## iPhone bank SMS import

On the Wallets section, select **Connect SMS Shortcut** and copy the one-time
token. Add a wallet named `CBC` or `China Bank`; CBC card alerts are assigned to
that wallet. The token can be rotated by creating another one or revoked from
the same screen.

In the iPhone Shortcut automation, add **Get Contents of URL** after the
message trigger:

- URL: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/sms-import`
- Method: `POST`
- Headers: `Content-Type` = `application/json`; `x-callet-token` = the token
  copied from Callet
- Request body: JSON with `message` set to the SMS text variable from the
  automation trigger

The current importer recognizes the CBC card purchase format, records it as an
expense, and ignores duplicate copies of the same SMS. Review each imported
entry in Activity. Other bank or GCash message formats need their own parser
before they can be imported automatically.
