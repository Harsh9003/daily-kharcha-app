import 'package:cloud_firestore/cloud_firestore.dart';

class StreakService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _streakRef(String uid) {
    return _db.collection('users').doc(uid).collection('userStats').doc('streak');
  }

  static Stream<Map<String, dynamic>> streakStream(String uid) {
    return _streakRef(uid).snapshots().map((doc) {
      final data = doc.data() ?? {};
      return {
        'currentStreak': data['currentStreak'] ?? 0,
        'bestStreak': data['bestStreak'] ?? 0,
        'lastTransactionDate': data['lastTransactionDate'] ?? '',
        'transactionCount': data['transactionCount'] ?? 0,
        'achievements': List<String>.from(data['achievements'] ?? const []),
        'seenAchievements': List<String>.from(data['seenAchievements'] ?? const []),
        'unseenAchievementCount': data['unseenAchievementCount'] ?? 0,
        'updatedAt': data['updatedAt'],
      };
    });
  }

  static Future<void> updateStreakAfterTransaction(String uid) async {
    final ref = _streakRef(uid);
    final today = _dateKey(DateTime.now());
    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      final data = snap.data() ?? {};

      final lastDate = (data['lastTransactionDate'] ?? '').toString();
      int currentStreak = (data['currentStreak'] ?? 0) as int;
      int bestStreak = (data['bestStreak'] ?? 0) as int;
      int transactionCount = (data['transactionCount'] ?? 0) as int;
      final oldAchievements = Set<String>.from(data['achievements'] ?? const []);
      final achievements = Set<String>.from(oldAchievements);
      final currentUnseenCount = (data['unseenAchievementCount'] ?? 0) is int
          ? data['unseenAchievementCount'] as int
          : 0;

      transactionCount += 1;

      if (lastDate == today) {
        currentStreak = currentStreak == 0 ? 1 : currentStreak;
      } else if (lastDate == yesterday) {
        currentStreak += 1;
      } else {
        currentStreak = 1;
      }

      if (currentStreak > bestStreak) bestStreak = currentStreak;

      achievements.add('first_expense');
      if (currentStreak >= 3) achievements.add('streak_3');
      if (currentStreak >= 7) achievements.add('streak_7');
      if (currentStreak >= 30) achievements.add('streak_30');
      if (transactionCount >= 25) achievements.add('tx_25');
      if (transactionCount >= 100) achievements.add('tx_100');

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

  static Future<void> markAchievementsSeen(String uid) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('userStats')
        .doc('streak');

    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};

    final achievements =
        List<String>.from(data['achievements'] ?? const []);

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

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
