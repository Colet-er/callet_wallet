import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'loan_notification_service.dart';

const _navy = Color(0xFF193B2B);
const _emerald = Color(0xFF83D6A2);
const _canvas = Color(0xFF0B120E);
const _ink = Color(0xFFE7F0E9);
const _muted = Color(0xFF9AAA9E);
const _line = Color(0xFF29392F);
const _sage = Color(0xFF1A2A20);
const _surface = Color(0xFF121C16);
const _surfaceRaised = Color(0xFF19261E);
const _expense = Color(0xFFFF958B);

final _php = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
final _shortDate = DateFormat('MMM d');
final _dbDate = DateFormat('yyyy-MM-dd');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Configure SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define.',
    );
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  try {
    await LoanNotificationService.instance.initialize();
  } catch (_) {
    // Keep sign-in and the in-app reminders available if phone notifications
    // are unavailable on this device or have not been configured yet.
  }
  runApp(const CalletApp());
}

class CalletApp extends StatelessWidget {
  const CalletApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Callet',
        debugShowCheckedModeBanner: false,
        color: _canvas,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _canvas,
          cardTheme: CardThemeData(
            color: _surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: _line),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          colorScheme: ColorScheme.fromSeed(
            brightness: Brightness.dark,
            seedColor: _emerald,
            primary: _emerald,
            onPrimary: _navy,
            secondary: _emerald,
            surface: _surface,
            onSurface: _ink,
            error: _expense,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _surfaceRaised,
            hintStyle: const TextStyle(color: _muted),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _emerald, width: 1.5),
            ),
          ),
        ),
        home: const AuthGate(),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (client.auth.currentSession != null) {
          return const DashboardPage();
        }
        return const SignInPage();
      },
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (error) {
      if (mounted) _showMessage(context, error.message);
    } catch (error) {
      if (mounted) _showMessage(context, 'Could not sign in: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        eyebrow: 'WELCOME BACK',
        title: 'Make room for\nwhat matters.',
        subtitle:
            'A calmer view of your everyday money, with space to plan for what comes next.',
        formTitle: 'Sign in to Callet',
        formSubtitle: 'Pick up where you left off.',
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'you@example.com',
                  ),
                  validator: (value) => value == null ||
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value.trim())
                      ? 'Enter a valid email address.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your password.'
                      : null,
                  onFieldSubmitted: (_) => _signIn(),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Sign in',
                  busy: _busy,
                  onPressed: _signIn,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                const Text('New to Callet? '),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegisterPage(),
                    ),
                  ),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ),
        ],
      );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {'full_name': _name.text.trim()},
      );
      if (!mounted) return;
      if (response.session == null) {
        _showMessage(
          context,
          'Check your inbox to confirm your account, then sign in.',
        );
        Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      if (mounted) _showMessage(context, error.message);
    } catch (error) {
      if (mounted) _showMessage(context, 'Could not create account: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        eyebrow: 'A FRESH START',
        title: 'Your goals.\nYour pace.',
        subtitle:
            'Build a clearer picture of your spending and make steady progress toward the things you care about.',
        formTitle: 'Create your account',
        formSubtitle: 'It only takes a minute to get started.',
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'you@example.com',
                  ),
                  validator: (value) => value == null ||
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value.trim())
                      ? 'Enter a valid email address.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'At least 8 characters',
                  ),
                  validator: (value) => value == null || value.length < 8
                      ? 'Use at least 8 characters.'
                      : null,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Create account',
                  busy: _busy,
                  onPressed: _register,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                const Text('Already have an account? '),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ],
      );
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.formTitle,
    required this.formSubtitle,
    required this.children,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String formTitle;
  final String formSubtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
            children: [
              const CalletBrand(),
              const SizedBox(height: 35),
              Text(
                eyebrow,
                style: const TextStyle(
                  color: _emerald,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: const TextStyle(color: _muted, height: 1.55),
              ),
              const SizedBox(height: 28),
              Card(
                elevation: 0,
                color: _surface,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: _line),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formTitle,
                        style: const TextStyle(
                          fontSize: 21,
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(formSubtitle, style: const TextStyle(color: _muted)),
                      const SizedBox(height: 22),
                      ...children,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'Your money is personal. Your data should be, too.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
}

class CalletBrand extends StatelessWidget {
  const CalletBrand({super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _sage,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.savings_outlined, color: _emerald),
          ),
          const SizedBox(width: 10),
          const Text(
            'Callet',
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
        ],
      );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _emerald,
            foregroundColor: _navy,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _navy,
                  ),
                )
              : Text(label),
        ),
      );
}

class LedgerTransaction {
  const LedgerTransaction({
    required this.id,
    required this.walletId,
    required this.amountCents,
    required this.type,
    required this.description,
    required this.category,
    required this.occurredOn,
  });

  final String id;
  final String walletId;
  final int amountCents;
  final String type;
  final String description;
  final String category;
  final DateTime occurredOn;

  factory LedgerTransaction.fromMap(Map<String, dynamic> row) =>
      LedgerTransaction(
        id: row['id'] as String,
        walletId: row['wallet_id'] as String,
        amountCents: (row['amount_cents'] as num).toInt(),
        type: row['type'] as String,
        description: row['description'] as String,
        category: row['category'] as String,
        occurredOn: DateTime.parse(row['occurred_on'] as String),
      );
}

class MoneyWallet {
  const MoneyWallet({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalanceCents,
    required this.openingBalanceOn,
  });

  final String id;
  final String name;
  final String type;
  final int openingBalanceCents;
  final DateTime openingBalanceOn;

  factory MoneyWallet.fromMap(Map<String, dynamic> row) => MoneyWallet(
        id: row['id'] as String,
        name: row['name'] as String,
        type: row['type'] as String,
        openingBalanceCents: (row['opening_balance_cents'] as num).toInt(),
        openingBalanceOn: DateTime.parse(row['opening_balance_on'] as String),
      );

  IconData get icon => switch (type) {
        'gcash' => Icons.account_balance_wallet_rounded,
        'bank' => Icons.account_balance_rounded,
        'cash' => Icons.payments_rounded,
        _ => Icons.wallet_rounded,
      };

  String get typeLabel => switch (type) {
        'gcash' => 'GCash',
        'bank' => 'Bank',
        'cash' => 'Cash',
        _ => 'Other',
      };

  int balanceFor(List<LedgerTransaction> transactions) => transactions
      .where((item) =>
          item.walletId == id && !item.occurredOn.isBefore(openingBalanceOn))
      .fold<int>(
        openingBalanceCents,
        (balance, item) =>
            balance +
            (item.type == 'income' ? item.amountCents : -item.amountCents),
      );
}

class PersonalLoan {
  const PersonalLoan({
    required this.id,
    required this.name,
    required this.lender,
    required this.originalAmountCents,
    required this.balanceCents,
    required this.dueOn,
    required this.termMonths,
    required this.annualInterestBps,
    required this.monthlyPaymentCents,
  });

  final String id;
  final String name;
  final String lender;
  final int originalAmountCents;
  final int balanceCents;
  final DateTime? dueOn;
  final int? termMonths;
  final int annualInterestBps;
  final int? monthlyPaymentCents;

