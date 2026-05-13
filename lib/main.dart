import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/pdf_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'services/notification_service.dart';
import 'services/reset_service.dart';
import 'services/recycle_bin_service.dart';
import 'services/streak_service.dart';
import 'widgets/streak_floating_card.dart';
import 'admin/admin_gate.dart';
import 'web/web_dashboard_page.dart';
import 'udhar/pages/udhar_book_page.dart';
import 'utils/app_colors.dart';
import 'reports/reports_page.dart';



GoogleSignIn buildGoogleSignIn() {
  return GoogleSignIn(
    clientId: kIsWeb
        ? "899253420996-4tk9d7b09045eh327krupkjvef5n0ige.apps.googleusercontent.com"
        : null,
    scopes: ['email'],
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.init();

  runApp(DailyKharchaApp());
}

class DailyKharchaApp extends StatefulWidget {
  const DailyKharchaApp({super.key});

  @override
  State<DailyKharchaApp> createState() => _DailyKharchaAppState();
}

class _DailyKharchaAppState extends State<DailyKharchaApp> {
  bool isDark = true;

  void toggleTheme() {
    setState(() {
      isDark = !isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        '/admin': (context) => const AdminGate(),
      },
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: AuthGate(
        isDark: isDark,
        onThemeToggle: toggleTheme,
      ),
    );
  }
}
class AuthGate extends StatelessWidget {
  final bool isDark;
  final VoidCallback onThemeToggle;

  const AuthGate({
    super.key,
    required this.isDark,
    required this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          
          return ResponsiveHomeWrapper(
            isDark: isDark,
            onThemeToggle: onThemeToggle,
          );
        }

        return LoginScreen();
      },
    );
  }
}
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = buildGoogleSignIn();

      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint("❌ User cancelled login");
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;

      if (user != null) {
        await saveUserProfileToFirestore(user);
      }

      debugPrint("✅ Login Success");
    } catch (e) {
      debugPrint("❌ Google Sign-In Error: $e");
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<double>(
      begin: 30,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> saveUserProfileToFirestore(User user) async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    final doc = await userRef.get();

    if (doc.exists) {
      // Existing user hai, role/isBlocked/createdAt ko touch nahi karna
      await userRef.set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      // New user hai tabhi default role user set karna
      await userRef.set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'role': 'user',
        'isBlocked': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Widget _featureTile(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.greenAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F1B),
              Color(0xFF1E1E2C),
              Color(0xFF2C2C54),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: child,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),

                    Center(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.headerStart,
                              AppColors.headerEnd,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.22),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Center(
                      child: Text(
                        "Daily Kharcha",
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Center(
                      child: Text(
                        "Track smarter. Save better. Grow daily.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.25),
                          ),
                        ),
                        child: const Text(
                          "Your expenses. Your control.",
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    _featureTile(
                      Icons.pie_chart_rounded,
                      "Beautiful reports with daily, weekly and monthly insights",
                    ),
                    _featureTile(
                      Icons.cloud_done_rounded,
                      "Secure Firebase sync so your data stays safe across devices",
                    ),
                    _featureTile(
                      Icons.picture_as_pdf_rounded,
                      "Export premium PDF reports and share your progress anytime",
                    ),

                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: () async {
                        await signInWithGoogle();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.login_rounded,
                              color: Colors.black87,
                              size: 22,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Sign in with Google",
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Center(
                      child: Text(
                        "Login once and stay securely signed in.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12.5,
                        ),
                      ),
                    ),

                    const Spacer(),

                    const Center(
                      child: Text(
                        "By continuing, you unlock your personal cloud-synced expense dashboard.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class MainScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onThemeToggle;

  const MainScreen({
    super.key,
    required this.isDark,
    required this.onThemeToggle,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  User? currentUser;
  static int savedCurrentIndex = 0;
  int currentIndex = savedCurrentIndex;
  String? get userId => FirebaseAuth.instance.currentUser?.uid;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _adminNotificationSubscription;
  final Set<String> _shownAdminNotificationIds = <String>{};
  late final DateTime _notificationListenerStartedAt = DateTime.now();

  bool reminderEnabled = false;
  String reminderText = "Aaj ka transaction add karna mat bhoolna";
  TimeOfDay reminderTime = const TimeOfDay(hour: 20, minute: 0);

  List<Map<String, dynamic>> transactions = [];
  List<String> categories = ["Food", "Travel", "Shopping", "Petrol"];

  int touchedPieIndex = -1;
  String selectedPieCategory = "";
  double selectedPieAmount = 0;

  Map<String, Color> categoryColors = {
    "Food": Colors.orange,
    "Travel": Colors.blue,
    "Shopping": Colors.purple,
    "Petrol": Colors.red,
  };

  String viewMode = "Monthly";
  DateTime selectedDate = DateTime.now();
  int selectedMonth = DateTime.now().month;
  String selectedDayType = "Today";
  bool showSearchBar = false;
  String searchQuery = "";
  String selectedModeFilter = "All";
  String selectedCategoryFilter = "All";
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  String reportView = "Monthly";
  bool showPercentage = false;
  String reportChartType = "List";
  int selectedWeekIndex = 0;

  double dailyLimit = 0;
  double monthlyLimit = 0;
  Map<int, double> monthlyLimitsByMonth = {};

  double getMonthlyLimitForSelectedMonth() {
    return monthlyLimitsByMonth[selectedMonth] ?? monthlyLimit;
  }

  bool isInternetAvailable = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  @override
  void initState() {
    super.initState();

    currentUser = FirebaseAuth.instance.currentUser;
    loadData();
    _listenForAdminNotifications();
  }

  @override
  void dispose() {
    _adminNotificationSubscription?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  void _listenForAdminNotifications() {
    final uid = userId;
    if (uid == null) return;

    _adminNotificationSubscription?.cancel();
    _adminNotificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final now = DateTime.now();

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final doc = change.doc;
        if (_shownAdminNotificationIds.contains(doc.id)) continue;

        final data = doc.data();
        if (data == null) continue;

        final targetType = (data['targetType'] ?? 'all').toString();
        final targetUserId = (data['targetUserId'] ?? '').toString();
        final isForThisUser = targetType == 'all' ||
            (targetType == 'single' && targetUserId == uid);
        if (!isForThisUser) continue;

        final scheduledAt = data['scheduledAt'];
        if (scheduledAt is Timestamp && scheduledAt.toDate().isAfter(now)) {
          continue;
        }

        final createdAt = data['createdAt'];
        if (createdAt is Timestamp &&
            createdAt.toDate().isBefore(_notificationListenerStartedAt.subtract(const Duration(seconds: 3)))) {
          _shownAdminNotificationIds.add(doc.id);
          continue;
        }

        final title = (data['title'] ?? 'Daily Kharcha').toString().trim();
        final body = (data['body'] ?? data['message'] ?? 'New admin notification').toString().trim();

        _shownAdminNotificationIds.add(doc.id);
        NotificationService.showAdminNotification(
          id: (doc.id.hashCode & 0x7fffffff).toString(),
          title: title.isEmpty ? 'Daily Kharcha' : title,
          body: body.isEmpty ? 'New admin notification' : body,
        );
      }
    });
  }

  Future<void> _saveTransactionToFirestore(Map<String, dynamic> tx) async {
    if (userId == null) {
      debugPrint("❌ No logged in user");
      return;
    }

    final String id = tx['id'].toString();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(id)
        .set({
      'amount': tx['amount'],
      'category': tx['category'],
      'date': (tx['date'] as DateTime).toIso8601String(),
      'mode': tx['mode'] ?? 'Cash',
      'note': tx['note'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint("🔥 Transaction synced with id: $id");
  }

  Future<bool> hasInternetConnection() async {
    try {
      await FirebaseFirestore.instance
          .collection('internet_check')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 3));

      return true;
    } catch (e) {
      return false;
    }
  }

  void openResetWarningDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// ⚠️ Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 34,
                  ),
                ),

                SizedBox(height: 16),

                /// Title
                Text(
                  "Reset All Data?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                SizedBox(height: 10),

                /// Description
                Text(
                  "All your transactions will be permanently deleted.\nYour categories will reset to default.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),

                SizedBox(height: 18),

                /// Warning box
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.redAccent),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "This action cannot be undone.",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                /// Buttons
                Row(
                  children: [
                    /// Cancel
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 10),

                    /// Delete
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);

                          await resetAllUserData();

                          showPremiumSnackBar(
                            message: "All data reset successfully",
                            icon: Icons.restart_alt_rounded,
                            color: Colors.redAccent,
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.redAccent,
                                Color(0xFFB00020),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              "Delete",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showPremiumSnackBar({
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Color color = const Color(0xFF2ECC71),
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 20,
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                 AppColors.headerStart,
                AppColors.headerEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

    void openReminderDialog() {
    final TextEditingController reminderController =
        TextEditingController(text: reminderText);

    bool localReminderEnabled = reminderEnabled;
    TimeOfDay localReminderTime = reminderTime;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Transaction Reminder",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Enable Reminder",
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Switch(
                          value: localReminderEnabled,
                          onChanged: (val) {
                            setDialogState(() {
                              localReminderEnabled = val;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: reminderController,
                      style: const TextStyle(color: Colors.black),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "Enter custom reminder text",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: localReminderTime,
                        );

                        if (picked != null) {
                          setDialogState(() {
                            localReminderTime = picked;
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Reminder Time: ${localReminderTime.hour.toString().padLeft(2, '0')}:${localReminderTime.minute.toString().padLeft(2, '0')}",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              setState(() {
                                reminderEnabled = localReminderEnabled;
                                reminderText = reminderController.text.trim().isEmpty
                                    ? "Aaj ka transaction add karna mat bhoolna"
                                    : reminderController.text.trim();
                                reminderTime = localReminderTime;
                              });

                              await saveData();

                              if (reminderEnabled) {
                                await NotificationService.scheduleDailyReminder(
                                  hour: reminderTime.hour,
                                  minute: reminderTime.minute,
                                  title: "Daily Kharcha Reminder",
                                  body: reminderText,
                                );
                              } else {
                                await NotificationService.cancelReminder();
                              }

                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    reminderEnabled
                                        ? "Reminder set successfully"
                                        : "Reminder turned off",
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [ AppColors.headerStart,
                                  AppColors.headerEnd,],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  "Save",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> deleteCategoryTransactionsFromFirestore(String category) async {
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .where('category', isEqualTo: category)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<void> updateCategoryNameInFirestore(
    String oldCategory,
    String newCategory,
  ) async {
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .where('category', isEqualTo: oldCategory)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'category': newCategory,
      });
    }

    await batch.commit();
  }

  Future<void> saveUserCategoriesToFirestore() async {
    if (userId == null) return;

    final encodedCategoryColors = categoryColors.map(
      (key, value) => MapEntry(key, value.value),
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set({
      'categories': categories,
      'categoryColors': encodedCategoryColors,
    }, SetOptions(merge: true));
  }

  Future<void> loadUserCategoriesFromFirestore() async {
    if (userId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final data = doc.data();

    if (data != null && data['categories'] != null) {
      final List savedCategories = data['categories'];

      categories = savedCategories.map((e) => e.toString()).toList();

      if (data['categoryColors'] != null) {
        final colorData = Map<String, dynamic>.from(data['categoryColors']);

        categoryColors = colorData.map(
          (key, value) => MapEntry(key, Color(value as int)),
        );
      }

      for (final category in categories) {
        categoryColors.putIfAbsent(category, () => Colors.teal);
      }
    } else {
      await saveUserCategoriesToFirestore();
    }
  }

  Future<void> deleteTransaction(Map<String, dynamic> tx) async {
    final oldTransactions = List<Map<String, dynamic>>.from(transactions);

    setState(() {
      transactions.removeWhere((item) {
        final sameId = item['id'] != null && tx['id'] != null && item['id'] == tx['id'];

        final sameLocalTx =
            item['id'] == null &&
            tx['id'] == null &&
            item['amount'] == tx['amount'] &&
            item['category'] == tx['category'] &&
            (item['date'] as DateTime).isAtSameMomentAs(tx['date'] as DateTime);

        return sameId || sameLocalTx || identical(item, tx);
      });
    });

    try {
      if (userId == null) return;

      await RecycleBinService.moveTransactionToRecycleBin(
        uid: userId!,
        transaction: tx,
      );

      await saveData();

      showPremiumSnackBar(
        message: "Moved to Recycle Bin",
        icon: Icons.recycling_rounded,
        color: Colors.orangeAccent,
      );
    } catch (e) {
      setState(() {
        transactions = oldTransactions;
      });

      showPremiumSnackBar(
        message: "Delete failed. Transaction restored",
        icon: Icons.error_rounded,
        color: Colors.redAccent,
      );

      debugPrint("❌ Recycle Bin Delete Error: $e");
    }
  }
  
  Future<void> signOutUser() async {
    try {
      final GoogleSignIn googleSignIn = buildGoogleSignIn();

      await googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();

      debugPrint("✅ User signed out");
    } catch (e) {
      debugPrint("❌ SignOut Error: $e");
    }
  }

  Widget _exportActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF40407A).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: const Color(0xFF2C2C54),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.black45,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> openRecycleBinDialog() async {
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                constraints: const BoxConstraints(maxHeight: 560),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [
                       AppColors.headerStart,
                       AppColors.headerEnd,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.recycling_rounded,
                          color: Colors.greenAccent,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Recycle Bin",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      "Deleted transactions 5 days tak yaha rahengi. Uske baad permanent delete ho jayengi.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: RecycleBinService.getRecycleBinItems(uid: userId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.greenAccent,
                              ),
                            );
                          }

                          final items = snapshot.data ?? [];

                          if (items.isEmpty) {
                            return const Center(
                              child: Text(
                                "Recycle Bin empty hai",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final DateTime txDate = item['date'] as DateTime;

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['category'].toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          "₹ ${(item['amount'] as double).toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      "${txDate.day}/${txDate.month}/${txDate.year}  ${txDate.hour}:${txDate.minute.toString().padLeft(2, '0')}",
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),

                                    if ((item['note'] ?? '').toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item['note'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 12),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () async {
                                              final restoredTx =
                                                  await RecycleBinService.restoreTransaction(
                                                uid: userId!,
                                                recycleItem: item,
                                              );

                                              setState(() {
                                                transactions.add(restoredTx);
                                                transactions.sort(
                                                  (a, b) => (b['date'] as DateTime)
                                                      .compareTo(a['date'] as DateTime),
                                                );
                                              });

                                              await saveData();

                                              setDialogState(() {});

                                              showPremiumSnackBar(
                                                message: "Transaction restored",
                                                icon: Icons.restore_rounded,
                                                color: Colors.greenAccent,
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.greenAccent.withOpacity(0.18),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                "Restore",
                                                style: TextStyle(
                                                  color: Colors.greenAccent,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 10),

                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () async {
                                              await RecycleBinService.permanentDelete(
                                                uid: userId!,
                                                binId: item['binId'].toString(),
                                              );

                                              setDialogState(() {});

                                              showPremiumSnackBar(
                                                message: "Permanently deleted",
                                                icon: Icons.delete_forever_rounded,
                                                color: Colors.redAccent,
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent.withOpacity(0.18),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                "Delete",
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // export dialog
  Future<void> openExportReportDialog() async {
    final reportList = getCurrentReportList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Export Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$reportView Report',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 18),
              _exportActionTile(
                icon: Icons.picture_as_pdf_rounded,
                title: 'Export PDF',
                subtitle: 'Open print / save PDF dialog',
                onTap: () async {
                  Navigator.pop(context);
                  await PdfService.exportPdf(
                    reportList: reportList,
                    reportView: reportView,
                    selectedDate: selectedDate,
                    selectedMonth: selectedMonth,
                    dailyLimit: dailyLimit,
                    monthlyLimit: monthlyLimit,
                    userName: "Daily Kharcha User",
                    // developerName: "Harshender Singh",
                  );
                },
              ),
              const SizedBox(height: 10),
              _exportActionTile(
                icon: Icons.share_rounded,
                title: 'Share Report',
                subtitle: 'Share the PDF report instantly',
                onTap: () async {
                  Navigator.pop(context);
                  await PdfService.sharePdf(
                    reportList: reportList,
                    reportView: reportView,
                    selectedDate: selectedDate,
                    selectedMonth: selectedMonth,
                    dailyLimit: dailyLimit,
                    monthlyLimit: monthlyLimit,
                    userName: currentUser?.displayName ?? "Daily Kharcha User",
                    // developerName: "Harshender Singh",
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> resetAllUserData() async {
    await ResetService.deleteAllUserTransactions();
    if (userId != null) {
      await RecycleBinService.deleteAllRecycleBinItems(uid: userId!);
    }

    setState(() {
      transactions.clear();

      categories = ["Food", "Travel", "Shopping", "Petrol"];

      categoryColors = {
        "Food": Colors.orange,
        "Travel": Colors.blue,
        "Shopping": Colors.purple,
        "Petrol": Colors.red,
      };

      dailyLimit = 0;
      monthlyLimit = 0;
      monthlyLimitsByMonth.clear();
      selectedWeekIndex = 0;
      showPercentage = false;
      reportChartType = "List";
      reportView = "Monthly";
    });

    await saveData();
  }

  Future<void> _loadTransactionsFromFirestore() async {
    try {
      if (userId == null) {
        transactions = [];
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .get();

      transactions = snapshot.docs.map((doc) {
        final data = doc.data();
        final rawDate = data['date'];

        DateTime txDate;

        if (rawDate is Timestamp) {
          txDate = rawDate.toDate();
        } else {
          txDate = DateTime.parse(rawDate.toString());
        }

        return {
          'id': doc.id,
          'amount': (data['amount'] as num).toDouble(),
          'category': data['category'] ?? 'Other',
          'date': txDate,
          'mode': data['mode'] ?? 'Cash',
          'note': data['note'] ?? '',
        };
      }).toList();

      transactions.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );

      debugPrint("✅ Loaded ${transactions.length} tx for user: $userId");
    } catch (e) {
      debugPrint("❌ Load Error: $e");
    }
  }

  Future<void> clearLocalUserData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('transactions');
    await prefs.remove('categories');
    await prefs.remove('categoryColors');
    await prefs.remove('viewMode');
    await prefs.remove('selectedMonth');
    await prefs.remove('selectedDayType');
    await prefs.remove('dailyLimit');
    await prefs.remove('monthlyLimit');
    await prefs.remove('monthlyLimitsByMonth');
    await prefs.remove('reportView');
    await prefs.remove('reportChartType');
    await prefs.remove('selectedDate');
    await prefs.remove('selectedWeekIndex');
    await prefs.remove('showPercentage');

    setState(() {
      transactions = [];
      categories = ["Food", "Travel", "Shopping", "Petrol"];
      categoryColors = {
        "Food": Colors.orange,
        "Travel": Colors.blue,
        "Shopping": Colors.purple,
        "Petrol": Colors.red,
      };
      viewMode = "Monthly";
      selectedDate = DateTime.now();
      selectedMonth = DateTime.now().month;
      selectedDayType = "Today";
      reportView = "Monthly";
      showPercentage = false;
      reportChartType = "List";
      selectedWeekIndex = 0;
      dailyLimit = 0;
      monthlyLimit = 0;
      monthlyLimitsByMonth.clear();
    });
  }

  Future<void> saveData() async {
      final prefs = await SharedPreferences.getInstance();

      final encodedTransactions = transactions.map((tx) {
        return {
          'amount': tx['amount'],
          'category': tx['category'],
          'date': (tx['date'] as DateTime).toIso8601String(),
          'mode': tx['mode'],
          'note': tx['note'] ?? '',
        };
      }).toList();

      final encodedCategoryColors = categoryColors.map(
        (key, value) => MapEntry(key, value.value),
      );

      await prefs.setString('transactions', jsonEncode(encodedTransactions));
      await prefs.setStringList('categories', categories);
      await prefs.setString('viewMode', viewMode);
      await prefs.setInt('selectedMonth', selectedMonth);
      await prefs.setString('selectedDayType', selectedDayType);
      await prefs.setDouble('dailyLimit', dailyLimit);
      await prefs.setDouble('monthlyLimit', monthlyLimit);
      await prefs.setString(
        'monthlyLimitsByMonth',
        jsonEncode(monthlyLimitsByMonth.map((key, value) => MapEntry(key.toString(), value))),
      );
      await prefs.setString('reportView', reportView);
      await prefs.setString('reportChartType', reportChartType);
      await prefs.setString('selectedDate', selectedDate.toIso8601String());
      await prefs.setInt('selectedWeekIndex', selectedWeekIndex);
      await prefs.setBool('showPercentage', showPercentage);
      await prefs.setString('categoryColors', jsonEncode(encodedCategoryColors));
      await prefs.setBool('reminderEnabled', reminderEnabled);
      await prefs.setString('reminderText', reminderText);
      await prefs.setInt('reminderHour', reminderTime.hour);
      await prefs.setInt('reminderMinute', reminderTime.minute);
    }

    Future<void> loadData() async {
      transactions = [];

      final prefs = await SharedPreferences.getInstance();
      reminderEnabled = prefs.getBool('reminderEnabled') ?? false;
      reminderText = prefs.getString('reminderText') ??
          "Aaj ka transaction add karna mat bhoolna";

      final reminderHour = prefs.getInt('reminderHour') ?? 20;
      final reminderMinute = prefs.getInt('reminderMinute') ?? 0;
      reminderTime = TimeOfDay(hour: reminderHour, minute: reminderMinute);

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) {
        setState(() {});
        return;
      }

      final txString = prefs.getString('transactions');
      if (txString != null) {
        final decoded = jsonDecode(txString) as List;
        transactions = decoded.map((item) {
          return {
            'amount': (item['amount'] as num).toDouble(),
            'category': item['category'],
            'date': DateTime.parse(item['date']),
            'mode': item['mode'] ?? "Cash",
            'note': item['note'] ?? '',
          };
        }).toList();
      }

    final savedCategories = prefs.getStringList('categories');
    if (savedCategories != null && savedCategories.isNotEmpty) {
      categories = savedCategories;
    }

    final savedCategoryColors = prefs.getString('categoryColors');
    if (savedCategoryColors != null && savedCategoryColors.isNotEmpty) {
      final decoded = jsonDecode(savedCategoryColors) as Map<String, dynamic>;
      categoryColors = decoded.map(
        (key, value) => MapEntry(key, Color(value as int)),
      );
    } else {
      categoryColors = {
        "Food": Colors.orange,
        "Travel": Colors.blue,
        "Shopping": Colors.purple,
        "Petrol": Colors.red,
      };
    }

    viewMode = prefs.getString('viewMode') ?? viewMode;
    selectedMonth = prefs.getInt('selectedMonth') ?? selectedMonth;
    selectedDayType = prefs.getString('selectedDayType') ?? selectedDayType;
    dailyLimit = prefs.getDouble('dailyLimit') ?? dailyLimit;
    monthlyLimit = prefs.getDouble('monthlyLimit') ?? monthlyLimit;
    final savedMonthlyLimitsByMonth = prefs.getString('monthlyLimitsByMonth');
    if (savedMonthlyLimitsByMonth != null && savedMonthlyLimitsByMonth.isNotEmpty) {
      final decodedMonthlyLimits = jsonDecode(savedMonthlyLimitsByMonth) as Map<String, dynamic>;
      monthlyLimitsByMonth = decodedMonthlyLimits.map(
        (key, value) => MapEntry(int.parse(key), (value as num).toDouble()),
      );
    }
    reportView = prefs.getString('reportView') ?? reportView;
    reportChartType = prefs.getString('reportChartType') ?? reportChartType;
    selectedWeekIndex = prefs.getInt('selectedWeekIndex') ?? selectedWeekIndex;
    showPercentage = prefs.getBool('showPercentage') ?? showPercentage;

    final savedDate = prefs.getString('selectedDate');
    if (savedDate != null) {
      selectedDate = DateTime.parse(savedDate);
    }

    for (final category in categories) {
      categoryColors.putIfAbsent(category, () => Colors.teal);
    }
    try {
      await loadUserCategoriesFromFirestore();
    } catch (e) {
      debugPrint('Category Firestore load failed: $e');
    }

    try {
      await _loadTransactionsFromFirestore();
    } catch (e) {
      debugPrint('Firestore load failed: $e');
    }

    final uid = userId;
    if (uid != null) {
      StreakService.syncUserStreakFromTransactions(uid).catchError((e) {
        debugPrint("🔥 Streak sync failed: $e");
      });
    }

    setState(() {});
  }

  Future<void> addTransaction(double amount, String category, String note) async {
    final now = DateTime.now();

    final DateTime finalDate = viewMode == "Daily"
        ? DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            now.hour,
            now.minute,
          )
        : DateTime(
            now.year,
            selectedMonth,
            now.day,
            now.hour,
            now.minute,
          );

    final String txId = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc()
        .id;

    final newTx = {
      'amount': amount,
      'category': category,
      'date': finalDate,
      'mode': "Cash",
      'note': note.trim(),
      'id': txId,
    };

    setState(() {
      transactions.add(newTx);
      categoryColors.putIfAbsent(category, () => Colors.teal);
    });

    await saveData();

    _saveTransactionAndUpdateStreak(newTx);
  }

  Future<void> _saveTransactionAndUpdateStreak(Map<String, dynamic> tx) async {
    final uid = userId;
    if (uid == null) {
      debugPrint("❌ Streak skipped: no logged in user");
      return;
    }

    try {
      await _saveTransactionToFirestore(tx);
      await StreakService.updateStreakAfterTransaction(uid);
      debugPrint("✅ Streak updated for user: $uid");
    } catch (e) {
      debugPrint("🔥 Transaction/streak sync failed: $e");

      // Fallback: jab internet wapas aaye/loadData chale, existing transactions se streak rebuild ho jayega.
      StreakService.syncUserStreakFromTransactions(uid).catchError((syncError) {
        debugPrint("🔥 Streak fallback sync failed: $syncError");
      });
    }
  }

  double get total {
    if (viewMode == "Monthly") {
      return transactions
          .where((t) => t['date'].month == selectedMonth)
          .fold(0.0, (s, i) => s + (i['amount'] as double));
    } else {
      return transactions
          .where((t) =>
              t['date'].day == selectedDate.day &&
              t['date'].month == selectedDate.month &&
              t['date'].year == selectedDate.year)
          .fold(0.0, (s, i) => s + (i['amount'] as double));
    }
  }

  double get currentLimit => viewMode == "Daily" ? dailyLimit : getMonthlyLimitForSelectedMonth();
  double get remaining => currentLimit == 0 ? 0 : currentLimit - total;

  Color get limitColor {
    if (currentLimit == 0) {
      return const Color.fromARGB(255, 247, 246, 246);
    }
    if (total > currentLimit) return Colors.red;
    if (total > currentLimit * 0.8) return Colors.orange;
    return const Color.fromARGB(255, 210, 213, 212);
  }

  List<Map<String, dynamic>> get filtered {
    List<Map<String, dynamic>> list;

    if (viewMode == "Monthly") {
      list = transactions
          .where((t) => t['date'].month == selectedMonth)
          .toList();
    } else {
      list = transactions
          .where((t) =>
              t['date'].day == selectedDate.day &&
              t['date'].month == selectedDate.month &&
              t['date'].year == selectedDate.year)
          .toList();
    }

    if (selectedModeFilter != "All") {
      list = list.where((t) => (t['mode'] ?? "Cash") == selectedModeFilter).toList();
    }

    if (selectedCategoryFilter != "All") {
      list = list.where((t) => t['category'] == selectedCategoryFilter).toList();
    }

    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();

      list = list.where((t) {
        final category = t['category'].toString().toLowerCase();
        final note = (t['note'] ?? '').toString().toLowerCase();
        final mode = (t['mode'] ?? '').toString().toLowerCase();
        final amount = t['amount'].toString();

        return category.contains(q) ||
            note.contains(q) ||
            mode.contains(q) ||
            amount.contains(q);
      }).toList();
    }

    list.sort((a, b) =>
        (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return list;
  }

  void deleteTx(Map<String, dynamic> tx) {
    setState(() async {
      await deleteTransaction(tx);
    });
    saveData();
  }

  String _weekdayShort(DateTime date) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return days[date.weekday - 1];
  }

  String _monthShort(DateTime date) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[date.month - 1];
  }

  String _formatWeekRange(DateTime start, DateTime end) {
    return "${_weekdayShort(start)} ${start.day} ${_monthShort(start)} - ${_weekdayShort(end)} ${end.day} ${_monthShort(end)}";
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  List<Map<String, DateTime>> getWeeksForMonth(int year, int month) {
    List<Map<String, DateTime>> weeks = [];

    DateTime start = DateTime(year, month, 1);
    DateTime monthEnd = DateTime(year, month + 1, 0);

    while (!start.isAfter(monthEnd)) {
      DateTime end = start.add(Duration(days: 6));
      if (end.isAfter(monthEnd)) {
        end = monthEnd;
      }

      weeks.add({
        "start": start,
        "end": end,
      });

      start = end.add(Duration(days: 1));
    }

    return weeks;
  }

  List<Map<String, dynamic>> getCurrentReportList() {
    if (reportView == "Monthly") {
      return transactions.where((t) {
        return t['date'].month == selectedMonth;
      }).toList();
    } else if (reportView == "Daily") {
      return transactions.where((t) {
        return t['date'].day == selectedDate.day &&
            t['date'].month == selectedDate.month &&
            t['date'].year == selectedDate.year;
      }).toList();
    } else {
      final weeks = getWeeksForMonth(DateTime.now().year, selectedMonth);
      if (weeks.isEmpty) return [];

      if (selectedWeekIndex >= weeks.length) {
        selectedWeekIndex = 0;
      }

      final selectedWeek = weeks[selectedWeekIndex];
      final start = selectedWeek['start']!;
      final end = selectedWeek['end']!;

      return transactions.where((t) {
        final d = t['date'] as DateTime;
        final onlyDate = DateTime(d.year, d.month, d.day);
        return (onlyDate.isAtSameMomentAs(DateTime(start.year, start.month, start.day)) ||
                onlyDate.isAfter(DateTime(start.year, start.month, start.day))) &&
            (onlyDate.isAtSameMomentAs(DateTime(end.year, end.month, end.day)) ||
                onlyDate.isBefore(DateTime(end.year, end.month, end.day)));
      }).toList();
    }
  }

  Color _getColor(dynamic category) {
    final String safeCategory = (category ?? '').toString().trim();

    if (safeCategory.isEmpty) {
      return Colors.teal;
    }

    return categoryColors[safeCategory] ?? Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: currentIndex == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (userId != null) ...[
                  StreakFloatingCard(uid: userId!),
                  const SizedBox(height: 10),
                ],
                FloatingActionButton(
                  heroTag: "limit",
                  backgroundColor: Colors.orange,
                  onPressed: () => openLimitDialog(context),
                  child: Icon(Icons.track_changes),
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "add",
                  onPressed: () => openAddDialog(context),
                  child: Icon(Icons.add),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: currentIndex == 0
            ? buildHome()
            : currentIndex == 1
                ? UdharBookPage(isDark: widget.isDark)
                : currentIndex == 2
                    ? buildReport()
                    : buildProfile(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.bottomBar,
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.white70,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: (i) {
          setState(() {
            currentIndex = i;
            savedCurrentIndex = i;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: "Udhar Book"),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: "Reports"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }


  Future<void> _refreshHomeData() async {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;

    try {
      await loadUserCategoriesFromFirestore();
    } catch (e) {
      debugPrint('Category refresh failed: $e');
    }

    try {
      await _loadTransactionsFromFirestore();
    } catch (e) {
      debugPrint('Transaction refresh failed: $e');
    }

    if (uid != null) {
      try {
        await StreakService.syncUserStreakFromTransactions(uid);
      } catch (e) {
        debugPrint('Streak refresh failed: $e');
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Widget buildHome() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (showSearchBar) {
          setState(() {
            showSearchBar = false;
            searchQuery = "";
            searchController.clear();
          });
          FocusScope.of(context).unfocus();
        }
      },
      child: Container(
        color: widget.isDark ? AppColors.darkBg : const Color(0xFFF6F7FB),
        child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.headerStart,
                  AppColors.headerEnd,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Daily Kharcha",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    GestureDetector(
                      onTap: () {
                        if (showSearchBar) {
                          setState(() {
                            showSearchBar = false;
                            searchQuery = "";
                            searchController.clear();
                          });
                          searchFocusNode.unfocus();
                        } else {
                          setState(() {
                            showSearchBar = true;
                          });

                          // Single tap par search box open hote hi keyboard bhi open ho.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && showSearchBar) {
                              searchFocusNode.requestFocus();
                            }
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        width: showSearchBar ? 138 : 44,
                        height: 42,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        
                        clipBehavior: Clip.hardEdge,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            if (showSearchBar)
                              Positioned(
                                left: 27,
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: TextField(
                                  controller: searchController,
                                  focusNode: searchFocusNode,
                                  autofocus: true,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  cursorColor: Colors.white,
                                  decoration: InputDecoration(
                                    hintText: "Search",
                                    hintStyle: TextStyle(color: Colors.white54),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.only(top: 11),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      searchQuery = value;
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(width: 8),

                    _notificationBellButton(),

                    SizedBox(width: 8),

                    _topIconButton(
                      icon: Icons.tune_rounded,
                      onTap: openFilterSheet,
                    ),
                  ],
                ),

                SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  viewMode == "Monthly"
                                      ? "Monthly Expense"
                                      : "Today's Expense",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _homeModeChip("Monthly", viewMode == "Monthly", () {
                                      setState(() => viewMode = "Monthly");
                                      saveData();
                                    }),
                                    const SizedBox(width: 8),
                                    _homeModeChip("Daily", viewMode == "Daily", () {
                                      setState(() => viewMode = "Daily");
                                      saveData();
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [

                              Expanded(
                                child: SizedBox(
                                  height: 34,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      currentLimit == 0
                                          ? "₹ ${total.toStringAsFixed(0)}"
                                          : "₹ ${total.toStringAsFixed(0)} / ₹ ${currentLimit.toStringAsFixed(0)}",
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: limitColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              if (currentLimit != 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 18),
                                  child: total > currentLimit
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFB00020).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFB00020).withOpacity(0.4),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.warning_amber_rounded,
                                                color: Color(0xFFB00020),
                                                size: 14,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                "Limit Crossed",
                                                style: TextStyle(
                                                  color: Color(0xFFB00020),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            "Remaining: ₹ ${remaining.toStringAsFixed(0)}",
                                            maxLines: 1,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  ],
                ),

                SizedBox(height: 10),

                if (viewMode == "Daily")
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _dailyItem("Custom", "Custom", () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDate = picked;
                              selectedDayType = "Custom";
                            });
                            saveData();
                          }
                        }),
                        _dailyItem("Yesterday", "Yesterday", () {
                          setState(() {
                            selectedDate =
                                DateTime.now().subtract(Duration(days: 1));
                            selectedDayType = "Yesterday";
                          });
                          saveData();
                        }),
                        _dailyItem("Today", "Today", () {
                          setState(() {
                            selectedDate = DateTime.now();
                            selectedDayType = "Today";
                          });
                          saveData();
                        }),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 12,
                      itemBuilder: (_, i) {
                        bool sel = selectedMonth == i + 1;
                        return GestureDetector(
                          onTap: () {
                            setState(() => selectedMonth = i + 1);
                            saveData();
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 5),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: sel ? Colors.white : Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              [
                                "Jan",
                                "Feb",
                                "Mar",
                                "Apr",
                                "May",
                                "Jun",
                                "Jul",
                                "Aug",
                                "Sep",
                                "Oct",
                                "Nov",
                                "Dec"
                              ][i],
                              style: TextStyle(
                                color: sel ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshHomeData,
              child: filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 190, top: 90),
                      children: [
                        Center(
                          child: Text(
                            "No transactions found",
                            style: TextStyle(color: widget.isDark ? Colors.white54 : Colors.black45),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 190),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        var tx = filtered[i];

                        return Dismissible(
                  key: ValueKey(
                    tx['id'] ?? '${tx['category']}_${(tx['date'] as DateTime).millisecondsSinceEpoch}_${tx['amount']}',
                  ),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.delete, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          "Delete",
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  onDismissed: (_) {
                    deleteTransaction(tx);
                  },
                  child: ListTile(
                    onTap: () => openTransactionDetail(tx),
                    title: Text(
                      tx['category'],
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white : const Color(0xFF171727),
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          "${tx['date'].day}/${tx['date'].month} | ${tx['date'].hour}:${tx['date'].minute.toString().padLeft(2, '0')}",
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.isDark
                                ? Colors.white.withOpacity(0.55)
                                : const Color(0xFF171727).withOpacity(0.52),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if ((tx['note'] ?? '').toString().trim().isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              (tx['note'] ?? '').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.isDark
                                    ? Colors.white.withOpacity(0.38)
                                    : const Color(0xFF2C2C54).withOpacity(0.52),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Text(
                      "₹ ${tx['amount'].toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark
                            ? Colors.greenAccent
                            : const Color(0xFF4B3F8F),
                      ),
                    ),
                  ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget buildReport() {
    return ReportsPage(
      reportList: getCurrentReportList(),
      reportView: reportView,
      selectedMonth: selectedMonth,
      selectedWeekIndex: selectedWeekIndex,
      selectedDate: selectedDate,
      showPercentage: showPercentage,
      onReportViewChanged: (value) {
        setState(() {
          reportView = value;
          selectedWeekIndex = 0;
        });
        saveData();
      },
      onMonthChanged: (month) {
        setState(() {
          selectedMonth = month;
        });
        saveData();
      },
      onWeekChanged: (weekIndex) {
        setState(() {
          selectedWeekIndex = weekIndex;
        });
        saveData();
      },
      onDateChanged: (date) {
        setState(() {
          selectedDate = date;
          selectedDayType = "Custom";
        });
        saveData();
      },
      onTogglePercentage: () {
        setState(() {
          showPercentage = !showPercentage;
        });
      },
      onSmartInsightsTap: openSmartInsightsDialog,
      onExportTap: openExportReportDialog,
      onCategoryTap: openCategoryTransactionsDialog,
    );
  }

  Widget buildProfile() {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double totalExpense = transactions.fold(
      0.0,
      (sum, tx) => sum + (tx['amount'] as double),
    );
    final int totalTransactions = transactions.length;

    return Container(
      color: isDark ? AppColors.darkBg : const Color(0xFFF6F7FB),
      child: SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.headerStart,
                  AppColors.headerEnd,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white12,
                    border: Border.all(
                      color: Colors.white24,
                      width: 1.2,
                    ),
                  ),
                  child: ClipOval(
                   child: user != null &&
                      user.photoURL != null &&
                      user.photoURL!.isNotEmpty
                  ? Image.network(
                      user.photoURL!,
                      fit: BoxFit.cover,
                      width: 68,
                      height: 68,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            (user.displayName?.isNotEmpty ?? false)
                                ? user.displayName![0].toUpperCase()
                                : "U",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        (user?.displayName?.isNotEmpty ?? false)
                            ? user!.displayName![0].toUpperCase()
                            : "U",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  user?.displayName ?? "Daily Kharcha User",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  user?.email ?? "Track your expenses smartly",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          GestureDetector(
            onTap: () async {
              await signOutUser();
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.headerStart,
                    AppColors.headerEnd,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  "Logout",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 18),
          Text(
            "Settings",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF171727)),
          ),
          SizedBox(height: 10),
          _profileTile(
            icon: Icons.today_rounded,
            title: "Daily Limit",
            value: dailyLimit == 0 ? "Not set" : "₹ ${dailyLimit.toStringAsFixed(0)}",
            onTap: () {
              setState(() {
                viewMode = "Daily";
                selectedDate = DateTime.now();
              });
              openLimitDialog(context);
            },
          ),
          SizedBox(height: 10),
          _profileTile(
            icon: Icons.calendar_month_rounded,
            title: "Monthly Limit",
            value: monthlyLimit == 0 ? "Not set" : "₹ ${monthlyLimit.toStringAsFixed(0)}",
            onTap: () {
              setState(() {
                viewMode = "Monthly";
              });
              openLimitDialog(context);
            },
          ),
          SizedBox(height: 10),
          _profileTile(
            icon: Icons.notifications_active_rounded,
            title: "Transaction Reminder",
            value: reminderEnabled
                ? "${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}"
                : "Off",
            onTap: () => openReminderDialog(),
          ),
          SizedBox(height: 10),
          _premiumDarkModeTile(),
          SizedBox(height: 18),
          Text(
            "Data",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF171727)),
          ),
          SizedBox(height: 10),
          _profileTile(
            icon: Icons.account_balance_wallet_rounded,
            title: "Total Expense",
            value: "₹ ${totalExpense.toStringAsFixed(0)}",
          ),
          SizedBox(height: 10),
          _profileTile(
            icon: Icons.receipt_long_rounded,
            title: "Total Transactions",
            value: "$totalTransactions",
          ),
          SizedBox(height: 10),
          _profileTile(
            icon: Icons.recycling_rounded,
            title: "Recycle Bin",
            value: "Restore",
            onTap: () => openRecycleBinDialog(),
          ),
          SizedBox(height: 10),
          _profileTile(
            icon: Icons.category_rounded,
            title: "Total Categories",
            value: "${categories.length}",
            onTap: () {
              showPremiumSnackBar(
                message: "Category manager opened",
                icon: Icons.category_rounded,
                color: Colors.amberAccent,
              );

              openCategoryManagerDialog();
            },
          ),
          SizedBox(height: 18),
          _profileTile(
            icon: Icons.delete_forever_rounded,
            title: "Reset All Data",
            value: "Permanent",
            onTap: () => openResetWarningDialog(),
          ),
          SizedBox(height: 18),
          Text(
            "About",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF171727)),
          ),
          SizedBox(height: 10),
          _profileTile(
            icon: Icons.apps_rounded,
            title: "App Name",
            value: "Daily Kharcha",
          ),
          // SizedBox(height: 10),
          // _profileTile(
          //   icon: Icons.code_rounded,
          //   title: "Developer",
          //   value: "Harshender Singh",
          // ),
          SizedBox(height: 10),
          _profileTile(
            icon: Icons.info_outline_rounded,
            title: "Version",
            value: "1.2.0",
          ),
        ],
      ),
      ),
    );
  }

  void openCategoryManagerDialog() {
    final TextEditingController categoryController = TextEditingController();

    String? dialogMessage;
    IconData dialogIcon = Icons.check_circle_rounded;
    Color dialogColor = Colors.greenAccent;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void showParentMessage(String message, IconData icon, Color color) {
              setDialogState(() {
                dialogMessage = message;
                dialogIcon = icon;
                dialogColor = color;
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Manage Categories",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Total Categories: ${categories.length}",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),

                    if (dialogMessage != null) ...[
                      SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF1E1E2C),
                              Color(0xFF2C2C54),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: dialogColor.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(dialogIcon, color: dialogColor, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                dialogMessage!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: categoryController,
                            style: TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: "Add new category",
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            final newCategory = categoryController.text.trim();

                            if (newCategory.isEmpty) {
                              showParentMessage(
                                "Category name enter karo",
                                Icons.info_rounded,
                                Colors.orangeAccent,
                              );
                              return;
                            }

                            if (categories.contains(newCategory)) {
                              showParentMessage(
                                "$newCategory already exists",
                                Icons.warning_rounded,
                                Colors.orangeAccent,
                              );
                              return;
                            }

                            setState(() {
                              categories.add(newCategory);
                              categoryColors[newCategory] = Colors.teal;
                            });

                            await saveData();
                            await saveUserCategoriesToFirestore();
                            categoryController.clear();
                            setDialogState(() {});

                            showParentMessage(
                              "$newCategory category added",
                              Icons.category_rounded,
                              Colors.amberAccent,
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF2C2C54),
                                  Color(0xFF40407A),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "Add",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 18),

                    Expanded(
                      child: ListView.separated(
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final currentColor =
                              categoryColors[category] ?? Colors.teal;
                          final count = transactions
                              .where((tx) => tx['category'] == category)
                              .length;

                          return GestureDetector(
                            onTap: () => openCategoryEditDialog(
                              category,
                              setDialogState,
                              showParentMessage,
                            ),
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: currentColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category,
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          "$count transaction${count == 1 ? '' : 's'}",
                                          style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.black45,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    SizedBox(height: 14),

                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF2C2C54),
                              Color(0xFF40407A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            "Done",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  void openCategoryEditDialog(
    String oldCategory,
    void Function(void Function()) refreshParent,
    void Function(String message, IconData icon, Color color) showParentMessage,
  ) {
    final TextEditingController renameController =
        TextEditingController(text: oldCategory);

    final List<Color> presetColors = [
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.red,
      Colors.green,
      Colors.teal,
      Colors.pink,
      Colors.brown,
      Colors.indigo,
      Colors.cyan,
    ];

    Color selectedColor = categoryColors[oldCategory] ?? Colors.teal;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Edit Category",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 14),

                    TextField(
                      controller: renameController,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: "Category Name",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    SizedBox(height: 14),

                    Text(
                      "Choose Color",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presetColors.map((color) {
                        final isSelected = selectedColor.value == color.value;

                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final newName = renameController.text.trim();

                              if (newName.isEmpty) {
                                showParentMessage(
                                  "Category name enter karo",
                                  Icons.info_rounded,
                                  Colors.orangeAccent,
                                );
                                return;
                              }

                              if (newName != oldCategory &&
                                  categories.contains(newName)) {
                                showParentMessage(
                                  "$newName already exists",
                                  Icons.warning_rounded,
                                  Colors.orangeAccent,
                                );
                                return;
                              }

                              setState(() {
                                final categoryIndex =
                                    categories.indexOf(oldCategory);

                                if (categoryIndex != -1) {
                                  categories[categoryIndex] = newName;
                                }

                                categoryColors.remove(oldCategory);
                                categoryColors[newName] = selectedColor;

                                for (var tx in transactions) {
                                  if (tx['category'] == oldCategory) {
                                    tx['category'] = newName;
                                  }
                                }
                              });

                              await updateCategoryNameInFirestore(
                                oldCategory,
                                newName,
                              );

                              await saveData();
                              await saveUserCategoriesToFirestore();
                              
                              Navigator.pop(context);

                              showParentMessage(
                                "Category renamed to $newName",
                                Icons.drive_file_rename_outline_rounded,
                                Colors.lightBlueAccent,
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF2C2C54),
                                    Color(0xFF40407A),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  "Save",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 10),

                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);

                              Future.delayed(Duration(milliseconds: 150), () {
                                openDeleteCategoryDecisionDialog(
                                  oldCategory,
                                  refreshParent,
                                  showParentMessage,
                                );
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Center(
                                child: Text(
                                  "Delete",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void openDeleteCategoryDecisionDialog(
    String category,
    void Function(void Function()) refreshParent,
    void Function(String message, IconData icon, Color color) showParentMessage,
  ) {
    final relatedTransactions =
        transactions.where((tx) => tx['category'] == category).toList();

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Delete Category Warning",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  relatedTransactions.isEmpty
                      ? "No transactions are linked with this category."
                      : "${relatedTransactions.length} transaction${relatedTransactions.length == 1 ? '' : 's'} are linked with this category.",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),

                SizedBox(height: 14),

                if (relatedTransactions.isNotEmpty)
                  Expanded(
                    child: ListView.separated(
                      itemCount: relatedTransactions.length,
                      separatorBuilder: (_, _) => SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final tx = relatedTransactions[index];
                        final date = tx['date'] as DateTime;

                        return Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx['category'],
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      "${date.day}/${date.month}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}",
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "₹ ${(tx['amount'] as double).toStringAsFixed(0)}",
                                style: TextStyle(
                                  color: Color(0xFF2C2C54),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                if (relatedTransactions.isEmpty) SizedBox(height: 8),

                SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 10),

                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await deleteCategoryTransactionsFromFirestore(category);

                          setState(() {
                            categories.remove(category);
                            categoryColors.remove(category);
                            transactions.removeWhere(
                              (tx) => tx['category'] == category,
                            );
                          });

                          await saveData();
                          await saveUserCategoriesToFirestore();

                          Navigator.pop(context);

                          Future.delayed(const Duration(milliseconds: 200), () {
                            showParentMessage(
                              "$category deleted successfully",
                              Icons.delete_rounded,
                              Colors.redAccent,
                            );
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Center(
                            child: Text(
                              "Delete",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileToggleTile({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? Colors.white : Colors.black),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          )
        ],
      ),
    );
  }

  Widget _premiumDarkModeTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        widget.onThemeToggle();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        margin: EdgeInsets.only(bottom: 2),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.headerStart,AppColors.headerEnd,]
                : [Colors.white, Colors.grey.shade100],
          ),
        ),
        child: Row(
          children: [
            Icon(
              isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              color: isDark ? Colors.amberAccent : Colors.orange,
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                isDark ? "Night Mode" : "Light Mode",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              width: 56,
              height: 30,
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: isDark ? Color(0xFF111633) : Colors.grey.shade300,
              ),
              child: AnimatedAlign(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Color(0xFFB388FF) : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void openTransactionDetail(Map<String, dynamic> tx) {
    final TextEditingController amountController = TextEditingController(
      text: ((tx['amount'] as num?) ?? 0).toStringAsFixed(0),
    );
    final TextEditingController noteController = TextEditingController(
      text: (tx['note'] ?? '').toString(),
    );

    String selectedCategory = (tx['category'] ?? 'Food').toString();
    String selectedMode = (tx['mode'] ?? 'Cash').toString();

    Future<void> openPremiumCategorySheet(
      StateSetter dialogSetState,
    ) async {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          final bool isDarkMode = widget.isDark;
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [ AppColors.headerStart,
                              AppColors.headerEnd,],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.category_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Category',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Choose where this expense belongs',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.48,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = categories[index];
                        final bool selected = item == selectedCategory;
                        final Color itemColor = categoryColors[item] ?? Colors.teal;

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            dialogSetState(() => selectedCategory = item);
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF2C2C54).withOpacity(isDarkMode ? 0.55 : 0.10)
                                  : (isDarkMode ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected ? const Color(0xFF2C2C54) : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: itemColor.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.label_rounded,
                                    color: itemColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF2C2C54),
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            final bool isDarkMode = widget.isDark;
            final Color panelColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
            final Color textColor = isDarkMode ? Colors.white : Colors.black87;
            final Color hintColor = isDarkMode ? Colors.white54 : Colors.black45;
            final Color fieldColor = isDarkMode ? Colors.white.withOpacity(0.07) : Colors.grey.shade100;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Edit Transaction',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: fieldColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.close_rounded, color: hintColor, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Text('Amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hintColor)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          prefixStyle: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w800),
                          hintText: 'Enter amount',
                          hintStyle: TextStyle(color: hintColor),
                          filled: true,
                          fillColor: fieldColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hintColor)),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => openPremiumCategorySheet(dialogSetState),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: fieldColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: (categoryColors[selectedCategory] ?? Colors.teal).withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  Icons.label_rounded,
                                  color: categoryColors[selectedCategory] ?? Colors.teal,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedCategory,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded, color: hintColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('Payment Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hintColor)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _modeChip(
                            title: 'Cash',
                            selected: selectedMode == 'Cash',
                            onTap: () => dialogSetState(() => selectedMode = 'Cash'),
                          ),
                          const SizedBox(width: 8),
                          _modeChip(
                            title: 'UPI',
                            selected: selectedMode == 'UPI',
                            onTap: () => dialogSetState(() => selectedMode = 'UPI'),
                          ),
                          const SizedBox(width: 8),
                          _modeChip(
                            title: 'Card',
                            selected: selectedMode == 'Card',
                            onTap: () => dialogSetState(() => selectedMode = 'Card'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Text('Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hintColor)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Add a small note...',
                          hintStyle: TextStyle(color: hintColor),
                          filled: true,
                          fillColor: fieldColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: fieldColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: hintColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                final double? amount = double.tryParse(amountController.text.trim());
                                if (amount == null || amount <= 0) {
                                  showPremiumSnackBar(
                                    message: 'Please enter a valid amount',
                                    icon: Icons.error_outline_rounded,
                                  );
                                  return;
                                }

                                setState(() {
                                  tx['amount'] = amount;
                                  tx['category'] = selectedCategory;
                                  tx['mode'] = selectedMode;
                                  tx['note'] = noteController.text.trim();
                                  categoryColors.putIfAbsent(selectedCategory, () => Colors.teal);
                                });

                                if (tx['id'] != null && userId != null) {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(userId)
                                      .collection('transactions')
                                      .doc(tx['id'].toString())
                                      .update({
                                        'amount': amount,
                                        'category': selectedCategory,
                                        'mode': selectedMode,
                                        'note': noteController.text.trim(),
                                      });
                                }

                                await saveData();
                                if (context.mounted) Navigator.pop(context);

                                showPremiumSnackBar(
                                  message: 'Transaction updated successfully',
                                  icon: Icons.check_circle_rounded,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [ AppColors.headerStart,
                                    AppColors.headerEnd,],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2C2C54).withOpacity(0.28),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  void openCategoryTransactionsDialog(String category, List<Map<String, dynamic>> reportList) {
    final categoryTransactions =
        reportList.where((tx) => tx['category'] == category).toList();

    categoryTransactions.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.greenAccent : const Color(0xFF4B3F8F);
    final dialogBg = isDark ? const Color(0xFF1B1B22) : Colors.white;
    final cardBg = isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white60 : Colors.black54;
    final softTextColor = isDark ? Colors.white38 : Colors.black45;

    final totalCategoryAmount = categoryTransactions.fold(
      0.0,
      (sum, tx) => sum + (tx['amount'] as double),
    );

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$category Transactions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  reportView == "Monthly"
                      ? "Selected month transactions"
                      : reportView == "Weekly"
                          ? "Selected week transactions"
                          : "Selected day transactions",
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total",
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "₹ ${totalCategoryAmount.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "${categoryTransactions.length} transaction${categoryTransactions.length == 1 ? '' : 's'}",
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: categoryTransactions.isEmpty
                      ? Center(
                          child: Text(
                            "No transactions found",
                            style: TextStyle(color: subTextColor),
                          ),
                        )
                      : ListView.separated(
                          itemCount: categoryTransactions.length,
                          separatorBuilder: (_, _) => SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final tx = categoryTransactions[index];
                            final date = tx['date'] as DateTime;

                            return Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(isDark ? 0.18 : 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      color: primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx['category'],
                                          style: TextStyle(
                                            color: titleColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}",
                                          style: TextStyle(
                                            color: subTextColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          tx['mode'] ?? "Cash",
                                          style: TextStyle(
                                            color: softTextColor,
                                            fontSize: 11,
                                          ),
                                        ),
                                        if ((tx['note'] ?? '').toString().trim().isNotEmpty) ...[
                                          SizedBox(height: 4),
                                          Text(
                                            " ${tx['note']}",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white54 : Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "₹ ${(tx['amount'] as double).toStringAsFixed(0)}",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2C2C54), Color(0xFF40407A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "Close",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openSmartInsightsDialog() {
    final reportList = getCurrentReportList();

    double totalAmount =
        reportList.fold(0.0, (sum, tx) => sum + (tx['amount'] as double));

    int totalTransactions = reportList.length;

    double averageAmount = totalTransactions == 0 ? 0 : totalAmount / totalTransactions;

    Map<String, double> categoryTotals = {};
    for (var tx in reportList) {
      final category = tx['category'] as String;
      final amount = tx['amount'] as double;
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
    }

    String topCategory = "No Data";
    double topCategoryAmount = 0;

    if (categoryTotals.isNotEmpty) {
      final topEntry = categoryTotals.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      topCategory = topEntry.key;
      topCategoryAmount = topEntry.value;
    }

    double activeLimit = reportView == "Daily" ? dailyLimit : monthlyLimit;
    bool isLimitCrossed = activeLimit > 0 && totalAmount > activeLimit;

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Smart Insights",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  reportView == "Monthly"
                      ? "Insights for selected month"
                      : reportView == "Weekly"
                          ? "Insights for selected week"
                          : "Insights for selected day",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 18),
                _insightTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: "Total Expense",
                  value: "₹ ${totalAmount.toStringAsFixed(0)}",
                ),
                SizedBox(height: 10),
                _insightTile(
                  icon: Icons.receipt_long_rounded,
                  title: "Transactions",
                  value: "$totalTransactions",
                ),
                SizedBox(height: 10),
                _insightTile(
                  icon: Icons.bar_chart_rounded,
                  title: "Average Spend",
                  value: "₹ ${averageAmount.toStringAsFixed(0)}",
                ),
                SizedBox(height: 10),
                _insightTile(
                  icon: Icons.local_fire_department_rounded,
                  title: "Top Category",
                  value: topCategory == "No Data"
                      ? topCategory
                      : "$topCategory • ₹ ${topCategoryAmount.toStringAsFixed(0)}",
                ),
                SizedBox(height: 10),
                _insightTile(
                  icon: isLimitCrossed
                      ? Icons.warning_amber_rounded
                      : Icons.verified_rounded,
                  title: "Limit Status",
                  value: activeLimit == 0
                      ? "No limit set"
                      : isLimitCrossed
                          ? "Limit crossed"
                          : "Within limit",
                  valueColor: isLimitCrossed ? Colors.red : Colors.green,
                ),
                SizedBox(height: 18),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2C2C54), Color(0xFF40407A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "Close",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDark ? Colors.white : Colors.black),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onTap != null) ...[
              SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _insightTile({
    required IconData icon,
    required String title,
    required String value,
    Color valueColor = const Color(0xFF2C2C54),
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF2C2C54).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Color(0xFF2C2C54), size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _homeModeChip(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.22) : Colors.black.withOpacity(0.40),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.white.withOpacity(0.20) : Colors.white.withOpacity(0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _modeChip({
  required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    IconData icon;

    if (title == "Cash") {
      icon = Icons.payments_rounded; // 💵
    } else if (title == "UPI") {
      icon = Icons.account_balance_wallet_rounded; // 🏦
    } else {
      icon = Icons.credit_card_rounded; // 💳
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: selected
                ? LinearGradient(
                    colors: [Color(0xFF2C2C54), Color(0xFF40407A)],
                  )
                : null,
            color: selected ? null : Colors.grey.shade100,
            border: Border.all(
              color: selected ? Color(0xFF40407A) : Colors.grey.shade300,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dailyItem(String label, String type, VoidCallback onTap) {
    bool isSelected = selectedDayType == type;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        margin: EdgeInsets.symmetric(horizontal: 6),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _notificationBellButton() {
    final uid = userId;

    if (uid == null) {
      return _topIconButton(
        icon: Icons.notifications_active_rounded,
        onTap: openNotificationsSheet,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnapshot) {
        final lastOpenedAt = userSnapshot.data?.data()?['notificationsOpenedAt'];
        DateTime? lastOpenedDate;
        if (lastOpenedAt is Timestamp) {
          lastOpenedDate = lastOpenedAt.toDate();
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('dismissedNotifications')
              .snapshots(),
          builder: (context, dismissedSnapshot) {
            final dismissedIds = dismissedSnapshot.hasData
                ? dismissedSnapshot.data!.docs.map((e) => e.id).toSet()
                : <String>{};

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                int unreadCount = 0;

                if (snapshot.hasData) {
                  final now = DateTime.now();
                  for (final doc in snapshot.data!.docs) {
                    if (dismissedIds.contains(doc.id)) continue;

                    final data = doc.data();
                    final targetType = (data['targetType'] ?? 'all').toString();
                    final targetUserId = (data['targetUserId'] ?? '').toString();
                    final isForThisUser = targetType == 'all' ||
                        (targetType == 'single' && targetUserId == uid);
                    if (!isForThisUser) continue;

                    final scheduledAt = data['scheduledAt'];
                    if (scheduledAt is Timestamp && scheduledAt.toDate().isAfter(now)) {
                      continue;
                    }

                    final createdAt = data['createdAt'];
                    if (createdAt is Timestamp) {
                      final createdDate = createdAt.toDate();
                      if (lastOpenedDate == null || createdDate.isAfter(lastOpenedDate)) {
                        unreadCount++;
                      }
                    } else if (lastOpenedDate == null) {
                      unreadCount++;
                    }
                  }
                }

                final showBadge = unreadCount > 0;

                return GestureDetector(
                  onTap: openNotificationsSheet,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 1, end: showBadge ? 1.06 : 1),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeInOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: showBadge
                                    ? Colors.white.withOpacity(0.18)
                                    : Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: showBadge
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFFF4D4D).withOpacity(0.34),
                                          blurRadius: 18,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Icon(
                                showBadge
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_none_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            if (showBadge)
                              Positioned(
                                right: -5,
                                top: -6,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF3B30), Color(0xFFFF7A59)],
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white, width: 1.4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.redAccent.withOpacity(0.4),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    unreadCount > 4 ? '4+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _topIconButton({
  required IconData icon,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

  void openNotificationsSheet() {
    final uid = userId;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'notificationsOpenedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [ AppColors.headerStart,
                          AppColors.headerEnd,],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Notifications",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: widget.isDark ? Colors.white : const Color(0xFF1E1E2C),
                            ),
                          ),
                          Text(
                            "Admin updates and app alerts",
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: widget.isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    // User ne jis notification ko swipe karke delete kiya hai,
                    // uski id yaha se read hogi, fir notifications list se filter hogi.
                    stream: FirebaseAuth.instance.currentUser == null
                        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
                        : FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection('dismissedNotifications')
                            .snapshots(),
                    builder: (context, dismissedSnapshot) {
                      final dismissedIds = dismissedSnapshot.hasData
                          ? dismissedSnapshot.data!.docs.map((e) => e.id).toSet()
                          : <String>{};

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('notifications')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                "Notifications load nahi ho paayi",
                                style: TextStyle(
                                  color: widget.isDark ? Colors.white70 : Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final docs = snapshot.data!.docs.where((doc) {
                            // Important fix:
                            // Agar user ne notification delete/hide kar diya hai,
                            // toh woh future reload/new notification ke saath wapas nahi aayegi.
                            if (dismissedIds.contains(doc.id)) return false;

                            final data = doc.data();
                            final scheduledAt = data['scheduledAt'];
                            if (scheduledAt is Timestamp && scheduledAt.toDate().isAfter(DateTime.now())) {
                              return false;
                            }

                            final targetType = (data['targetType'] ?? 'all').toString();
                            final targetUserId = (data['targetUserId'] ?? '').toString();

                            return targetType == 'all' ||
                                (targetType == 'single' && userId != null && targetUserId == userId);
                          }).toList();

                          if (docs.isEmpty) {
                            return Center(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: widget.isDark ? Colors.white10 : const Color(0xFFF4F6FA),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.notifications_none_rounded,
                                      size: 42,
                                      color: widget.isDark ? Colors.white38 : Colors.black38,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "No notifications yet",
                                      style: TextStyle(
                                        color: widget.isDark ? Colors.white70 : Colors.black54,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final data = docs[index].data();
                              final title = (data['title'] ?? '').toString();
                              final body = (data['body'] ?? '').toString();
                              final createdAt = data['createdAt'];
                              String timeText = "";

                              if (createdAt is Timestamp) {
                                final dt = createdAt.toDate();
                                timeText = "${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                              }

                              return Dismissible(
                                key: ValueKey(docs[index].id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(
                                    Icons.delete_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                onDismissed: (_) async {
                                  final user = FirebaseAuth.instance.currentUser;

                                  if (user != null) {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .collection('dismissedNotifications')
                                        .doc(docs[index].id)
                                        .set({
                                      'dismissedAt': FieldValue.serverTimestamp(),
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: widget.isDark ? Colors.white10 : Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
                                    ),
                                    boxShadow: widget.isDark
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 12,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF40407A).withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(
                                          Icons.campaign_rounded,
                                          color: Color(0xFF6C63FF),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title.isEmpty ? "Notification" : title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: widget.isDark ? Colors.white : const Color(0xFF1E1E2C),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              body,
                                              style: TextStyle(
                                                color: widget.isDark ? Colors.white70 : Colors.black54,
                                                fontSize: 13,
                                                height: 1.35,
                                              ),
                                            ),
                                            if (timeText.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                timeText,
                                                style: TextStyle(
                                                  color: widget.isDark ? Colors.white38 : Colors.black38,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            final bool dark = widget.isDark;
            final Color sheetColor = dark ? const Color(0xFF1E1E1E) : Colors.white;
            final Color titleColor = dark ? Colors.white : const Color(0xFF171727);
            final Color subColor = dark ? Colors.white70 : const Color(0xFF171727).withOpacity(0.70);
            final Color chipTextColor = dark ? Colors.white : const Color(0xFF171727);

            Widget premiumChip({
              required String label,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return ChoiceChip(
                label: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : chipTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: selected,
                onSelected: (_) => onTap(),
                selectedColor: const Color(0xFF4B3F8F),
                backgroundColor: dark ? const Color(0xFF111111) : const Color(0xFFF4F1FA),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF4B3F8F)
                      : (dark ? Colors.white24 : const Color(0xFF2C2C54).withOpacity(0.18)),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }

            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 22,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Filter Transactions",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: titleColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "Find expenses faster",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subColor.withOpacity(0.72),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close_rounded, color: subColor),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Text(
                        "Payment Mode",
                        style: TextStyle(
                          color: subColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ["All", "Cash", "UPI", "Card"].map((mode) {
                          return premiumChip(
                            label: mode,
                            selected: selectedModeFilter == mode,
                            onTap: () {
                              sheetSetState(() => selectedModeFilter = mode);
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        "Category",
                        style: TextStyle(
                          color: subColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ["All", ...categories].map((cat) {
                          return premiumChip(
                            label: cat,
                            selected: selectedCategoryFilter == cat,
                            onTap: () {
                              sheetSetState(() => selectedCategoryFilter = cat);
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedModeFilter = "All";
                            selectedCategoryFilter = "All";
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [ AppColors.headerStart,
                              AppColors.headerEnd,],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2C2C54).withOpacity(0.24),
                                blurRadius: 14,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "Clear Filter",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
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
      },
    );
  }

  void openAddDialog(BuildContext context) {
    TextEditingController amountController = TextEditingController();
    TextEditingController customController = TextEditingController();
    
    String category = categories.isNotEmpty ? categories[0] : "";
    bool isCustom = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Add Expense",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 16),

                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: "Enter Amount",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...categories.map((cat) {
                          bool isSelected = !isCustom && category == cat;

                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                category = cat;
                                isCustom = false;
                              });
                            },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Color(0xFF2C2C54) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }),

                        GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              isCustom = true;
                              category = "";
                            });
                          },
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isCustom ? Colors.orange : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Custom",
                              style: TextStyle(
                                color: isCustom ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (isCustom) ...[
                      SizedBox(height: 12),
                      TextField(
                        controller: customController,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: "Custom Category",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 20),

                    GestureDetector(
                      onTap: () async {
                        double amount = double.tryParse(amountController.text.trim()) ?? 0;
                        String finalCategory =
                            isCustom ? customController.text.trim() : category;

                        if (amount <= 0 || finalCategory.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Amount aur category dono fill karo")),
                          );
                          return;
                        }

                        if (!categories.contains(finalCategory)) {
                          setState(() {
                            categories.add(finalCategory);
                            categoryColors[finalCategory] = Colors.teal;
                          });
                          await saveUserCategoriesToFirestore();
                        }

                        if (Navigator.canPop(context)) {
                          Navigator.of(context, rootNavigator: true).pop();
                        }

                        showPremiumSnackBar(
                          message: isInternetAvailable
                              ? "Transaction saved successfully"
                              : "Saved offline. Internet aate hi sync ho jayegi",
                          icon: isInternetAvailable
                              ? Icons.receipt_long_rounded
                              : Icons.cloud_off_rounded,
                          color: isInternetAvailable ? Colors.greenAccent : Colors.orangeAccent,
                        );

                        addTransaction(amount, finalCategory, "");

                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2C2C54), Color(0xFF40407A)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            "Add",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  void openLimitDialog(BuildContext context) {
    String selectedLimitMode = "This Month";
    final bool isMonthlyDialog = viewMode == "Monthly";

    final controller = TextEditingController(
      text: viewMode == "Daily"
          ? (dailyLimit == 0 ? "" : dailyLimit.toStringAsFixed(0))
          : (getMonthlyLimitForSelectedMonth() == 0
              ? ""
              : getMonthlyLimitForSelectedMonth().toStringAsFixed(0)),
    );

    void refreshControllerForMode(String mode) {
      final value = mode == "All Months"
          ? monthlyLimit
          : (monthlyLimitsByMonth[selectedMonth] ?? monthlyLimit);
      controller.text = value == 0 ? "" : value.toStringAsFixed(0);
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }

    Widget buildLimitModeChip({
      required String title,
      required String subtitle,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF2C2C54), Color(0xFF40407A)],
                    )
                  : null,
              color: selected ? null : const Color(0xFFF4F3FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? Colors.transparent : const Color(0xFFE4E1EF),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2C2C54).withOpacity(0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withOpacity(0.16) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: selected ? Colors.white : const Color(0xFF2C2C54),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? Colors.white : const Color(0xFF1F1F35),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? Colors.white.withOpacity(0.72) : Colors.black45,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
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

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.72),
      barrierLabel: "Limit Dialog",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0.92, end: 1.0),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.20),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C54).withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.track_changes_rounded,
                            color: Color(0xFF2C2C54),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          viewMode == "Daily" ? "Set Daily Limit" : "Set Monthly Limit",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          viewMode == "Daily"
                              ? "Add your daily spending limit"
                              : "Choose one budget for every month or only this month",
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (isMonthlyDialog) ...[
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              buildLimitModeChip(
                                title: "All Months",
                                subtitle: "Default limit",
                                icon: Icons.all_inclusive_rounded,
                                selected: selectedLimitMode == "All Months",
                                onTap: () {
                                  setStateDialog(() {
                                    selectedLimitMode = "All Months";
                                    refreshControllerForMode(selectedLimitMode);
                                  });
                                },
                              ),
                              const SizedBox(width: 10),
                              buildLimitModeChip(
                                title: "This Month",
                                subtitle: "Only selected",
                                icon: Icons.calendar_month_rounded,
                                selected: selectedLimitMode == "This Month",
                                onTap: () {
                                  setStateDialog(() {
                                    selectedLimitMode = "This Month";
                                    refreshControllerForMode(selectedLimitMode);
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            prefixText: "₹  ",
                            prefixStyle: const TextStyle(
                              color: Color(0xFF2C2C54),
                              fontWeight: FontWeight.w800,
                            ),
                            hintText: "Enter limit amount",
                            hintStyle: const TextStyle(color: Colors.black38),
                            filled: true,
                            fillColor: const Color(0xFFF5F3FA),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 15,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF40407A),
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        if (isMonthlyDialog) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: Colors.black38,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  selectedLimitMode == "All Months"
                                      ? "This will become the default limit for every month."
                                      : "This limit will apply only to the selected month.",
                                  style: const TextStyle(
                                    color: Colors.black45,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "Cancel",
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final value = double.tryParse(controller.text.trim()) ?? 0;

                                  setState(() {
                                    if (viewMode == "Daily") {
                                      dailyLimit = value;
                                    } else if (selectedLimitMode == "All Months") {
                                      monthlyLimit = value;
                                    } else {
                                      monthlyLimitsByMonth[selectedMonth] = value;
                                    }
                                  });

                                  await saveData();
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2C2C54), Color(0xFF40407A)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2C2C54).withOpacity(0.28),
                                        blurRadius: 16,
                                        offset: const Offset(0, 7),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "Save",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }
}
class ResponsiveHomeWrapper extends StatelessWidget {
  final bool isDark;
  final VoidCallback onThemeToggle;

  const ResponsiveHomeWrapper({
    super.key,
    required this.isDark,
    required this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100) {
          return WebDashboardPage(
            isDark: isDark,
            onThemeToggle: onThemeToggle,
          );
        }

        return MainScreen(
          isDark: isDark,
          onThemeToggle: onThemeToggle,
        );
      },
    );
  }
}