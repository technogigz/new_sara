import 'dart:convert';
import 'dart:developer'; // Added for logging

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/KingStarline&Jackpot/KingStarlineOptionScreen.dart'; // Ensure this path is correct

import '../components/KingJackpotBiddingClosedDialog.dart'; // Ensure this path is correct
import '../ulits/Constents.dart'; // Ensure this path is correct

// 1. Updated the data model for the API response
class StarlineGame {
  final int id; // Corresponds to "gameId" from API response
  final String time; // Corresponds to "gameName" from API response
  final String status; // Derived from "statusText" from API response
  final String result; // Corresponds to "result" from API response
  final bool isClosed; // Derived from "playStatus" from API response
  final String openTime; // Corresponds to "openTime" from API response
  final String additionalInfo; // Derived from "closeTime" and "isClosed"

  StarlineGame({
    required this.id,
    required this.time,
    required this.status,
    required this.result,
    required this.isClosed,
    required this.openTime,
    this.additionalInfo = '',
  });

  // Factory constructor to create a StarlineGame object from JSON
  factory StarlineGame.fromJson(Map<String, dynamic> json) {
    // *** FIX IS HERE: Changed 'json['id']' to 'json['gameId']' ***
    final int gameId = (json['gameId'] is int)
        ? json['gameId']
        : (json['gameId'] is String ? int.tryParse(json['gameId']) ?? 0 : 0);

    final String gameName = json['gameName'] ?? 'N/A';
    final String result = json['result'] ?? '****-*';
    final String statusText = json['statusText'] ?? 'Unknown';
    final bool playStatus = json['playStatus'] ?? false;
    final String closeTime = json['closeTime'] ?? '--:--';
    final String openTime = json['openTime'] ?? "--:--";

    bool closed = !playStatus;
    String displayStatus = statusText;
    String displayAdditionalInfo = closed ? "Bid closed at $closeTime" : '';

    return StarlineGame(
      id: gameId, // Assigning the parsed gameId to the 'id' field
      time: gameName,
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
  final GetStorage _storage = GetStorage(); // Initialize GetStorage

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

    final String? accessToken = _storage.read('accessToken');
    final String? registerId = _storage.read('registerId');

    if (accessToken == null || accessToken.isEmpty) {
      log('Error: Access token not found. Cannot fetch Starline game list.');
      setState(() {
        _errorMessage = 'Access token not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    if (registerId == null || registerId.isEmpty) {
      log('Error: Register ID not found. Cannot fetch Starline game list.');
      setState(() {
        _errorMessage = 'Register ID not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    final url = Uri.parse('${Constant.apiEndpoint}starline-game-list');
    final headers = {
      'deviceId': 'qwert', // Consider making this dynamic based on device info
      'deviceName':
          'sm2233', // Consider making this dynamic based on device info
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken', // Use dynamic accessToken
    };
    final body = jsonEncode({
      "registerId": registerId,
    }); // Use dynamic registerId

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        log("Starline Game List API Response Status: ${response.statusCode}");
        log("Starline Game List API Response Body: ${response.body}");
        // log("Starline Game List API Response Info: ${responseData['info']}"); // Keep this line for detailed debugging if needed, but remove in production for privacy.

        // Check if status is true and 'info' key exists and is a List
        if (responseData['status'] == true && responseData['info'] is List) {
          setState(() {
            _gameTimes = (responseData['info'] as List)
                .map((gameJson) => StarlineGame.fromJson(gameJson))
                .toList();
            _isLoading = false;
          });
        } else {
          log(
            "Starline Game List API Error: Status false or 'info' missing. Message: ${responseData['msg']}",
          );
          setState(() {
            _errorMessage = responseData['msg'] ?? 'Failed to load game data.';
            _isLoading = false;
          });
        }
      } else {
        log(
          "Starline Game List API HTTP Error: ${response.statusCode}, Body: ${response.body}",
        );
        setState(() {
          _errorMessage =
              'Error ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}\n${response.body}'; // Include response body for more context
          _isLoading = false;
        });
      }
    } catch (e) {
      log("Exception during Starline Game List API call: $e");
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
                    log("History button tapped");
                  },
                  borderRadius: BorderRadius.circular(8),
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
                          log(
                            "Notifications switched to: $_notificationsEnabled",
                          );
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
            padding: const EdgeInsets.symmetric(
              horizontal: 5.0,
            ), // Horizontal padding of 5.0 on each side
            child: Column(
              children: [
                Row(
                  // This is likely the problematic Row
                  children: [
                    _buildInfoCard('Single Digit', '10-100'),
                    const SizedBox(width: 5), // Fixed width of 5
                    _buildInfoCard('Double Pana', '10-3200'),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  // This one too, potentially
                  children: [
                    _buildInfoCard('Single Pana', '10-1600'),
                    const SizedBox(width: 10), // Fixed width of 10
                    _buildInfoCard('Triple Pana', '10-10000'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          _isLoading
              ? const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  ),
                )
              : _errorMessage.isNotEmpty
              ? Expanded(
                  child: Center(
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              : Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _gameTimes.length,
                    itemBuilder: (context, index) {
                      final game = _gameTimes[index];
                      return _buildGameTimeListItem(
                        id: game
                            .id, // <--- Correctly passing the parsed game ID here
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
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(height: 4, width: 5),

              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameTimeListItem({
    required int id,
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
                    log(
                      "Play Game tapped for Game ID: $id, Time: $time, Status: $status",
                    );
                    if (isClosed) {
                      showDialog(
                        context: context,
                        builder: (context) => KingJackpotBiddingClosedDialog(
                          time: time,
                          resultTime: openTime,
                          bidLastTime: additionalInfo.replaceAll(
                            "Bid closed at ",
                            "",
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => KingStarlineOptionScreen(
                            gameTime: time,
                            title: "King Starline",
                            starlineGameId:
                                id, // <--- Correctly passing the `id` here
                            paanaStatus: bool.fromEnvironment(status),
                            registeredId: _storage.read("registerId"),
                          ),
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
            if (additionalInfo
                .isNotEmpty) // Only show if additionalInfo is not empty
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

// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:http/http.dart' as http;
// import 'package:new_sara/KingStarline&Jackpot/KingStarlineOptionScreen.dart'; // Ensure this path is correct
//
// import '../components/KingJackpotBiddingClosedDialog.dart';
// import '../ulits/Constents.dart';
//
// // 1. Update the data model for the API response
// class StarlineGame {
//   final int id; // <--- Correctly defined as a field
//   final String time;
//   final String status;
//   final String result;
//   final bool isClosed;
//   final String openTime;
//   final String additionalInfo; // Now holds closeTime
//
//   StarlineGame({
//     required this.id, // <--- Required in constructor
//     required this.time,
//     required this.status,
//     required this.result,
//     required this.isClosed,
//     required this.openTime,
//     this.additionalInfo = '',
//   });
//
//   // Factory constructor to create a StarlineGame object from JSON
//   factory StarlineGame.fromJson(Map<String, dynamic> json) {
//     // Safely parse the 'id'.
//     // Handle cases where 'id' might be null or not an int.
//     final int gameId = (json['id'] is int)
//         ? json['id']
//         : (json['id'] is String
//               ? int.tryParse(json['id']) ??
//                     0 // Try parsing if it's a string
//               : 0); // Default to 0 if null or neither int nor string
//
//     final String gameName = json['gameName'] ?? 'N/A';
//     final String result = json['result'] ?? '****-*';
//     final String statusText = json['statusText'] ?? 'Unknown';
//     final bool playStatus = json['playStatus'] ?? false;
//     final String closeTime = json['closeTime'] ?? '--:--';
//     final String openTime = json['openTime'] ?? "--:--";
//
//     bool closed = !playStatus;
//     String displayStatus = statusText; // Use statusText directly
//     String displayAdditionalInfo = closed
//         ? "Bid closed at $closeTime"
//         : ''; // Only show when closed
//
//     return StarlineGame(
//       id: gameId, // <--- Correctly initialize id
//       time: gameName,
//       status: displayStatus,
//       result: result,
//       isClosed: closed,
//       openTime: openTime,
//       additionalInfo: displayAdditionalInfo,
//     );
//   }
// }
//
// class KingStarlineDashboardScreen extends StatefulWidget {
//   const KingStarlineDashboardScreen({super.key});
//
//   @override
//   State<KingStarlineDashboardScreen> createState() =>
//       _KingStarlineDashboardScreenState();
// }
//
// class _KingStarlineDashboardScreenState
//     extends State<KingStarlineDashboardScreen> {
//   bool _notificationsEnabled = true;
//   List<StarlineGame> _gameTimes = [];
//   bool _isLoading = true;
//   String _errorMessage = '';
//   final GetStorage _storage = GetStorage(); // Initialize GetStorage
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchGameList(); // Call API when the widget initializes
//   }
//
//   Future<void> _fetchGameList() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = '';
//     });
//
//     final String? accessToken = _storage.read('accessToken');
//     final String? registerId = _storage.read('registerId');
//
//     if (accessToken == null || accessToken.isEmpty) {
//       setState(() {
//         _errorMessage = 'Access token not found. Please log in again.';
//         _isLoading = false;
//       });
//       return;
//     }
//
//     if (registerId == null || registerId.isEmpty) {
//       setState(() {
//         _errorMessage = 'Register ID not found. Please log in again.';
//         _isLoading = false;
//       });
//       return;
//     }
//
//     final url = Uri.parse('${Constant.apiEndpoint}starline-game-list');
//     final headers = {
//       'deviceId': 'qwert', // Consider making this dynamic based on device info
//       'deviceName':
//           'sm2233', // Consider making this dynamic based on device info
//       'accessStatus': '1',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $accessToken', // Use dynamic accessToken
//     };
//     final body = jsonEncode({
//       "registerId": registerId,
//     }); // Use dynamic registerId
//
//     try {
//       final response = await http.post(url, headers: headers, body: body);
//
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> responseData = json.decode(response.body);
//
//         log("Starline Game List API Response Status: ${response.statusCode}");
//         log("Starline Game List API Response Body: ${response.body}");
//         log("Starline Game List API Response Info: ${responseData['info']}");
//
//         // Check if status is true and 'info' key exists and is a List
//         if (responseData['status'] == true && responseData['info'] is List) {
//           setState(() {
//             _gameTimes = (responseData['info'] as List)
//                 .map((gameJson) => StarlineGame.fromJson(gameJson))
//                 .toList();
//             _isLoading = false;
//           });
//         } else {
//           setState(() {
//             _errorMessage = responseData['msg'] ?? 'Failed to load game data.';
//             _isLoading = false;
//           });
//         }
//       } else {
//         setState(() {
//           _errorMessage =
//               'Error ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}\n${response.body}'; // Include response body for more context
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'An error occurred: $e';
//         _isLoading = false;
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade200,
//       appBar: AppBar(
//         backgroundColor: Colors.grey.shade300,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(
//             Icons.arrow_back_ios_new,
//             color: Colors.black,
//             size: 20,
//           ),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//         title: const Text(
//           'King Starline Dashboard',
//           style: TextStyle(color: Colors.black, fontSize: 18),
//         ),
//       ),
//       body: Column(
//         children: [
//           Container(
//             color: Colors.grey.shade300,
//             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 InkWell(
//                   onTap: () {
//                     // Handle history tap
//                     // You might want to implement navigation to a history screen here
//                   },
//                   borderRadius: BorderRadius.circular(8),
//                   child: const Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       SizedBox(width: 5),
//                       Icon(Icons.calendar_month, color: Colors.black, size: 24),
//                       SizedBox(width: 4),
//                       Text(
//                         'History',
//                         style: TextStyle(
//                           color: Colors.black,
//                           fontSize: 14,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Text(
//                       'Notifications',
//                       style: TextStyle(color: Colors.black, fontSize: 14),
//                     ),
//                     Transform.scale(
//                       scale: 0.8,
//                       child: Switch(
//                         value: _notificationsEnabled,
//                         onChanged: (bool value) {
//                           setState(() {
//                             _notificationsEnabled = value;
//                           });
//                           // Add logic to save notification preference or perform action
//                         },
//                         activeTrackColor: Colors.teal[300],
//                         activeColor: Colors.teal,
//                         inactiveTrackColor: Colors.grey[300],
//                         inactiveThumbColor: Colors.grey,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           Divider(height: 1, thickness: 1, color: Colors.grey[200]),
//           const SizedBox(height: 5),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 5.0),
//             child: Column(
//               children: [
//                 Row(
//                   children: [
//                     _buildInfoCard('Single Digit', '10-100'),
//                     const SizedBox(width: 5),
//                     _buildInfoCard('Double Pana', '10-3200'),
//                   ],
//                 ),
//                 const SizedBox(height: 5),
//                 Row(
//                   children: [
//                     _buildInfoCard('Single Pana', '10-1600'),
//                     const SizedBox(width: 10),
//                     _buildInfoCard('Triple Pana', '10-10000'),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 5),
//           _isLoading
//               ? const Expanded(
//                   child: Center(child: CircularProgressIndicator()),
//                 )
//               : _errorMessage.isNotEmpty
//               ? Expanded(child: Center(child: Text(_errorMessage)))
//               : Expanded(
//                   child: ListView.builder(
//                     padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                     itemCount: _gameTimes.length,
//                     itemBuilder: (context, index) {
//                       final game = _gameTimes[index];
//
//                       return _buildGameTimeListItem(
//                         id: game.id,
//                         time: game.time,
//                         status: game.status,
//                         result: game.result,
//                         isClosed: game.isClosed,
//                         openTime: game.openTime,
//                         additionalInfo: game.additionalInfo,
//                       );
//                     },
//                   ),
//                 ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInfoCard(String title, String value) {
//     return Expanded(
//       child: Card(
//         color: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
//         elevation: 2,
//         shadowColor: Colors.black.withOpacity(0.05),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 title,
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                   color: Colors.grey[700],
//                 ),
//               ),
//               const SizedBox(height: 4, width: 5),
//               Text(
//                 value,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.amber,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildGameTimeListItem({
//     required int id,
//     required String time,
//     required String status,
//     required String result,
//     required bool isClosed,
//     required String openTime,
//     required String additionalInfo,
//   }) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 5),
//       color: Colors.white,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       elevation: 2,
//       shadowColor: Colors.black.withOpacity(0.05),
//       child: Padding(
//         padding: const EdgeInsets.all(5.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               mainAxisAlignment: MainAxisAlignment.start,
//               children: [
//                 Image.asset(
//                   isClosed
//                       ? "assets/images/ic_clock_closed.png"
//                       : "assets/images/ic_clock_active.png",
//                   color: isClosed ? Colors.grey[600] : Colors.amber[700],
//                   height: 38,
//                 ),
//                 const SizedBox(width: 15),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(
//                         time,
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black87,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         status,
//                         style: TextStyle(
//                           fontSize: 13,
//                           color: isClosed ? Colors.red[700] : Colors.green[700],
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 15,
//                     vertical: 8,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.black,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Text(
//                     result,
//                     style: const TextStyle(
//                       color: Colors.amber,
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 GestureDetector(
//                   onTap: () {
//                     if (isClosed) {
//                       showDialog(
//                         context: context,
//                         builder: (context) => KingJackpotBiddingClosedDialog(
//                           time: time,
//                           resultTime: openTime,
//                           bidLastTime: additionalInfo.replaceAll(
//                             "Bid closed at ",
//                             "",
//                           ),
//                         ),
//                       );
//                     } else {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => KingStarlineOptionScreen(
//                             gameTime: time,
//                             title: "King Starline",
//                             selectedId:
//                                 id, // <--- Correctly passing the `id` here
//                           ),
//                         ),
//                       );
//                     }
//                   },
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const SizedBox(height: 5),
//                       Container(
//                         width: 45,
//                         height: 45,
//                         decoration: const BoxDecoration(
//                           color: Colors.amber,
//                           shape: BoxShape.circle,
//                         ),
//                         child: Icon(
//                           Icons.play_arrow,
//                           color: Colors.grey.shade600,
//                           size: 28,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       const Text(
//                         "Play Game",
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(width: 5),
//               ],
//             ),
//             if (additionalInfo
//                 .isNotEmpty) // Only show if additionalInfo is not empty
//               Padding(
//                 padding: const EdgeInsets.only(top: 0, left: 55.0, bottom: 3),
//                 child: Text(
//                   additionalInfo,
//                   style: TextStyle(
//                     fontSize: 13,
//                     color: Colors.grey[600],
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