  factory PersonalLoan.fromMap(Map<String, dynamic> row) => PersonalLoan(
        id: row['id'] as String,
        name: row['name'] as String,
        lender: row['lender'] as String,
        originalAmountCents: (row['original_amount_cents'] as num).toInt(),
        balanceCents: (row['balance_cents'] as num).toInt(),
        dueOn: row['due_on'] == null
            ? null
            : DateTime.parse(row['due_on'] as String),
        termMonths: (row['term_months'] as num?)?.toInt(),
        annualInterestBps: (row['annual_interest_bps'] as num?)?.toInt() ?? 0,
        monthlyPaymentCents:
            (row['monthly_payment_cents'] as num?)?.toInt(),
      );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<LedgerTransaction> _transactions = [];
  List<MoneyWallet> _wallets = [];
  List<PersonalLoan> _loans = [];
  int? _weeklyExpenseLimitCents;
  int _sectionIndex = 0;
  bool _navExpanded = false;
  bool _loading = true;
  String? _error;
  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var walletRows = await _client
          .from('wallets')
          .select('id, name, type, opening_balance_cents, opening_balance_on')
          .order('created_at');
      if (walletRows.isEmpty) {
        await _client.from('wallets').insert({
          'user_id': _client.auth.currentUser!.id,
          'name': 'Cash',
          'type': 'cash',
          'opening_balance_cents': 0,
          'opening_balance_on': '1900-01-01',
        });
        walletRows = await _client
            .from('wallets')
            .select('id, name, type, opening_balance_cents, opening_balance_on')
            .order('created_at');
      }
      final rows = await _client
          .from('transactions')
          .select(
              'id, wallet_id, amount_cents, type, description, category, occurred_on')
          .order('occurred_on', ascending: false)
          .order('created_at', ascending: false);
      final loanRows = await _client
          .from('loans')
          .select('id, name, lender, original_amount_cents, balance_cents, due_on, term_months, annual_interest_bps, monthly_payment_cents')
          .order('created_at', ascending: false);
      final preferenceRows = await _client
          .from('user_preferences')
          .select('weekly_expense_limit_cents')
          .limit(1);
      if (!mounted) return;
      setState(() {
        _wallets = walletRows
            .map((row) => MoneyWallet.fromMap(row))
            .toList(growable: false);
        _transactions = rows
            .map((row) => LedgerTransaction.fromMap(row))
            .toList(growable: false);
        _loans = loanRows
            .map((row) => PersonalLoan.fromMap(row))
            .toList(growable: false);
        _weeklyExpenseLimitCents = preferenceRows.isEmpty
            ? null
            : (preferenceRows.first['weekly_expense_limit_cents'] as num?)
                ?.toInt();
        _loading = false;
      });
      unawaited(_synchronizeLoanNotifications());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your money data: $error';
        _loading = false;
      });
    }
  }

  Future<void> _loadTransactions() => _loadData();

  Future<void> _synchronizeLoanNotifications() async {
    try {
      await LoanNotificationService.instance.synchronize(
        _loans
            .where((loan) => loan.balanceCents > 0 && loan.dueOn != null)
            .map((loan) => LoanReminder(
                  id: loan.id,
                  name: loan.name,
                  dueOn: loan.dueOn!,
                  monthlyPaymentCents: loan.monthlyPaymentCents,
                ))
            .toList(growable: false),
      );
    } catch (_) {
      // Surface errors when the user enables notifications from Reminders.
    }
  }

  Future<void> _enablePhoneNotifications() async {
    if (kIsWeb) {
      _showMessage(
        context,
        'Phone pop-up notifications are available in the Android or iPhone app. Web reminders stay in Callet.',
      );
      return;
    }
    try {
      final granted =
          await LoanNotificationService.instance.requestPermission();
      if (!mounted) return;
      if (!granted) {
        _showMessage(
          context,
          'Notifications are off. Allow them in your phone settings to receive loan reminders.',
        );
        return;
      }
      await _synchronizeLoanNotifications();
      if (mounted) {
        _showMessage(
          context,
          'Phone notifications are on. Loan reminders are scheduled for 9 AM, seven days before each due date.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(context, 'Could not enable phone notifications: $error');
      }
    }
  }

  Future<void> _addTransaction() async {
    if (_wallets.isEmpty) {
      _showMessage(
          context, 'Wallets are not ready yet. Refresh and try again.');
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _canvas,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => AddTransactionSheet(wallets: _wallets),
    );
    if (saved == true) await _loadTransactions();
  }

  Future<void> _addWallet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _canvas,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const AddWalletSheet(),
    );
    if (saved == true) await _loadData();
  }

  Future<void> _addLoan() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _canvas,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const LoanSheet(),
    );
    if (saved == true) await _loadData();
  }

  Future<void> _editLoan(PersonalLoan loan) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _canvas,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => LoanSheet(loan: loan),
    );
    if (saved == true) await _loadData();
  }

  Future<void> _deleteLoan(PersonalLoan loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete loan?'),
        content: Text('Remove ${loan.name} from your loan list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.from('loans').delete().eq('id', loan.id);
      await _loadData();
    } catch (error) {
      if (mounted) _showMessage(context, 'Could not delete loan: $error');
    }
  }

  Future<void> _deleteTransaction(LedgerTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete activity?'),
        content: Text(
          'Remove "${transaction.description}"? This will update the wallet balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.from('transactions').delete().eq('id', transaction.id);
      await _loadData();
    } catch (error) {
      if (mounted) _showMessage(context, 'Could not delete activity: $error');
    }
  }

  int _weeklySpendingCents(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    return _transactions
        .where((item) =>
            item.type == 'expense' &&
            !item.occurredOn.isBefore(weekStart) &&
            !item.occurredOn.isAfter(today))
        .fold<int>(0, (sum, item) => sum + item.amountCents);
  }

  int _noticeCount(DateTime now) => _noticeMessages(now).length;

  List<String> _noticeMessages(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final notices = <String>[];
    for (final loan in _loans) {
      if (loan.balanceCents <= 0 || loan.dueOn == null) continue;
      final due = DateTime(loan.dueOn!.year, loan.dueOn!.month, loan.dueOn!.day);
      final days = due.difference(today).inDays;
      final payment = loan.monthlyPaymentCents == null
          ? ''
          : ' Scheduled payment: ${_php.format(loan.monthlyPaymentCents! / 100)}.';
      if (days < 0) {
        notices.add('${loan.name} payment is overdue by ${-days} day(s).$payment');
      } else if (days == 7) {
        notices.add('7-day reminder: ${loan.name} payment is due on ${DateFormat('MMM d').format(due)}.$payment');
      } else if (days < 7) {
        notices.add(days == 0
            ? '${loan.name} payment is due today.$payment'
            : '${loan.name} payment is due in $days day(s).$payment');
      }
    }
    final limit = _weeklyExpenseLimitCents;
    if (limit != null && limit > 0) {
      final spent = _weeklySpendingCents(now);
      if (spent >= limit) {
        notices.add('Weekly expense limit reached: ${_php.format(spent / 100)} of ${_php.format(limit / 100)}.');
      } else if (spent >= limit * 0.8) {
        notices.add('You have used ${(spent * 100 / limit).round()}% of your weekly expense limit.');
      }
    }
    return notices;
  }

  Future<void> _showNotifications() async {
    final notices = _noticeMessages(DateTime.now());
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reminders'),
        content: notices.isEmpty
            ? const Text('You’re all caught up. Loan due dates and weekly spending alerts will appear here.')
            : SizedBox(
                width: 420,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: notices
                          .map((notice) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.notifications_active_outlined,
                                        size: 18, color: _emerald),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(notice)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _enablePhoneNotifications();
            },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Enable phone notifications'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editWeeklyLimit() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _canvas,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => WeeklyLimitSheet(
        initialLimitCents: _weeklyExpenseLimitCents,
      ),
    );
    if (saved == true) await _loadData();
  }

  Future<void> _openChat() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _canvas,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => ChatAssistantSheet(
        wallets: _wallets,
        walletBalanceCents: _wallets.fold<int>(
          0,
          (sum, wallet) => sum + wallet.balanceFor(_transactions),
        ),
        loans: _loans,
        transactions: _transactions,
        weeklySpentCents: _weeklySpendingCents(DateTime.now()),
        weeklyLimitCents: _weeklyExpenseLimitCents,
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      if (mounted) _showMessage(context, 'Could not sign out: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name']?.toString().trim();
    final name = (fullName != null && fullName.isNotEmpty)
        ? fullName.split(' ').first
        : user?.email?.split('@').first ?? 'there';
    final now = DateTime.now();
    final monthTransactions = _transactions
        .where((item) =>
            item.occurredOn.year == now.year &&
            item.occurredOn.month == now.month)
        .toList(growable: false);
    final income = monthTransactions
        .where((item) => item.type == 'income')
        .fold<int>(0, (sum, item) => sum + item.amountCents);
    final expenses = monthTransactions
        .where((item) => item.type == 'expense')
        .fold<int>(0, (sum, item) => sum + item.amountCents);
    final balance = _wallets.fold<int>(
        0, (sum, wallet) => sum + wallet.balanceFor(_transactions));
    final savings = income - expenses;
    final savingsRate = income == 0 ? null : ((savings / income) * 100).round();

    final wide = MediaQuery.sizeOf(context).width >= 850;
    final content = _sectionIndex == 1
        ? _walletsSection()
        : _sectionIndex == 2
            ? _activitySection()
            : _sectionIndex == 3
                ? _loansSection()
                : _overviewSection(
                    now: now,
                    name: name,
                    balance: balance,
                    income: income,
                    expenses: expenses,
                    savings: savings,
                    savingsRate: savingsRate,
                  );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _canvas,
        surfaceTintColor: Colors.transparent,
        title: const CalletBrand(),
        actions: [
          IconButton(
            tooltip: 'Chat with Callet',
            onPressed: _openChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          Badge(
            isLabelVisible: _noticeCount(now) > 0,
            label: Text('${_noticeCount(now)}'),
            child: IconButton(
              tooltip: 'Reminders',
              onPressed: _showNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: _navExpanded,
              minExtendedWidth: 204,
              selectedIndex: _sectionIndex,
              onDestinationSelected: (index) =>
                  setState(() => _sectionIndex = index),
              leading: IconButton(
                tooltip:
                    _navExpanded ? 'Collapse navigation' : 'Expand navigation',
                onPressed: () => setState(() => _navExpanded = !_navExpanded),
                icon: Icon(_navExpanded
                    ? Icons.menu_open_rounded
                    : Icons.menu_rounded),
              ),
              labelType: _navExpanded ? null : NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard_rounded),
                  label: Text('Overview'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                  label: Text('Wallets'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: Text('Activity'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.request_quote_outlined),
                  selectedIcon: Icon(Icons.request_quote_rounded),
                  label: Text('Loans'),
                ),
              ],
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTransactions,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView(
                    key: PageStorageKey<int>(_sectionIndex),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    children: content,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _sectionIndex,
              onDestinationSelected: (index) =>
                  setState(() => _sectionIndex = index),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.space_dashboard_outlined), label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    label: 'Wallets'),
                NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined), label: 'Activity'),
                NavigationDestination(
                    icon: Icon(Icons.request_quote_outlined), label: 'Loans'),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sectionIndex == 1
            ? _addWallet
            : _sectionIndex == 3
                ? _addLoan
                : _addTransaction,
        backgroundColor: _emerald,
        foregroundColor: _navy,
        icon: Icon(_sectionIndex == 1
            ? Icons.account_balance_wallet_outlined
            : Icons.add),
        label: Text(_sectionIndex == 1
            ? 'Add wallet'
            : _sectionIndex == 3
                ? 'Add loan'
                : 'Add transaction'),
      ),
    );
  }

  List<Widget> _overviewSection({
    required DateTime now,
    required String name,
    required int balance,
    required int income,
    required int expenses,
    required int savings,
    required int? savingsRate,
  }) =>
      [
        Text(
          DateFormat('EEEE, MMMM d').format(now).toUpperCase(),
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Text('Good day, $name',
            style: const TextStyle(
                color: _ink,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.7)),
        const SizedBox(height: 5),
        const Text('Here’s how your money is looking today.',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 22),
        _BalanceCard(balance: balance),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final incomeCard = _SummaryCard(
            label: 'Total income',
            value: _php.format(income / 100),
            icon: Icons.south_west_rounded,
            color: _emerald,
          );
          final expenseCard = _SummaryCard(
            label: 'Total expenses',
            value: _php.format(expenses / 100),
            icon: Icons.north_east_rounded,
            color: _expense,
          );
          if (constraints.maxWidth < 370) {
            return Column(children: [
              incomeCard,
              const SizedBox(height: 12),
              expenseCard,
            ]);
          }
          return Row(children: [
            Expanded(child: incomeCard),
            const SizedBox(width: 12),
            Expanded(child: expenseCard),
          ]);
        }),
        const SizedBox(height: 12),
        _SummaryCard(
          label: 'Net savings',
          value: _php.format(savings / 100),
          detail: savingsRate == null
              ? 'Start tracking to see your rate'
              : '$savingsRate% of tracked income',
          icon: Icons.auto_awesome_outlined,
          color: savings < 0 ? _expense : _emerald,
        ),
        const SizedBox(height: 16),
        _weeklyLimitCard(now),
        const SizedBox(height: 24),
        _sectionTitle('Your wallets',
            action: 'See all',
            onPressed: () => setState(() => _sectionIndex = 1)),
        const SizedBox(height: 12),
        _WalletCards(
            wallets: _wallets, transactions: _transactions, compact: true),
        const SizedBox(height: 24),
        _CashFlowChart(transactions: _transactions),
        const SizedBox(height: 24),
        _sectionTitle('Recent activity',
            action: 'See all',
            onPressed: () => setState(() => _sectionIndex = 2)),
        const SizedBox(height: 9),
        ..._transactionContent(limit: 5),
      ];

  Widget _weeklyLimitCard(DateTime now) {
    final spent = _weeklySpendingCents(now);
    final limit = _weeklyExpenseLimitCents;
    final progress = limit == null || limit <= 0
        ? 0.0
        : (spent / limit).clamp(0.0, 1.0).toDouble();
    final over = limit != null && spent > limit;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Weekly expense limit',
                      style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: _editWeeklyLimit,
                  child: Text(limit == null ? 'Set limit' : 'Edit'),
                ),
              ],
            ),
            if (limit == null)
              const Text('Set a weekly target to keep an eye on spending.',
                  style: TextStyle(color: _muted))
            else ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                color: over ? _expense : _emerald,
                backgroundColor: _line,
              ),
              const SizedBox(height: 8),
              Text(
                '${_php.format(spent / 100)} of ${_php.format(limit / 100)} this week',
                style: TextStyle(color: over ? _expense : _muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _walletsSection() => [
        _sectionTitle('Your wallets',
            action: 'Add wallet', onPressed: _addWallet),
        const SizedBox(height: 7),
        const Text('Keep GCash, bank accounts, and cash balances in one view.',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 18),
        if (_loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator()))
        else if (_error != null)
          _ErrorCard(message: _error!, onRetry: _loadData)
        else
          _WalletCards(wallets: _wallets, transactions: _transactions),
      ];

  List<Widget> _activitySection() => [
        _sectionTitle('Activity', action: 'Add', onPressed: _addTransaction),
        const SizedBox(height: 7),
        const Text('A complete record of money coming in and going out.',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 18),
        ..._transactionContent(),
      ];

  List<Widget> _loansSection() {
    final totalDebt = _loans.fold<int>(0, (sum, loan) => sum + loan.balanceCents);
    final monthlyPayable = _loans
        .where((loan) => loan.balanceCents > 0)
        .fold<int>(0, (sum, loan) => sum + (loan.monthlyPaymentCents ?? 0));
    final loansWithPayment = _loans
        .where((loan) => loan.balanceCents > 0 && loan.monthlyPaymentCents != null)
        .length;
    return [
      _sectionTitle('Loans', action: 'Add loan', onPressed: _addLoan),
      const SizedBox(height: 7),
      const Text('Track what you owe and keep each balance up to date.',
          style: TextStyle(color: _muted)),
      const SizedBox(height: 18),
      _SummaryCard(
        label: 'Total outstanding',
        value: _php.format(totalDebt / 100),
        icon: Icons.request_quote_outlined,
        color: _expense,
      ),
      const SizedBox(height: 10),
      _SummaryCard(
        label: 'Total payable each month',
        value: _php.format(monthlyPayable / 100),
        detail: '$loansWithPayment active loan${loansWithPayment == 1 ? '' : 's'} included',
        icon: Icons.calendar_month_outlined,
        color: _emerald,
      ),
      const SizedBox(height: 18),
      if (_loading)
        const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
      else if (_error != null)
        _ErrorCard(message: _error!, onRetry: _loadData)
      else if (_loans.isEmpty)
        const _EmptyLoans()
      else
        ..._loans.map((loan) => _LoanCard(
              loan: loan,
              onEdit: () => _editLoan(loan),
              onDelete: () => _deleteLoan(loan),
            )),
    ];
  }

  List<Widget> _transactionContent({int? limit}) {
    if (_loading) {
      return [
        const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()))
      ];
    }
    if (_error != null) {
      return [_ErrorCard(message: _error!, onRetry: _loadData)];
    }
    if (_transactions.isEmpty) return [const _EmptyTransactions()];
    final items = limit == null ? _transactions : _transactions.take(limit);
    return items
        .map((transaction) => _TransactionTile(
              transaction,
              walletName: _walletNameFor(transaction.walletId),
              onDelete: limit == null
                  ? () => _deleteTransaction(transaction)
                  : null,
            ))
        .toList();
  }

  String? _walletNameFor(String walletId) {
    for (final wallet in _wallets) {
      if (wallet.id == walletId) return wallet.name;
    }
    return null;
  }

  Widget _sectionTitle(String title,
          {required String action, required VoidCallback onPressed}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: _ink, fontSize: 20, fontWeight: FontWeight.w700)),
          TextButton.icon(
            onPressed: onPressed,
            icon: Icon(
                action == 'See all'
                    ? Icons.arrow_forward_rounded
                    : Icons.add_rounded,
                size: 18),
            label: Text(action),
          ),
        ],
      );
}

