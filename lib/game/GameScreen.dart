import 'dart:convert';
import 'dart:developer'; // For logging

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
// Import your game screens
import 'package:new_sara/game/Jodi/JodiBulkScreen.dart';
import 'package:new_sara/game/Panna/SinglePanna/SinglePanna.dart';
import 'package:new_sara/game/Panna/SinglePanna/SinglePannaBulk.dart';
import 'package:new_sara/game/RedBracket/RedBracketScreen.dart';
import 'package:new_sara/game/SPDPTPScreen/ChoiceSpDpTpBoardScreen.dart';
import 'package:new_sara/game/SPDPTPScreen/SPMotors.dart';
import 'package:new_sara/game/SPDPTPScreen/SpDpTpBoardScreen.dart';
import 'package:new_sara/game/SPDPTPScreen/TPMotorScreen.dart';
import 'package:new_sara/game/Sangam/FullSangamBoardScreen.dart';
import 'package:new_sara/game/Sangam/HalfSangamABoardScreen.dart';
import 'package:new_sara/game/Sangam/HalfSangamBBoardScreen.dart';

import '../Helper/TranslationHelper.dart'; // YOUR TranslationHelper
import '../ulits/Constents.dart';
import 'DigitBasedBoard/DigitBasedBoardScreen.dart';
import 'GameItem.dart';
import 'Jodi/JodiBidScreen.dart';
import 'Jodi/group_jodi_screen.dart';
import 'OddEvenBoard/OddEvenBoardScreen.dart';
import 'PannelGroup/PannelGroup.dart';
import 'SPDPTPScreen/DPMotors.dart';
import 'SingleDigitBetScreen/SingleDigitBetScreen.dart';
import 'SingleDigitBetScreen/SingleDigitsBulkScreen.dart';
import 'TwoDigitPanel/TwoDigitPanel.dart';

// ✅ Main Screen
class GameMenuScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final bool openSessionStatus;
  final bool closeSessionStatus;
  const GameMenuScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.openSessionStatus,
    required this.closeSessionStatus,
  });

  @override
  State<GameMenuScreen> createState() => _GameMenuScreenState();
}

class _GameMenuScreenState extends State<GameMenuScreen> {
  Future<List<GameItem>>? _futureGames; // Made nullable for initial state
  final storage = GetStorage();
  late String _currentLanguageCode;
  Future<String>?
  _translatedScreenTitleFuture; // To cache the main title translation

  // Simple in-memory cache for translations
  final Map<String, String> _translationCache = {};

