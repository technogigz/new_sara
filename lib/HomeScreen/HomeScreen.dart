import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/ChartScreen/ChartScreen.dart';
import 'package:new_sara/Login/LoginWithMpinScreen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Bids/MyBidsPage.dart';
import '../Helper/Toast.dart';
import '../Navigation/FundsFragmentContainer.dart';
import '../Notice/WithdrawInfoScreen.dart';
import '../Notification/NotificationScreen.dart';
import '../Passbook/PassbookPage.dart';
import '../SetMPIN/SetNewPinScreen.dart';
import '../SettingsScreen/SettingsScreen.dart';
// Assuming ChatScreen is the one used for bottom nav "Support" and drawer "Chats"
import '../Support/ChatSupport/ChatSupport.dart'; // Or wherever your ChatScreen is defined
import '../Support/SupportPage.dart'; // This is _screens[4]
import '../Video/LanguageSelectionScreen.dart';
import '../components/AppName.dart';
import '../game/gameRates/GameRateScreen.dart'; // This is _screens[7]
import '../ulits/ColorsR.dart';
import '../ulits/Constents.dart';
import 'HomePage.dart'; // This is _screens[2]

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 2; // Default to HomePage (main tab)
  late GetStorage storage = GetStorage();
  late String accessToken;
  late String registerId;
  late bool accountStatus;
  late String preferredLanguage;
  late String mobile;
  late String mobileNumber;
  late String name;
  late bool? accountActiveStatus;
  late String walletBallence;
  late bool isLogin;

  launchWhatsAppChat() {
    // Replace with your WhatsApp number
    String phoneNumber = storage.read('whatsappNumber');
    final cleanNumber = phoneNumber.replaceAll('+', '').replaceAll(' ', '');
    launchUrl(Uri.parse('https://wa.me/91${cleanNumber}'));
  }

  // Define your screens. Ensure ChatScreen is const if it has no internal state
  // or that a new instance is acceptable each time.
  final List<Widget> _screens = [
    BidScreen(), // 0
    PassbookPage(), // 1
    HomePage(), // 2 (Main Home Tab)
    FundsFragmentContainer(), // 3
    SupportPage(), // 4 (If different from ChatScreen for drawer/bottom nav)
    WithdrawInfoScreen(), // 5 (Notice Board/Rules)
    SettingsScreen(), // 6
    GameRateScreen(), // 7
    ChatScreen(), // 8 (Used for bottom nav "Support" & drawer "Chats")
  ];

  @override
  void initState() {
    super.initState();

    // Initial reads
    mobile = storage.read('mobileNoEnc') ?? '';
    mobileNumber = storage.read('mobileNo') ?? '';
    name = storage.read('fullName') ?? '';
    accountActiveStatus = storage.read('accountStatus');
    walletBallence = storage.read('walletBalance') ?? '';

    // Listen to updates
    storage.listenKey('mobileNoEnc', (value) => mobile = value);
    storage.listenKey('fullName', (value) => name = value);
    storage.listenKey('accountStatus', (value) => accountActiveStatus = value);
    storage.listenKey('walletBalance', (value) => walletBallence = value);

    if (storage.read('accessToken') != null &&
        storage.read('registerId') != null) {
      storage.write('isLoggedIn', true);
    }

    // setState(() {});
  }

  void _onItemTapped(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() {
        _selectedIndex = index;
      });
    } else {
      log("Error: Attempted to select invalid index: $index");
    }
  }

  // For pushing screens that are not part of the main _selectedIndex navigation
  void _navigateToNewScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  // For drawer items that should push a new screen
  void _navigateToDrawerScreenAndPush(Widget screen) {
    Navigator.pop(context); // Close the drawer
    _navigateToNewScreen(screen);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle back button press
        if (_selectedIndex != 2) {
          _onItemTapped(2); // Go back to HomePage tab
          return false; // Prevent default back button behavior (do not pop screen)
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
              : Center(
                  child: Text(
                    "Error: Screen not found for index $_selectedIndex",
                  ),
                ),
        ),
        bottomNavigationBar: _buildBottomAppBar(),
        floatingActionButton: Container(
          margin: const EdgeInsets.only(
            top: 65,
            left: 5,
            right: 5,
          ), // Adjust margin if needed
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            backgroundColor: Colors.orange,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
              side: BorderSide(color: Colors.orange, width: 2),
            ),
            onPressed: () => _onItemTapped(2), // Home is index 2
            child: Image.asset("assets/images/home_orange.png"),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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

            // Show Wallet only if account is active
            if (accountActiveStatus == true)
              GestureDetector(
                onTap: () {
                  _navigateToDrawerScreenAndPush(PassbookPage());
                },
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
                        "₹${walletBallence}",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w200,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(width: 12),

            // Show Notification Icon only if account is active
            if (accountActiveStatus == true)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: IconButton(
                      icon: Image.asset(
                        "assets/images/ic_notification.png",
                        width: 22,
                        height: 22,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        _navigateToNewScreen(NoticeHistoryScreen());
                      },
                    ),
                  ),
                  // Add badge here if needed
                ],
              ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    String mobile = storage.read('mobileNoEnc') ?? '';
    String name = storage.read('fullName') ?? '';
    bool accountStatus = storage.read('accountStatus') ?? false;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
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
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                mobile,
                                style: const TextStyle(color: Colors.black54),
                                overflow: TextOverflow.ellipsis,
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

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  _buildDrawerItem("assets/images/home_nav.png", "Home", () {
                    Navigator.pop(context);
                    _onItemTapped(2);
                  }, true),

                  _buildDrawerItem("assets/images/bid_nav.png", "My Bids", () {
                    Navigator.pop(context);
                    _onItemTapped(0);
                  }, accountStatus),

                  _buildDrawerItem("assets/images/mpin_nav.png", "M-PIN", () {
                    Navigator.pop(context);
                    _handleMpin();
                  }, accountStatus),

                  _buildDrawerItem(
                    "assets/images/passbook.png",
                    "Passbook",
                    () {
                      _navigateToDrawerScreenAndPush(PassbookPage());
                    },
                    accountStatus,
                  ),

                  // _buildDrawerItem("assets/images/chat_icon.png", "Chats", () {
                  //   _navigateToDrawerScreenAndPush(ChatScreen());
                  // }, accountStatus),
                  _buildDrawerItem("assets/images/funds_nav.png", "Funds", () {
                    Navigator.pop(context);
                    _onItemTapped(3);
                  }, accountStatus),

                  // _buildDrawerItem(
                  //   "assets/images/ic_notification.png",
                  //   "Notification",
                  //   () {
                  //     _navigateToDrawerScreenAndPush(NoticeHistoryScreen());
                  //   },
                  //   accountStatus,
                  // ),
                  _buildDrawerItem("assets/images/videos.png", "Videos", () {
                    _navigateToDrawerScreenAndPush(LanguageSelectionScreen());
                  }, accountStatus),

                  // _buildDrawerItem(
                  //   "assets/images/notice.png",
                  //   "Notice Board/Rules",
                  //   () {
                  //     Navigator.pop(context);
                  //     _onItemTapped(5);
                  //   },
                  //   accountStatus,
                  // ),
                  _buildDrawerItem(
                    "assets/images/rate_stars.png",
                    "Game Rates",
                    () {
                      Navigator.pop(context);
                      _onItemTapped(7);
                    },
                    accountStatus,
                  ),

                  _buildDrawerItem("assets/images/charts.png", "Charts", () {
                    _navigateToDrawerScreenAndPush(ChartScreen());
                  }, accountStatus),

                  // _buildDrawerItem(
                  //   "assets/images/idea_nav.png",
                  //   "Submit Idea",
                  //   () {
                  //     _navigateToDrawerScreenAndPush(SubmitIdeaScreen());
                  //   },
                  //   accountStatus,
                  // ),
                  _buildDrawerItem(
                    "assets/images/setting_nav.png",
                    "Settings",
                    () {
                      Navigator.pop(context);
                      _onItemTapped(6);
                    },
                    accountStatus,
                  ),

                  _buildDrawerItem(
                    "assets/images/share.png",
                    "Share Application",
                    () {
                      Navigator.pop(context);
                      Share.share(
                        "I'm loving Sara 777 App\n\nDownload App now\n\nFrom:-\nhttps://sara777.net.in",
                        subject: "Check out the Sara 777 App!",
                      );
                    },
                    accountStatus,
                  ),

                  _buildDrawerItem("assets/images/power.png", "LOGOUT", () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginWithMpinScreen(),
                      ),
                    );
                  }, accountStatus),
                ],
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
    final String? mobile1 = storage.read('mobileNo');
    log("Mobile number: $mobile1");
    try {
      final response = await http.post(
        Uri.parse('${Constant.apiEndpoint}send-otp'),
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"mobileNo": mobile1}),
      );

      final data = jsonDecode(response.body);
      log("OTP API response: $data");

      if (response.statusCode == 200 && data['status'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SetNewPinScreen(mobile: mobile1 ?? ""),
          ),
        );
      } else {
        popToast(
          data['message'] ?? "OTP sending failed",
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
    bool accountStatus = storage.read('accountStatus') ?? false;

    return Container(
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
      child: SizedBox(
        height: 68,
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
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.15,
            ), // space for FAB
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
    );
  }

  Widget _buildNavItem(
    String iconPath,
    String label,
    int index, {
    bool visible = true,
  }) {
    if (!visible) return const SizedBox.shrink();

    final isSelected = _selectedIndex == index;
    final color = isSelected ? Colors.orange : Colors.black;

    return GestureDetector(
      onTap: () {
        if (index == 8) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          );
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
