import 'dart:convert';
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http; // Import http package
import 'package:new_sara/KingStarline&Jackpot/JackpotJodiOptionsScreen.dart'; // Assuming this exists
import 'package:new_sara/components/KingJackpotBiddingClosedDialog.dart'; // Assuming this exists

import '../Helper/TranslationHelper.dart';
import '../ulits/Constents.dart'; // Assuming this exists

class KingJackpotDashboard extends StatefulWidget {
  @override
  _KingJackpotDashboardState createState() => _KingJackpotDashboardState();
}

class _KingJackpotDashboardState extends State<KingJackpotDashboard> {
  bool isNotificationOn = true;
  late Future<JackpotGameData> futureGameData;

  final String toLang = GetStorage().read('language') ?? 'en';
  Map<String, String> translatedTexts = {};
  int _totalJodiElements = 0; // New state variable for total elements

  @override
  void initState() {
    super.initState();
    futureGameData = fetchGameData();
    _loadTranslations();
  }

  String tr(String key) => translatedTexts[key] ?? key;

  Future<void> _loadTranslations() async {
    final keysToTranslate = [
      "King Jackpot",
      "History",
      "Notifications",
      "Jodi",
      "1-10",
      "Closed",
      "Running",
      "Play Game",
      "No data available.",
      "Error:",
    ];

    for (final text in keysToTranslate) {
      final translated = await TranslationHelper.translate(text, toLang);
      translatedTexts[text] = translated;
    }

    setState(() {});
  }

  Future<JackpotGameData> fetchGameData() async {
    final String? accessToken = GetStorage().read('accessToken') ?? '';
    final String registerId = GetStorage().read('registerId') ?? '';

    log("Fetching King Jackpot data...");
    log("AccessToken: $accessToken");
    log("RegisterId: $registerId");

    try {
      final response = await http.post(
        Uri.parse("${Constant.apiEndpoint}jackpot-game-list"),
        headers: {
          "Content-Type": "application/json",
          "deviceId": "qwert",
          "deviceName": "sm2233",
          "accessStatus": "1",
          "Authorization": "Bearer $accessToken",
        },
        body: json.encode({"registerId": registerId}),
      );

      log("Jackpot API Response Status: ${response.statusCode}");
      log("Jackpot API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jackpotGameDataFromJson(response.body);
        // Update totalJodiElements after successful data fetch
        if (data.info != null) {
          setState(() {
            log("Total Jodi Elements: ${data.info!.length}");
            _totalJodiElements = data.info!.length;
          });
        }
        return data;
      } else {
        throw Exception(
          "Failed to load jackpot game data: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      log("Error fetching jackpot game data: $e");
      throw Exception("Failed to load jackpot game data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildChips(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: RefreshIndicator(
                  color: Colors.amber,
                  onRefresh: () async {
                    setState(() {
                      futureGameData = fetchGameData();
                    });
                    await futureGameData;
                  },
                  child: FutureBuilder<JackpotGameData>(
                    future: futureGameData,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.amber),
                        );
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Text("${tr("Error:")} ${snapshot.error}"),
                        );
                      } else if (!snapshot.hasData ||
                          snapshot.data!.info == null ||
                          snapshot.data!.info!.isEmpty) {
                        return Center(child: Text(tr("No data available.")));
                      }

                      final gameData = snapshot.data!.info!;

                      return GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: gameData.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 190,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemBuilder: (context, index) {
                          final game = gameData[index];
                          return _buildGameCard(
                            game.gameId,
                            game.gameName,
                            game.result,
                            game.statusText,
                            game.closeTime,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 26),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 10),
              Text(
                tr("King Jackpot"),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_outlined),
                  const SizedBox(width: 6),
                  Text(
                    tr("History"),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    tr("Notifications"),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: isNotificationOn,
                    onChanged: (value) =>
                        setState(() => isNotificationOn = value),
                    activeColor: Colors.teal,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Wrap(
          children: [
            // Updated Jodi chip label
            _chip("Jodi", isSelected: false),
            _chip(tr("1 - $_totalJodiElements"), isSelected: true),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.orange : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGameCard(
    int gameid,
    String time,
    String result,
    String status,
    String closeTime,
  ) {
    final bool isRunning = status.toLowerCase() == "running";
    final bool isClosed = status.toLowerCase() == "closed";

    Color statusColor = Colors.grey;
    if (isRunning) {
      statusColor = Colors.green;
    } else if (isClosed) {
      statusColor = Colors.red;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Image.asset(
                isClosed
                    ? "assets/images/ic_clock_closed.png"
                    : "assets/images/ic_clock_active.png",
                color: isRunning ? Colors.orange : Colors.grey,
                height: 30,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (result.isNotEmpty)
            CircleAvatar(
              backgroundColor: Colors.black,
              radius: 14,
              child: Text(
                result,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const Spacer(),
          Text(status, style: TextStyle(color: statusColor)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              if (isClosed) {
                showDialog(
                  context: context,
                  builder: (context) => KingJackpotBiddingClosedDialog(
                    time: time,
                    resultTime: closeTime,
                    bidLastTime: closeTime,
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JackpotJodiOptionsScreen(
                      title: "King Jackpot, $time",
                      gameTime: time,
                      gameId: gameid,
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: Text(tr("Play Game")),
            style: ElevatedButton.styleFrom(
              backgroundColor: isRunning
                  ? const Color(0xFF1D2232)
                  : const Color(0xFF1D2232),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//Jackpot Model:
JackpotGameData jackpotGameDataFromJson(String str) =>
    JackpotGameData.fromJson(json.decode(str));

String jackpotGameDataToJson(JackpotGameData data) =>
    json.encode(data.toJson());

class JackpotGameData {
  final bool status;
  final String msg;
  final List<JackpotGameInfo>? info;

  JackpotGameData({required this.status, required this.msg, this.info});

  factory JackpotGameData.fromJson(Map<String, dynamic> json) =>
      JackpotGameData(
        status: json["status"],
        msg: json["msg"],
        info: json["info"] == null
            ? null
            : List<JackpotGameInfo>.from(
                json["info"].map((x) => JackpotGameInfo.fromJson(x)),
              ),
      );

  Map<String, dynamic> toJson() => {
    "status": status,
    "msg": msg,
    "info": info == null
        ? null
        : List<dynamic>.from(info!.map((x) => x.toJson())),
  };
}

class JackpotGameInfo {
  final int gameId;
  final String gameName;
  final String openTime;
  final String closeTime;
  final String result;
  final String statusText;
  final bool playStatus;

  JackpotGameInfo({
    required this.gameId,
    required this.gameName,
    required this.openTime,
    required this.closeTime,
    required this.result,
    required this.statusText,
    required this.playStatus,
  });

  factory JackpotGameInfo.fromJson(Map<String, dynamic> json) =>
      JackpotGameInfo(
        gameId: json["gameId"],
        gameName: json["gameName"],
        openTime: json["openTime"],
        closeTime: json["closeTime"],
        result: json["result"],
        statusText: json["statusText"],
        playStatus: json["playStatus"],
      );

  Map<String, dynamic> toJson() => {
    "gameId": gameId,
    "gameName": gameName,
    "openTime": openTime,
    "closeTime": closeTime,
    "result": result,
    "statusText": statusText,
    "playStatus": playStatus,
  };
}
