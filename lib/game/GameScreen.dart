import 'dart:convert';
import 'dart:core';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/game/Jodi/JodiBulkScreen.dart';
import 'package:new_sara/game/Panna/SinglePanna/SinglePanna.dart';
import 'package:new_sara/game/Panna/SinglePanna/SinglePannaBulk.dart';
import 'package:new_sara/game/RedBracket/RedBracketScreen.dart';
import 'package:new_sara/game/SPDPTPScreen/ChoiceSpDpTpBoardScreen.dart';
import 'package:new_sara/game/SPDPTPScreen/SpDpTpBoardScreen.dart';
import 'package:new_sara/game/Sangam/FullSangamBoardScreen.dart';
import 'package:new_sara/game/Sangam/HalfSangamABoardScreen.dart';
import 'package:new_sara/game/Sangam/HalfSangamBBoardScreen.dart';

import '../Helper/TranslationHelper.dart';
import '../ulits/Constents.dart';
import 'DigitBasedBoard/DigitBasedBoardScreen.dart';
import 'Jodi/JodiBidScreen.dart';
import 'Jodi/group_jodi_screen.dart';
import 'OddEvenBoard/OddEvenBoardScreen.dart';
import 'SingleDigitBetScreen/SingleDigitBetScreen.dart';
import 'SingleDigitBetScreen/SingleDigitsBulkScreen.dart';
import 'TwoDigitPanel/TwoDigitPanel.dart';

// ✅ Model - Added translatedName field
class GameItem {
  final int id;
  final String name; // Original name from API
  final String type;
  final String image;
  final bool sessionSelection;
  String translatedName; // Field to store the translated name

  GameItem({
    required this.id,
    required this.name,
    required this.type,
    required this.image,
    required this.sessionSelection,
    this.translatedName = '', // Initialize translatedName
  });

  factory GameItem.fromJson(Map<String, dynamic> json) {
    return GameItem(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      image: json['image'],
      sessionSelection: json['sessionSelection'] ?? false,
    );
  }
}

// ✅ Main Screen
class GameMenuScreen extends StatefulWidget {
  final String title;

  const GameMenuScreen({super.key, required this.title});

  @override
  State<GameMenuScreen> createState() => _GameMenuScreenState();
}

class _GameMenuScreenState extends State<GameMenuScreen> {
  late Future<List<GameItem>> _futureGames;
  final storage = GetStorage();
  late String _currentLanguageCode; // Store current language code

  @override
  void initState() {
    super.initState();
    _currentLanguageCode =
        storage.read('selectedLanguage') ??
        'en'; // Use 'selectedLanguage' for consistency
    _futureGames = fetchGameList();
  }

