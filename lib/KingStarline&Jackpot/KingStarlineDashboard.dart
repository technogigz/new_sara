import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/KingStarline&Jackpot/KingStarlineOptionScreen.dart';

import '../components/KingJackpotBiddingClosedDialog.dart';

// 1. Update the data model for the API response
class StarlineGame {
  final String time;
  final String status;
  final String result;
  final bool isClosed;
  final String openTime;
  final String additionalInfo; // Now holds closeTime

  StarlineGame({
    required this.time,
    required this.status,
    required this.result,
    required this.isClosed,
    required this.openTime,
    this.additionalInfo = '',
  });

  // Factory constructor to create a StarlineGame object from JSON
  factory StarlineGame.fromJson(Map<String, dynamic> json) {
    final String gameName = json['gameName'] ?? 'N/A';
    final String result = json['result'] ?? '****-*';
    final String statusText = json['statusText'] ?? 'Unknown';
    final bool playStatus =
        json['playStatus'] ??
        false; // Use playStatus to determine if it's 'running' or 'closed'
    final String closeTime =
        json['closeTime'] ?? '--:--'; // Use closeTime for additional info

    // Determine the display status and isClosed based on playStatus
    bool closed = !playStatus; // If playStatus is false, it's closed
    String displayStatus = playStatus ? 'Running Now' : 'Closed for Today';
    String openTime = json['openTime'] ?? "--:--";
    String displayAdditionalInfo = closed ? closeTime : '';

    return StarlineGame(
      time: gameName, // Use gameName for the time display (e.g., "10:30 AM")
      status: displayStatus,
      result: result,
      isClosed: closed,
      openTime: openTime,
      additionalInfo: displayAdditionalInfo,
    );
  }
}

class KingStarlineDashboardScreen extends StatefulWidget {
  const KingStarlineDashboardScreen({super.key});

  @override
  State<KingStarlineDashboardScreen> createState() =>
      _KingStarlineDashboardScreenState();
}

