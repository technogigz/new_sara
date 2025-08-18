import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:marquee/marquee.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Helper/UserController.dart';
import '../KingStarline&Jackpot/KingJackpotDashboard.dart';
import '../KingStarline&Jackpot/KingStarlineDashboard.dart';
import '../components/closeBidDialogue.dart';
import '../game/GameScreen.dart';
import '../ulits/Constents.dart';

// Placeholder for TranslationHelper
class TranslationHelper {
  static Future<String> translate(String text, String lang) async {
    await Future.delayed(const Duration(milliseconds: 5));
    return text;
  }
}

// ---------------- Data Models ----------------
class HomeData {
  final bool status;
  final String msg;
  final List<Info>? result;

  HomeData({required this.status, required this.msg, this.result});

  factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
    status: _b(json["status"]),
    msg: json["msg"]?.toString() ?? '',
    result: json["info"] == null
        ? null
        : List<Info>.from(
            (json["info"] as List).map(
              (x) => Info.fromJson(x as Map<String, dynamic>),
            ),
          ),
  );
}

class Info {
  final int gameId;
  final String gameName;
  final String openTime;
  final String closeTime;
  final String result;
  final String statusText;
  final bool playStatus;
  final bool openSessionStatus;
  final bool closeSessionStatus;

  Info({
    required this.gameId,
    required this.gameName,
    required this.openTime,
    required this.closeTime,
    required this.result,
    required this.statusText,
    required this.playStatus,
    required this.openSessionStatus,
    required this.closeSessionStatus,
  });

  factory Info.fromJson(Map<String, dynamic> json) => Info(
    gameId: int.tryParse(json["gameId"].toString()) ?? 0,
    gameName: json["gameName"]?.toString() ?? '',
    openTime: json["openTime"]?.toString() ?? '',
    closeTime: json["closeTime"]?.toString() ?? '',
    result: json["result"]?.toString() ?? '',
    statusText: json["statusText"]?.toString() ?? '',
    playStatus: _b(json["playStatus"]),
    openSessionStatus: _b(json["openSessionStatus"]),
    closeSessionStatus: _b(json["closeSessionStatus"]),
  );
}

// Robust bool parser
bool _b(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes' || s == 'y';
  }
  return false;
}

class ContactDetails {
  final String? mobileNo;
  final String? whatsappNo;
  final String? appLink;
  final String? homepageContent;
  final String? videoDescription;

  ContactDetails({
    this.mobileNo,
    this.whatsappNo,
    this.appLink,
    this.homepageContent,
    this.videoDescription,
  });
}

HomeData homeDataFromJson(String str) =>
    HomeData.fromJson(json.decode(str) as Map<String, dynamic>);