  @override
  void initState() {
    super.initState();
    _currentLanguageCode = storage.read('selectedLanguage') ?? 'en';
    _translatedScreenTitleFuture = _getTranslatedName(
      widget.title,
    ); // Initial translation for title
    // Listen for language changes
    storage.listenKey('selectedLanguage', (value) {
      if (value != null && value is String && value != _currentLanguageCode) {
        setState(() {
          _currentLanguageCode = value;
          _translationCache.clear(); // Clear cache on language change
          _translatedScreenTitleFuture = _getTranslatedName(
            widget.title,
          ); // Re-translate title
          _futureGames =
              fetchGameList(); // Re-trigger fetch and translation for game items
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
      log(
        'Returning "$originalName" translation from in-memory cache.',
        name: 'TranslationCache',
      );
      return _translationCache[cacheKey]!; // Guaranteed non-null
    }

    // Check GetStorage for cached translation
    final storedTranslation = storage.read('translation_$cacheKey');
    if (storedTranslation != null && storedTranslation is String) {
      _translationCache[cacheKey] = storedTranslation;
      log(
        'Returning "$originalName" translation from GetStorage cache.',
        name: 'TranslationCache',
      );
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
        log(
          'Fetched and cached translation for "$originalName": "$translated".',
          name: 'TranslationFetch',
        );
        return translated;
      } else {
        log(
          'TranslationHelper returned empty text for "$originalName". Falling back to original.',
          name: 'GameMenuScreen.Translation',
        );
        return originalName; // Fallback to original if translation is empty
      }
    } catch (e) {
      log(
        'Error translating "$originalName": $e. Falling back to original name.',
        name: 'GameMenuScreen.Translation',
      );
      return originalName; // Fallback to original name on any error
    }
  }

  Future<List<GameItem>> fetchGameList() async {
    String? bearerToken = storage.read('accessToken');
    if (bearerToken == null || bearerToken.isEmpty) {
      log(
        'Error: Access token not found in GetStorage or is empty.',
        name: 'GameMenuScreen.Auth',
      );
      throw Exception('Access token not found or is empty');
    }

    log('Fetching game bid types from API...', name: 'GameMenuScreen.API');
    final response = await http.get(
      Uri.parse("${Constant.apiEndpoint}game-bid-type"),
      headers: {
        'deviceId': 'qwert', // Consider making these dynamic if needed
        'deviceName': 'sm2233', // Consider making these dynamic if needed
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

        log("API Response Status True: ${json.encode(decoded)}");

        for (var itemJson in data) {
          GameItem gameItem = GameItem.fromJson(itemJson);
          gameItems.add(gameItem);

          // Start translation in the background for each item
          _getTranslatedName(gameItem.name)
              .then((translatedName) {
                if (mounted) {
                  // Only update state if the widget is still mounted
                  setState(() {
                    gameItem.updateDisplayName(translatedName);
                  });
                }
              })
              .catchError((e) {
                log(
                  'Error setting display name for ${gameItem.name}: $e',
                  name: 'GameMenuScreen.Translation',
                );
              });
        }
        log(
          'Successfully fetched and initialized ${gameItems.length} game items.',
          name: 'GameMenuScreen.API',
        );
        return gameItems; // Return items immediately (initially with original names)
      } else {
        log(
          "API Response Status Not True or Info Missing: ${json.encode(decoded)}",
          name: 'GameMenuScreen.API',
        );
        throw Exception(
          "No game items found in API response or status is false.",
        );
      }
    } else {
      log(
        "API Error: ${response.statusCode}, ${response.body}",
        name: 'GameMenuScreen.API',
      );
      throw Exception("Failed to load game list: ${response.statusCode}");
    }
  }

  // New method to show the market closed dialog
  Future<void> _showMarketClosedDialog(String gameName) async {
    final translatedTitle = await _getTranslatedName('Market Closed');
    final translatedOk = await _getTranslatedName('OK');
    final translatedContentPrefix = await _getTranslatedName('The market for');
    final translatedContentSuffix = await _getTranslatedName(
      'is currently closed.',
    );

    // Construct the full message using translated parts and the already translated gameName
    final String fullyTranslatedContent =
        '$translatedContentPrefix $gameName $translatedContentSuffix';

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

  // Helper function to build routes dynamically (not used directly in current tap logic, but good to keep)
  MaterialPageRoute _buildGameRoute(
    Widget screen,
    String parentScreenTranslatedTitle,
    GameItem item,
  ) {
    return MaterialPageRoute(
      builder: (_) => screen,
      settings: RouteSettings(
        arguments: {
          'title': "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
          'gameId': item.id,
          'gameType': item.type,
          'gameName': item.name,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey.shade200,
        elevation: 0,
        title: FutureBuilder<String>(
          future: _translatedScreenTitleFuture, // Use the cached future
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
            log('Refreshing game menu data...', name: 'GameMenuScreen.Refresh');
            setState(() {
              _translationCache.clear(); // Clear cache on refresh
              _translatedScreenTitleFuture = _getTranslatedName(
                widget.title,
              ); // Re-translate title
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
                            name: 'GameMenuScreen.Tap',
                          );

                          // --- CHECK SESSION SELECTION HERE ---
                          if (widget.openSessionStatus == false &&
                              item.sessionSelection == false) {
                            await _showMarketClosedDialog(
                              item.currentDisplayName,
                            ); // Await the dialog
                            return;
                          } else {}

                          // Translate the screen title part of the destination title
                          String parentScreenTranslatedTitle =
                              await _translatedScreenTitleFuture!; // Await the cached future

                          // Dynamic routing based on gameType
                          Widget? destinationScreen;
                          switch (gameType) {
                            case 'singleDigits':
                              destinationScreen = SingleDigitBetScreen(
                                title:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameName: item.name,
                                gameCategoryType: item.type,
                                selectionStatus: widget.openSessionStatus,
                              );
                              break;

                            case 'spMotor':
                              destinationScreen = SPMotorsBetScreen(
                                title:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameName: item.name,
                                gameCategoryType: item.type,
                              );
                              break;

                            case 'doublePana':
                            case 'dpMotor':
                              destinationScreen = DPMotorsBetScreen(
                                title:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameName: item.name,
                                gameCategoryType: item.type,
                              );
                              break;

                            case 'triplePana':
                              destinationScreen = TPMotorsBetScreen(
                                title:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameName: item.name,
                                gameCategoryType: item.type,
                              );
                              break;

                            case 'singleDigitsBulk':
                              destinationScreen = SingleDigitsBulkScreen(
                                title:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
                                gameName: item.name,
                                selectionStatus: widget.openSessionStatus,
                              );
                              break;

                            case 'doublePanaBulk':
                            case 'singlePanaBulk':
                              destinationScreen = SinglePannaBulkBoardScreen(
                                title:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
                                gameName: item.name,
                              );
                              break;

                            case 'panelGroup':
                              destinationScreen = PanelGroupScreen(
                                title:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameName: item.name,
                                gameCategoryType: item.type,
                              );
                              break;

                            case 'jodi':
                            case 'groupDigit':
                            case 'twoDigitPanna':
                              destinationScreen = JodiBidScreen(
                                title:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
                                gameName: item.name,
                              );
                              break;

                            case 'jodiBulk':
                              destinationScreen = JodiBulkScreen(
                                screenTitle:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
                                gameName: item.name,
                              );
                              break;

                            case 'singlePana':
                              destinationScreen = SinglePannaScreen(
                                title:
                                    "$parentScreenTranslatedTitle ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
                              );
                              break;

                            case 'twoDigitsPanel':
                              destinationScreen = TwoDigitPanelScreen(
                                title:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
                              );
                              break;

                            case 'groupJodi':
                              destinationScreen = GroupJodiScreen(
                                title:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
                              );
                              break;

                            case 'digitBasedJodi':
                              destinationScreen = DigitBasedBoardScreen(
                                title:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: item.id
                                    .toString(), // Ensure gameId is String if expected by this screen
                                gameType: item.type,
                                gameName: item.name,
                              );
                              break;

                            case 'oddEven':
                              destinationScreen = OddEvenBoardScreen(
                                title:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
                              );
                              break;

                            case 'choicePannaSPDP':
                              destinationScreen = ChoiceSpDpTpBoardScreen(
                                screenTitle:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
                                gameName: item.name,
                              );
                              break;

                            case 'SPDPTP':
                              destinationScreen = SpDpTpBoardScreen(
                                screenTitle:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
                              );
                              break;

                            case 'redBracket':
                              destinationScreen = RedBracketBoardScreen(
                                screenTitle:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
                              );
                              break;

                            case 'halfSangamA':
                              destinationScreen = HalfSangamABoardScreen(
                                screenTitle:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
                                gameName: item.name,
                              );
                              break;
                            case 'halfSangamB':
                              destinationScreen = HalfSangamBBoardScreen(
                                screenTitle:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
                                gameName: item.name,
                              );
                              break;
                            case 'fullSangam':
                              destinationScreen = FullSangamBoardScreen(
                                screenTitle:
                                    "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                gameId: widget.gameId,
                                gameType: item.type,
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
                              log(
                                "Unhandled game type: ${item.type}",
                                name: 'GameMenuScreen.Navigation',
                              );
                              break;
                          }

                          if (destinationScreen != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => destinationScreen!,
                              ),
                            );
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
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.image_not_supported_outlined,
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