class _KingStarlineDashboardScreenState
    extends State<KingStarlineDashboardScreen> {
  bool _notificationsEnabled = true;
  List<StarlineGame> _gameTimes = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchGameList(); // Call API when the widget initializes
  }

  Future<void> _fetchGameList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final url = Uri.parse('https://sara777.win/api/v1/starline-game-list');
    final headers = {
      'deviceId': 'qwert',
      'deviceName': 'sm2233',
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization':
          'Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiI5YzdjYmVkOS03OWYyLTRmZGItODRmMC02NGYxZmQxNWJjOWIiLCJqdGkiOiI0ZWRiMWFhZTRmYTBmYTQyOTM5ZmQ0OTllY2U5MmU1OTYwOWYyMzkyYjEyMzhkMTFkYjUyZGNkZjkyN2JjYjA2ODVlMDM1NjMyZjdiMzRjOCIsImlhdCI6MTc1MjgzOTU5Mi42NzczOCwibmJmIjoxNzUyODM5NTkyLjY3NzM4MywiZXhwIjoxOTEwNjA1OTkyLjY3MjQ0NCwic3ViIjoiMTAwMTYiLCJzY29wZXMiOltdfQ.QrM8ZxEp_thk_6HcCXA2CQYPygem7fZLC2_Dpx3glUCEHtpTcHqwEEikdm0jHPGm_UY9xW46cyhR_eIa9u3K-TWxBql5UI9QCGPNE0eTTCMue6rfBkvr6jmbhWTM5V1XVbw50x2jjpJ6s2flww-i2_WFOSL6pB4qgIB2RFTR07oFVdLng8pBoLqOx7XA6x2ki2u1f-vXUOhSOAZp5FhZgN2Bkmw1Gi5xV7SwOmnPM2DY-ozyyOQVjdhYFtLWSdwRYHe1f0X0XriNUJBole-nerNdxn4EV3wlhzbbIR-RQtWP__e9BjK8Na4CLss_vqfoi_NMOV0cQcxRGDQnq2XGdHDA5WYIVqrqHRF2hb1WEnYhDxH4biETd1nl4G1hGMK3Q2uVe_bh9Q7YfJe1OzrxbtVQEUe4aFyuF9fEmxuVe3by2Q4fM8v6FoH64-kwQp_acUmbmhig-YIT0OnD1iWgOxvOdm-UEB4AiSZ_3mysZ9JaReLK-bizCquihKMCfA0vQnzpACbIrg8K9FxoafnJ5ykhyna7A0prwHAnBLuf7klw7lTUi8GcbPfu0U1VVmP6gK-uEkmDzi2D8RnDiihG6NgQkwrwQmmubwhKKx1AeP9N8c549CI1U8oT061JFwJOllRNCAtkUfFlyAAOgDBPoh5L7Kcy0sJ2VgRCiP3alCc',
    };
    final body = jsonEncode({"registerId": "WnprNlE3QldhSG4vQmthRktvRU9RZz09"});

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Check if status is true and 'info' key exists and is a List
        if (responseData['status'] == true && responseData['info'] is List) {
          setState(() {
            _gameTimes =
                (responseData['info'] as List) // Change 'data' to 'info'
                    .map((gameJson) => StarlineGame.fromJson(gameJson))
                    .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = responseData['msg'] ?? 'Failed to load game data.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage =
              'Error: ${response.statusCode} - ${response.reasonPhrase}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade300,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'King Starline Dashboard',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey.shade300,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    // Handle history tap
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 5),
                      Icon(
                        Icons.calendar_today_outlined,
                        color: Colors.black,
                        size: 20,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(color: Colors.black, fontSize: 14),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _notificationsEnabled,
                        onChanged: (bool value) {
                          setState(() {
                            _notificationsEnabled = value;
                          });
                        },
                        activeTrackColor: Colors.teal[300],
                        activeColor: Colors.teal,
                        inactiveTrackColor: Colors.grey[300],
                        inactiveThumbColor: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildInfoCard('Single Digit', '10-100'),
                    const SizedBox(width: 5),
                    _buildInfoCard('Double Pana', '10-3200'),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _buildInfoCard('Single Pana', '10-1600'),
                    const SizedBox(width: 10),
                    _buildInfoCard('Triple Pana', '10-10000'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          _isLoading
              ? const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _errorMessage.isNotEmpty
              ? Expanded(child: Center(child: Text(_errorMessage)))
              : Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _gameTimes.length,
                    itemBuilder: (context, index) {
                      final game = _gameTimes[index];
                      return _buildGameTimeListItem(
                        time: game.time,
                        status: game.status,
                        result: game.result,
                        isClosed: game.isClosed,
                        openTime: game.openTime,
                        additionalInfo: game.additionalInfo,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Expanded(
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4, width: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameTimeListItem({
    required String time,
    required String status,
    required String result,
    required bool isClosed,
    required String openTime,
    required String additionalInfo,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 5),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Image.asset(
                  isClosed
                      ? "assets/images/ic_clock_closed.png"
                      : "assets/images/ic_clock_active.png",
                  color: isClosed ? Colors.grey[600] : Colors.amber[700],
                  height: 38,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 13,
                          color: isClosed ? Colors.red[700] : Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    result,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    if (isClosed) {
                      showDialog(
                        context: context,
                        builder: (context) => KingJackpotBiddingClosedDialog(
                          time: time,
                          resultTime:
                              openTime, // Populate from API if available
                          bidLastTime: additionalInfo.replaceAll(
                            "Bid closed at",
                            "",
                          ), // Using additionalInfo for bidLastTime
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              KingStarlineOptionScreen(gameTime: time),
                        ),
                      );
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 5),
                      Container(
                        width: 45,
                        height: 45,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.grey.shade600,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Play Game",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 5),
              ],
            ),
            if (additionalInfo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 0, left: 55.0, bottom: 3),
                child: Text(
                  additionalInfo,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