// ---------------- HomePage ----------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<HomeData> _futureHomeData;
  late Future<ContactDetails?> _futureContactDetails;
  late String _preferredLanguage;

  final Map<String, String> _translatedUiStrings = {};
  final GetStorage _storage = GetStorage();

  // ✅ Use the SAME controller; don't create a new one here
  late final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController(), permanent: true);

  static const List<String> _uiKeysToTranslate = [
    "KING STARLINE",
    "King Jackpot",
    "Play Game",
    "Open Bid",
    "Close Bid",
    "24X7 Helpline: +919649115777. Available Languages: English • Hindi • Telugu • Kannada",
    "Market Closed",
  ];

  @override
  void initState() {
    super.initState();

    log('HomePage sees UserController hash: ${userController.hashCode}');

    _preferredLanguage = _storage.read('selectedLanguage') ?? 'en';

    // Kick off initial loads
    _preTranslateUI();
    _futureHomeData = _fetchDashboardData();
    _futureContactDetails = fetchContactDetail();

    // If auth changes while we're on this page, refresh futures automatically
    everAll([userController.accessToken, userController.registerId], (_) {
      setState(() {
        _futureHomeData = _fetchDashboardData();
        _futureContactDetails = fetchContactDetail();
      });
    });
  }

  Future<void> _preTranslateUI() async {
    for (final key in _uiKeysToTranslate) {
      if (!_translatedUiStrings.containsKey(key) ||
          _translatedUiStrings[key] == key) {
        _translatedUiStrings[key] = await TranslationHelper.translate(
          key,
          _preferredLanguage,
        );
      }
    }
    if (mounted) setState(() {});
  }

  String _t(String key) => _translatedUiStrings[key] ?? key;

  Future<void> _handleRefresh() async {
    try {
      await userController.refreshEverything();
      setState(() {
        _futureHomeData = _fetchDashboardData();
        _futureContactDetails = fetchContactDetail();
      });
    } catch (e) {
      log("Error during refresh: $e");
    }
  }

  Future<ContactDetails?> fetchContactDetail() async {
    final url = Uri.parse('${Constant.apiEndpoint}contact-detail');
    final headers = {
      'deviceId': 'qwert',
      'deviceName': 'sm2233',
      'accessStatus': '1',
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${_storage.read('accessToken') ?? ''}',
    };

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        log('✅ Contact details fetched: $data');

        final contactInfo =
            (data['info'] as Map?)?['contactInfo'] as Map<String, dynamic>?;
        final videosInfo =
            (data['info'] as Map?)?['videosInfo'] as Map<String, dynamic>?;

        return ContactDetails(
          mobileNo: contactInfo?['mobileNo']?.toString(),
          whatsappNo: contactInfo?['whatsappNo']?.toString(),
          appLink: contactInfo?['appLink']?.toString(),
          homepageContent: contactInfo?['homepageContent']?.toString(),
          videoDescription: videosInfo?['description']?.toString(),
        );
      } else {
        log('❌ contact-detail ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      log('❗ Error fetching contact details: $e');
      return null;
    }
  }

  Future<HomeData> _fetchDashboardData() async {
    final String token = _storage.read('accessToken') ?? '';
    final String regId = _storage.read('registerId') ?? '';

    if (token.isEmpty || regId.isEmpty) {
      log("❌ Aborting game-list: Missing access token or register ID.");
      return HomeData(
        status: false,
        msg: "User not logged in",
        result: const [],
      );
    }

    final response = await http.post(
      Uri.parse("${Constant.apiEndpoint}game-list"),
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Accept": "application/json",
        "deviceId": "qwert",
        "deviceName": "sm2233",
        "accessStatus": "1",
        "Authorization": "Bearer $token",
      },
      body: json.encode({"registerId": regId}),
    );

    if (response.statusCode == 200) {
      return homeDataFromJson(response.body);
    } else {
      log(
        "Failed to load dashboard data: ${response.statusCode} - ${response.body}",
      );
      throw Exception(
        "Failed to load dashboard data: ${response.statusCode} - ${response.body}",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.grey.shade200,
        child: RefreshIndicator(
          color: Colors.red,
          backgroundColor: Colors.grey.shade200,
          onRefresh: _handleRefresh,
          child: FutureBuilder<HomeData>(
            future: _futureHomeData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.red,
                    ),
                  ),
                );
              } else if (snapshot.hasError) {
                log("FutureBuilder Error: ${snapshot.error}");
                return const Center(
                  child: Text(
                    "Error loading data. Please try again.",
                    style: TextStyle(color: Colors.red),
                  ),
                );
              } else if (!snapshot.hasData ||
                  snapshot.data!.result == null ||
                  snapshot.data!.result!.isEmpty) {
                return const Center(child: Text("No game data available."));
              }

              final results = snapshot.data!.result!;

              // ✅ Make the WHOLE section reactive to accountStatus changes
              return Obx(() {
                final acc = userController.accountStatus.value;

                return Container(
                  color: Colors.grey.shade300,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      const SizedBox(height: 5),

                      // Marquee
                      if (acc)
                        FutureBuilder<ContactDetails?>(
                          future: _futureContactDetails,
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              final homepageContent =
                                  snapshot.data!.homepageContent ?? '';
                              if (homepageContent.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return SizedBox(
                                height: 30,
                                child: Marquee(
                                  text:
                                      homepageContent +
                                      List.filled(10, '\t').join(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                  scrollAxis: Axis.horizontal,
                                  blankSpace: 50.0,
                                  velocity: 30.0,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                      if (acc) const SizedBox(height: 12),

                      // Category Buttons
                      if (acc)
                        Row(
                          children: [
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CustomCategoryButton(
                                title: _t("KING STARLINE"),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const KingStarlineDashboardScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CustomCategoryButton(
                                title: _t("King Jackpot"),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => KingJackpotDashboard(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),

                      if (acc) const SizedBox(height: 16),

                      // Contact row
                      if (acc)
                        FutureBuilder<ContactDetails?>(
                          future: _futureContactDetails,
                          builder: (context, contactSnapshot) {
                            if (contactSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red,
                                ),
                              );
                            }
                            if (contactSnapshot.hasData &&
                                contactSnapshot.data != null) {
                              final contactData = contactSnapshot.data!;
                              // Optional: cache whatsapp in storage
                              if ((contactData.whatsappNo ?? '').isNotEmpty) {
                                _storage.write(
                                  'whatsappNo',
                                  contactData.whatsappNo,
                                );
                              }
                              return Row(
                                children: [
                                  _ContactItem(contactData.whatsappNo ?? 'N/A'),
                                  const Spacer(),
                                  _ContactItem(contactData.mobileNo ?? 'N/A'),
                                ],
                              );
                            }
                            return const Center(
                              child: Text("Contact info unavailable."),
                            );
                          },
                        ),

                      if (acc) const SizedBox(height: 16),

                      // Game Cards (always visible as per your original code)
                      ...results.map(
                        (game) => _GameCard(
                          id: game.gameId,
                          title: game.gameName,
                          result: game.result,
                          open: game.openTime,
                          close: game.closeTime,
                          openBidLastTime: game.openTime,
                          closeBidLastTime: game.closeTime,
                          status: game.statusText,
                          statusColor:
                              game.statusText.toLowerCase().contains("open")
                              ? Colors.green
                              : Colors.red,
                          accountStatus: acc,
                          openSessionStatus: game.openSessionStatus,
                          closeSessionStatus: game.closeSessionStatus,
                          getTranslatedString: _t,
                        ),
                      ),
                    ],
                  ),
                );
              });
            },
          ),
        ),
      ),
    );
  }
}

