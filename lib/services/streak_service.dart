import 'package:cloud_firestore/cloud_firestore.dart';

class StreakService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _streakRef(String uid) {
    return _db.collection('users').doc(uid).collection('userStats').doc('streak');
  }

  static CollectionReference<Map<String, dynamic>> _transactionsRef(String uid) {
    return _db.collection('users').doc(uid).collection('transactions');
  }

  static Stream<Map<String, dynamic>> streakStream(String uid) {
    return _streakRef(uid).snapshots().map((doc) {
      final data = doc.data() ?? {};
      return {
        'currentStreak': _toInt(data['currentStreak']),
        'bestStreak': _toInt(data['bestStreak']),
        'lastTransactionDate': data['lastTransactionDate']?.toString() ?? '',
        'transactionCount': _toInt(data['transactionCount']),
        'achievements': List<String>.from(data['achievements'] ?? const []),
        'seenAchievements': List<String>.from(data['seenAchievements'] ?? const []),
        'unseenAchievementCount': _toInt(data['unseenAchievementCount']),
        'updatedAt': data['updatedAt'],
      };
    });
  }

  static Future<void> updateStreakAfterTransaction(String uid) async {
    if (uid.trim().isEmpty) return;

    final ref = _streakRef(uid);
    final now = DateTime.now();
    final today = _dateKey(now);
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      final data = snap.data() ?? {};

      final lastDate = data['lastTransactionDate']?.toString() ?? '';
      int currentStreak = _toInt(data['currentStreak']);
      int bestStreak = _toInt(data['bestStreak']);
      int transactionCount = _toInt(data['transactionCount']);
      final oldAchievements = Set<String>.from(data['achievements'] ?? const []);
      final achievements = Set<String>.from(oldAchievements);
      final currentUnseenCount = _toInt(data['unseenAchievementCount']);

      transactionCount += 1;

      if (lastDate == today) {
        currentStreak = currentStreak <= 0 ? 1 : currentStreak;
      } else if (lastDate == yesterday) {
        currentStreak += 1;
      } else {
        currentStreak = 1;
      }

      if (currentStreak > bestStreak) bestStreak = currentStreak;

      _addAchievements(
        achievements: achievements,
        currentStreak: currentStreak,
        transactionCount: transactionCount,
      );

      final newlyUnlockedCount = achievements.difference(oldAchievements).length;

      transaction.set(
        ref,
        {
          'currentStreak': currentStreak,
          'bestStreak': bestStreak,
          'lastTransactionDate': today,
          'transactionCount': transactionCount,
          'achievements': achievements.toList(),
          'unseenAchievementCount': currentUnseenCount + newlyUnlockedCount,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// User mobile ke liye important fallback.
  /// Agar streak doc missing/old ho, toh user's existing transactions se streak rebuild ho jayega.
  static Future<void> syncUserStreakFromTransactions(String uid) async {
    if (uid.trim().isEmpty) return;

    final txSnap = await _transactionsRef(uid).get();

    final dateKeys = <String>{};

    for (final doc in txSnap.docs) {
      final data = doc.data();
      final parsedDate = _parseDate(data['date']);
      if (parsedDate != null) {
        dateKeys.add(_dateKey(parsedDate));
      }
    }

    final transactionCount = txSnap.docs.length;
    final currentStreak = _calculateCurrentStreak(dateKeys);
    final calculatedBestStreak = _calculateBestStreak(dateKeys);

    final streakSnap = await _streakRef(uid).get();
    final oldData = streakSnap.data() ?? {};

    final previousBest = _toInt(oldData['bestStreak']);
    final bestStreak = calculatedBestStreak > previousBest
        ? calculatedBestStreak
        : previousBest;

    final oldAchievements = Set<String>.from(oldData['achievements'] ?? const []);
    final achievements = Set<String>.from(oldAchievements);

    _addAchievements(
      achievements: achievements,
      currentStreak: currentStreak,
      transactionCount: transactionCount,
    );

    final newlyUnlockedCount = achievements.difference(oldAchievements).length;
    final currentUnseenCount = _toInt(oldData['unseenAchievementCount']);

    await _streakRef(uid).set({
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'lastTransactionDate': dateKeys.isEmpty ? '' : dateKeys.reduce((a, b) => a.compareTo(b) > 0 ? a : b),
      'transactionCount': transactionCount,
      'achievements': achievements.toList(),
      'unseenAchievementCount': currentUnseenCount + newlyUnlockedCount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> markAchievementsSeen(String uid) async {
    final docRef = _streakRef(uid);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final achievements = List<String>.from(data['achievements'] ?? const []);

    await docRef.set({
      'seenAchievements': achievements,
      'unseenAchievementCount': 0,
      'lastAchievementSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static List<Map<String, dynamic>> achievementList({
    required int currentStreak,
    required int bestStreak,
    required int transactionCount,
    required List<String> unlocked,
  }) {
    final unlockedSet = unlocked.toSet();

    return [
      {
        'id': 'first_expense',
        'icon': '🎉',
        'title': 'First Expense',
        'subtitle': 'Add your first transaction',
        'progress': transactionCount >= 1 ? 1.0 : 0.0,
        'unlocked': unlockedSet.contains('first_expense'),
      },
      {
        'id': 'streak_3',
        'icon': '🔥',
        'title': '3 Day Streak',
        'subtitle': 'Track expenses for 3 days',
        'progress': (currentStreak / 3).clamp(0.0, 1.0),
        'unlocked': unlockedSet.contains('streak_3'),
      },
      {
        'id': 'streak_7',
        'icon': '⚡',
        'title': '7 Day Streak',
        'subtitle': 'Track expenses for 7 days',
        'progress': (currentStreak / 7).clamp(0.0, 1.0),
        'unlocked': unlockedSet.contains('streak_7'),
      },
      {
        'id': 'tx_25',
        'icon': '💸',
        'title': '25 Transactions',
        'subtitle': 'Add 25 total transactions',
        'progress': (transactionCount / 25).clamp(0.0, 1.0),
        'unlocked': unlockedSet.contains('tx_25'),
      },
      {
        'id': 'streak_30',
        'icon': '👑',
        'title': '30 Day Champion',
        'subtitle': 'Track expenses for 30 days',
        'progress': (currentStreak / 30).clamp(0.0, 1.0),
        'unlocked': unlockedSet.contains('streak_30'),
      },
      {
        'id': 'tx_100',
        'icon': '🏆',
        'title': 'Expense Master',
        'subtitle': 'Add 100 total transactions',
        'progress': (transactionCount / 100).clamp(0.0, 1.0),
        'unlocked': unlockedSet.contains('tx_100'),
      },
    ];
  }

  static void _addAchievements({
    required Set<String> achievements,
    required int currentStreak,
    required int transactionCount,
  }) {
    if (transactionCount >= 1) achievements.add('first_expense');
    if (currentStreak >= 3) achievements.add('streak_3');
    if (currentStreak >= 7) achievements.add('streak_7');
    if (currentStreak >= 30) achievements.add('streak_30');
    if (transactionCount >= 25) achievements.add('tx_25');
    if (transactionCount >= 100) achievements.add('tx_100');
  }

  static int _calculateCurrentStreak(Set<String> dateKeys) {
    if (dateKeys.isEmpty) return 0;

    // Important: streak ko latest transaction date se calculate karo.
    // Agar user ne aaj transaction add nahi ki hai, toh rebuild currentStreak ko 0 mat karo.
    final latestKey = dateKeys.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    var cursor = DateTime.parse(latestKey);
    var streak = 0;

    while (dateKeys.contains(_dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  static int _calculateBestStreak(Set<String> dateKeys) {
    if (dateKeys.isEmpty) return 0;

    final dates = dateKeys.toList()..sort();
    var best = 1;
    var current = 1;

    for (var i = 1; i < dates.length; i++) {
      final prev = DateTime.parse(dates[i - 1]);
      final currentDate = DateTime.parse(dates[i]);
      final diff = currentDate.difference(prev).inDays;

      if (diff == 1) {
        current++;
      } else if (diff > 1) {
        current = 1;
      }

      if (current > best) best = current;
    }

    return best;
  }

  static DateTime? _parseDate(dynamic rawDate) {
    if (rawDate == null) return null;
    if (rawDate is Timestamp) return rawDate.toDate();
    if (rawDate is DateTime) return rawDate;
    return DateTime.tryParse(rawDate.toString());
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static String _dateKey(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