class _WalletCards extends StatelessWidget {
  const _WalletCards({
    required this.wallets,
    required this.transactions,
    this.compact = false,
  });

  final List<MoneyWallet> wallets;
  final List<LedgerTransaction> transactions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) return const _EmptyWallets();
    return LayoutBuilder(builder: (context, constraints) {
      final columns = compact
          ? (constraints.maxWidth > 560 ? 2 : 1)
          : (constraints.maxWidth > 670
              ? 3
              : constraints.maxWidth > 390
                  ? 2
                  : 1);
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      final entries = compact ? wallets.take(2) : wallets;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: entries
            .map((wallet) => SizedBox(
                  width: width,
                  child: _WalletCard(
                    wallet: wallet,
                    balance: wallet.balanceFor(transactions),
                  ),
                ))
            .toList(),
      );
    });
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet, required this.balance});

  final MoneyWallet wallet;
  final int balance;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 142),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: _sage,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(wallet.icon, color: _emerald, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _sage,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(wallet.typeLabel,
                    style: const TextStyle(
                        color: _emerald,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 14),
            Text(wallet.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(_php.format(balance / 100),
                  style: const TextStyle(
                      color: _ink, fontSize: 21, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _EmptyWallets extends StatelessWidget {
  const _EmptyWallets();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Row(children: [
          Icon(Icons.account_balance_wallet_outlined, color: _emerald),
          SizedBox(width: 12),
          Expanded(
            child: Text('Add a wallet to start tracking its balance.',
                style: TextStyle(color: _muted)),
          ),
        ]),
      );
}

class _CashFlowChart extends StatelessWidget {
  const _CashFlowChart({required this.transactions});

  final List<LedgerTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (index) => DateTime(now.year, now.month - 5 + index),
    );
    final totals = months.map((month) {
      var income = 0;
      var expenses = 0;
      for (final transaction in transactions) {
        if (transaction.occurredOn.year == month.year &&
            transaction.occurredOn.month == month.month) {
          if (transaction.type == 'income') {
            income += transaction.amountCents;
          } else {
            expenses += transaction.amountCents;
          }
        }
      }
      return (income: income, expenses: expenses);
    }).toList(growable: false);
    final maxValue = totals.fold<int>(
      1,
      (max, month) => [
        max,
        month.income,
        month.expenses,
      ].reduce((a, b) => a > b ? a : b),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 15),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR MONEY, OVER TIME',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Cash flow',
            style: TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _ChartLegend(color: _emerald, label: 'Income'),
              SizedBox(width: 16),
              _ChartLegend(color: _expense, label: 'Expenses'),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < months.length; index++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _ChartBar(
                                amount: totals[index].income,
                                maxValue: maxValue,
                                color: _emerald,
                              ),
                              const SizedBox(width: 3),
                              _ChartBar(
                                amount: totals[index].expenses,
                                maxValue: maxValue,
                                color: _expense,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('MMM').format(months[index]),
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      );
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({
    required this.amount,
    required this.maxValue,
    required this.color,
  });

  final int amount;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height:
            amount == 0 ? 3 : (amount / maxValue * 92).clamp(4, 92).toDouble(),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_navy, _surfaceRaised],
          ),
          border: Border.all(color: _emerald.withOpacity(0.18)),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Available balance',
                    style: TextStyle(color: Color(0xFFC5D4D4)),
                  ),
                ),
                Icon(Icons.account_balance_wallet_outlined,
                    color: Color(0xFFD4E9E0)),
              ],
            ),
            const SizedBox(height: 15),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _php.format(balance / 100),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Across your tracked activity',
              style: TextStyle(color: Color(0xFFC3D2D1), fontSize: 12),
            ),
          ],
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.detail,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? detail;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 13),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 5),
              Text(detail!,
                  style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ],
        ),
      );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(this.transaction, {this.walletName, this.onDelete});

  final LedgerTransaction transaction;
  final String? walletName;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final color = isIncome ? _emerald : _expense;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction.category} · ${_shortDate.format(transaction.occurredOn)}${walletName == null ? '' : ' · $walletName'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${isIncome ? '+' : '−'}${_php.format(transaction.amountCents / 100)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete activity',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              color: _muted,
            ),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Column(
          children: [
            Icon(Icons.swap_horiz_rounded, color: _emerald, size: 32),
            SizedBox(height: 8),
            Text(
              'Your money story starts here.',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 5),
            Text(
              'Add a transaction to see it reflected in your overview.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(message, style: const TextStyle(color: Colors.red)),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.loan,
    required this.onEdit,
    required this.onDelete,
  });

  final PersonalLoan loan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 11),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(loan.name,
                        style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(loan.lender, style: const TextStyle(color: _muted)),
                  ]),
                ),
                IconButton(tooltip: 'Edit loan', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
                IconButton(tooltip: 'Delete loan', onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _LoanMetric(label: 'Outstanding', value: _php.format(loan.balanceCents / 100), emphasized: true)),
                Expanded(child: _LoanMetric(label: 'Original amount', value: _php.format(loan.originalAmountCents / 100))),
              ]),
              if (loan.termMonths != null || loan.monthlyPaymentCents != null) ...[
                const SizedBox(height: 10),
                Text(
                  '${loan.termMonths == null ? 'Term not set' : '${loan.termMonths} month term'} · ${((loan.annualInterestBps / 100).toStringAsFixed(2))}% APR',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                if (loan.monthlyPaymentCents != null) ...[
                  const SizedBox(height: 3),
                  Text('Scheduled payment ${_php.format(loan.monthlyPaymentCents! / 100)} / month',
                      style: const TextStyle(color: _muted, fontSize: 12)),
                ],
              ],
              if (loan.dueOn != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.event_outlined, size: 16, color: _muted),
                  const SizedBox(width: 6),
                  Text('Next due ${DateFormat('MMM d, yyyy').format(loan.dueOn!)}',
                      style: const TextStyle(color: _muted, fontSize: 12)),
                ]),
              ],
            ],
          ),
        ),
      );
}

