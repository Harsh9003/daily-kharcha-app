import 'package:flutter/material.dart';
import '../services/streak_service.dart';
import 'achievements_dialog.dart';

class StreakFloatingCard extends StatefulWidget {
  final String uid;

  const StreakFloatingCard({
    super.key,
    required this.uid,
  });

  @override
  State<StreakFloatingCard> createState() => _StreakFloatingCardState();
}

class _StreakFloatingCardState extends State<StreakFloatingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  bool _hideBadgeAfterOpen = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 1, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: StreakService.streakStream(widget.uid),
      builder: (context, snapshot) {
        final data = snapshot.data ?? const {};

        final currentStreak = (data['currentStreak'] ?? 0) as int;
        final bestStreak = (data['bestStreak'] ?? 0) as int;
        final transactionCount = (data['transactionCount'] ?? 0) as int;

        final achievements =
            List<String>.from(data['achievements'] ?? const []);
        final seenAchievements =
            List<String>.from(data['seenAchievements'] ?? const []);

        final firestoreUnseenCount = data['unseenAchievementCount'];

        final rawUnseenCount = firestoreUnseenCount is int
            ? firestoreUnseenCount
            : achievements.where((id) => !seenAchievements.contains(id)).length;

        final unseenCount = _hideBadgeAfterOpen ? 0 : rawUnseenCount;
        
        return ScaleTransition(
          scale: currentStreak > 0 ? _scale : const AlwaysStoppedAnimation(1),
          child: GestureDetector(
            onTap: () async {
              setState(() {
                _hideBadgeAfterOpen = true;
              });

              await StreakService.markAchievementsSeen(widget.uid);

              if (!context.mounted) return;

              showDialog(
                context: context,
                barrierColor: Colors.black.withOpacity(0.65),
                builder: (_) => AchievementsDialog(
                  currentStreak: currentStreak,
                  bestStreak: bestStreak,
                  transactionCount: transactionCount,
                  unlockedAchievements: achievements,
                ),
              );
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8A00), Color(0xFFFF3D00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6D00).withOpacity(0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 20)),
                        Text(
                          currentStreak <= 0 ? '0' : currentStreak.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (unseenCount > 0)
                    Positioned(
                      right: -3,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          unseenCount > 9 ? '9+' : unseenCount.toString(),
                          style: const TextStyle(
                            color: Color(0xFF101018),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}