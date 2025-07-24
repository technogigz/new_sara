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

import '../Helper/TranslationHelper.dart'; // YOUR TranslationHelper
import '../ulits/Constents.dart';
import 'DigitBasedBoard/DigitBasedBoardScreen.dart';
import 'Jodi/JodiBidScreen.dart';
import 'Jodi/group_jodi_screen.dart';
import 'OddEvenBoard/OddEvenBoardScreen.dart';
import 'SingleDigitBetScreen/SingleDigitBetScreen.dart';
import 'SingleDigitBetScreen/SingleDigitsBulkScreen.dart';
import 'TwoDigitPanel/TwoDigitPanel.dart';

// ✅ Model - Modified GameItem
class GameItem {
  final int id;
  final String name; // Original name from API
  final String type;
  final String image;
  final bool sessionSelection;
  String
  currentDisplayName; // Display name (initially original, then translated) - Non-nullable

  GameItem({
    required this.id,
    required this.name,
    required this.type,
    required this.image,
    required this.sessionSelection,
    String?
    currentDisplayName, // Make optional in constructor for initial assignment
  }) : this.currentDisplayName =
           currentDisplayName ??
           name; // Default to original name if not provided

  factory GameItem.fromJson(Map<String, dynamic> json) {
    return GameItem(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      image: json['image'],
      sessionSelection: json['sessionSelection'] ?? false,
      // currentDisplayName is initialized in the constructor after fromJson is called
    );
  }

  // Method to update display name
  void updateDisplayName(String newName) {
    currentDisplayName = newName;
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
  Future<List<GameItem>>? _futureGames; // Made nullable for initial state
  final storage = GetStorage();
  late String _currentLanguageCode;

  // Simple in-memory cache for translations
  final Map<String, String> _translationCache = {};

  @override
  void initState() {
    super.initState();
    _currentLanguageCode = storage.read('selectedLanguage') ?? 'en';
    // Listen for language changes
    storage.listenKey('selectedLanguage', (value) {
      if (value != null && value is String && value != _currentLanguageCode) {
        setState(() {
          _currentLanguageCode = value;
          // Clear cache and refetch/retranslate all games on language change
          _translationCache.clear();
          _futureGames = fetchGameList(); // Re-trigger fetch and translation
        });
      }
    });
    _futureGames = fetchGameList(); // Initial fetch
  }

  // New helper to get translation from cache or fetch
  Future<String> _getTranslatedName(String originalName) async {
    // If the target language is English, no need to translate
    if (_currentLanguageCode == 'en') {
      return originalName;
    }

    final cacheKey = '$originalName:$_currentLanguageCode';
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!; // Guaranteed non-null
    }

    // Check GetStorage for cached translation
    final storedTranslation = storage.read('translation_$cacheKey');
    if (storedTranslation != null && storedTranslation is String) {
      _translationCache[cacheKey] = storedTranslation;
      return storedTranslation;
    }

    // Fetch and cache
    try {
      final translated = await TranslationHelper.translate(
        originalName,
        _currentLanguageCode,
      );
      // Check if the result from your TranslationHelper is null or empty
      if (translated.isNotEmpty) {
        _translationCache[cacheKey] = translated;
        storage.write('translation_$cacheKey', translated);
        return translated;
      } else {
        log(
          'TranslationHelper returned empty text for "$originalName". Falling back to original.',
        );
        return originalName; // Fallback to original if translation is empty
      }
    } catch (e) {
      log(
        'Error translating "$originalName": $e. Falling back to original name.',
      );
      return originalName; // Fallback to original name on any error
    }
  }

