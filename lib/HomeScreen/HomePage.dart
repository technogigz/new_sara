import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:marquee/marquee.dart';
import 'package:url_launcher/url_launcher.dart';

import '../KingStarline&Jackpot/KingJackpotDashboard.dart';
import '../KingStarline&Jackpot/KingStarlineDashboard.dart';
import '../components/closeBidDialogue.dart';
import '../game/GameScreen.dart';
import '../ulits/Constents.dart';

// Placeholder for TranslationHelper
class TranslationHelper {
  static Future<String> translate(String text, String lang) async {
    // Dummy translation for demonstration
    return text;
  }
}

// HomeData.dart content
class HomeData {
  final bool status;
  final String msg;
  final List<Info>? result;

  HomeData({required this.status, required this.msg, this.result});

  factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
    status: json["status"],
    msg: json["msg"],
    result: json["info"] == null
        ? null
        : List<Info>.from(json["info"].map((x) => Info.fromJson(x))),
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
    gameId: json["gameId"],
    gameName: json["gameName"],
    openTime: json["openTime"],
    closeTime: json["closeTime"],
    result: json["result"],
    statusText: json["statusText"],
    playStatus: json["playStatus"],
    openSessionStatus: json["openSessionStatus"],
    closeSessionStatus: json["closeSessionStatus"],
  );
}

