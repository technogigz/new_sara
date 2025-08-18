// File: lib/HomeScreen.dart
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Bids/MyBidsPage.dart';
import '../ChartScreen/ChartScreen.dart';
import '../Helper/Toast.dart';
import '../Helper/UserController.dart';
import '../Login/LoginWithMpinScreen.dart';
import '../Navigation/FundsFragmentContainer.dart';
import '../Notice/WithdrawInfoScreen.dart';
import '../Notification/NotificationScreen.dart'; // assumes NoticeHistoryScreen is here
import '../Passbook/PassbookPage.dart';
import '../SetMPIN/SetNewPinScreen.dart';
import '../SettingsScreen/SettingsScreen.dart';
import '../Support/ChatSupport/ChatSupport.dart';
import '../Support/SupportPage.dart';
import '../Video/LanguageSelectionScreen.dart';
import '../components/AppName.dart';
import '../game/gameRates/GameRateScreen.dart';
import '../ulits/ColorsR.dart';
import '../ulits/Constents.dart';
import 'HomePage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Safe find-or-put (in case main.dart missed registering once)
  late final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController(), permanent: true);

  final GetStorage storage = GetStorage();

  int _selectedIndex = 2; // Default: Home tab

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    log('HomeScreen sees UserController hash: ${userController.hashCode}');

    // ✅ First fill user → then others (avoid race)
    _bootstrapLoad();

    storage.write('isLoggedIn', true);

    // Optional: start polling so wallet/flags stay fresh
    userController.startLivePolling(interval: const Duration(seconds: 6));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    userController.stopLivePolling();
    super.dispose();
  }

  // App resume par light refresh
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      userController.fetchAndUpdateUserDetails();
    }
  }

  Future<void> _bootstrapLoad() async {
    try {
      // 1) Must be first (sets mobileNo, accountStatus, wallet, etc.)
      await userController.fetchAndUpdateUserDetails();

      // 2) Dependent stuff in parallel
      await Future.wait([
        userController.fetchAndUpdateFeeSettings(),
        userController.fetchAndUpdateContactDetails(),
        userController.fetchPaymentDetails(),
      ]);
    } catch (e, st) {
      log('Warm-up error: $e', stackTrace: st);
    }
  }

  // ---------- WhatsApp Helpers ----------
  String _normalizePhone(String raw, {String defaultCountryCode = '91'}) {
    var p = raw.replaceAll(RegExp(r'[^0-9]'), '');
    p = p.replaceFirst(RegExp(r'^0+'), '');
    if (p.length == 10) p = '$defaultCountryCode$p';
    return p;
  }

  /// Priority: contactWhatsapp -> contactMobile -> storage.whatsappNo -> user.mobileNo
  String? _getSupportNumber() {
    final w = userController.contactWhatsappNo.value.trim();
    if (w.isNotEmpty) return w;

    final c = userController.contactMobileNo.value.trim();
    if (c.isNotEmpty) return c;

    final s = (storage.read('whatsappNo') ?? '').toString().trim();
    if (s.isNotEmpty) return s;

    final u = userController.mobileNo.value.trim();
    if (u.isNotEmpty) return u;

    return null;
  }

  Future<void> launchWhatsAppChat({String? message}) async {
    try {
      final raw = _getSupportNumber();
      if (raw == null) {
        popToast(
          "WhatsApp number not available",
          4,
          Colors.white,
          ColorsR.appColorRed,
        );
        log("❌ WhatsApp number missing (all sources empty)");
        return;
      }

      final phone = _normalizePhone(raw);
      final encoded = (message ?? '').trim().isEmpty
          ? ''
          : Uri.encodeComponent(message!.trim());

      final nativeUri = Uri.parse(
        'whatsapp://send?phone=$phone${encoded.isNotEmpty ? '&text=$encoded' : ''}',
      );
      if (await canLaunchUrl(nativeUri)) {
        final ok = await launchUrl(
          nativeUri,
          mode: LaunchMode.externalApplication,
        );
        log(
          ok ? '✅ Launched WhatsApp (native): $nativeUri' : '❌ Failed (native)',
        );
        if (ok) return;
      }

      final webUri = Uri.parse(
        'https://wa.me/$phone${encoded.isNotEmpty ? '?text=$encoded' : ''}',
      );
      if (await canLaunchUrl(webUri)) {
        final ok = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
        log(ok ? '✅ Launched WhatsApp (web): $webUri' : '❌ Failed (web)');
        if (ok) return;
      }

      popToast(
        "Could not launch WhatsApp",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
    } catch (e, st) {
      log('❌ WhatsApp launch error: $e', stackTrace: st);
      popToast(
        "Error launching WhatsApp",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
    }
  }
  // --------------------------------------

  final List<Widget> _screens = [
    BidScreen(), // 0
    PassbookPage(), // 1
    HomePage(), // 2 (Main Home Tab)
    FundsFragmentContainer(), // 3
    SupportPage(), // 4
    WithdrawInfoScreen(), // 5 (Notice/Rules)
    SettingsScreen(), // 6
    GameRateScreen(), // 7
    ChatScreen(), // 8 (we open WhatsApp instead on tap)
  ];

  void _onItemTapped(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _selectedIndex = index);
    } else {
      log("Error: Attempted to select invalid index: $index");
    }
  }

  void _navigateToNewScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _navigateToDrawerScreenAndPush(Widget screen) {
    Navigator.pop(context);
    _navigateToNewScreen(screen);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 2) {
          _onItemTapped(2);
          return false;
        }
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        drawer: _buildDrawer(),
        appBar: _buildAppBar(context),
        body: SafeArea(
          child: (_selectedIndex >= 0 && _selectedIndex < _screens.length)
              ? _screens[_selectedIndex]
              : const Center(child: Text("Error: Screen not found")),
        ),
        bottomNavigationBar: SafeArea(child: _buildBottomAppBar()),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 40,
      backgroundColor: Colors.grey.shade300,
      elevation: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            Builder(
              builder: (ctx) => SizedBox(
                width: 42,
                height: 42,
                child: IconButton(
                  icon: Image.asset(
                    "assets/images/ic_menu.png",
                    width: 24,
                    height: 24,
                    color: Colors.black,
                  ),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox(width: 150, height: 40, child: AppName()),
            const Spacer(),

            // Wallet (visible only if account active) — FULLY REACTIVE
            Obx(
              () => userController.accountStatus.value
                  ? GestureDetector(
                      onTap: () =>
                          _navigateToDrawerScreenAndPush(const PassbookPage()),
                      child: SizedBox(
                        height: 42,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Image.asset(
                              "assets/images/ic_wallet.png",
                              width: 22,
                              height: 22,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "₹${userController.walletBalance.value}",
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w200,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 12),

            // Notifications (visible only if account active)
            Obx(
              () => userController.accountStatus.value
                  ? SizedBox(
                      width: 42,
                      height: 42,
                      child: IconButton(
                        icon: Image.asset(
                          "assets/images/ic_notification.png",
                          width: 22,
                          height: 22,
                          color: Colors.black,
                        ),
                        onPressed: () =>
                            _navigateToNewScreen(const NoticeHistoryScreen()),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              height: 100,
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.grey.shade300,
                          child: const Icon(
                            Icons.person,
                            size: 36,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Obx(
                                () => Text(
                                  userController.fullName.value,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Obx(
                                () => Text(
                                  userController.mobileNoEnc.value,
                                  style: const TextStyle(color: Colors.black54),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Items
            Expanded(
              child: Obx(
                () => ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  children: [
                    _buildDrawerItem("assets/images/home_nav.png", "Home", () {
                      Navigator.pop(context);
                      _onItemTapped(2);
                    }, true),
                    _buildDrawerItem(
                      "assets/images/bid_nav.png",
                      "My Bids",
                      () {
                        Navigator.pop(context);
                        _onItemTapped(0);
                      },
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/mpin_nav.png",
                      "M-PIN",
                      () {
                        Navigator.pop(context);
                        _handleMpin();
                      },
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/passbook.png",
                      "Passbook",
                      () =>
                          _navigateToDrawerScreenAndPush(const PassbookPage()),
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/funds_nav.png",
                      "Funds",
                      () {
                        Navigator.pop(context);
                        _onItemTapped(3);
                      },
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/videos.png",
                      "Videos",
                      () => _navigateToDrawerScreenAndPush(
                        const LanguageSelectionScreen(),
                      ),
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/rate_stars.png",
                      "Game Rates",
                      () {
                        Navigator.pop(context);
                        _onItemTapped(7);
                      },
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/charts.png",
                      "Charts",
                      () => _navigateToDrawerScreenAndPush(const ChartScreen()),
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/setting_nav.png",
                      "Settings",
                      () {
                        Navigator.pop(context);
                        _onItemTapped(6);
                      },
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/share.png",
                      "Share Application",
                      () {
                        Navigator.pop(context);
                        Share.share(
                          "I'm loving Sara 777 App\n\nDownload App now\n\nFrom:-\nhttps://sara777.win",
                          subject: "Check out the Sara 777 App!",
                        );
                      },
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/power.png",
                      "LOGOUT",
                      () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginWithMpinScreen(),
                          ),
                        );
                      },
                      userController.accountStatus.value,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    String imagePath,
    String title,
    VoidCallback onTap,
    bool visible,
  ) {
    if (!visible) return const SizedBox.shrink();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Image.asset(
        imagePath,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      onTap: onTap,
    );
  }

  void _handleMpin() async {
    final String mobile = userController.mobileNo.value;
    if (mobile.isEmpty) {
      log("Mobile number is not available.");
      popToast(
        "Mobile number is not available",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
      return;
    }

    log("Mobile number: $mobile");
    try {
      final response = await http.post(
        Uri.parse('${Constant.apiEndpoint}send-otp'),
        headers: {
          'deviceId': (storage.read('deviceId') ?? 'unknown-device').toString(),
          'deviceName': (storage.read('deviceName') ?? 'unknown-model')
              .toString(),
          'accessStatus': '1',
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({"mobileNo": mobile}),
      );

      final data = jsonDecode(response.body);
      log("OTP API response: $data");

      if (response.statusCode == 200 &&
          (data['status'] == true ||
              data['status'] == 1 ||
              data['status'] == '1')) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SetNewPinScreen(mobile: mobile)),
        );
      } else {
        popToast(
          (data['message'] ?? "OTP sending failed").toString(),
          4,
          Colors.white,
          ColorsR.appColorRed,
        );
      }
    } catch (e) {
      log("Network error in _handleMpin: $e");
      if (!mounted) return;
      popToast("Network error: $e", 4, Colors.red, Colors.white);
    }
  }

  Widget _buildBottomAppBar() {
    return Obx(() {
      final accountStatus = userController.accountStatus.value;
      return SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 68,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(
                          "assets/images/bid_nav.png",
                          "My Bids",
                          0,
                          visible: accountStatus,
                        ),
                        _buildNavItem(
                          "assets/images/passbook.png",
                          "Passbook",
                          1,
                          visible: accountStatus,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.15),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(
                          "assets/images/funds.png",
                          "Funds",
                          3,
                          visible: accountStatus,
                        ),
                        _buildNavItem(
                          "assets/images/chat_icon.png",
                          "Support",
                          8,
                          visible: accountStatus,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Center FAB-like home button
            Positioned(
              top: 4,
              child: SizedBox(
                width: 55,
                height: 55,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _onItemTapped(2),
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: Icon(Icons.home, color: Colors.black, size: 30),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNavItem(
    String iconPath,
    String label,
    int index, {
    bool visible = true,
  }) {
    if (!visible) return const SizedBox.shrink();

    final isSelected = _selectedIndex == index;
    final color = isSelected ? Colors.red : Colors.black;

    return GestureDetector(
      onTap: () {
        if (index == 8) {
          launchWhatsAppChat();
        } else if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PassbookPage()),
          );
        } else {
          _onItemTapped(index);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(iconPath, width: 30, height: 30, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
