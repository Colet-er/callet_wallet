# Callet

Callet is a personal finance app built with Flutter and Supabase. The same
Dart application targets web, iOS, and Android and includes email
authentication, a finance dashboard, and an account-scoped transaction ledger.
PostgreSQL row-level security protects each user's wallets and transactions.

## Set up Supabase

1. Run `supabase/migrations/202610190001_create_callet_ledger.sql` in the
   Supabase SQL editor.
2. Run `supabase/migrations/202610190002_add_wallets.sql` in the Supabase SQL
   editor. This adds GCash, bank, and cash wallets and assigns existing
   transactions to a starting wallet.
3. Enable email/password authentication in Supabase Auth.
4. Install the Flutter SDK and fetch dependencies:

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

Amounts are displayed in Philippine pesos and stored as integer centavos.
The Supabase anon key is intended to be public; never include a service-role
key in a client app.
