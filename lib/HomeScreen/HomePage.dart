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

// Placeholder for TranslationHelper - Assuming this is an external helper
class TranslationHelper {
  static Future<String> translate(String text, String lang) async {
    // In a real application, this would involve an actual translation service
    // For demonstration, we just return the text.
    await Future.delayed(Duration(milliseconds: 5)); // Simulate network delay
    return text;
  }
}

// --- Data Models ---
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

// --- NEW DATA MODEL FOR CONTACTS ---
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

HomeData homeDataFromJson(String str) => HomeData.fromJson(json.decode(str));

// --- HomePage Widget ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<HomeData> _futureHomeData;
  late Future<ContactDetails?> _futureContactDetails; // NEW FUTURE
  late String _preferredLanguage;
  final Map<String, String> _translatedUiStrings = {};
  final GetStorage _storage = GetStorage();

  late String mobile;
  late String mobileNumber;
  late String name;
  late bool? accountActiveStatus;
  late String walletBallence;
  bool _accountStatus = false;

  // List of UI keys to pre-translate
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
    _loadInitialData();
    _preTranslateUI();
    _futureHomeData = _fetchDashboardData();
    _futureContactDetails = fetchContactDetail(); // INITIALIZE THE NEW FUTURE

    // Listen for language changes and refresh UI strings
    _storage.listenKey('selectedLanguage', (value) {
      if (_preferredLanguage != (value ?? 'en')) {
        _preferredLanguage = value ?? 'en';
        _preTranslateUI();
      }
    });
    // Listen for account status changes
    _storage.listenKey('accountStatus', (value) {
      if (_accountStatus != (value ?? false)) {
        setState(() {
          _accountStatus = value ?? false;
        });
      }
    });
  }

  void _loadInitialData() {
    mobile = _storage.read('mobileNoEnc') ?? '';
    mobileNumber = _storage.read('mobileNo') ?? '';
    name = _storage.read('fullName') ?? '';
    accountActiveStatus = _storage.read('accountStatus');
    walletBallence = _storage.read('walletBalance') ?? '';
    _preferredLanguage = _storage.read('selectedLanguage') ?? 'en';
    _accountStatus = _storage.read('accountStatus') ?? false;
  }

  @override
  void dispose() {
    super.dispose();
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

  String _getTranslatedString(String key) {
    return _translatedUiStrings[key] ?? key;
  }

  Future<void> _handleRefresh() async {
    final registerId = _storage.read('registerId') ?? '';
    if (registerId.isNotEmpty) {
      await _fetchAndSaveUserDetails(registerId);
    }

    try {
      final updatedHomeData = await _fetchDashboardData();
      final updatedContactDetails = await fetchContactDetail();
      setState(() {
        _futureHomeData = Future.value(updatedHomeData);
        _futureContactDetails = Future.value(updatedContactDetails);
        _loadInitialData();
      });
    } catch (e) {
      log("Error during refresh: $e");
    }
  }

  // MODIFIED TO RETURN FUTURE<ContactDetails?>
  Future<ContactDetails?> fetchContactDetail() async {
    final url = Uri.parse('${Constant.apiEndpoint}contact-detail');
    final headers = {
      'deviceId': 'qwert',
      'deviceName': 'sm2233',
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${_storage.read('accessToken')}',
    };

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        log('✅ Contact details fetched: $data');

        final contactInfo = data['info']?['contactInfo'];
        final videosInfo = data['info']?['videosInfo'];

        return ContactDetails(
          mobileNo: contactInfo?['mobileNo'] as String?,
          whatsappNo: contactInfo?['whatsappNo'] as String?,
          appLink: contactInfo?['appLink'] as String?,
          homepageContent: contactInfo?['homepageContent'] as String?,
          videoDescription: videosInfo?['description'] as String?,
        );
      } else {
        log(
          '❌ Failed with status: ${response.statusCode}, body: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      log('❗ Error fetching contact details: $e');
      return null;
    }
  }

  Future<void> _fetchAndSaveUserDetails(String registerId) async {
    final url = Uri.parse('${Constant.apiEndpoint}user-details-by-register-id');
    final String currentAccessToken = _storage.read('accessToken') ?? '';
    log("Fetching user details for Register Id: $registerId");
    log("Using Access Token: $currentAccessToken");
    try {
      final response = await http.post(
        url,
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $currentAccessToken',
        },
        body: jsonEncode({"registerId": registerId}),
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final info = responseData['info'];
        log("User details received: $info");
        _storage.write('userId', info['userId']);
        _storage.write('fullName', info['fullName']);
        _storage.write('emailId', info['emailId']);
        _storage.write('mobileNo', info['mobileNo']);
        _storage.write('mobileNoEnc', info['mobileNoEnc']);
        _storage.write('walletBalance', info['walletBalance']);
        _storage.write('profilePicture', info['profilePicture']);
        _storage.write('accountStatus', info['accountStatus']);
        _storage.write('betStatus', info['betStatus']);
        log("✅ User details saved to GetStorage.");
      } else {
        log(
          "❌ Failed to fetch user details: ${response.statusCode} => ${response.body}",
        );
      }
    } catch (e) {
      log("❌ Exception fetching user details: $e");
    }
  }

  Future<HomeData> _fetchDashboardData() async {
    final String currentAccessToken = _storage.read('accessToken') ?? '';
    final String currentRegisterId = _storage.read('registerId') ?? '';

    if (currentAccessToken.isEmpty || currentRegisterId.isEmpty) {
      log("❌ Aborting API call: Missing access token or register ID.");
      return HomeData(status: false, msg: "User not logged in", result: []);
    }

    final response = await http.post(
      Uri.parse("${Constant.apiEndpoint}game-list"),
      headers: {
        "Content-Type": "application/json",
        "deviceId": "qwert",
        "deviceName": "sm2233",
        "accessStatus": "1",
        "Authorization": "Bearer $currentAccessToken",
      },
      body: json.encode({"registerId": currentRegisterId}),
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
          color: Colors.orange,
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
                      color: Colors.orange,
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

              return Container(
                color: Colors.grey.shade300,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const SizedBox(height: 5),

                    // Marquee if visible
                    if (_accountStatus)
                      FutureBuilder<ContactDetails?>(
                        future: _futureContactDetails,
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            final homepageContent =
                                snapshot.data!.homepageContent ?? '';
                            return SizedBox(
                              height: 30,
                              child: Marquee(
                                text: homepageContent.isNotEmpty
                                    ? homepageContent +
                                          List.filled(10, '\t').join()
                                    : _getTranslatedString(
                                            "24X7 Helpline: +919649115777. Available Languages: English • Hindi • Telugu • Kannada",
                                          ) +
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
                          return const SizedBox.shrink(); // Hide the marquee if data is not available
                        },
                      ),

                    if (_accountStatus) const SizedBox(height: 12),

                    // Category Buttons if visible
                    if (_accountStatus)
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CustomCategoryButton(
                                title: _getTranslatedString("KING STARLINE"),
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
                                title: _getTranslatedString("King Jackpot"),
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
                      ),

                    if (_accountStatus) const SizedBox(height: 16),

                    // NEW FUTURE BUILDER FOR CONTACT DETAILS
                    if (_accountStatus)
                      FutureBuilder<ContactDetails?>(
                        future: _futureContactDetails,
                        builder: (context, contactSnapshot) {
                          if (contactSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          if (contactSnapshot.hasData &&
                              contactSnapshot.data != null) {
                            final contactData = contactSnapshot.data!;
                            _storage.write(
                              'whatsappNo',
                              contactData.homepageContent,
                            );
                            return Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Pass the whatsapp number to the widget
                                  _ContactItem(contactData.whatsappNo ?? 'N/A'),
                                  const Spacer(),
                                  _ContactItem(contactData.mobileNo ?? 'N/A'),
                                ],
                              ),
                            );
                          }
                          // If there's an error or no data, show a default message or nothing
                          return const Center(
                            child: Text("Contact info unavailable."),
                          );
                        },
                      ),

                    if (_accountStatus) const SizedBox(height: 16),

                    // Game Cards
                    ...results
                        .map(
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
                            accountStatus: _accountStatus,
                            openSessionStatus: game.openSessionStatus,
                            closeSessionStatus: game.closeSessionStatus,
                            getTranslatedString: _getTranslatedString,
                          ),
                        )
                        .toList(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// --- Extracted Widgets ---
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
          color: Colors.orange,
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
        final cleanNumber = number.replaceAll('+', '').replaceAll(' ', '');
        final url = Uri.parse("https://wa.me/$cleanNumber");

        if (await canLaunchUrl(url)) {
          await launchUrl(url);
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
  final Function(String) getTranslatedString;

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
                    color: Colors.orange,
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
                      color: Colors.orange,
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

// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:marquee/marquee.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// import '../KingStarline&Jackpot/KingJackpotDashboard.dart';
// import '../KingStarline&Jackpot/KingStarlineDashboard.dart';
// import '../components/closeBidDialogue.dart';
// import '../game/GameScreen.dart';
// import '../ulits/Constents.dart';
//
// // Placeholder for TranslationHelper - Assuming this is an external helper
// class TranslationHelper {
//   static Future<String> translate(String text, String lang) async {
//     // In a real application, this would involve an actual translation service
//     // For demonstration, we just return the text.
//     await Future.delayed(Duration(milliseconds: 5)); // Simulate network delay
//     return text;
//   }
// }
//
// // --- Data Models ---
// // HomeData.dart content
// class HomeData {
//   final bool status;
//   final String msg;
//   final List<Info>? result;
//
//   HomeData({required this.status, required this.msg, this.result});
//
//   factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
//     status: json["status"],
//     msg: json["msg"],
//     result: json["info"] == null
//         ? null
//         : List<Info>.from(json["info"].map((x) => Info.fromJson(x))),
//   );
// }
//
// class Info {
//   final int gameId;
//   final String gameName;
//   final String openTime;
//   final String closeTime;
//   final String result;
//   final String statusText;
//   final bool playStatus;
//   final bool openSessionStatus;
//   final bool closeSessionStatus;
//
//   Info({
//     required this.gameId,
//     required this.gameName,
//     required this.openTime,
//     required this.closeTime,
//     required this.result,
//     required this.statusText,
//     required this.playStatus,
//     required this.openSessionStatus,
//     required this.closeSessionStatus,
//   });
//
//   factory Info.fromJson(Map<String, dynamic> json) => Info(
//     gameId: json["gameId"],
//     gameName: json["gameName"],
//     openTime: json["openTime"],
//     closeTime: json["closeTime"],
//     result: json["result"],
//     statusText: json["statusText"],
//     playStatus: json["playStatus"],
//     openSessionStatus: json["openSessionStatus"],
//     closeSessionStatus: json["closeSessionStatus"],
//   );
// }
//
// // --- NEW DATA MODEL FOR CONTACTS ---
// class ContactDetails {
//   final String? mobileNo;
//   final String? whatsappNo;
//   final String? appLink;
//   final String? homepageContent;
//   final String? videoDescription;
//
//   ContactDetails({
//     this.mobileNo,
//     this.whatsappNo,
//     this.appLink,
//     this.homepageContent,
//     this.videoDescription,
//   });
// }
//
// HomeData homeDataFromJson(String str) => HomeData.fromJson(json.decode(str));
//
// // --- HomePage Widget ---
// class HomePage extends StatefulWidget {
//   const HomePage({super.key});
//
//   @override
//   State<HomePage> createState() => _HomePageState();
// }
//
// class _HomePageState extends State<HomePage> {
//   late Future<HomeData> _futureHomeData; // Use _ for private variables
//   late String _preferredLanguage;
//   final Map<String, String> _translatedUiStrings = {}; // Cache UI strings
//   final GetStorage _storage = GetStorage(); // Use _ for private
//
//   late String mobile;
//   late String mobileNumber;
//   late String name;
//   late bool? accountActiveStatus;
//   late String walletBallence;
//   bool _accountStatus = false;
//
//   // List of UI keys to pre-translate
//   static const List<String> _uiKeysToTranslate = [
//     "KING STARLINE",
//     "King Jackpot",
//     "Play Game",
//     "Open Bid",
//     "Close Bid",
//     "24X7 Helpline: +919649115777. Available Languages: English • Hindi • Telugu • Kannada",
//     "Market Closed",
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _loadInitialData();
//     _preTranslateUI();
//     _futureHomeData = _fetchDashboardData();
//
//     // Listen for language changes and refresh UI strings
//     _storage.listenKey('selectedLanguage', (value) {
//       if (_preferredLanguage != (value ?? 'en')) {
//         _preferredLanguage = value ?? 'en';
//         _preTranslateUI();
//       }
//     });
//     // Listen for account status changes
//     _storage.listenKey('accountStatus', (value) {
//       if (_accountStatus != (value ?? false)) {
//         setState(() {
//           _accountStatus = value ?? false;
//         });
//       }
//     });
//   }
//
//   void _loadInitialData() {
//     mobile = _storage.read('mobileNoEnc') ?? '';
//     mobileNumber = _storage.read('mobileNo') ?? '';
//     name = _storage.read('fullName') ?? '';
//     accountActiveStatus = _storage.read('accountStatus');
//     walletBallence = _storage.read('walletBalance') ?? '';
//     _preferredLanguage = _storage.read('selectedLanguage') ?? 'en';
//     _accountStatus = _storage.read('accountStatus') ?? false;
//
//     fetchContactDetail();
//   }
//
//   @override
//   void dispose() {
//     // There are no explicit `cancel` methods for GetStorage listeners
//     super.dispose();
//   }
//
//   Future<void> _preTranslateUI() async {
//     for (final key in _uiKeysToTranslate) {
//       if (!_translatedUiStrings.containsKey(key) ||
//           _translatedUiStrings[key] == key) {
//         _translatedUiStrings[key] = await TranslationHelper.translate(
//           key,
//           _preferredLanguage,
//         );
//       }
//     }
//     if (mounted) setState(() {});
//   }
//
//   String _getTranslatedString(String key) {
//     return _translatedUiStrings[key] ?? key;
//   }
//
//   Future<void> _handleRefresh() async {
//     // Read the latest register ID from storage
//     final registerId = _storage.read('registerId') ?? '';
//
//     // Fetch user details first, this will refresh the wallet balance and other details
//     if (registerId.isNotEmpty) {
//       await _fetchAndSaveUserDetails(registerId);
//     }
//
//     // Now fetch the dashboard data with the potentially updated user info
//     try {
//       final updatedData = await _fetchDashboardData();
//       setState(() {
//         _futureHomeData = Future.value(updatedData);
//         _loadInitialData(); // Reload local state variables with fresh data
//       });
//     } catch (e) {
//       // Handle the error, maybe show a snackbar
//       log("Error during refresh: $e");
//     }
//   }
//
//   // MODIFIED TO RETURN FUTURE<ContactDetails?>
//   Future<ContactDetails?> fetchContactDetail() async {
//     final url = Uri.parse('${Constant.apiEndpoint}contact-detail');
//     final headers = {
//       'deviceId': 'qwert',
//       'deviceName': 'sm2233',
//       'accessStatus': '1',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer ${_storage.read('accessToken')}',
//     };
//
//     try {
//       final response = await http.get(url, headers: headers);
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         log('✅ Contact details fetched: $data');
//
//         final contactInfo = data['info']?['contactInfo'];
//         final videosInfo = data['info']?['videosInfo'];
//
//         return ContactDetails(
//           mobileNo: contactInfo?['mobileNo'] as String?,
//           whatsappNo: contactInfo?['whatsappNo'] as String?,
//           appLink: contactInfo?['appLink'] as String?,
//           homepageContent: contactInfo?['homepageContent'] as String?,
//           videoDescription: videosInfo?['description'] as String?,
//         );
//       } else {
//         log(
//           '❌ Failed with status: ${response.statusCode}, body: ${response.body}',
//         );
//         return null;
//       }
//     } catch (e) {
//       log('❗ Error fetching contact details: $e');
//       return null;
//     }
//   }
//
//   Future<void> _fetchAndSaveUserDetails(String registerId) async {
//     final url = Uri.parse('${Constant.apiEndpoint}user-details-by-register-id');
//     final String currentAccessToken = _storage.read('accessToken') ?? '';
//     log("Fetching user details for Register Id: $registerId");
//     log("Using Access Token: $currentAccessToken");
//     try {
//       final response = await http.post(
//         url,
//         headers: {
//           'deviceId': 'qwert',
//           'deviceName': 'sm2233',
//           'accessStatus': '1',
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $currentAccessToken',
//         },
//         body: jsonEncode({"registerId": registerId}),
//       );
//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);
//         final info = responseData['info'];
//         log("User details received: $info");
//         // Update GetStorage with the latest user data
//         _storage.write('userId', info['userId']);
//         _storage.write('fullName', info['fullName']);
//         _storage.write('emailId', info['emailId']);
//         _storage.write('mobileNo', info['mobileNo']);
//         _storage.write('mobileNoEnc', info['mobileNoEnc']);
//         _storage.write('walletBalance', info['walletBalance']);
//         _storage.write('profilePicture', info['profilePicture']);
//         _storage.write('accountStatus', info['accountStatus']);
//         _storage.write('betStatus', info['betStatus']);
//         log("✅ User details saved to GetStorage.");
//       } else {
//         log(
//           "❌ Failed to fetch user details: ${response.statusCode} => ${response.body}",
//         );
//       }
//     } catch (e) {
//       log("❌ Exception fetching user details: $e");
//     }
//   }
//
//   Future<HomeData> _fetchDashboardData() async {
//     // Read the latest token and register ID directly before the call
//     final String currentAccessToken = _storage.read('accessToken') ?? '';
//     final String currentRegisterId = _storage.read('registerId') ?? '';
//
//     if (currentAccessToken.isEmpty || currentRegisterId.isEmpty) {
//       log("❌ Aborting API call: Missing access token or register ID.");
//       // Return a dummy object or throw an error to prevent a crash
//       return HomeData(status: false, msg: "User not logged in", result: []);
//     }
//
//     final response = await http.post(
//       Uri.parse("${Constant.apiEndpoint}game-list"),
//       headers: {
//         "Content-Type": "application/json",
//         "deviceId": "qwert",
//         "deviceName": "sm2233",
//         "accessStatus": "1",
//         "Authorization": "Bearer $currentAccessToken",
//       },
//       body: json.encode({"registerId": currentRegisterId}),
//     );
//
//     if (response.statusCode == 200) {
//       return homeDataFromJson(response.body);
//     } else {
//       log(
//         "Failed to load dashboard data: ${response.statusCode} - ${response.body}",
//       );
//       throw Exception(
//         "Failed to load dashboard data: ${response.statusCode} - ${response.body}",
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         color: Colors.grey.shade200,
//         child: RefreshIndicator(
//           color: Colors.orange,
//           backgroundColor: Colors.grey.shade200,
//           onRefresh: _handleRefresh,
//           child: FutureBuilder<HomeData>(
//             future: _futureHomeData,
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(
//                   child: SizedBox(
//                     width: 28,
//                     height: 28,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 3,
//                       color: Colors.orange,
//                     ),
//                   ),
//                 );
//               } else if (snapshot.hasError) {
//                 log("FutureBuilder Error: ${snapshot.error}");
//                 // Show a user-friendly error message
//                 return Center(
//                   child: Text(
//                     "Error loading data. Please try again.",
//                     style: TextStyle(color: Colors.red),
//                   ),
//                 );
//               } else if (!snapshot.hasData ||
//                   snapshot.data!.result == null ||
//                   snapshot.data!.result!.isEmpty) {
//                 return const Center(child: Text("No game data available."));
//               }
//
//               final results = snapshot.data!.result!;
//
//               return Container(
//                 color: Colors.grey.shade300,
//                 child: ListView(
//                   padding: const EdgeInsets.all(12),
//                   children: [
//                     const SizedBox(height: 5),
//
//                     // Marquee if visible
//                     if (_accountStatus)
//                       SizedBox(
//                         height: 30,
//                         child: Marquee(
//                           text:
//                               _getTranslatedString(
//                                 "24X7 Helpline: +919649115777. Available Languages: English • Hindi • Telugu • Kannada",
//                               ) +
//                               List.filled(10, '\t').join(),
//                           style: GoogleFonts.poppins(
//                             color: Colors.red,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 22,
//                           ),
//                           scrollAxis: Axis.horizontal,
//                           blankSpace: 50.0,
//                           velocity: 30.0,
//                         ),
//                       ),
//
//                     if (_accountStatus) const SizedBox(height: 12),
//
//                     // Category Buttons if visible
//                     if (_accountStatus)
//                       SizedBox(
//                         width: double.infinity,
//                         child: Row(
//                           children: [
//                             const SizedBox(width: 8),
//                             Expanded(
//                               child: _CustomCategoryButton(
//                                 title: _getTranslatedString("KING STARLINE"),
//                                 onTap: () {
//                                   Navigator.of(context).push(
//                                     MaterialPageRoute(
//                                       builder: (_) =>
//                                           const KingStarlineDashboardScreen(),
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             Expanded(
//                               child: _CustomCategoryButton(
//                                 title: _getTranslatedString("King Jackpot"),
//                                 onTap: () {
//                                   Navigator.of(context).push(
//                                     MaterialPageRoute(
//                                       builder: (_) => KingJackpotDashboard(),
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                           ],
//                         ),
//                       ),
//
//                     if (_accountStatus) const SizedBox(height: 16),
//
//                     // Contact Items if visible
//                     if (_accountStatus)
//                       // NEW FUTURE BUILDER FOR CONTACT DETAILS
//                       if (_accountStatus)
//                         FutureBuilder<ContactDetails?>(
//                           future: fetchContactDetail(),
//                           builder: (context, contactSnapshot) {
//                             if (contactSnapshot.connectionState ==
//                                 ConnectionState.waiting) {
//                               return const Center(
//                                 child: CircularProgressIndicator(
//                                   strokeWidth: 2,
//                                 ),
//                               );
//                             }
//                             if (contactSnapshot.hasData &&
//                                 contactSnapshot.data != null) {
//                               final contactData = contactSnapshot.data!;
//                               return Center(
//                                 child: Row(
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: [
//                                     // Pass the whatsapp number to the widget
//                                     _ContactItem(
//                                       contactData.whatsappNo ?? 'N/A',
//                                     ),
//                                     const Spacer(),
//                                     _ContactItem(contactData.mobileNo ?? 'N/A'),
//                                   ],
//                                 ),
//                               );
//                             }
//                             // If there's an error or no data, show a default message or nothing
//                             return const Center(
//                               child: Text("Contact info unavailable."),
//                             );
//                           },
//                         ),
//
//                     if (_accountStatus) const SizedBox(height: 16),
//
//                     // Game Cards
//                     ...results
//                         .map(
//                           (game) => _GameCard(
//                             id: game.gameId,
//                             title: game.gameName,
//                             result: game.result,
//                             open: game.openTime,
//                             close: game.closeTime,
//                             openBidLastTime: game.openTime,
//                             closeBidLastTime: game.closeTime,
//                             status: game.statusText,
//                             statusColor:
//                                 game.statusText.toLowerCase().contains("open")
//                                 ? Colors.green
//                                 : Colors.red,
//                             accountStatus: _accountStatus,
//                             openSessionStatus: game.openSessionStatus,
//                             closeSessionStatus: game.closeSessionStatus,
//                             getTranslatedString: _getTranslatedString,
//                           ),
//                         )
//                         .toList(),
//                   ],
//                 ),
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // --- Extracted Widgets ---
// class _CustomCategoryButton extends StatelessWidget {
//   final String title;
//   final VoidCallback onTap;
//
//   const _CustomCategoryButton({
//     required this.title,
//     required this.onTap,
//     super.key,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//         decoration: BoxDecoration(
//           color: Colors.orange,
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               width: 28,
//               height: 28,
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(
//                 Icons.play_arrow,
//                 color: Colors.grey.shade600,
//                 size: 18,
//               ),
//             ),
//             const SizedBox(width: 6),
//             Flexible(
//               child: Text(
//                 title.toUpperCase(),
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                   color: Colors.black,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _ContactItem extends StatelessWidget {
//   final String number;
//
//   const _ContactItem(this.number);
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () async {
//         final cleanNumber = number.replaceAll('+', '').replaceAll(' ', '');
//         final url = Uri.parse("https://wa.me/$cleanNumber");
//
//         if (await canLaunchUrl(url)) {
//           await launchUrl(url);
//         } else {
//           log("Could not launch $url");
//         }
//       },
//       child: Row(
//         children: [
//           Image.asset(
//             "assets/images/whatsapp_figma.png",
//             height: 25,
//             width: 25,
//             errorBuilder: (context, error, stackTrace) {
//               return const Icon(Icons.phone, color: Colors.green, size: 25);
//             },
//           ),
//           const SizedBox(width: 5),
//           Text(
//             number,
//             style: GoogleFonts.poppins(
//               color: Colors.black,
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _GameCard extends StatelessWidget {
//   final int id;
//   final String title;
//   final String result;
//   final String open;
//   final String close;
//   final String openBidLastTime;
//   final String closeBidLastTime;
//   final String status;
//   final Color statusColor;
//   final bool accountStatus;
//   final bool openSessionStatus;
//   final bool closeSessionStatus;
//   final Function(String) getTranslatedString;
//
//   const _GameCard({
//     required this.id,
//     required this.title,
//     required this.result,
//     required this.open,
//     required this.close,
//     required this.openBidLastTime,
//     required this.closeBidLastTime,
//     required this.status,
//     required this.statusColor,
//     required this.accountStatus,
//     required this.openSessionStatus,
//     required this.closeSessionStatus,
//     required this.getTranslatedString,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 6),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(10),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.08),
//             blurRadius: 5,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title.toUpperCase(),
//                   style: GoogleFonts.poppins(
//                     fontSize: 24,
//                     color: Colors.black,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   result,
//                   style: GoogleFonts.poppins(
//                     fontSize: 22,
//                     color: const Color(0xFFF9B233),
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 Row(
//                   children: [
//                     Text(
//                       "${getTranslatedString("Open Bid")}\n$open",
//                       style: const TextStyle(fontSize: 14),
//                     ),
//                     const SizedBox(width: 40),
//                     Text(
//                       "${getTranslatedString("Close Bid")}\n$close",
//                       style: const TextStyle(fontSize: 14),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           if (accountStatus)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Text(
//                   status,
//                   style: TextStyle(
//                     color: statusColor,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 GestureDetector(
//                   onTap: () {
//                     if (status.toLowerCase().contains("closed for today") ||
//                         status.toLowerCase().contains("holiday for today")) {
//                       closeBidDialogue(
//                         context: context,
//                         gameName: title,
//                         openResultTime: open,
//                         openBidLastTime: openBidLastTime,
//                         closeResultTime: close,
//                         closeBidLastTime: closeBidLastTime,
//                       );
//                     } else {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (_) => GameMenuScreen(
//                             title: title,
//                             gameId: id,
//                             openSessionStatus: openSessionStatus,
//                             closeSessionStatus: closeSessionStatus,
//                           ),
//                         ),
//                       );
//                     }
//                   },
//                   child: Container(
//                     padding: const EdgeInsets.all(10),
//                     decoration: BoxDecoration(
//                       color: Colors.orange,
//                       borderRadius: BorderRadius.circular(25),
//                     ),
//                     child: Icon(
//                       Icons.play_arrow,
//                       size: 30,
//                       color: Colors.grey.shade600,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 5),
//                 Text(
//                   getTranslatedString("Play Game"),
//                   style: const TextStyle(fontSize: 13),
//                 ),
//               ],
//             ),
//         ],
//       ),
//     );
//   }
// }
//
// // import 'dart:convert';
// // import 'dart:developer';
// //
// // import 'package:flutter/material.dart';
// // import 'package:get_storage/get_storage.dart';
// // import 'package:google_fonts/google_fonts.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:marquee/marquee.dart';
// // import 'package:url_launcher/url_launcher.dart';
// //
// // import '../KingStarline&Jackpot/KingJackpotDashboard.dart';
// // import '../KingStarline&Jackpot/KingStarlineDashboard.dart';
// // import '../components/closeBidDialogue.dart';
// // import '../game/GameScreen.dart';
// // import '../ulits/Constents.dart';
// //
// // // Placeholder for TranslationHelper - Assuming this is an external helper
// // class TranslationHelper {
// //   static Future<String> translate(String text, String lang) async {
// //     // In a real application, this would involve an actual translation service
// //     // For demonstration, we just return the text.
// //     await Future.delayed(Duration(milliseconds: 5)); // Simulate network delay
// //     return text;
// //   }
// // }
// //
// // // --- Data Models ---
// // // HomeData.dart content
// // class HomeData {
// //   final bool status;
// //   final String msg;
// //   final List<Info>? result;
// //
// //   HomeData({required this.status, required this.msg, this.result});
// //
// //   factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
// //     status: json["status"],
// //     msg: json["msg"],
// //     result: json["info"] == null
// //         ? null
// //         : List<Info>.from(json["info"].map((x) => Info.fromJson(x))),
// //   );
// // }
// //
// // class Info {
// //   final int gameId;
// //   final String gameName;
// //   final String openTime;
// //   final String closeTime;
// //   final String result;
// //   final String statusText;
// //   final bool playStatus;
// //   final bool openSessionStatus;
// //   final bool closeSessionStatus;
// //
// //   Info({
// //     required this.gameId,
// //     required this.gameName,
// //     required this.openTime,
// //     required this.closeTime,
// //     required this.result,
// //     required this.statusText,
// //     required this.playStatus,
// //     required this.openSessionStatus,
// //     required this.closeSessionStatus,
// //   });
// //
// //   factory Info.fromJson(Map<String, dynamic> json) => Info(
// //     gameId: json["gameId"],
// //     gameName: json["gameName"],
// //     openTime: json["openTime"],
// //     closeTime: json["closeTime"],
// //     result: json["result"],
// //     statusText: json["statusText"],
// //     playStatus: json["playStatus"],
// //     openSessionStatus: json["openSessionStatus"],
// //     closeSessionStatus: json["closeSessionStatus"],
// //   );
// // }
// //
// // HomeData homeDataFromJson(String str) => HomeData.fromJson(json.decode(str));
// //
// // // --- HomePage Widget ---
// // class HomePage extends StatefulWidget {
// //   const HomePage({super.key});
// //
// //   @override
// //   State<HomePage> createState() => _HomePageState();
// // }
// //
// // class _HomePageState extends State<HomePage> {
// //   late Future<HomeData> _futureHomeData; // Use _ for private variables
// //   late String _preferredLanguage;
// //   final Map<String, String> _translatedUiStrings = {}; // Cache UI strings
// //   final GetStorage _storage = GetStorage(); // Use _ for private
// //
// //   late String accessToken;
// //   late String registerId;
// //   late bool accountStatus;
// //   late String preferredLanguage;
// //   late String mobile;
// //   late String mobileNumber;
// //   late String name;
// //   late bool? accountActiveStatus;
// //   late String walletBallence;
// //   String _accessToken = '';
// //   String _registerId = '';
// //   bool _accountStatus = false;
// //
// //   // List of UI keys to pre-translate
// //   static const List<String> _uiKeysToTranslate = [
// //     "KING STARLINE",
// //     "King Jackpot",
// //     "Play Game",
// //     "Open Bid",
// //     "Close Bid",
// //     "24X7 Helpline: +919649115777. Available Languages: English • Hindi • Telugu • Kannada",
// //     "Market Closed",
// //   ];
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     // Initial reads
// //     mobile = _storage.read('mobileNoEnc') ?? '';
// //     mobileNumber = _storage.read('mobileNo') ?? '';
// //     name = _storage.read('fullName') ?? '';
// //     accountActiveStatus = _storage.read('accountStatus');
// //     walletBallence = _storage.read('walletBalance') ?? '';
// //     _preferredLanguage = _storage.read('selectedLanguage') ?? 'en';
// //     // Listen to updates
// //     _storage.listenKey('mobileNoEnc', (value) => mobile = value);
// //     _storage.listenKey('fullName', (value) => name = value);
// //     _storage.listenKey('accountStatus', (value) => accountActiveStatus = value);
// //     _storage.listenKey('walletBalance', (value) => walletBallence = value);
// //     _handleRefresh(); // This should probably be handled elsewhere if login state is more complex
// //
// //     _setupStorageListeners(); // Setup listeners once
// //     _futureHomeData = _fetchDashboardData();
// //     // Initial data load and user details fetch
// //     _preTranslateUI(); // Translate all UI strings
// //   }
// //
// //   // Dispose listeners to prevent memory leaks
// //   @override
// //   void dispose() {
// //     // GetStorage listeners don't have explicit `cancel` methods like StreamSubscriptions.
// //     // They are typically managed internally by GetStorage or tied to the app's lifecycle.
// //     // However, if you had custom stream subscriptions, you would dispose them here.
// //     super.dispose();
// //   }
// //
// //   //  Sets up listeners for changes in specific GetStorage keys, updating UI state
// //   void _setupStorageListeners() {
// //     // Only update state if the value actually changes to avoid unnecessary rebuilds
// //     _storage.listenKey('accessToken', (value) {
// //       if (_accessToken != (value ?? '')) {
// //         _accessToken = value ?? '';
// //       }
// //     });
// //
// //     _storage.listenKey('registerId', (value) {
// //       if (_registerId != (value ?? '')) {
// //         _registerId = value ?? '';
// //       }
// //     });
// //
// //     _storage.listenKey('accountStatus', (value) {
// //       if (_accountStatus != (value ?? false)) {
// //         _accountStatus = value ?? false;
// //       }
// //     });
// //
// //     _storage.listenKey('selectedLanguage', (value) {
// //       if (_preferredLanguage != (value ?? 'en')) {
// //         _preferredLanguage = value ?? 'en';
// //       }
// //     });
// //     _preTranslateUI();
// //   }
// //
// //   Future<void> _preTranslateUI() async {
// //     for (final key in _uiKeysToTranslate) {
// //       // Only translate if not already translated for the current language
// //       if (!_translatedUiStrings.containsKey(key) ||
// //           _translatedUiStrings[key] == key) {
// //         _translatedUiStrings[key] = await TranslationHelper.translate(
// //           key,
// //           _preferredLanguage,
// //         );
// //       }
// //     }
// //     // Only call setState if translations have actually changed or are newly loaded
// //     if (mounted) setState(() {});
// //   }
// //
// //   // Helper to get translated string, falls back to original if not found
// //   String _getTranslatedString(String key) {
// //     return _translatedUiStrings[key] ?? key;
// //   }
// //
// //   Future<void> _handleRefresh() async {
// //     final updatedData = await _fetchDashboardData();
// //     _registerId =
// //         _storage.read('registerId') ?? ''; // Ensure registerId is fresh
// //     _futureHomeData = Future.value(updatedData);
// //
// //     // Fetch user details separately, it doesn't need to rebuild the entire FutureBuilder
// //     if (_registerId.isNotEmpty) {
// //       await _fetchAndSaveUserDetails(_registerId);
// //     }
// //
// //     setState(() {});
// //   }
// //
// //   Future<void> _fetchAndSaveUserDetails(String registerId) async {
// //     final url = Uri.parse('${Constant.apiEndpoint}user-details-by-register-id');
// //     final String currentAccessToken =
// //         _storage.read('accessToken') ?? ''; // Use current token
// //
// //     log("Fetching user details for Register Id: $registerId");
// //     log("Using Access Token: $currentAccessToken");
// //
// //     try {
// //       final response = await http.post(
// //         url,
// //         headers: {
// //           'deviceId': 'qwert', // Consider making these constants
// //           'deviceName': 'sm2233', // Consider making these constants
// //           'accessStatus': '1', // Consider making these constants
// //           'Content-Type': 'application/json',
// //           'Authorization': 'Bearer $currentAccessToken',
// //         },
// //         body: jsonEncode({"registerId": registerId}),
// //       );
// //
// //       if (response.statusCode == 200) {
// //         final responseData = jsonDecode(response.body);
// //         final info = responseData['info'];
// //         log("User details received: $info");
// //
// //         // Use `_storage.writeIfNull` or check if value changed before writing
// //         // to minimize unnecessary GetStorage writes.
// //         _storage.write('userId', info['userId']);
// //         _storage.write('fullName', info['fullName']);
// //         _storage.write('emailId', info['emailId']);
// //         _storage.write('mobileNo', info['mobileNo']);
// //         _storage.write('mobileNoEnc', info['mobileNoEnc']);
// //         _storage.write('walletBalance', info['walletBalance']);
// //         _storage.write('profilePicture', info['profilePicture']);
// //         _storage.write('accountStatus', info['accountStatus']);
// //         _storage.write('betStatus', info['betStatus']);
// //
// //         log("✅ User details saved to GetStorage.");
// //       } else {
// //         log(
// //           "❌ Failed to fetch user details: ${response.statusCode} => ${response.body}",
// //         );
// //       }
// //     } catch (e) {
// //       log("❌ Exception fetching user details: $e");
// //     }
// //   }
// //
// //   Future<HomeData> _fetchDashboardData() async {
// //     final response = await http.post(
// //       Uri.parse("${Constant.apiEndpoint}game-list"),
// //       headers: {
// //         "Content-Type": "application/json",
// //         "deviceId": "qwert",
// //         "deviceName": "sm2233",
// //         "accessStatus": "1",
// //         "Authorization": "Bearer $_accessToken", // Use the current access token
// //       },
// //       body: json.encode({
// //         "registerId": _registerId,
// //       }), // Use the current registerId
// //     );
// //
// //     if (response.statusCode == 200) {
// //       return homeDataFromJson(response.body);
// //     } else {
// //       log(
// //         "Failed to load dashboard data: ${response.statusCode} - ${response.body}",
// //       );
// //       throw Exception(
// //         "Failed to load dashboard data: ${response.statusCode} - ${response.body}",
// //       );
// //     }
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       body: Container(
// //         color: Colors.grey.shade200,
// //         child: RefreshIndicator(
// //           color: Colors.orange,
// //           backgroundColor: Colors.grey.shade200,
// //           onRefresh: _handleRefresh,
// //           child: FutureBuilder<HomeData>(
// //             future: _futureHomeData,
// //             builder: (context, snapshot) {
// //               if (snapshot.connectionState == ConnectionState.waiting) {
// //                 return const Center(
// //                   child: SizedBox(
// //                     width: 28,
// //                     height: 28,
// //                     child: CircularProgressIndicator(
// //                       strokeWidth: 3,
// //                       color: Colors.orange,
// //                     ),
// //                   ),
// //                 );
// //               } else if (snapshot.hasError) {
// //                 return Center(child: Text("Error: ${snapshot.error}"));
// //               } else if (!snapshot.hasData ||
// //                   snapshot.data!.result == null ||
// //                   snapshot.data!.result!.isEmpty) {
// //                 return const Center(child: Text("No game data available."));
// //               }
// //
// //               final results = snapshot.data!.result!;
// //
// //               return Container(
// //                 color: Colors.grey.shade300,
// //                 child: ListView(
// //                   padding: const EdgeInsets.all(12),
// //                   children: [
// //                     const SizedBox(height: 5),
// //
// //                     // Marquee if visible
// //                     if (_accountStatus)
// //                       SizedBox(
// //                         height: 30,
// //                         child: Marquee(
// //                           text:
// //                               _getTranslatedString(
// //                                 "24X7 Helpline: +919649115777. Available Languages: English • Hindi • Telugu • Kannada",
// //                               ) +
// //                               List.filled(10, '\t').join(),
// //                           style: GoogleFonts.poppins(
// //                             color: Colors.red,
// //                             fontWeight: FontWeight.bold,
// //                             fontSize: 22,
// //                           ),
// //                           scrollAxis: Axis.horizontal,
// //                           blankSpace: 50.0,
// //                           velocity: 30.0,
// //                         ),
// //                       ),
// //
// //                     if (_accountStatus) const SizedBox(height: 12),
// //
// //                     // Category Buttons if visible
// //                     if (_accountStatus)
// //                       SizedBox(
// //                         width: double.infinity,
// //                         child: Row(
// //                           children: [
// //                             const SizedBox(
// //                               width: 8,
// //                             ), // Optional horizontal margin
// //                             Expanded(
// //                               child: _CustomCategoryButton(
// //                                 title: _getTranslatedString("KING STARLINE"),
// //                                 onTap: () {
// //                                   Navigator.of(context).push(
// //                                     MaterialPageRoute(
// //                                       builder: (_) =>
// //                                           const KingStarlineDashboardScreen(),
// //                                     ),
// //                                   );
// //                                 },
// //                               ),
// //                             ),
// //                             const SizedBox(width: 8),
// //                             Expanded(
// //                               child: _CustomCategoryButton(
// //                                 title: _getTranslatedString("King Jackpot"),
// //                                 onTap: () {
// //                                   Navigator.of(context).push(
// //                                     MaterialPageRoute(
// //                                       builder: (_) => KingJackpotDashboard(),
// //                                     ),
// //                                   );
// //                                 },
// //                               ),
// //                             ),
// //                             const SizedBox(width: 8),
// //                           ],
// //                         ),
// //                       ),
// //
// //                     if (_accountStatus) const SizedBox(height: 16),
// //
// //                     // Contact Items if visible
// //                     if (_accountStatus)
// //                       const Center(
// //                         // Made const as children are const
// //                         child: Row(
// //                           mainAxisSize: MainAxisSize.min,
// //                           children: [
// //                             _ContactItem("+919649115777"),
// //                             Spacer(),
// //                             _ContactItem("+918875115777"),
// //                           ],
// //                         ),
// //                       ),
// //
// //                     if (_accountStatus) const SizedBox(height: 16),
// //
// //                     // Game Cards
// //                     ...results
// //                         .map(
// //                           (game) => _GameCard(
// //                             id: game.gameId,
// //                             title: game.gameName,
// //                             result: game.result,
// //                             open: game.openTime,
// //                             close: game.closeTime,
// //                             openBidLastTime: game.openTime,
// //                             closeBidLastTime: game.closeTime,
// //                             status: game.statusText,
// //                             statusColor:
// //                                 game.statusText.toLowerCase().contains("open")
// //                                 ? Colors.green
// //                                 : Colors.red,
// //                             accountStatus: _accountStatus,
// //                             openSessionStatus: game.openSessionStatus,
// //                             closeSessionStatus: game.closeSessionStatus,
// //                             getTranslatedString:
// //                                 _getTranslatedString, // Pass the translation function
// //                           ),
// //                         )
// //                         .toList(),
// //                   ],
// //                 ),
// //               );
// //             },
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // // --- Extracted Widgets for Better Performance and Readability ---
// // class _CustomCategoryButton extends StatelessWidget {
// //   final String title;
// //   final VoidCallback onTap;
// //
// //   const _CustomCategoryButton({
// //     required this.title,
// //     required this.onTap,
// //     super.key,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return GestureDetector(
// //       onTap: onTap,
// //       child: Container(
// //         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
// //         decoration: BoxDecoration(
// //           color: Colors.orange,
// //           borderRadius: BorderRadius.circular(20),
// //         ),
// //         child: Row(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             Container(
// //               width: 28,
// //               height: 28,
// //               decoration: const BoxDecoration(
// //                 color: Colors.white,
// //                 shape: BoxShape.circle,
// //               ),
// //               child: Icon(
// //                 Icons.play_arrow,
// //                 color: Colors.grey.shade600,
// //                 size: 18,
// //               ),
// //             ),
// //             const SizedBox(width: 6),
// //             Flexible(
// //               child: Text(
// //                 title.toUpperCase(),
// //                 overflow: TextOverflow.ellipsis,
// //                 style: const TextStyle(
// //                   fontWeight: FontWeight.bold,
// //                   fontSize: 16,
// //                   color: Colors.black,
// //                 ),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // class _ContactItem extends StatelessWidget {
// //   final String number;
// //
// //   const _ContactItem(this.number);
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return GestureDetector(
// //       onTap: () async {
// //         final cleanNumber = number.replaceAll('+', '').replaceAll(' ', '');
// //         final url = Uri.parse("https://wa.me/$cleanNumber");
// //
// //         if (await canLaunchUrl(url)) {
// //           await launchUrl(url);
// //         } else {
// //           debuglog("Could not launch $url");
// //         }
// //       },
// //       child: Row(
// //         children: [
// //           Image.asset(
// //             "assets/images/whatsapp_figma.png",
// //             height: 25,
// //             width: 25,
// //             errorBuilder: (context, error, stackTrace) {
// //               return const Icon(Icons.phone, color: Colors.green, size: 25);
// //             },
// //           ),
// //           const SizedBox(width: 5),
// //           Text(
// //             number,
// //             style: GoogleFonts.poppins(
// //               color: Colors.black,
// //               fontSize: 16,
// //               fontWeight: FontWeight.bold,
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // class _GameCard extends StatelessWidget {
// //   final int id;
// //   final String title;
// //   final String result;
// //   final String open;
// //   final String close;
// //   final String openBidLastTime;
// //   final String closeBidLastTime;
// //   final String status;
// //   final Color statusColor;
// //   final bool accountStatus;
// //   final bool openSessionStatus;
// //   final bool closeSessionStatus;
// //   final Function(String) getTranslatedString; // Pass translation function
// //
// //   const _GameCard({
// //     required this.id,
// //     required this.title,
// //     required this.result,
// //     required this.open,
// //     required this.close,
// //     required this.openBidLastTime,
// //     required this.closeBidLastTime,
// //     required this.status,
// //     required this.statusColor,
// //     required this.accountStatus,
// //     required this.openSessionStatus,
// //     required this.closeSessionStatus,
// //     required this.getTranslatedString,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       margin: const EdgeInsets.symmetric(vertical: 6),
// //       padding: const EdgeInsets.all(16),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(10),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.black.withOpacity(0.08),
// //             blurRadius: 5,
// //             offset: const Offset(0, 3),
// //           ),
// //         ],
// //       ),
// //       child: Row(
// //         children: [
// //           // Left content: Game name, result, bid times
// //           Expanded(
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 Text(
// //                   title.toUpperCase(),
// //                   style: GoogleFonts.poppins(
// //                     fontSize: 24,
// //                     color: Colors.black,
// //                     fontWeight: FontWeight.bold,
// //                   ),
// //                 ),
// //                 const SizedBox(height: 2),
// //                 Text(
// //                   result,
// //                   style: GoogleFonts.poppins(
// //                     fontSize: 22,
// //                     color: const Color(0xFFF9B233),
// //                     fontWeight: FontWeight.bold,
// //                   ),
// //                 ),
// //                 const SizedBox(height: 10),
// //                 Row(
// //                   children: [
// //                     Text(
// //                       "${getTranslatedString("Open Bid")}\n$open",
// //                       style: const TextStyle(fontSize: 14),
// //                     ),
// //                     const SizedBox(width: 40),
// //                     Text(
// //                       "${getTranslatedString("Close Bid")}\n$close",
// //                       style: const TextStyle(fontSize: 14),
// //                     ),
// //                   ],
// //                 ),
// //               ],
// //             ),
// //           ),
// //
// //           // Right content: Only shown if account is active
// //           if (accountStatus)
// //             Column(
// //               crossAxisAlignment: CrossAxisAlignment.end,
// //               children: [
// //                 Text(
// //                   status,
// //                   style: TextStyle(
// //                     color: statusColor,
// //                     fontWeight: FontWeight.w600,
// //                   ),
// //                 ),
// //                 const SizedBox(height: 10),
// //                 GestureDetector(
// //                   onTap: () {
// //                     if (status.toLowerCase().contains("closed for today") ||
// //                         status.toLowerCase().contains("holiday for today")) {
// //                       closeBidDialogue(
// //                         context: context,
// //                         gameName: title,
// //                         openResultTime: open,
// //                         openBidLastTime: openBidLastTime,
// //                         closeResultTime: close,
// //                         closeBidLastTime: closeBidLastTime,
// //                       );
// //                     } else {
// //                       Navigator.push(
// //                         context,
// //                         MaterialPageRoute(
// //                           builder: (_) => GameMenuScreen(
// //                             title: title,
// //                             gameId: id,
// //                             openSessionStatus: openSessionStatus,
// //                             closeSessionStatus: closeSessionStatus,
// //                           ),
// //                         ),
// //                       );
// //                     }
// //                   },
// //                   child: Container(
// //                     padding: const EdgeInsets.all(10),
// //                     decoration: BoxDecoration(
// //                       color: Colors.orange,
// //                       borderRadius: BorderRadius.circular(25),
// //                     ),
// //                     child: Icon(
// //                       Icons.play_arrow,
// //                       size: 30,
// //                       color: Colors.grey.shade600,
// //                     ),
// //                   ),
// //                 ),
// //                 const SizedBox(height: 5),
// //                 Text(
// //                   getTranslatedString("Play Game"),
// //                   style: const TextStyle(fontSize: 13),
// //                 ),
// //               ],
// //             ),
// //         ],
// //       ),
// //     );
// //   }
// // }
