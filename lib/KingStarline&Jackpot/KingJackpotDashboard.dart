import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/Bids/KingJackpotResultHis/KingJackpotResultScreen.dart';
import 'package:new_sara/KingStarline&Jackpot/JackpotJodiOptionsScreen.dart';
import 'package:new_sara/components/KingJackpotBiddingClosedDialog.dart';

import '../Helper/TranslationHelper.dart';
import '../ulits/Constents.dart';

class KingJackpotDashboard extends StatefulWidget {
  const KingJackpotDashboard({super.key});

  @override
  State<KingJackpotDashboard> createState() => _KingJackpotDashboardState();
}

class _KingJackpotDashboardState extends State<KingJackpotDashboard> {
  static const Color kCardBg = Colors.white;
  static const Color kPrimaryDark = Color(0xFF1D2232);

  bool isNotificationOn = true;
  late Future<JackpotGameData> futureGameData;

  final String toLang = GetStorage().read('language') ?? 'en';
  Map<String, String> _i18n = {};
  int _totalJodiElements = 0;

  @override
  void initState() {
    super.initState();
    futureGameData = fetchGameData();
    _loadTranslations();
  }

  String tr(String key) => _i18n[key] ?? key;

  Future<void> _loadTranslations() async {
    // Translate once, then setState once
    final keys = <String>[
      'King Jackpot',
      'History',
      'Notifications',
      'Jodi',
      'Closed',
      'Running',
      'Play Game',
      'No data available.',
      'Error:',
      'Retry',
    ];

    try {
      final results = await Future.wait(
        keys.map((k) => TranslationHelper.translate(k, toLang)),
      );
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < keys.length; i++) {
          _i18n[keys[i]] = results[i];
        }
      });
    } catch (_) {
      // If translation fails, keep English labels silently
    }
  }

  Future<JackpotGameData> fetchGameData() async {
    final storage = GetStorage();
    final String accessToken = storage.read('accessToken') ?? '';
    final String registerId = storage.read('registerId') ?? '';
    final String deviceId =
        storage.read('deviceId')?.toString() ?? 'unknown_device';
    final String deviceName =
        storage.read('deviceName')?.toString() ?? 'unknown_model';
    final bool accountStatus = (storage.read('accountStatus') ?? true) == true;

    dev.log('[Jackpot] Fetching...', name: 'KingJackpot');
    dev.log(
      '[Jackpot] AccessToken: ${accessToken.isNotEmpty}',
      name: 'KingJackpot',
    );
    dev.log('[Jackpot] RegisterId: $registerId', name: 'KingJackpot');

    try {
      final now = DateTime.now();
      final uri = Uri.parse('${Constant.apiEndpoint}jackpot-game-list');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
              'deviceId': deviceId,
              'deviceName': deviceName,
              'accessStatus': accountStatus ? '1' : '0',
              'Authorization': 'Bearer $accessToken',
              // timezone/context headers (helpful server-side)
              'x-client-time': now.toIso8601String(),
              'x-tz-offset-mins': now.timeZoneOffset.inMinutes.toString(),
              'x-tz-name': now.timeZoneName,
            },
            body: json.encode({'registerId': registerId}),
          )
          .timeout(const Duration(seconds: 20));

      dev.log('[Jackpot] Status: ${res.statusCode}', name: 'KingJackpot');
      dev.log('[Jackpot] Body: ${res.body}', name: 'KingJackpot');

      if (res.statusCode == 200) {
        final data = jackpotGameDataFromJson(res.body);

        if (data.info != null) {
          final count = data.info!.length;
          dev.log('[Jackpot] Total Jodi Elements: $count', name: 'KingJackpot');
          if (mounted) setState(() => _totalJodiElements = count);
        }
        return data;
      }

      throw Exception(
        'Failed to load jackpot game data: ${res.statusCode} - ${res.body}',
      );
    } catch (e) {
      dev.log('[Jackpot] Error: $e', name: 'KingJackpot');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildChips(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: RefreshIndicator(
                  color: Colors.red,
                  onRefresh: () async {
                    setState(() => futureGameData = fetchGameData());
                    await futureGameData;
                  },
                  child: FutureBuilder<JackpotGameData>(
                    future: futureGameData,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.red),
                        );
                      }

                      if (snap.hasError) {
                        return _errorView(
                          context,
                          message: '${tr("Error:")} ${snap.error}',
                          onRetry: () =>
                              setState(() => futureGameData = fetchGameData()),
                        );
                      }

                      final info = snap.data?.info;
                      if (info == null || info.isEmpty) {
                        return Center(
                          child: Text(
                            tr('No data available.'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }

                      return GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: info.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 190,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemBuilder: (context, i) {
                          final g = info[i];
                          return _buildGameCard(
                            gameId: g.gameId,
                            timeLabel: g.gameName,
                            result: g.result,
                            statusText: g.statusText,
                            closeTime: g.closeTime,
                            playStatus: g.playStatus,
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 26),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              Text(
                tr('King Jackpot'),
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
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      //   Navigate to the history
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => KingJackpotResultScreen(),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 4.0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 5),
                          Icon(
                            Icons.calendar_month,
                            color: Colors.black,
                            size: 24,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'History',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    tr('Notifications'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: isNotificationOn,
                    onChanged: (v) => setState(() => isNotificationOn = v),
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
          spacing: 8,
          children: [
            _chip(tr('Jodi'), isSelected: false),
            // Dynamic count: don't translate
            _chip('1 - $_totalJodiElements', isSelected: true),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: isSelected ? Colors.red : Colors.black12,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.red : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required int gameId,
    required String timeLabel,
    required String result,
    required String statusText,
    required String closeTime,
    required bool playStatus,
  }) {
    // Prefer server boolean, fallback to text
    final statusLower = statusText.toLowerCase().trim();
    final isClosedByText = statusLower == 'closed';
    final isRunningByText = statusLower == 'running';
    final canPlay = playStatus && !isClosedByText;

    final Color statusColor = isClosedByText
        ? Colors.red
        : (isRunningByText || canPlay)
        ? Colors.green
        : Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  timeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Image.asset(
                (isClosedByText || !canPlay)
                    ? 'assets/images/ic_clock_closed.png'
                    : 'assets/images/ic_clock_active.png',
                color: canPlay ? Colors.red : Colors.grey,
                height: 30,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (result.trim().isNotEmpty)
            CircleAvatar(
              backgroundColor: Colors.black,
              radius: 14,
              child: Text(
                result.trim(),
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const Spacer(),
          Text(
            statusText,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _onPlayPressed(
              canPlay: canPlay,
              timeLabel: timeLabel,
              closeTime: closeTime,
              gameId: gameId,
            ),
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: Text(tr('Play Game')),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryDark,
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

  void _onPlayPressed({
    required bool canPlay,
    required String timeLabel,
    required String closeTime,
    required int gameId,
  }) {
    if (!canPlay) {
      showDialog(
        context: context,
        builder: (_) => KingJackpotBiddingClosedDialog(
          time: timeLabel,
          resultTime: closeTime,
          bidLastTime: closeTime,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JackpotJodiOptionsScreen(
          title: 'King Jackpot, $timeLabel',
          gameTime: timeLabel,
          gameId: gameId,
          digitJodiStatus: false,
          sessionSelection: true,
        ),
      ),
    );
  }

  Widget _errorView(
    BuildContext context, {
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(tr('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= MODELS =======================

JackpotGameData jackpotGameDataFromJson(String str) =>
    JackpotGameData.fromJson(json.decode(str) as Map<String, dynamic>);

String jackpotGameDataToJson(JackpotGameData data) =>
    json.encode(data.toJson());

class JackpotGameData {
  final bool status;
  final String msg;
  final List<JackpotGameInfo>? info;

  JackpotGameData({required this.status, required this.msg, this.info});

  factory JackpotGameData.fromJson(Map<String, dynamic> json) {
    final rawInfo = json['info'];
    List<JackpotGameInfo>? parsedInfo;
    if (rawInfo is List) {
      parsedInfo = rawInfo
          .map(
            (x) => JackpotGameInfo.fromJson((x as Map).cast<String, dynamic>()),
          )
          .toList();
    }

    final dynamic s = json['status'];
    final status = s == true || s == 1 || s == '1';

    return JackpotGameData(
      status: status,
      msg: (json['msg'] ?? '').toString(),
      info: parsedInfo,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'msg': msg,
    'info': info?.map((x) => x.toJson()).toList(),
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

  factory JackpotGameInfo.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    bool parseBool(dynamic v) {
      if (v is bool) return v;
      final s = v?.toString().toLowerCase().trim();
      return s == '1' ||
          s == 'true' ||
          s == 'yes' ||
          s == 'open' ||
          s == 'running';
    }

    return JackpotGameInfo(
      gameId: parseInt(json['gameId']),
      gameName: (json['gameName'] ?? '').toString(),
      openTime: (json['openTime'] ?? '').toString(),
      closeTime: (json['closeTime'] ?? '').toString(),
      result: (json['result'] ?? '').toString(),
      statusText: (json['statusText'] ?? '').toString(),
      playStatus: parseBool(json['playStatus']),
    );
  }

  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'gameName': gameName,
    'openTime': openTime,
    'closeTime': closeTime,
    'result': result,
    'statusText': statusText,
    'playStatus': playStatus,
  };
}