// ---------------- Extracted Widgets ----------------
class _CustomCategoryButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _CustomCategoryButton({
    required this.title,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow,
                color: Colors.grey.shade600,
                size: 18,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  final String number;

  const _ContactItem(this.number);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final cleanNumber = number
            .replaceAll('+91', '')
            .replaceAll(' ', '')
            .trim();
        final url = Uri.parse("https://wa.me/$cleanNumber");

        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          log("Could not launch $url");
        }
      },
      child: Row(
        children: [
          Image.asset(
            "assets/images/whatsapp_figma.png",
            height: 25,
            width: 25,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.phone, color: Colors.green, size: 25);
            },
          ),
          const SizedBox(width: 5),
          Text(
            number,
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final int id;
  final String title;
  final String result;
  final String open;
  final String close;
  final String openBidLastTime;
  final String closeBidLastTime;
  final String status;
  final Color statusColor;
  final bool accountStatus;
  final bool openSessionStatus;
  final bool closeSessionStatus;
  final String Function(String) getTranslatedString;

  const _GameCard({
    required this.id,
    required this.title,
    required this.result,
    required this.open,
    required this.close,
    required this.openBidLastTime,
    required this.closeBidLastTime,
    required this.status,
    required this.statusColor,
    required this.accountStatus,
    required this.openSessionStatus,
    required this.closeSessionStatus,
    required this.getTranslatedString,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: title + result + times
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      "${getTranslatedString("Open Bid")}\n$open",
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 40),
                    Text(
                      "${getTranslatedString("Close Bid")}\n$close",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right: CTA (only if account active)
          if (accountStatus)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    final s = status.toLowerCase();
                    if (s.contains("closed for today") ||
                        s.contains("holiday for today")) {
                      closeBidDialogue(
                        context: context,
                        gameName: title,
                        openResultTime: open,
                        openBidLastTime: openBidLastTime,
                        closeResultTime: close,
                        closeBidLastTime: closeBidLastTime,
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GameMenuScreen(
                            title: title,
                            gameId: id,
                            openSessionStatus: openSessionStatus,
                            closeSessionStatus: closeSessionStatus,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  getTranslatedString("Play Game"),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