  Future<List<GameItem>> fetchGameList() async {
    String? bearerToken = storage.read('accessToken'); // Use nullable String
    if (bearerToken == null || bearerToken.isEmpty) {
      log('Error: Access token not found in GetStorage or is empty.');
      throw Exception('Access token not found or is empty');
    }

    // IMPORTANT: Verify Constant.apiEndpoint in Constents.dart
    // It should be 'https://sara777.win/api/' if the full URL is https://sara777.win/api/game-bid-type
    final response = await http.get(
      Uri.parse("${Constant.apiEndpoint}game-bid-type"),
      headers: {
        'deviceId': 'qwert',
        'deviceName': 'sm2233',
        'accessStatus': '1',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['status'] == true && decoded['info'] != null) {
        // Check status is true
        final List data = decoded['info'];
        List<GameItem> gameItems = [];
        for (var itemJson in data) {
          GameItem gameItem = GameItem.fromJson(itemJson);
          // Translate the name here and store it in the model
          gameItem.translatedName = await TranslationHelper.translate(
            gameItem.name,
            _currentLanguageCode,
          );
          gameItems.add(gameItem);
        }
        return gameItems;
      } else {
        log(
          "API Response Status Not True or Info Missing: ${json.encode(decoded)}",
        );
        throw Exception(
          "No game items found in API response or status is false.",
        );
      }
    } else {
      log("API Error: ${response.statusCode}, ${response.body}");
      throw Exception("Failed to load game list: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use _currentLanguageCode from state
    String screenTitle = widget.title; // Original title for the screen

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey.shade200,
        elevation: 0,
        title: FutureBuilder<String>(
          future: TranslationHelper.translate(
            widget.title,
            _currentLanguageCode,
          ),
          builder: (context, snapshot) {
            return Text(
              snapshot.data ?? widget.title,
              style: const TextStyle(color: Colors.black),
            );
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.amber,
          onRefresh: () async {
            setState(() {
              _futureGames = fetchGameList();
            });
          },
          child: FutureBuilder<List<GameItem>>(
            future: _futureGames,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Error loading games: ${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No games found"));
              } else {
                final games = snapshot.data!;

                return Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    itemCount: games.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                    itemBuilder: (context, index) {
                      final item = games[index];
                      final gameType = item
                          .type; // No toLowerCase here, match API exact type

                      return GestureDetector(
                        onTap: () {
                          log(
                            "Navigating for Game Type: $gameType, Name: ${item.name}, Translated: ${item.translatedName}",
                          );

                          switch (gameType) {
                            case 'singleDigits':
                            case 'spMotor':
                            case 'dpMotor':
                            case 'triplePana':
                            case 'doublePana':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SingleDigitBetScreen(
                                    title:
                                        "$screenTitle, ${item.translatedName}", // Use pre-translated name
                                    gameId: item.id,
                                    gameName: item
                                        .name, // Original name for internal logic
                                    gameCategoryType:
                                        item.type, // Correct parameter name
                                  ),
                                ),
                              );
                              break;

                            case 'singleDigitsBulk':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SingleDigitsBulkScreen(
                                    title:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item
                                        .type, // Assuming this screen still uses 'gameType'
                                    gameName: item.name, // Original name
                                    selectedGameType:
                                        '', // Assuming this is a placeholder as per your code
                                  ),
                                ),
                              );
                              break;

                            case 'singlePanaBulk':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SinglePannaBulkBoardScreen(
                                    title:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item.type,
                                    gameName: item.name, // Original name
                                  ),
                                ),
                              );
                              break;
                            case 'jodi':
                            case 'panelGroup':
                            case 'groupDigit':
                            case 'twoDigitPanna':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JodiBidScreen(
                                    title:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item.type,
                                  ),
                                ),
                              );
                              break;

                            case 'jodiBulk':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JodiBulkScreen(
                                    screenTitle:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item.type,
                                  ),
                                ),
                              );
                              break;

                            case 'singlePana':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SinglePannaScreen(
                                    title:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item.type,
                                  ),
                                ),
                              );
                              break;

                            case 'twoDigitsPanel':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TwoDigitPanelScreen(
                                    title:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item.type,
                                  ),
                                ),
                              );
                              break;

                            case 'groupJodi':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupJodiScreen(
                                    title:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item.type,
                                  ),
                                ),
                              );
                              break;
                            case 'digitBasedJodi':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DigitBasedBoardScreen(
                                    title:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id
                                        .toString(), // Corrected: Use .toString()
                                    gameType: item.type,
                                  ),
                                ),
                              );
                              break;

                            case 'oddEven':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OddEvenBoardScreen(
                                    title:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item.type,
                                  ),
                                ),
                              );
                              break;

                            case 'choicePannaSPDP':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChoiceSpDpTpBoardScreen(
                                    screenTitle:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item.type,
                                  ),
                                ),
                              );
                              break;

                            case 'SPDPTP':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SpDpTpBoardScreen(
                                    screenTitle:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item.type,
                                  ),
                                ),
                              );
                              break;
                            case 'redBracket':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RedBracketBoardScreen(
                                    screenTitle:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item.type,
                                  ),
                                ),
                              );
                              break;

                            case 'halfSangamA':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HalfSangamABoardScreen(
                                    screenTitle:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item.type,
                                  ),
                                ),
                              );
                              break;
                            case 'halfSangamB':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HalfSangamBBoardScreen(
                                    screenTitle:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item.type,
                                  ),
                                ),
                              );
                              break;
                            case 'fullSangam':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullSangamBoardScreen(
                                    screenTitle:
                                        "$screenTitle, ${item.translatedName}", // Use translated name
                                    gameId: item.id,
                                    gameType: item.type,
                                  ),
                                ),
                              );
                              break;

                            default:
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "No screen available for ${item.translatedName}",
                                  ),
                                ),
                              );
                              log("Unhandled game type: ${item.type}");
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 6,
                                spreadRadius: 1,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Image.network(
                                  item.image,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.image_not_supported),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Display the pre-translated name
                              Text(
                                item.translatedName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

// import 'dart:convert';
// import 'dart:core';
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:http/http.dart' as http;
// import 'package:new_sara/game/Jodi/JodiBulkScreen.dart';
// import 'package:new_sara/game/Panna/SinglePanna/SinglePanna.dart';
// import 'package:new_sara/game/Panna/SinglePanna/SinglePannaBulk.dart';
// import 'package:new_sara/game/RedBracket/RedBracketScreen.dart';
// import 'package:new_sara/game/SPDPTPScreen/ChoiceSpDpTpBoardScreen.dart';
// import 'package:new_sara/game/SPDPTPScreen/SpDpTpBoardScreen.dart';
// import 'package:new_sara/game/Sangam/FullSangamBoardScreen.dart';
// import 'package:new_sara/game/Sangam/HalfSangamABoardScreen.dart';
// import 'package:new_sara/game/Sangam/HalfSangamBBoardScreen.dart';
//
// import '../Helper/TranslationHelper.dart';
// import '../ulits/Constents.dart';
// import 'DigitBasedBoard/DigitBasedBoardScreen.dart';
// import 'Jodi/JodiBidScreen.dart';
// import 'Jodi/group_jodi_screen.dart';
// import 'OddEvenBoard/OddEvenBoardScreen.dart';
// import 'SingleDigitBetScreen/SingleDigitBetScreen.dart';
// import 'SingleDigitBetScreen/SingleDigitsBulkScreen.dart';
// import 'TwoDigitPanel/TwoDigitPanel.dart';
//
// // ✅ Model
// class GameItem {
//   final int id;
//   final String name;
//   final String type;
//   final String image;
//   final bool sessionSelection;
//
//   GameItem({
//     required this.id,
//     required this.name,
//     required this.type,
//     required this.image,
//     required this.sessionSelection,
//   });
//
//   factory GameItem.fromJson(Map<String, dynamic> json) {
//     return GameItem(
//       id: json['id'],
//       name: json['name'],
//       type: json['type'],
//       image: json['image'],
//       sessionSelection: json['sessionSelection'] ?? false,
//     );
//   }
// }
//
// // ✅ Main Screen
// class GameMenuScreen extends StatefulWidget {
//   final String title;
//
//   const GameMenuScreen({super.key, required this.title});
//
//   @override
//   State<GameMenuScreen> createState() => _GameMenuScreenState();
// }
//
// class _GameMenuScreenState extends State<GameMenuScreen> {
//   late Future<List<GameItem>> _futureGames;
//   final storage = GetStorage();
//
//   @override
//   void initState() {
//     super.initState();
//     _futureGames = fetchGameList();
//   }
//
//   Future<List<GameItem>> fetchGameList() async {
//     String bearerToken = storage.read('accessToken');
//     final response = await http.get(
//       Uri.parse("${Constant.apiEndpoint}game-bid-type"),
//       headers: {
//         'deviceId': 'qwert',
//         'deviceName': 'sm2233',
//         'accessStatus': '1',
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $bearerToken',
//       },
//     );
//
//     if (response.statusCode == 200) {
//       final decoded = json.decode(response.body);
//       if (decoded['status'] != null && decoded['info'] != null) {
//         final List data = decoded['info'];
//         return data.map((e) => GameItem.fromJson(e)).toList();
//       } else {
//         throw Exception("No game items found");
//       }
//     } else {
//       throw Exception("Failed to load game list");
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     String languageCode = storage.read('language') ?? 'en';
//     String screenTitle = widget.title;
//
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.grey.shade200,
//         elevation: 0,
//         title: FutureBuilder<String>(
//           future: TranslationHelper.translate(widget.title, languageCode),
//           builder: (context, snapshot) {
//             return Text(
//               snapshot.data ?? widget.title,
//               style: const TextStyle(color: Colors.black),
//             );
//           },
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: SafeArea(
//         child: RefreshIndicator(
//           color: Colors.amber,
//           onRefresh: () async {
//             setState(() {
//               _futureGames = fetchGameList();
//             });
//           },
//           child: FutureBuilder<List<GameItem>>(
//             future: _futureGames,
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(
//                   child: CircularProgressIndicator(color: Colors.amber),
//                 );
//               } else if (snapshot.hasError) {
//                 return Center(child: Text("Error: ${snapshot.error}"));
//               } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                 return const Center(child: Text("No games found"));
//               } else {
//                 final games = snapshot.data!;
//
//                 return Container(
//                   color: Colors.grey.shade200,
//                   padding: const EdgeInsets.all(12),
//                   child: GridView.builder(
//                     itemCount: games.length,
//                     physics: const AlwaysScrollableScrollPhysics(),
//                     gridDelegate:
//                         const SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: 2,
//                           mainAxisSpacing: 8,
//                           crossAxisSpacing: 8,
//                           childAspectRatio: 1,
//                         ),
//                     itemBuilder: (context, index) {
//                       final item = games[index];
//                       final gameType = item.type; // No toLowerCase here
//
//                       return GestureDetector(
//                         onTap: () {
//                           log("Navigating for Game Type: $gameType");
//
//                           switch (gameType) {
//                             case 'singleDigits':
//                             case 'spMotor':
//                             case 'dpMotor':
//                             case 'triplePana':
//                             case 'doublePana':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => SingleDigitBetScreen(
//                                     title:
//                                         "$screenTitle, ${item.translatedTitle}", // Recommended: Use translatedTitle for display
//                                     gameId: item.id,
//                                     gameName: item
//                                         .title, // Keep original title for internal game logic if needed
//                                     gameCategoryType: item
//                                         .type, // This is the new, correct parameter name
//                                   ),
//                                 ),
//                               );
//                               break;
//
//                             case 'singleDigitsBulk':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => SingleDigitsBulkScreen(
//                                     title: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                     gameName: item.name,
//                                     selectedGameType: '',
//                                   ),
//                                 ),
//                               );
//                               break;
//
//                             case 'singlePanaBulk':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => SinglePannaBulkBoardScreen(
//                                     title: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                     gameName: '${item.name}',
//                                   ),
//                                 ),
//                               );
//                               break;
//                             case 'jodi':
//                             case 'panelGroup':
//                             case 'groupDigit':
//                             case 'twoDigitPanna':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => JodiBidScreen(
//                                     title: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//
//                             case 'jodiBulk':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => JodiBulkScreen(
//                                     screenTitle: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//
//                             case 'singlePana':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => SinglePannaScreen(
//                                     title: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//
//                             case 'twoDigitsPanel':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => TwoDigitPanelScreen(
//                                     title: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//
//                             // TODO: Add these screens later
//                             case 'groupJodi':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => GroupJodiScreen(
//                                     title: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//                             case 'digitBasedJodi':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => DigitBasedBoardScreen(
//                                     title: "$screenTitle, ${item.name}",
//                                     gameId: item.id as String,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//
//                             case 'oddEven':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => OddEvenBoardScreen(
//                                     title: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//
//                             case 'choicePannaSPDP':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => ChoiceSpDpTpBoardScreen(
//                                     screenTitle: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//
//                             case 'SPDPTP':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => SpDpTpBoardScreen(
//                                     screenTitle: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//                             case 'redBracket':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => RedBracketBoardScreen(
//                                     screenTitle: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//
//                             case 'halfSangamA':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => HalfSangamABoardScreen(
//                                     screenTitle: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//                             case 'halfSangamB':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => HalfSangamBBoardScreen(
//                                     screenTitle: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//                             case 'fullSangam':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => FullSangamBoardScreen(
//                                     screenTitle: "$screenTitle, ${item.name}",
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//
//                             default:
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(
//                                   content: Text(
//                                     "No screen available for ${item.name}",
//                                   ),
//                                 ),
//                               );
//                           }
//                         },
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: Colors.grey.shade300,
//                             borderRadius: BorderRadius.circular(12),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.grey.withOpacity(0.2),
//                                 blurRadius: 6,
//                                 spreadRadius: 1,
//                                 offset: const Offset(2, 2),
//                               ),
//                             ],
//                           ),
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Container(
//                                 width: 90,
//                                 height: 90,
//                                 decoration: const BoxDecoration(
//                                   shape: BoxShape.circle,
//                                   color: Colors.white,
//                                 ),
//                                 padding: const EdgeInsets.all(20),
//                                 child: Image.network(
//                                   item.image,
//                                   fit: BoxFit.contain,
//                                   errorBuilder: (context, error, stackTrace) =>
//                                       const Icon(Icons.image_not_supported),
//                                 ),
//                               ),
//                               const SizedBox(height: 10),
//                               FutureBuilder<String>(
//                                 future: TranslationHelper.translate(
//                                   item.name,
//                                   languageCode,
//                                 ),
//                                 builder: (context, translatedSnapshot) {
//                                   return Text(
//                                     translatedSnapshot.data ?? item.name,
//                                     textAlign: TextAlign.center,
//                                     style: const TextStyle(
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 );
//               }
//             },
//           ),
//         ),
//       ),
//     );
//   }
// }