  Future<List<GameItem>> fetchGameList() async {
    String? bearerToken = storage.read('accessToken');
    if (bearerToken == null || bearerToken.isEmpty) {
      log('Error: Access token not found in GetStorage or is empty.');
      throw Exception('Access token not found or is empty');
    }

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
        final List data = decoded['info'];
        List<GameItem> gameItems = [];

        for (var itemJson in data) {
          GameItem gameItem = GameItem.fromJson(itemJson);
          gameItems.add(gameItem);

          // Start translation in the background for each item
          _getTranslatedName(gameItem.name)
              .then((translatedName) {
                if (mounted) {
                  setState(() {
                    gameItem.updateDisplayName(translatedName);
                  });
                }
              })
              .catchError((e) {
                log('Error setting display name for ${gameItem.name}: $e');
              });
        }
        return gameItems; // Return items immediately (initially with original names)
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

  // --- New method to show the market closed dialog ---
  Future<void> _showMarketClosedDialog(String gameName) async {
    // Translate dialog content on demand using the robust _getTranslatedName
    final translatedTitle = await _getTranslatedName('Market Closed');
    final translatedOk = await _getTranslatedName('OK');

    // For the content message, we need to handle the dynamic part ($gameName)
    // Send the full message to TranslationHelper or construct it after translation.
    // Let's construct it for clarity and ensure proper string interpolation.
    final String contentMessageTemplate =
        'The market for $gameName is currently closed.';
    final String fullyTranslatedContent = await _getTranslatedName(
      contentMessageTemplate,
    );

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(translatedTitle),
          content: Text(fullyTranslatedContent),
          actions: <Widget>[
            TextButton(
              child: Text(translatedOk),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dismiss dialog
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Translate screen title once using _getTranslatedName
    final Future<String> translatedScreenTitle = _getTranslatedName(
      widget.title,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey.shade200,
        elevation: 0,
        title: FutureBuilder<String>(
          future: translatedScreenTitle,
          builder: (context, snapshot) {
            return Text(
              snapshot.data ??
                  widget.title, // Show original until translation is ready
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
              _translationCache.clear(); // Clear cache on refresh
              _futureGames =
                  fetchGameList(); // Re-fetch all data and translations
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
                          mainAxisSpacing:
                              12, // Increased spacing to match image
                          crossAxisSpacing:
                              12, // Increased spacing to match image
                          childAspectRatio:
                              1, // Keep aspect ratio for square cards
                        ),
                    itemBuilder: (context, index) {
                      final item = games[index];
                      final gameType = item.type; // From API

                      return GestureDetector(
                        onTap: () async {
                          log(
                            "Attempting navigation for Game Type: $gameType, Name: ${item.name}, Current Display: ${item.currentDisplayName}",
                          );

                          // --- CHECK SESSION SELECTION HERE ---
                          if (!item.sessionSelection) {
                            await _showMarketClosedDialog(
                              item.currentDisplayName,
                            ); // Await dialog
                            return;
                          }
                          // --- END CHECK ---

                          // Translate the screen title part of the destination title
                          String parentScreenTranslatedTitle =
                              await translatedScreenTitle;

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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
                                    gameId: item.id,
                                    gameName: item.name,
                                    gameCategoryType: item.type,
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
                                    gameId: item.id,
                                    gameType: item.type,
                                    gameName: item.name,
                                  ),
                                ),
                              );
                              break;

                            case 'doublePanaBulk':
                            case 'singlePanaBulk':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SinglePannaBulkBoardScreen(
                                    title:
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
                                    gameId: item.id,
                                    gameType: item.type,
                                    gameName: item.name,
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
                                    gameId: item.id,
                                    gameType: item.type,
                                    gameName: item.name,
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
                                    gameId: item.id,
                                    gameType: item.type,
                                    gameName: item.name,
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
                                    gameId: item.id.toString(),
                                    gameType: item.type,
                                    gameName: item.name,
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
                                    "No screen available for ${item.currentDisplayName}",
                                  ),
                                ),
                              );
                              log("Unhandled game type: ${item.type}");
                          }
                        },
                        // UI structure matching Image 1
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                Colors.grey.shade300, // Card background color
                            borderRadius: BorderRadius.circular(
                              8,
                            ), // Rounded corners
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(
                                  0.2,
                                ), // Subtle shadow
                                blurRadius: 4,
                                spreadRadius: 0.5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // The overall container for the image area, defining its max size within the card
                              Container(
                                width:
                                    100, // Explicitly set a smaller size for the circular container
                                height:
                                    100, // to ensure it's a circle and has internal padding/spacing
                                decoration: BoxDecoration(
                                  color: Colors
                                      .white, // The white circular background
                                  shape: BoxShape
                                      .circle, // Makes it a perfect circle
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 3,
                                      spreadRadius: 0.5,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(
                                  20,
                                ), // Padding inside the white circle for the image
                                child: Image.network(
                                  item.image,
                                  fit: BoxFit
                                      .contain, // Ensure the entire image is visible within the padded circle
                                  // REMOVED: color: Colors.amber.shade700, // This was likely causing the "weird" look
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.broken_image_outlined,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                ),
                              ),

                              const SizedBox(
                                height: 8,
                              ), // Spacing between image and text
                              Text(
                                item.currentDisplayName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black, // Text color
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
// import '../Helper/TranslationHelper.dart'; // YOUR TranslationHelper
// import '../ulits/Constents.dart';
// import 'DigitBasedBoard/DigitBasedBoardScreen.dart';
// import 'Jodi/JodiBidScreen.dart';
// import 'Jodi/group_jodi_screen.dart';
// import 'OddEvenBoard/OddEvenBoardScreen.dart';
// import 'SingleDigitBetScreen/SingleDigitBetScreen.dart';
// import 'SingleDigitBetScreen/SingleDigitsBulkScreen.dart';
// import 'TwoDigitPanel/TwoDigitPanel.dart';
//
// // ✅ Model - Modified GameItem
// class GameItem {
//   final int id;
//   final String name; // Original name from API
//   final String type;
//   final String image;
//   final bool sessionSelection;
//   String
//   currentDisplayName; // Display name (initially original, then translated) - Non-nullable
//
//   GameItem({
//     required this.id,
//     required this.name,
//     required this.type,
//     required this.image,
//     required this.sessionSelection,
//     String?
//     currentDisplayName, // Make optional in constructor for initial assignment
//   }) : this.currentDisplayName =
//            currentDisplayName ??
//            name; // Default to original name if not provided
//
//   factory GameItem.fromJson(Map<String, dynamic> json) {
//     return GameItem(
//       id: json['id'],
//       name: json['name'],
//       type: json['type'],
//       image: json['image'],
//       sessionSelection: json['sessionSelection'] ?? false,
//       // currentDisplayName is initialized in the constructor after fromJson is called
//     );
//   }
//
//   // Method to update display name
//   void updateDisplayName(String newName) {
//     currentDisplayName = newName;
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
//   Future<List<GameItem>>? _futureGames; // Made nullable for initial state
//   final storage = GetStorage();
//   late String _currentLanguageCode;
//
//   // Simple in-memory cache for translations
//   final Map<String, String> _translationCache = {};
//
//   @override
//   void initState() {
//     super.initState();
//     _currentLanguageCode = storage.read('selectedLanguage') ?? 'en';
//     // Listen for language changes
//     storage.listenKey('selectedLanguage', (value) {
//       if (value != null && value is String && value != _currentLanguageCode) {
//         setState(() {
//           _currentLanguageCode = value;
//           // Clear cache and refetch/retranslate all games on language change
//           _translationCache.clear();
//           _futureGames = fetchGameList(); // Re-trigger fetch and translation
//         });
//       }
//     });
//     _futureGames = fetchGameList(); // Initial fetch
//   }
//
//   // New helper to get translation from cache or fetch
//   Future<String> _getTranslatedName(String originalName) async {
//     // If the target language is English, no need to translate
//     if (_currentLanguageCode == 'en') {
//       return originalName;
//     }
//
//     final cacheKey = '$originalName:$_currentLanguageCode';
//     if (_translationCache.containsKey(cacheKey)) {
//       return _translationCache[cacheKey]!; // Guaranteed non-null
//     }
//
//     // Check GetStorage for cached translation
//     final storedTranslation = storage.read('translation_$cacheKey');
//     if (storedTranslation != null && storedTranslation is String) {
//       _translationCache[cacheKey] = storedTranslation;
//       return storedTranslation;
//     }
//
//     // Fetch and cache
//     try {
//       final translated = await TranslationHelper.translate(
//         originalName,
//         _currentLanguageCode,
//       );
//       // **CRUCIAL CHANGE HERE:** Check if the result from your TranslationHelper is null or empty
//       if (translated.isNotEmpty) {
//         _translationCache[cacheKey] = translated;
//         storage.write('translation_$cacheKey', translated);
//         return translated;
//       } else {
//         log(
//           'TranslationHelper returned empty text for "$originalName". Falling back to original.',
//         );
//         return originalName; // Fallback to original if translation is empty
//       }
//     } catch (e) {
//       log(
//         'Error translating "$originalName": $e. Falling back to original name.',
//       );
//       return originalName; // Fallback to original name on any error
//     }
//   }
//
//   Future<List<GameItem>> fetchGameList() async {
//     String? bearerToken = storage.read('accessToken');
//     if (bearerToken == null || bearerToken.isEmpty) {
//       log('Error: Access token not found in GetStorage or is empty.');
//       throw Exception('Access token not found or is empty');
//     }
//
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
//       if (decoded['status'] == true && decoded['info'] != null) {
//         final List data = decoded['info'];
//         List<GameItem> gameItems = [];
//
//         for (var itemJson in data) {
//           GameItem gameItem = GameItem.fromJson(itemJson);
//           gameItems.add(gameItem);
//
//           // Start translation in the background for each item
//           _getTranslatedName(gameItem.name)
//               .then((translatedName) {
//                 if (mounted) {
//                   setState(() {
//                     gameItem.updateDisplayName(translatedName);
//                   });
//                 }
//               })
//               .catchError((e) {
//                 log('Error setting display name for ${gameItem.name}: $e');
//               });
//         }
//         return gameItems; // Return items immediately (initially with original names)
//       } else {
//         log(
//           "API Response Status Not True or Info Missing: ${json.encode(decoded)}",
//         );
//         throw Exception(
//           "No game items found in API response or status is false.",
//         );
//       }
//     } else {
//       log("API Error: ${response.statusCode}, ${response.body}");
//       throw Exception("Failed to load game list: ${response.statusCode}");
//     }
//   }
//
//   // --- New method to show the market closed dialog ---
//   Future<void> _showMarketClosedDialog(String gameName) async {
//     // Translate dialog content on demand using the robust _getTranslatedName
//     final translatedTitle = await _getTranslatedName('Market Closed');
//     final translatedOk = await _getTranslatedName('OK');
//
//     // For the content message, we need to handle the dynamic part ($gameName)
//     // Send the full message to TranslationHelper or construct it after translation.
//     // Let's construct it for clarity and ensure proper string interpolation.
//     final String contentMessageTemplate =
//         'The market for $gameName is currently closed.';
//     final String fullyTranslatedContent = await _getTranslatedName(
//       contentMessageTemplate,
//     );
//
//     return showDialog<void>(
//       context: context,
//       barrierDismissible: false, // User must tap a button
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: Text(translatedTitle),
//           content: Text(fullyTranslatedContent),
//           actions: <Widget>[
//             TextButton(
//               child: Text(translatedOk),
//               onPressed: () {
//                 Navigator.of(dialogContext).pop(); // Dismiss dialog
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Translate screen title once using _getTranslatedName
//     final Future<String> translatedScreenTitle = _getTranslatedName(
//       widget.title,
//     );
//
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.grey.shade200,
//         elevation: 0,
//         title: FutureBuilder<String>(
//           future: translatedScreenTitle,
//           builder: (context, snapshot) {
//             return Text(
//               snapshot.data ??
//                   widget.title, // Show original until translation is ready
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
//               _translationCache.clear(); // Clear cache on refresh
//               _futureGames =
//                   fetchGameList(); // Re-fetch all data and translations
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
//                 return Center(
//                   child: Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Text(
//                       "Error loading games: ${snapshot.error}",
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(color: Colors.red, fontSize: 16),
//                     ),
//                   ),
//                 );
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
//                       final gameType = item.type; // From API
//
//                       return GestureDetector(
//                         onTap: () async {
//                           // Made onTap async
//                           log(
//                             "Attempting navigation for Game Type: $gameType, Name: ${item.name}, Current Display: ${item.currentDisplayName}",
//                           );
//
//                           // --- CHECK SESSION SELECTION HERE ---
//                           if (!item.sessionSelection) {
//                             await _showMarketClosedDialog(
//                               item.currentDisplayName,
//                             ); // Await dialog
//                             return;
//                           }
//                           // --- END CHECK ---
//
//                           // Translate the screen title part of the destination title
//                           String parentScreenTranslatedTitle =
//                               await translatedScreenTitle;
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
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
//                                     gameId: item.id,
//                                     gameName: item.name,
//                                     gameCategoryType: item.type,
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
//                                     title:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                     gameName: item.name,
//                                   ),
//                                 ),
//                               );
//                               break;
//
//                             case 'doublePanaBulk':
//                             case 'singlePanaBulk':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => SinglePannaBulkBoardScreen(
//                                     title:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                     gameName: item.name,
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
//                                     title:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                     gameName: item.name,
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
//                                     screenTitle:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                     gameName: item.name,
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
//                                     title:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
//                                     title:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
//                                     gameId: item.id,
//                                     gameType: item.type,
//                                   ),
//                                 ),
//                               );
//                               break;
//
//                             case 'groupJodi':
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => GroupJodiScreen(
//                                     title:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
//                                     title:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
//                                     gameId: item.id.toString(),
//                                     gameType: item.type,
//                                     gameName: item.name,
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
//                                     title:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
//                                     screenTitle:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
//                                     screenTitle:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
//                                     screenTitle:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
//                                     screenTitle:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
//                                     screenTitle:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
//                                     screenTitle:
//                                         "$parentScreenTranslatedTitle, ${item.currentDisplayName}", // Use display name
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
//                                     "No screen available for ${item.currentDisplayName}",
//                                   ),
//                                 ),
//                               );
//                               log("Unhandled game type: ${item.type}");
//                           }
//                         },
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white, // Changed background to white
//                             borderRadius: BorderRadius.circular(12),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.grey.withOpacity(
//                                   0.3,
//                                 ), // More visible shadow
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
//                                 width: 100,
//                                 height: 100,
//                                 decoration: const BoxDecoration(
//                                   shape: BoxShape.circle,
//                                   color: Colors.white,
//                                 ),
//                                 padding: const EdgeInsets.all(10),
//                                 child: Padding(
//                                   padding: const EdgeInsets.all(8.0),
//                                   child: Image.network(
//                                     item.image,
//                                     fit: BoxFit.contain,
//                                     errorBuilder:
//                                         (
//                                           context,
//                                           error,
//                                           stackTrace,
//                                         ) => const Icon(
//                                           Icons
//                                               .broken_image_outlined, // More descriptive icon
//                                           size: 60,
//                                           color: Colors.grey,
//                                         ),
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(height: 10),
//                               // Display the currentDisplayName (original or translated)
//                               Text(
//                                 item.currentDisplayName, // This is now guaranteed to be a String
//                                 textAlign: TextAlign.center,
//                                 style: const TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w600,
//                                 ),
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
