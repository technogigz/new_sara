import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

import '../Helper/TranslationHelper.dart';
import '../ulits/Constents.dart';

class KingStarlineBidType {
  final int id;
  final String title;
  final String image;
  final String type;
  final bool digitPannaStatus; // Used for conditional routing
  String translatedTitle; // This will hold the translated title

  KingStarlineBidType({
    required this.id,
    required this.title,
    required this.image,
    required this.type,
    required this.digitPannaStatus,
    this.translatedTitle = '', // Initialize with empty string
  });

  factory KingStarlineBidType.fromJson(Map<String, dynamic> json) {
    return KingStarlineBidType(
      id: json['id'] ?? 0,
      title: json['name'] ?? '',
      image: json['image'] ?? '',
      type: json['type'] ?? '',
      digitPannaStatus: json['digitPannaStatus'] ?? false,
    );
  }

  // Method to update translated title after fetching
  void updateTranslatedTitle(String newTitle) {
    translatedTitle = newTitle;
  }
}

class KingStarlineOptionScreen extends StatefulWidget {
  final String
  gameTime; // Specific time for this Starline game (e.g., "1:00 PM")
  final String title;
  final dynamic
  selectedId; // General title for Starline (e.g., "King Starline") - Renamed from 'selectedId' to 'starlineGameId' for clarity below

  const KingStarlineOptionScreen({
    super.key,
    required this.gameTime,
    required this.title,
    required this.selectedId, // Keeping this name as per your code
  });

  @override
  State<KingStarlineOptionScreen> createState() =>
      _KingStarlineOptionScreenState();
}

class _KingStarlineOptionScreenState extends State<KingStarlineOptionScreen> {
  List<KingStarlineBidType> options = [];
  bool isLoading = true;
  final GetStorage _storage = GetStorage();

  late String _currentLanguageCode;
  int _walletBalance = 0;

  final Map<String, String> _translationCache = {};

  // Futures for dynamically translated texts
  Future<String>? _translatedWalletTextFuture;
  Future<String>? _translatedNetworkErrorTextFuture;
  Future<String>? _translatedNoBidTypesTextFuture;
  Future<String>? _translatedAuthenticationErrorTextFuture;
  Future<String>? _translatedFailedToLoadTextFuture;
  Future<String>? _translatedNoScreenConfiguredTextFuture;
  Future<String>?
  _translatedMarketClosedTextFuture; // New: For market closed dialog
  Future<String>?
  _translatedOkTextFuture; // New: For market closed dialog OK button

  @override
  void initState() {
    super.initState();

    _currentLanguageCode = _storage.read('selectedLanguage') ?? 'en';
    _loadWalletBalance(); // Initial load of wallet balance
    _preTranslateFixedTexts(); // Pre-translate fixed texts

    // Listen for language changes and re-fetch/re-translate
    _storage.listenKey('selectedLanguage', (value) {
      if (value != null && value is String && value != _currentLanguageCode) {
        if (mounted) {
          // Check if mounted before setState
          setState(() {
            _currentLanguageCode = value;
            _translationCache.clear(); // Clear cache on language change
            _preTranslateFixedTexts(); // Re-translate fixed texts
            fetchKingStarlineBidTypes(); // Re-trigger fetch and translation
          });
        }
      }
    });

    // Listen for wallet balance changes
    _storage.listenKey('walletBalance', (value) {
      if (mounted) {
        setState(() {
          _loadWalletBalance(); // Reload wallet balance on change
        });
      }
    });

    fetchKingStarlineBidTypes(); // Initial fetch
  }

  // New: Pre-translate fixed strings used in the UI
  void _preTranslateFixedTexts() {
    _translatedWalletTextFuture = _getTranslatedText('Wallet');
    _translatedNetworkErrorTextFuture = _getTranslatedText(
      'Network error. Please try again later.',
    );
    _translatedNoBidTypesTextFuture = _getTranslatedText(
      'No Starline games available.\nPlease try again later.',
    );
    _translatedAuthenticationErrorTextFuture = _getTranslatedText(
      'Authentication error: Please log in again.',
    );
    _translatedFailedToLoadTextFuture = _getTranslatedText(
      'Failed to load starline bid types:',
    );
    _translatedNoScreenConfiguredTextFuture = _getTranslatedText(
      'No screen configured for game type:',
    );
    _translatedMarketClosedTextFuture = _getTranslatedText(
      'Market Closed',
    ); // New
    _translatedOkTextFuture = _getTranslatedText('OK'); // New
  }