class _LoanMetric extends StatelessWidget {
  const _LoanMetric({required this.label, required this.value, this.emphasized = false});

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: emphasized ? _expense : _ink, fontWeight: FontWeight.w700)),
        ],
      );
}

class _EmptyLoans extends StatelessWidget {
  const _EmptyLoans();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Icon(Icons.request_quote_outlined, color: _emerald, size: 30),
            const SizedBox(height: 10),
            const Text('No loans added yet', style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            const Text('Add a loan to keep its outstanding balance in view.', textAlign: TextAlign.center, style: TextStyle(color: _muted)),
          ]),
        ),
      );
}

class LoanSheet extends StatefulWidget {
  const LoanSheet({this.loan, super.key});

  final PersonalLoan? loan;

  @override
  State<LoanSheet> createState() => _LoanSheetState();
}

class _LoanSheetState extends State<LoanSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _lender;
  late final TextEditingController _originalAmount;
  late final TextEditingController _balance;
  late final TextEditingController _termMonths;
  late final TextEditingController _annualInterest;
  late final TextEditingController _monthlyPayment;
  DateTime? _dueOn;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;
    _name = TextEditingController(text: loan?.name ?? '');
    _lender = TextEditingController(text: loan?.lender ?? '');
    _originalAmount = TextEditingController(
        text: loan == null ? '' : (loan.originalAmountCents / 100).toStringAsFixed(2));
    _balance = TextEditingController(
        text: loan == null ? '' : (loan.balanceCents / 100).toStringAsFixed(2));
    _termMonths = TextEditingController(text: loan?.termMonths?.toString() ?? '');
    _annualInterest = TextEditingController(
        text: loan == null ? '0' : (loan.annualInterestBps / 100).toStringAsFixed(2));
    _monthlyPayment = TextEditingController(
        text: loan?.monthlyPaymentCents == null
            ? ''
            : (loan!.monthlyPaymentCents! / 100).toStringAsFixed(2));
    _dueOn = loan?.dueOn;
  }

  @override
  void dispose() {
    _name.dispose();
    _lender.dispose();
    _originalAmount.dispose();
    _balance.dispose();
    _termMonths.dispose();
    _annualInterest.dispose();
    _monthlyPayment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueOn == null) {
      _showMessage(context, 'Set the next payment date to schedule a reminder.');
      return;
    }
    final original = double.parse(_originalAmount.text.trim());
    final balance = double.parse(_balance.text.trim());
    final termMonths = int.parse(_termMonths.text.trim());
    final annualInterestPercent = double.parse(_annualInterest.text.trim());
    final monthlyPayment = double.parse(_monthlyPayment.text.trim());
    setState(() => _busy = true);
    try {
      final client = Supabase.instance.client;
      final values = {
        'name': _name.text.trim(),
        'lender': _lender.text.trim(),
        'original_amount_cents': (original * 100).round(),
        'balance_cents': (balance * 100).round(),
        'term_months': termMonths,
        'annual_interest_bps': (annualInterestPercent * 100).round(),
        'monthly_payment_cents': (monthlyPayment * 100).round(),
        'due_on': _dueOn == null ? null : _dbDate.format(_dueOn!),
      };
      if (widget.loan == null) {
        await client.from('loans').insert({
          'user_id': client.auth.currentUser!.id,
          ...values,
        });
      } else {
        await client.from('loans').update(values).eq('id', widget.loan!.id);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showMessage(context, 'Could not save loan: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueOn ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _dueOn = date);
  }

  void _estimateMonthlyPayment() {
    final principal = double.tryParse(_originalAmount.text.trim());
    final months = int.tryParse(_termMonths.text.trim());
    final annualRate = double.tryParse(_annualInterest.text.trim());
    if (principal == null ||
        months == null ||
        annualRate == null ||
        !principal.isFinite ||
        !annualRate.isFinite ||
        principal <= 0 ||
        principal > 100000000 ||
        months < 1 ||
        months > 600 ||
        annualRate < 0 ||
        annualRate > 1000) {
      _showMessage(context, 'Enter the amount, loan term, and APR first.');
      return;
    }
    final monthlyRate = annualRate / 100 / 12;
    final payment = monthlyRate == 0
        ? principal / months
        : principal * monthlyRate /
            (1 - math.pow(1 + monthlyRate, -months)).toDouble();
    _monthlyPayment.text = payment.toStringAsFixed(2);
  }

  String? _amountError(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null || !amount.isFinite || amount < 0 || amount > 100000000) {
      return 'Enter an amount from ₱0 to ₱100,000,000.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(widget.loan == null ? 'Add loan' : 'Update loan', style: const TextStyle(color: _ink, fontSize: 21, fontWeight: FontWeight.w700))),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 6),
              const Text('Track the amount borrowed and what remains to be paid.', style: TextStyle(color: _muted)),
              const SizedBox(height: 17),
              TextFormField(controller: _name, maxLength: 60, textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Loan name', hintText: 'e.g. Car loan'),
                  validator: (value) => value == null || value.trim().isEmpty || value.trim().length > 60 ? 'Enter a loan name.' : null),
              const SizedBox(height: 8),
              TextFormField(controller: _lender, maxLength: 60, textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Lender', hintText: 'e.g. Bank or person'),
                  validator: (value) => value == null || value.trim().isEmpty || value.trim().length > 60 ? 'Enter the lender.' : null),
              const SizedBox(height: 8),
              TextFormField(controller: _originalAmount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Original amount', prefixText: '₱ '),
                  validator: (value) => _amountError(value)),
              const SizedBox(height: 13),
              TextFormField(controller: _balance, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Current outstanding balance', prefixText: '₱ '),
                  validator: _amountError),
              const SizedBox(height: 13),
              TextFormField(
                controller: _termMonths,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Loan term (months)'),
                validator: (value) {
                  final months = int.tryParse(value?.trim() ?? '');
                  return months == null || months < 1 || months > 600
                      ? 'Enter a term from 1 to 600 months.'
                      : null;
                },
              ),
              const SizedBox(height: 13),
              TextFormField(
                controller: _annualInterest,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Annual interest rate', suffixText: '% APR'),
                validator: (value) {
                  final rate = double.tryParse(value?.trim() ?? '');
                  return rate == null || !rate.isFinite || rate < 0 || rate > 1000
                      ? 'Enter an APR from 0% to 1,000%.'
                      : null;
                },
              ),
              const SizedBox(height: 13),
              TextFormField(
                controller: _monthlyPayment,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Scheduled monthly payment', prefixText: '₱ '),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  return amount == null || !amount.isFinite || amount <= 0 || amount > 100000000
                      ? 'Enter a monthly payment greater than ₱0.'
                      : null;
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _estimateMonthlyPayment,
                  icon: const Icon(Icons.calculate_outlined, size: 18),
                  label: const Text('Estimate payment'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  'Estimate uses a standard fixed-payment formula; lender fees may change the actual amount.',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                OutlinedButton.icon(onPressed: _selectDueDate, icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_dueOn == null ? 'Set next payment date' : DateFormat('MMM d, yyyy').format(_dueOn!))),
                if (_dueOn != null) TextButton(onPressed: () => setState(() => _dueOn = null), child: const Text('Clear')),
              ]),
              const SizedBox(height: 18),
              PrimaryButton(label: widget.loan == null ? 'Save loan' : 'Save changes', busy: _busy, onPressed: _save),
            ]),
          ),
        ),
      );
}

