import 'package:flutter/material.dart';
import '../services/streak_service.dart';

class AchievementsDialog extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final int transactionCount;
  final List<String> unlockedAchievements;

  const AchievementsDialog({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
    required this.transactionCount,
    required this.unlockedAchievements,
  });

  @override
  Widget build(BuildContext context) {
    final achievements = StreakService.achievementList(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      transactionCount: transactionCount,
      unlocked: unlockedAchievements,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        decoration: BoxDecoration(
          color: const Color(0xFF171720),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 22, 18, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2E2A60), Color(0xFF6C63FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Text('🔥', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Streak & Achievements',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Keep tracking daily to unlock rewards',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryTile(
                            icon: '🔥',
                            title: '$currentStreak Days',
                            subtitle: 'Current streak',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryTile(
                            icon: '👑',
                            title: '$bestStreak Days',
                            subtitle: 'Best streak',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 390),
                      child: SingleChildScrollView(
                        child: Column(
                          children: achievements.map((achievement) {
                            return _AchievementTile(achievement: achievement);
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;

  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.58),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _AchievementTile extends StatelessWidget {
  final Map<String, dynamic> achievement;

  const _AchievementTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement['unlocked'] == true;
    final progress = (achievement['progress'] as num).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: unlocked
            ? const Color(0xFF6C63FF).withOpacity(0.15)
            : Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked
              ? const Color(0xFF6C63FF).withOpacity(0.55)
              : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: unlocked
                  ? Colors.white.withOpacity(0.16)
                  : Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                achievement['icon'].toString(),
                style: TextStyle(
                  fontSize: 23,
                  color: unlocked ? null : Colors.white.withOpacity(0.45),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement['title'].toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      unlocked ? Icons.verified_rounded : Icons.lock_rounded,
                      size: 18,
                      color: unlocked ? Colors.greenAccent : Colors.white38,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  achievement['subtitle'].toString(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.58),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      unlocked ? Colors.greenAccent : const Color(0xFF6C63FF),
                    ),
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