  // Helper method to load wallet balance safely
  void _loadWalletBalance() {
    final storedWallet = _storage.read('walletBalance');
    if (storedWallet is int) {
      _walletBalance = storedWallet;
    } else if (storedWallet is String) {
      _walletBalance = int.tryParse(storedWallet) ?? 0;
    } else {
      _walletBalance = 0;
    }
  }

  // Helper method to get translated text, leveraging cache and TranslationHelper
  Future<String> _getTranslatedText(String text) async {
    // If target language is English, no need to translate
    if (_currentLanguageCode == 'en') {
      return text;
    }

    final cacheKey = '$text:$_currentLanguageCode';
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    // Check GetStorage for cached translation (persistent cache)
    final storedTranslation = _storage.read('translation_$cacheKey');
    if (storedTranslation != null && storedTranslation is String) {
      _translationCache[cacheKey] = storedTranslation;
      return storedTranslation;
    }

    try {
      final translated = await TranslationHelper.translate(
        text,
        _currentLanguageCode,
      );
      if (translated.isNotEmpty) {
        _translationCache[cacheKey] = translated;
        _storage.write(
          'translation_$cacheKey',
          translated,
        ); // Store in GetStorage
        return translated;
      } else {
        log(
          'TranslationHelper returned empty text for "$text". Falling back to original.',
        );
        return text;
      }
    } catch (e) {
      log('Error translating "$text": $e. Falling back to original text.');
      return text;
    }
  }

