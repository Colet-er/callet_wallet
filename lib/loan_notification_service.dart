import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LoanReminder {
  const LoanReminder({
    required this.id,
    required this.name,
    required this.dueOn,
    required this.monthlyPaymentCents,
  });

  final String id;
  final String name;
  final DateTime dueOn;
  final int? monthlyPaymentCents;
}

class LoanNotificationService {
  LoanNotificationService._();

  static final instance = LoanNotificationService._();

  static const _payloadPrefix = 'callet-loan-reminder:';
  static const _channelId = 'loan_payment_reminders';
  static const _channelName = 'Loan payment reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (kIsWeb || _initialized || !_isPhonePlatform) return;

    tz_data.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Keep scheduling usable if the device timezone lookup plugin is absent.
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb || !_isPhonePlatform) return false;
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  Future<void> synchronize(List<LoanReminder> loans) async {
    if (kIsWeb || !_isPhonePlatform) return;
    await initialize();
    if (!_initialized) return;

    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith(_payloadPrefix) ?? false) {
        await _plugin.cancel(request.id);
      }
    }

    final now = tz.TZDateTime.now(tz.local);
    for (final loan in loans) {
      final dueDate = DateTime(loan.dueOn.year, loan.dueOn.month, loan.dueOn.day);
      final reminderDate = dueDate.subtract(const Duration(days: 7));
      var scheduleAt = tz.TZDateTime(
        tz.local,
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        9,
      );
      if (!scheduleAt.isAfter(now) &&
          reminderDate.year == now.year &&
          reminderDate.month == now.month &&
          reminderDate.day == now.day) {
        scheduleAt = now.add(const Duration(minutes: 1));
      }
      if (!scheduleAt.isAfter(now)) continue;

      final payment = loan.monthlyPaymentCents == null
          ? 'Your loan payment is due in 7 days.'
          : '₱${(loan.monthlyPaymentCents! / 100).toStringAsFixed(2)} is due in 7 days.';
      await _plugin.zonedSchedule(
        _notificationId(loan.id),
        '${loan.name} payment reminder',
        payment,
        scheduleAt,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Reminders seven days before loan payments.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '$_payloadPrefix${loan.id}',
      );
    }
  }

  bool get _isPhonePlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  int _notificationId(String value) {
    // FNV-1a keeps IDs stable across launches, unlike String.hashCode.
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