HomeData homeDataFromJson(String str) => HomeData.fromJson(json.decode(str));

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<HomeData> futureHomeData;
  String preferredLanguage = 'en'; // Not from storage
  Map<String, String> translatedTexts = {};
  Map<String, String> uiStrings = {};

  String accessToken = '';
  String registerId = '';
  bool accountStatus = false;
  final storage = GetStorage();

  @override
  void initState() {
    super.initState();
    storage.write('isLoggedIn', true);
    // Initial read
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = storage.read('accountStatus') ?? false;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    // Auto-update on key change
    storage.listenKey('accessToken', (value) {
      setState(() {
        accessToken = value ?? '';
      });
    });

    storage.listenKey('registerId', (value) {
      setState(() {
        registerId = value ?? '';
      });
    });

    storage.listenKey('accountStatus', (value) {
      setState(() {
        accountStatus = value ?? false;
      });
    });

    storage.listenKey('selectedLanguage', (value) {
      setState(() {
        preferredLanguage = value ?? 'en';
      });
    });

    futureHomeData = fetchDashboardData();
    preTranslateUI(); // translate all UI strings
  }

  Future<void> preTranslateUI() async {
    final keys = [
      "KING STARLINE",
      "King Jackpot",
      "Play Game",
      "Open Bid",
      "Close Bid",
      "24X7 Helpline: +919649115777. Available Languages: English • Hindi • Telugu • Kannada",
      "Market Closed",
    ];

    for (final key in keys) {
      uiStrings[key] = await TranslationHelper.translate(
        key,
        preferredLanguage,
      );
    }

    if (mounted) setState(() {});
  }

  Future<String> tr(String text) async {
    if (preferredLanguage == 'en') return text;
    if (translatedTexts.containsKey(text)) return translatedTexts[text]!;
    final translated = await TranslationHelper.translate(
      text,
      preferredLanguage,
    );
    translatedTexts[text] = translated;
    return translated;
  }

  Future<void> _handleRefresh() async {
    final updatedData = await fetchDashboardData();
    registerId = GetStorage().read('registerId') ?? '';
    setState(() {
      futureHomeData = Future.value(updatedData);
      log("Barrier token: ${GetStorage().read('accessToken')}");

      fetchAndSaveUserDetails(registerId);
    });
  }

  Future<void> fetchAndSaveUserDetails(String registerId) async {
    final url = Uri.parse('${Constant.apiEndpoint}user-details-by-register-id');
    String accessToken = storage.read('accessToken');

    log("Register Id: $registerId");
    log("Access Token: $accessToken");

    try {
      final response = await http.post(
        url,
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({"registerId": registerId}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final info = responseData['info'];
        log("User details: $info");

        // Save individual fields to GetStorage
        storage.write('userId', info['userId']);
        storage.write('fullName', info['fullName']);
        storage.write('emailId', info['emailId']);
        storage.write('mobileNo', info['mobileNo']);
        storage.write('mobileNoEnc', info['mobileNoEnc']);
        storage.write('walletBalance', info['walletBalance']);
        storage.write('profilePicture', info['profilePicture']);
        storage.write('accountStatus', info['accountStatus']);
        storage.write('betStatus', info['betStatus']);

        log("✅ User details saved to GetStorage:");
        info.forEach((key, value) => log('$key: $value'));
      } else {
        print("❌ Failed: ${response.statusCode} => ${response.body}");
      }
    } catch (e) {
      print("❌ Exception: $e");
    }
  }

  Future<HomeData> fetchDashboardData() async {
    final response = await http.post(
      Uri.parse("${Constant.apiEndpoint}game-list"),
      headers: {
        "Content-Type": "application/json",
        "deviceId": "qwert",
        "deviceName": "sm2233",
        "accessStatus": "1",
        "Authorization": "Bearer $accessToken",
      },
      body: json.encode({"registerId": registerId}),
    );

    if (response.statusCode == 200) {
      return homeDataFromJson(response.body);
    } else {
      throw Exception(
        "Failed to load dashboard data: ${response.statusCode} - ${response.body}",
      );
    }
  }

  String _formatResult(String? open, String? close) {
    final formattedOpen = (open != null && open.isNotEmpty) ? open : "***";
    final formattedClose = (close != null && close.isNotEmpty) ? close : "***";
    return "$formattedOpen - $formattedClose";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.grey.shade200,
        child: RefreshIndicator(
          color: Colors.orange,
          backgroundColor: Colors.grey.shade200,
          onRefresh: _handleRefresh,
          child: FutureBuilder<HomeData>(
            future: futureHomeData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.amber,
                    ),
                  ),
                );
              } else if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              } else if (!snapshot.hasData ||
                  snapshot.data!.result == null ||
                  snapshot.data!.result!.isEmpty) {
                return const Center(child: Text("No game data available."));
              }

              final results = snapshot.data!.result!;

              return Container(
                color: Colors.grey.shade300,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const SizedBox(height: 5),

                    // Marquee if visible
                    if (accountStatus)
                      SizedBox(
                        height: 30,
                        child: Marquee(
                          text:
                              (uiStrings["24X7 Helpline: +919649115777. Available Languages: English • Hindi • Telugu • Kannada"] ??
                                  "24X7 Helpline...") +
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
                      ),

                    if (accountStatus) const SizedBox(height: 12),

                    // Category Buttons if visible
                    if (accountStatus)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _customCategoryButton(
                            uiStrings["KING STARLINE"] ?? "KING STARLINE",
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => KingStarlineDashboardScreen(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(width: 5),
                          _customCategoryButton(
                            uiStrings["King Jackpot"] ?? "King Jackpot",
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => KingJackpotDashboard(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                    if (accountStatus) const SizedBox(height: 16),

                    // Contact Items if visible
                    if (accountStatus)
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _contactItem("+919649115777", isVisible: true),
                            Spacer(),
                            _contactItem("+918875115777", isVisible: true),
                          ],
                        ),
                      ),

                    if (accountStatus) const SizedBox(height: 16),

                    // Game Cards
                    for (var game in results)
                      _buildCustomGameCard(
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
                        accountStatus: accountStatus,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Category Buttons
  Widget _customCategoryButton(String title, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.3,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Contact Items
  Widget _contactItem(String number, {bool isVisible = true}) {
    return Visibility(
      visible: isVisible,
      child: GestureDetector(
        onTap: () async {
          final cleanNumber = number.replaceAll('+', '').replaceAll(' ', '');
          final url = Uri.parse("https://wa.me/$cleanNumber");

          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          } else {
            debugPrint("Could not launch $url");
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
      ),
    );
  }

  // Game Cards
  Widget _buildCustomGameCard({
    required String title,
    required String result,
    required String open,
    required String close,
    required String openBidLastTime,
    required String closeBidLastTime,
    required String status,
    required Color statusColor,
    required bool accountStatus,
    required id, // true = active, false = inactive/suspended
  }) {
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
          // Left content: Game name, result, bid times
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    color: const Color(0xFFF9B233),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      "${uiStrings["Open Bid"] ?? "Open Bid"}\n$open",
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 40),
                    Text(
                      "${uiStrings["Close Bid"] ?? "Close Bid"}\n$close",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right content: Only shown if account is active
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
                    if (status.toLowerCase().contains("closed for today") ||
                        status.toLowerCase().contains("holiday for today")) {
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
                          builder: (_) =>
                              GameMenuScreen(title: "$title", gameId: id),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      size: 30,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  uiStrings["Play Game"] ?? "Play Game",
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