  // New: Method to show the market closed dialog
  Future<void> _showMarketClosedDialog(String gameName) async {
    final translatedTitle =
        await _translatedMarketClosedTextFuture ??
        'Market Closed'; // Use pre-translated future
    final translatedOk =
        await _translatedOkTextFuture ?? 'OK'; // Use pre-translated future
    final translatedContentPrefix = await _getTranslatedText('The market for');
    final translatedContentSuffix = await _getTranslatedText(
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

  Future<void> fetchKingStarlineBidTypes() async {
    if (!mounted) return; // Guard against setState calls after dispose

    setState(() {
      isLoading = true; // Set loading state to true before fetching
      options = []; // Clear previous options
    });

    final url = Uri.parse('${Constant.apiEndpoint}starline-game-bid-type');
    String? bearerToken = _storage.read("accessToken");

    if (bearerToken == null || bearerToken.isEmpty) {
      log('Error: Access token not found or is empty. Cannot fetch bid types.');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      final String authErrorMsg =
          await _translatedAuthenticationErrorTextFuture ??
          'Authentication error: Please log in again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMsg)));
      return;
    }

    final headers = {
      'deviceId': 'qwerr',
      'deviceName': 'sm2233',
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $bearerToken',
    };

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        log('Full KingStarline API Response Data: ${jsonEncode(data)}');

        if (data['status'] == true && data['info'] != null) {
          final List<dynamic> list = data['info'];
          List<KingStarlineBidType> fetchedOptions = [];

          for (var itemJson in list) {
            try {
              var option = KingStarlineBidType.fromJson(itemJson);
              fetchedOptions.add(option);
            } catch (e) {
              log(
                'Error parsing KingStarlineBidType from JSON item: $itemJson. Error: $e',
              );
            }
          }

          // **OPTIMIZATION: Concurrently translate all items**
          List<Future<void>> translationFutures = [];
          for (var option in fetchedOptions) {
            translationFutures.add(
              _getTranslatedText(option.title).then((translatedName) {
                option.updateTranslatedTitle(translatedName);
              }),
            );
          }
          await Future.wait(
            translationFutures,
          ); // Wait for all translations to complete

          if (mounted) {
            setState(() {
              options = fetchedOptions; // Update with translated options
              isLoading = false;
            });
          }
        } else {
          log(
            "KingStarline API Response Status Not True or Info Missing: ${json.encode(data)}",
          );
          if (mounted) {
            setState(() {
              options =
                  []; // Clear options if API status is false or info is missing
              isLoading = false;
            });
          }
          final String noBidTypesMsg =
              await _translatedNoBidTypesTextFuture ??
              'No Starline games available.\nPlease try again later.';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(noBidTypesMsg)));
        }
      } else {
        log("KingStarline API Error: ${response.statusCode}, ${response.body}");
        if (mounted) {
          setState(() => isLoading = false);
        }
        final String failedToLoadMsg =
            await _translatedFailedToLoadTextFuture ??
            'Failed to load starline bid types:';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$failedToLoadMsg ${response.statusCode}')),
        );
      }
    } catch (e) {
      log("Exception during KingStarline API call: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
      final String networkErrorMsg =
          await _translatedNetworkErrorTextFuture ??
          'Network error. Please try again later.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(networkErrorMsg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use widget.title for the main app bar title, as it's passed from the previous screen
    final String appBarTitle = widget.title;

    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey.shade300,
        elevation: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
            ),
            const SizedBox(width: 8),
            Text(
              appBarTitle, // Using the passed title
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w200,
              ),
            ),
            const Spacer(),
            Image.asset(
              "assets/images/wallet_icon.png",
              color: Colors.black,
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 4),
            Text(
              "₹ $_walletBalance", // Use the private wallet balance
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
            : options.isEmpty
            ? Center(
                child: FutureBuilder<String>(
                  future: _translatedNoBidTypesTextFuture,
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ??
                          'No Starline games available.\nPlease try again later.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    );
                  },
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(40),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: options.map((item) => _optionItem(item)).toList(),
                ),
              ),
      ),
    );
  }

  Widget _optionItem(KingStarlineBidType item) {
    // The parent screen title, e.g., "King Starline" (from widget.title)
    final String parentScreenTitle = widget.title;

    return InkWell(
      onTap: () async {
        log(
          'Tapped on: ${item.translatedTitle} (Original Title: ${item.title}, Type: ${item.type}, Digit Panna Status: ${item.digitPannaStatus})',
        );
        // Normalize the type string for robust comparison
        final gameType = item.type.toLowerCase().trim();

        // Dynamic routing based on gameType
        Widget? destinationScreen;
        switch (gameType) {
          case 'singledigits':
            // Corrected logic: if digitPannaStatus is true, go to SinglePannaScreen, else SingleDigitBetScreen

            // destinationScreen = SingleDigitBetScreen(
            //   title: "$parentScreenTitle, ${item.translatedTitle}",
            //   gameId: widget.selectedId, // Pass the selected Starline Game ID
            //   gameName: item.title,
            //   gameCategoryType: item.type,
            // );
            break;
          //
          // case 'spmotor':
          //   destinationScreen = SPMotorsBetScreen(
          //     title: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //     gameName: item.title,
          //     gameCategoryType: item.type,
          //   );
          //   break;
          //
          // case 'dpmotor':
          // case 'doublepana': // Assuming 'doublepana' also maps to DPMotorsBetScreen
          //   destinationScreen = DPMotorsBetScreen(
          //     title: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //     gameName: item.title,
          //     gameCategoryType: item.type,
          //   );
          //   break;
          //
          // case 'triplepana':
          //   destinationScreen = TPMotorsBetScreen(
          //     title: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //     gameName: item.title,
          //     gameCategoryType: item.type,
          //   );
          //   break;
          //
          // case 'singledigitsbulk':
          //   destinationScreen = SingleDigitsBulkScreen(
          //     title: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameName: item.title,
          //     gameType: item.type,
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //   );
          //   break;
          //
          // case 'singlepanabulk':
          // case 'doublepanabulk':
          //   destinationScreen = SinglePannaBulkBoardScreen(
          //     title: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //     gameType: item.type,
          //     gameName: item.title,
          //   );
          //   break;
          //
          // case 'jodi':
          //   destinationScreen = JodiBidScreen(
          //     title: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameType: item.type,
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //     gameName: item.title,
          //   );
          //   break;
          //
          // case 'panelgroup':
          //   destinationScreen = PanelGroupScreen(
          //     title: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //     gameName: item.title,
          //     gameCategoryType: item.type,
          //   );
          //   break;
          //
          // case 'groupdigit': // This typically goes to JodiBidScreen or a specific digit-group screen
          // case 'twodigitpanna': // This typically goes to JodiBidScreen if it's a "Jodi-like" input
          //   destinationScreen = JodiBidScreen(
          //     // Assuming JodiBidScreen can handle these types
          //     title: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameType: item.type,
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //     gameName: item.title,
          //   );
          //   break;
          //
          // case 'jodibulk':
          //   destinationScreen = JodiBulkScreen(
          //     screenTitle: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameType: item.type,
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //     gameName: item.title,
          //   );
          //   break;
          //
          // case 'singlepana':
          //   destinationScreen = SinglePannaScreen(
          //     title: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameType: item.type,
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //   );
          //   break;
          //
          // case 'twodigitspanel':
          //   destinationScreen = TwoDigitPanelScreen(
          //     title: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameType: item.type,
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //   );
          //   break;
          //
          // case 'groupjodi':
          //   destinationScreen = GroupJodiScreen(
          //     title: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameType: item.type,
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //   );
          //   break;
          //
          // case 'digitbasedjodi':
          //   destinationScreen = DigitBasedBoardScreen(
          //     title: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameId: widget.selectedId.toString(), // Ensure gameId is String
          //     gameType: item.type,
          //     gameName: item.title,
          //   );
          //   break;
          //
          // case 'oddeven':
          //   destinationScreen = OddEvenBoardScreen(
          //     title: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameType: item.type,
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //   );
          //   break;
          //
          // case 'choicepannaspdp':
          //   destinationScreen = ChoiceSpDpTpBoardScreen(
          //     screenTitle: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameType: item.type,
          //     gameId: widget.selectedId,
          //     gameName:
          //         widget.title +
          //         ", " +
          //         item.title, // Pass the selected Starline Game ID
          //   );
          //   break;
          //
          // case 'spdptp':
          //   destinationScreen = SpDpTpBoardScreen(
          //     screenTitle: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameType: item.type,
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //   );
          //   break;
          //
          // case 'redbracket':
          //   destinationScreen = RedBracketBoardScreen(
          //     screenTitle: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameType: item.type,
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //   );
          //   break;
          //
          // case 'halfsangama':
          //   destinationScreen = HalfSangamABoardScreen(
          //     screenTitle: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameType: item.type,
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //   );
          //   break;
          //
          // case 'halfsangamb':
          //   destinationScreen = HalfSangamBBoardScreen(
          //     screenTitle: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameType: item.type,
          //     gameId: widget.selectedId,
          //     gameName: item.title, // Pass the selected Starline Game ID
          //   );
          //   break;
          //
          // case 'fullsangam':
          //   destinationScreen = FullSangamBoardScreen(
          //     screenTitle: "$parentScreenTitle, ${item.translatedTitle}",
          //     gameType: item.type,
          //     gameId: widget.selectedId, // Pass the selected Starline Game ID
          //   );
          //   break;

          default:
            final String noScreenConfiguredMsg =
                await _translatedNoScreenConfiguredTextFuture ??
                'No screen configured for game type:';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "$noScreenConfiguredMsg '${item.type}' (Original: '${item.title}')",
                ),
              ),
            );
            log(
              "Unhandled game type: ${item.type} (Original title: ${item.title})",
            );
        }

        if (destinationScreen != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destinationScreen!),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Image.network(
                item.image,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  log(
                    'Image load error for ${item.title}: ${item.image} | $error',
                  );
                  return const Icon(
                    Icons.broken_image,
                    size: 40,
                    color: Colors.red,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.translatedTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