class WeeklyLimitSheet extends StatefulWidget {
  const WeeklyLimitSheet({required this.initialLimitCents, super.key});

  final int? initialLimitCents;

  @override
  State<WeeklyLimitSheet> createState() => _WeeklyLimitSheetState();
}

class _WeeklyLimitSheetState extends State<WeeklyLimitSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _limit;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _limit = TextEditingController(
      text: widget.initialLimitCents == null
          ? ''
          : (widget.initialLimitCents! / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save({bool clear = false}) async {
    if (!clear && !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final client = Supabase.instance.client;
      await client.from('user_preferences').upsert({
        'user_id': client.auth.currentUser!.id,
        'weekly_expense_limit_cents': clear
            ? null
            : (double.parse(_limit.text.trim()) * 100).round(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showMessage(context, 'Could not save weekly limit: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Weekly expense limit',
                  style: TextStyle(
                      color: _ink, fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Spending is counted Monday through Sunday.',
                  style: TextStyle(color: _muted)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _limit,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Weekly limit', prefixText: '₱ '),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  return amount == null ||
                          !amount.isFinite ||
                          amount <= 0 ||
                          amount > 100000000
                      ? 'Enter a limit above ₱0.'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Save limit',
                busy: _busy,
                onPressed: _save,
              ),
              if (widget.initialLimitCents != null) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _busy ? null : () => _save(clear: true),
                    child: const Text('Remove limit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class _ChatMessage {
  const _ChatMessage(this.text, {required this.fromUser});

  final String text;
  final bool fromUser;
}

class ChatAssistantSheet extends StatefulWidget {
  const ChatAssistantSheet({
    required this.wallets,
    required this.walletBalanceCents,
    required this.loans,
    required this.transactions,
    required this.weeklySpentCents,
    required this.weeklyLimitCents,
    super.key,
  });

  final List<MoneyWallet> wallets;
  final int walletBalanceCents;
  final List<PersonalLoan> loans;
  final List<LedgerTransaction> transactions;
  final int weeklySpentCents;
  final int? weeklyLimitCents;

  @override
  State<ChatAssistantSheet> createState() => _ChatAssistantSheetState();
}

class _ChatAssistantSheetState extends State<ChatAssistantSheet> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      'Hi! Ask me about your saved Callet data: wallets, banks, activity, loans, and weekly spending. I can also show a full finance summary.',
      fromUser: false,
    ),
  ];

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final question = _input.text.trim();
    if (question.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(question, fromUser: true));
      _messages.add(_ChatMessage(_answer(question), fromUser: false));
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _answer(String question) {
    final text = question.toLowerCase();
    final allDataAnswer = _answerAllDataQuestion(text);
    if (allDataAnswer != null) return allDataAnswer;
    final walletAnswer = _answerWalletQuestion(text);
    if (walletAnswer != null) return walletAnswer;
    if (text.contains('monthly') || text.contains('installment')) {
      final monthlyTotal = widget.loans
          .where((loan) => loan.balanceCents > 0)
          .fold<int>(0, (sum, loan) => sum + (loan.monthlyPaymentCents ?? 0));
      return 'Your scheduled monthly loan payments total ${_php.format(monthlyTotal / 100)}.';
    }
    if (text.contains('balance') || text.contains('wallet')) {
      return 'Your tracked wallet balance is ${_php.format(widget.walletBalanceCents / 100)}.';
    }
    if (text.contains('loan') || text.contains('debt')) {
      if (text.contains('all') ||
          text.contains('list') ||
          text.contains('detail') ||
          text.contains('term')) {
        return _allLoanReport();
      }
      final total = widget.loans.fold<int>(
          0, (sum, loan) => sum + loan.balanceCents);
      final next = widget.loans
          .where((loan) => loan.balanceCents > 0 && loan.dueOn != null)
          .toList()
        ..sort((a, b) => a.dueOn!.compareTo(b.dueOn!));
      final due = next.isEmpty
          ? ' No upcoming loan payment is scheduled.'
          : ' Next due: ${next.first.name} on ${DateFormat('MMM d, yyyy').format(next.first.dueOn!)}.';
      return 'Your tracked outstanding loans total ${_php.format(total / 100)}.$due';
    }
    if (text.contains('due') || text.contains('payment') || text.contains('remind')) {
      final next = widget.loans
          .where((loan) => loan.balanceCents > 0 && loan.dueOn != null)
          .toList()
        ..sort((a, b) => a.dueOn!.compareTo(b.dueOn!));
      if (next.isEmpty) return 'You do not have a loan payment date set yet.';
      return '${next.first.name} is next due on ${DateFormat('MMMM d, yyyy').format(next.first.dueOn!)}. Scheduled monthly payment: ${next.first.monthlyPaymentCents == null ? 'not set' : _php.format(next.first.monthlyPaymentCents! / 100)}.';
    }
    if (text.contains('week') || text.contains('spend') || text.contains('expense') || text.contains('budget') || text.contains('limit')) {
      final limit = widget.weeklyLimitCents;
      if (limit == null) {
        return 'You have spent ${_php.format(widget.weeklySpentCents / 100)} this week. Set a weekly expense limit on the overview to track your target.';
      }
      final remaining = limit - widget.weeklySpentCents;
      return 'This week you have spent ${_php.format(widget.weeklySpentCents / 100)} of ${_php.format(limit / 100)}. ${remaining >= 0 ? '${_php.format(remaining / 100)} remains.' : 'You are ${_php.format(-remaining / 100)} over the limit.'}';
    }
    final asksForActivityHistory =
        (text.contains('all') || text.contains('history') || text.contains('list')) &&
            (text.contains('activity') ||
                text.contains('transaction') ||
                text.contains('description'));
    if (asksForActivityHistory) return _allActivityReport();
    if (text.contains('recent') || text.contains('activity') || text.contains('transaction')) {
      if (widget.transactions.isEmpty) return 'There are no transactions saved yet.';
      final latest = widget.transactions.first;
      return 'Your latest saved activity is ${latest.description}, ${_php.format(latest.amountCents / 100)} on ${DateFormat('MMM d, yyyy').format(latest.occurredOn)}.';
    }
    return 'I can answer from your saved wallets, activity, loans, and weekly limit. Try “Show my full finance summary” or “List all transactions.”';
  }

  String? _answerAllDataQuestion(String text) {
    final asksForFullSummary = text.contains('everything') ||
        text.contains('all data') ||
        text.contains('all records') ||
        text.contains('system data') ||
        text.contains('full summary') ||
        text.contains('full report') ||
        (text.contains('overview') &&
            (text.contains('my') ||
                text.contains('finance') ||
                text.contains('account')));
    return asksForFullSummary ? _fullDataReport() : null;
  }

  String _fullDataReport() {
    final sections = <String>['Your saved Callet finance data:'];

    sections.add('Wallets and banks:');
    if (widget.wallets.isEmpty) {
      sections.add('No wallets are saved.');
    } else {
      for (final wallet in widget.wallets) {
        final balance = _php.format(wallet.balanceFor(widget.transactions) / 100);
        final openingBalance =
            _php.format(wallet.openingBalanceCents / 100);
        sections.add(
          '- ${wallet.name} (${wallet.typeLabel}): current balance $balance; '
          'opening balance $openingBalance on '
          '${DateFormat('MMM d, yyyy').format(wallet.openingBalanceOn)}',
        );
      }
    }

    sections.add(_allLoanReport());

    final incomeCents = widget.transactions
        .where((transaction) => transaction.type == 'income')
        .fold<int>(0, (sum, transaction) => sum + transaction.amountCents);
    final expenseCents = widget.transactions
        .where((transaction) => transaction.type == 'expense')
        .fold<int>(0, (sum, transaction) => sum + transaction.amountCents);
    sections.add(
      'Activity totals: ${widget.transactions.length} transactions, '
      '${_php.format(incomeCents / 100)} income, '
      '${_php.format(expenseCents / 100)} expenses.',
    );
    sections.add(_weeklyBudgetSummary());
    sections.add(_allActivityReport());
    return sections.join('\n');
  }

  String _allLoanReport() {
    if (widget.loans.isEmpty) return 'Loans: no loans are saved.';
    final lines = widget.loans.map((loan) {
      final dueDate = loan.dueOn == null
          ? 'next due date not set'
          : 'next due ${DateFormat('MMM d, yyyy').format(loan.dueOn!)}';
      final monthlyPayment = loan.monthlyPaymentCents == null
          ? 'monthly payment not set'
          : '${_php.format(loan.monthlyPaymentCents! / 100)} per month';
      final term = loan.termMonths == null
          ? 'term not set'
          : '${loan.termMonths} month term';
      return '- ${loan.name} from ${loan.lender}: balance '
          '${_php.format(loan.balanceCents / 100)} of '
          '${_php.format(loan.originalAmountCents / 100)}, $monthlyPayment, '
          '$dueDate, $term, APR '
          '${(loan.annualInterestBps / 100).toStringAsFixed(2)}%';
    });
    return 'Loans:\n${lines.join('\n')}';
  }

  String _weeklyBudgetSummary() {
    final limit = widget.weeklyLimitCents;
    if (limit == null || limit <= 0) {
      return 'Weekly limit: not set. Spending this week: '
          '${_php.format(widget.weeklySpentCents / 100)}.';
    }
    final remaining = limit - widget.weeklySpentCents;
    return 'Weekly spending: ${_php.format(widget.weeklySpentCents / 100)} '
        'of ${_php.format(limit / 100)}. '
        '${remaining >= 0 ? '${_php.format(remaining / 100)} remaining.' : '${_php.format(-remaining / 100)} over the limit.'}';
  }

  String _allActivityReport() {
    if (widget.transactions.isEmpty) return 'No transactions are saved.';
    final transactions = widget.transactions.toList()
      ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));
    final lines = transactions.map((transaction) {
      final wallet = _walletForTransaction(transaction.walletId);
      final walletLabel = wallet == null ? '' : ' · ${wallet.name}';
      final kind = transaction.type == 'income' ? 'Income' : 'Expense';
      return '- ${DateFormat('MMM d, yyyy').format(transaction.occurredOn)} · '
          '$kind · ${transaction.description} · ${transaction.category} · '
          '${_php.format(transaction.amountCents / 100)}$walletLabel';
    });
    return 'Saved activity:\n${lines.join('\n')}';
  }

  MoneyWallet? _walletForTransaction(String walletId) {
    for (final wallet in widget.wallets) {
      if (wallet.id == walletId) return wallet;
    }
    return null;
  }

  String? _answerWalletQuestion(String text) {
    final mentionsWalletName = widget.wallets.any((wallet) {
      final name = wallet.name.trim().toLowerCase();
      final isGenericName = const {
        'bank',
        'gcash',
        'cash',
        'wallet',
        'account',
      }.contains(name);
      return name.isNotEmpty && !isGenericName && text.contains(name);
    });
    final asksWallet = mentionsWalletName ||
        text.contains('wallet') ||
        text.contains('bank') ||
        text.contains('account') ||
        text.contains('gcash');
    if (!asksWallet) return null;
    if (widget.wallets.isEmpty) {
      return 'You do not have any wallets saved in Callet yet.';
    }

    final asksForDetails = text.contains('all') ||
        text.contains('list') ||
        text.contains('description') ||
        text.contains('activity') ||
        text.contains('transaction') ||
        text.contains('account') ||
        text.contains('bank') ||
        text.contains('banks') ||
        text.contains('gcash') ||
        (text.contains('wallet') && !text.contains('balance'));

    MoneyWallet? namedWallet;
    for (final wallet in widget.wallets) {
      final name = wallet.name.trim().toLowerCase();
      final isGenericName = const {
        'bank',
        'gcash',
        'cash',
        'wallet',
        'account',
      }.contains(name);
      if (name.isNotEmpty && !isGenericName && text.contains(name)) {
        namedWallet = wallet;
        break;
      }
    }
    if (namedWallet != null) {
      return _walletSummary(
        namedWallet,
        includeAllActivity: text.contains('all'),
      );
    }
    if (!asksForDetails) return null;

    final types = <String>{
      if (text.contains('bank')) 'bank',
      if (text.contains('gcash')) 'gcash',
    };
    final matchingWallets = widget.wallets
        .where((wallet) => types.isEmpty || types.contains(wallet.type))
        .toList(growable: false);
    if (matchingWallets.isEmpty) {
      return types.contains('bank') && !types.contains('gcash')
          ? 'You do not have any bank wallets saved in Callet yet.'
          : types.contains('gcash') && !types.contains('bank')
              ? 'You do not have any GCash wallets saved in Callet yet.'
              : 'You do not have any matching wallets saved in Callet yet.';
    }

    return matchingWallets
        .map((wallet) => _walletSummary(
              wallet,
              includeAllActivity: text.contains('all'),
            ))
        .join('\n\n');
  }

  String _walletSummary(
    MoneyWallet wallet, {
    required bool includeAllActivity,
  }) {
    final balance = _php.format(wallet.balanceFor(widget.transactions) / 100);
    final activity = widget.transactions
        .where((transaction) => transaction.walletId == wallet.id)
        .toList()
      ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn));
    if (activity.isEmpty) {
      return '${wallet.name} (${wallet.typeLabel}) has a balance of $balance and no saved activity yet.';
    }

    final shownActivity = includeAllActivity ? activity : activity.take(5);
    final descriptions = shownActivity.map((transaction) {
      final kind = transaction.type == 'income' ? 'Income' : 'Expense';
      final category = transaction.category.isEmpty
          ? ''
          : ' · ${transaction.category}';
      return '$kind: ${transaction.description}$category, '
          '${_php.format(transaction.amountCents / 100)} on '
          '${DateFormat('MMM d, yyyy').format(transaction.occurredOn)}';
    }).join('; ');
    final suffix = activity.length > 5 && !includeAllActivity
        ? ' Showing the 5 most recent of ${activity.length} activities.'
        : '';
    return '${wallet.name} (${wallet.typeLabel}) has a balance of $balance. '
        'Activity descriptions: $descriptions.$suffix';
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            18,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 12,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Chat with Callet',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Your finance data stays in this app.',
                    style: TextStyle(color: _muted, fontSize: 12)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return Align(
                      alignment: message.fromUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: message.fromUser ? _sage : _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _line),
                        ),
                        child: Text(message.text,
                            style: const TextStyle(color: _ink)),
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about your finances…',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class AddWalletSheet extends StatefulWidget {
  const AddWalletSheet({super.key});

  @override
  State<AddWalletSheet> createState() => _AddWalletSheetState();
}

class _AddWalletSheetState extends State<AddWalletSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _openingBalance = TextEditingController(text: '0');
  String _type = 'gcash';
  DateTime _balanceDate = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _openingBalance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final parsed = double.parse(_openingBalance.text.trim());
    setState(() => _busy = true);
    try {
      final client = Supabase.instance.client;
      await client.from('wallets').insert({
        'user_id': client.auth.currentUser!.id,
        'name': _name.text.trim(),
        'type': _type,
        'opening_balance_cents': (parsed * 100).round(),
        'opening_balance_on': _dbDate.format(_balanceDate),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showMessage(context, 'Could not save wallet: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectBalanceDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _balanceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _balanceDate = date);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                    child: Text('Add wallet',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 21,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 6),
                const Text(
                    'Set a starting balance and the date it applies from.',
                    style: TextStyle(color: _muted)),
                const SizedBox(height: 17),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Wallet type'),
                  items: const [
                    DropdownMenuItem(value: 'gcash', child: Text('GCash')),
                    DropdownMenuItem(
                        value: 'bank', child: Text('Bank account')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _name,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Wallet name', hintText: 'e.g. Main GCash'),
                  validator: (value) => value == null ||
                          value.trim().isEmpty ||
                          value.trim().length > 40
                      ? 'Enter a wallet name (up to 40 characters).'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _openingBalance,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Starting balance', prefixText: '₱ '),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null ||
                        !amount.isFinite ||
                        amount < 0 ||
                        amount > 100000000) {
                      return 'Enter a balance from ₱0 to ₱100,000,000.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _selectBalanceDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                      'Balance as of ${DateFormat('MMMM d, yyyy').format(_balanceDate)}'),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                    label: 'Save wallet', busy: _busy, onPressed: _save),
              ],
            ),
          ),
        ),
      );
}

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({required this.wallets, super.key});

  final List<MoneyWallet> wallets;

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  static const _categories = [
    'General',
    'Food',
    'Transport',
    'Housing',
    'Bills',
    'Shopping',
    'Health',
    'Salary',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  String _type = 'expense';
  String _category = 'General';
  String? _walletId;
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amountCents = (double.parse(_amount.text.trim()) * 100).round();
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.from('transactions').insert({
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'wallet_id': _walletId ?? widget.wallets.first.id,
        'amount_cents': amountCents,
        'type': _type,
        'description': _description.text.trim(),
        'category': _category,
        'occurred_on': _dbDate.format(_date),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showMessage(context, 'Could not save transaction: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _date = date);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add transaction',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'expense',
                      label: Text('Expense'),
                      icon: Icon(Icons.north_east_rounded),
                    ),
                    ButtonSegment(
                      value: 'income',
                      label: Text('Income'),
                      icon: Icon(Icons.south_west_rounded),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (value) =>
                      setState(() => _type = value.first),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g. Weekly groceries',
                  ),
                  validator: (value) => value == null ||
                          value.trim().isEmpty ||
                          value.trim().length > 100
                      ? 'Enter a description (up to 100 characters).'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₱ ',
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null ||
                        !amount.isFinite ||
                        amount <= 0 ||
                        amount > 1000000) {
                      return 'Enter an amount between ₱0.01 and ₱1,000,000.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _walletId ?? widget.wallets.first.id,
                  decoration: const InputDecoration(labelText: 'Wallet'),
                  items: widget.wallets
                      .map((wallet) => DropdownMenuItem(
                            value: wallet.id,
                            child: Text('${wallet.name} · ${wallet.typeLabel}'),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _walletId = value),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(DateFormat('MMMM d, yyyy').format(_date)),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Save transaction',
                  busy: _busy,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      );
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
