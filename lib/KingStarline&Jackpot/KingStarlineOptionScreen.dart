import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

import '../Helper/TranslationHelper.dart';
import '../game/DigitBasedBoard/DigitBasedBoardScreen.dart';
import '../game/Jodi/JodiBidScreen.dart';
import '../game/Jodi/JodiBulkScreen.dart';
import '../game/Jodi/group_jodi_screen.dart';
import '../game/OddEvenBoard/OddEvenBoardScreen.dart';
import '../game/Panna/SinglePanna/SinglePanna.dart';
import '../game/RedBracket/RedBracketScreen.dart';
import '../game/SPDPTPScreen/ChoiceSpDpTpBoardScreen.dart';
import '../game/SPDPTPScreen/SpDpTpBoardScreen.dart';
import '../game/Sangam/FullSangamBoardScreen.dart';
import '../game/Sangam/HalfSangamABoardScreen.dart';
import '../game/Sangam/HalfSangamBBoardScreen.dart';
import '../game/SingleDigitBetScreen/SingleDigitBetScreen.dart';
import '../game/SingleDigitBetScreen/SingleDigitsBulkScreen.dart';
import '../game/TwoDigitPanel/TwoDigitPanel.dart';
import '../ulits/Constents.dart';

class KingStarlineBidType {
  final int id;
  final String title;
  final String image;
  final String type;
  final bool digitPannaStatus;
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
  final String gameTime;
  final String title;

  const KingStarlineOptionScreen({
    super.key,
    required this.gameTime,
    required this.title,
  });

  @override
  State<KingStarlineOptionScreen> createState() =>
      _KingStarlineOptionScreenState();
}

class _KingStarlineOptionScreenState extends State<KingStarlineOptionScreen> {
  List<KingStarlineBidType> options = [];
  bool isLoading = true;
  final GetStorage _storage = GetStorage();

  late String _currentLanguageCode; // Renamed for clarity and consistency
  int _walletBalance = 0; // Renamed for clarity and private

  // In-memory cache for translations within this screen's scope
  final Map<String, String> _translationCache = {};

  @override
  void initState() {
    super.initState();

    _currentLanguageCode = _storage.read('selectedLanguage') ?? 'en';
    _loadWalletBalance(); // Initial load of wallet balance

    // Listen for language changes and re-fetch/re-translate
    _storage.listenKey('selectedLanguage', (value) {
      if (value != null && value is String && value != _currentLanguageCode) {
        setState(() {
          _currentLanguageCode = value;
          _translationCache.clear(); // Clear cache on language change
          fetchKingStarlineBidTypes(); // Re-trigger fetch and translation
        });
      }
    });

    // Listen for wallet balance changes
    _storage.listenKey('walletBalance', (value) {
      if (mounted) {
        // Ensure widget is still mounted before setState
        setState(() {
          _loadWalletBalance(); // Reload wallet balance on change
        });
      }
    });

    fetchKingStarlineBidTypes(); // Initial fetch
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication error: Please log in again.'),
        ),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No starline bid types found or API issue.'),
            ),
          );
        }
      } else {
        log("KingStarline API Error: ${response.statusCode}, ${response.body}");
        if (mounted) {
          setState(() => isLoading = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load starline bid types: ${response.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      log("Exception during KingStarline API call: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again later.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Translate the screen title once, outside the build method if possible,
    // or use a FutureBuilder here if it needs to be dynamic based on selectedLanguage.
    // For now, it's a fixed string "KingStarline Game" in _optionItem, but consider if widget.title needs translation.
    // Assuming widget.title (from outside) is already handled or not requiring dynamic translation here.
    final String appBarTitle = widget.title; // Use widget.title for consistency

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
              // Using widget.title for the main app bar title, if that's the intention
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
            ? const Center(
                child: Text(
                  "No Starline games available.\nPlease try again later.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
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
    // Note: 'KingStarline Game' is a fixed string here. If it also needs
    // to be translated, you'd call _getTranslatedText('KingStarline Game')
    // in the build method and pass it down or make it a FutureBuilder.
    const String screenTitle = "KingStarline Game";

    return InkWell(
      onTap: () {
        log(
          'Tapped on: ${item.translatedTitle} (Original Title: ${item.title}, Type: ${item.type}, Digit Panna Status: ${item.digitPannaStatus})',
        );
        // Normalize the type string for robust comparison
        final gameType = item.type.toLowerCase().trim();

        // Pass gameTime to relevant screens if they need it for API calls
        // For example, SingleDigitBetScreen might need it to fetch market status for that specific time.

        switch (gameType) {
          case 'singledigits':
          case 'spmotor':
          case 'dpmotor':
          case 'triplepana':
          case 'doublepana':
            // Check digitPannaStatus only for 'singleDigits' as per common logic
            // Assuming if digitPannaStatus is true for 'singleDigits', it means SinglePanna screen.
            // You might need to adjust this logic based on actual requirements.
            if (item.type.toLowerCase() == 'singledigits' &&
                item.digitPannaStatus) {
              // If singleDigits and digitPannaStatus is true, go to SinglePannaScreen (Panna game)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SinglePannaScreen(
                    title: "$screenTitle, ${item.translatedTitle}",
                    gameType: item.type, // Still pass 'singleDigits' type
                    gameId: item.id,
                  ),
                ),
              );
            } else {
              // Otherwise, go to SingleDigitBetScreen (Digit game)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SingleDigitBetScreen(
                    title: "$screenTitle, ${item.translatedTitle}",
                    gameId: item.id,
                    gameName: item.title,
                    gameCategoryType: item.type,
                  ),
                ),
              );
            }
            break;

          case 'singledigitsbulk':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SingleDigitsBulkScreen(
                  title: "$screenTitle, ${item.translatedTitle}",
                  gameName: item.title,
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          case 'jodi':
          case 'panelgroup':
          case 'singlepanabulk':
          case 'doublepanabulk':
          case 'groupdigit':
          case 'twodigitpanna':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JodiBidScreen(
                  title: "$screenTitle, ${item.translatedTitle}",
                  gameType: item.type,
                  gameId: item.id,
                  gameName: item.title,
                ),
              ),
            );
            break;

          case 'jodibulk':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JodiBulkScreen(
                  screenTitle: "$screenTitle, ${item.translatedTitle}",
                  gameType: item.type,
                  gameId: item.id,
                  gameName: item.title,
                ),
              ),
            );
            break;

          case 'singlepana':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SinglePannaScreen(
                  title: "$screenTitle, ${item.translatedTitle}",
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          case 'twodigitspanel':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TwoDigitPanelScreen(
                  title: "$screenTitle, ${item.translatedTitle}",
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          case 'groupjodi':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupJodiScreen(
                  title: "$screenTitle, ${item.translatedTitle}",
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          case 'digitbasedjodi':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DigitBasedBoardScreen(
                  title: "$screenTitle, ${item.translatedTitle}",
                  gameId: item.id.toString(),
                  gameType: item.type,
                  gameName: item.title,
                ),
              ),
            );
            break;

          case 'oddeven':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OddEvenBoardScreen(
                  title: "$screenTitle, ${item.translatedTitle}",
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          case 'choicepannaspdp':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChoiceSpDpTpBoardScreen(
                  screenTitle: "$screenTitle, ${item.translatedTitle}",
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          case 'spdptp':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SpDpTpBoardScreen(
                  screenTitle: "$screenTitle, ${item.translatedTitle}",
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          case 'redbracket':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RedBracketBoardScreen(
                  screenTitle: "$screenTitle, ${item.translatedTitle}",
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          case 'halfsangama':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HalfSangamABoardScreen(
                  screenTitle: "$screenTitle, ${item.translatedTitle}",
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          case 'halfsangamb':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HalfSangamBBoardScreen(
                  screenTitle: "$screenTitle, ${item.translatedTitle}",
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          case 'fullsangam':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullSangamBoardScreen(
                  screenTitle: "$screenTitle, ${item.translatedTitle}",
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "No screen configured for game type: '${item.type}' (Original: '${item.title}')",
                ),
              ),
            );
            log(
              "Unhandled game type: ${item.type} (Original title: ${item.title})",
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

// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:http/http.dart' as http;
//
// import '../Helper/TranslationHelper.dart';
// import '../game/DigitBasedBoard/DigitBasedBoardScreen.dart';
// import '../game/Jodi/JodiBidScreen.dart';
// import '../game/Jodi/JodiBulkScreen.dart';
// import '../game/Jodi/group_jodi_screen.dart';
// import '../game/OddEvenBoard/OddEvenBoardScreen.dart';
// import '../game/Panna/SinglePanna/SinglePanna.dart';
// import '../game/RedBracket/RedBracketScreen.dart';
// import '../game/SPDPTPScreen/ChoiceSpDpTpBoardScreen.dart';
// import '../game/SPDPTPScreen/SpDpTpBoardScreen.dart';
// import '../game/Sangam/FullSangamBoardScreen.dart';
// import '../game/Sangam/HalfSangamABoardScreen.dart';
// import '../game/Sangam/HalfSangamBBoardScreen.dart';
// import '../game/SingleDigitBetScreen/SingleDigitBetScreen.dart';
// import '../game/SingleDigitBetScreen/SingleDigitsBulkScreen.dart';
// import '../game/TwoDigitPanel/TwoDigitPanel.dart';
// import '../ulits/Constents.dart';
//
// class KingStarlineBidType {
//   final int id;
//   final String title;
//   final String image;
//   final String type;
//   final bool digitPannaStatus; // Added this field based on your API response
//   String translatedTitle;
//
//   KingStarlineBidType({
//     required this.id,
//     required this.title,
//     required this.image,
//     required this.type,
//     required this.digitPannaStatus, // Added to constructor
//     this.translatedTitle = '',
//   });
//
//   factory KingStarlineBidType.fromJson(Map<String, dynamic> json) {
//     return KingStarlineBidType(
//       id: json['id'] ?? 0,
//       title: json['name'] ?? '',
//       image: json['image'] ?? '',
//       type: json['type'] ?? '',
//       digitPannaStatus: json['digitPannaStatus'] ?? false, // Parsed this field
//     );
//   }
// }
//
// class KingStarlineOptionScreen extends StatefulWidget {
//   final String gameTime;
//   final String title;
//
//   const KingStarlineOptionScreen({
//     super.key,
//     required this.gameTime,
//     required this.title,
//   });
//
//   @override
//   State<KingStarlineOptionScreen> createState() =>
//       _KingStarlineOptionScreenState();
// }
//
// class _KingStarlineOptionScreenState extends State<KingStarlineOptionScreen> {
//   List<KingStarlineBidType> options = [];
//   bool isLoading = true;
//   // It's safer to get the GetStorage instance once, e.g., in initState or directly in the class
//   final GetStorage _storage = GetStorage();
//
//   late String selectedLanguage;
//   int walletBalance = 0; // No need for late here, initialized directly
//
//   @override
//   void initState() {
//     super.initState();
//
//     fetchKingStarlineBidTypes();
//     // Initialize values from storage
//     selectedLanguage = _storage.read('selectedLanguage') ?? 'en';
//
//     final storedWallet = _storage.read('walletBalance');
//     if (storedWallet is int) {
//       walletBalance = storedWallet;
//     } else if (storedWallet is String) {
//       walletBalance = int.tryParse(storedWallet) ?? 0;
//     } else {
//       walletBalance = 0;
//     }
//
//     // Listen for changes
//     _storage.listenKey('selectedLanguage', (value) {
//       if (value != null) {
//         setState(() {
//           selectedLanguage = value;
//         });
//       }
//     });
//
//     _storage.listenKey('walletBalance', (value) {
//       setState(() {
//         if (value is int) {
//           walletBalance = value;
//         } else if (value is String) {
//           walletBalance = int.tryParse(value) ?? 0;
//         } else {
//           walletBalance = 0;
//         }
//       });
//     });
//   }
//
//   Future<void> fetchKingStarlineBidTypes() async {
//     final url = Uri.parse('${Constant.apiEndpoint}starline-game-bid-type');
//     String? bearerToken = _storage.read("accessToken"); // Use the instance
//     if (bearerToken == null) {
//       log('Error: Access token not found in GetStorage.');
//       setState(() {
//         isLoading = false;
//       });
//       return;
//     }
//
//     final headers = {
//       'deviceId': 'qwerr',
//       'deviceName': 'sm2233',
//       'accessStatus': '1',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $bearerToken',
//     };
//
//     try {
//       final response = await http.get(url, headers: headers);
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         log('Full API Response Data: ${jsonEncode(data)}');
//         final List<dynamic> list = data['info'] ?? [];
//
//         List<KingStarlineBidType> translatedList = [];
//
//         for (var item in list) {
//           try {
//             var option = KingStarlineBidType.fromJson(item);
//             option.translatedTitle = await TranslationHelper.translate(
//               option.title,
//               selectedLanguage,
//             );
//             translatedList.add(option);
//           } catch (e) {
//             log(
//               'Error parsing KingStarlineBidType from JSON item: $item. Error: $e',
//             );
//           }
//         }
//
//         setState(() {
//           options = translatedList;
//           isLoading = false;
//         });
//       } else {
//         log("API Error: ${response.statusCode}, ${response.body}");
//         setState(() => isLoading = false);
//       }
//     } catch (e) {
//       log("Exception during API call: $e");
//       setState(() => isLoading = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade300,
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         backgroundColor: Colors.grey.shade300,
//         elevation: 0,
//         title: Row(
//           children: [
//             GestureDetector(
//               onTap: () => Navigator.pop(context),
//               child: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
//             ),
//             const SizedBox(width: 8),
//             Text(
//               widget.gameTime,
//               style: const TextStyle(
//                 color: Colors.black,
//                 fontSize: 18,
//                 fontWeight: FontWeight.w200,
//               ),
//             ),
//             const Spacer(),
//             Image.asset(
//               "assets/images/wallet_icon.png", // Make sure this asset exists
//               color: Colors.black,
//               width: 24,
//               height: 24,
//             ),
//             const SizedBox(width: 4),
//             Text(
//               "₹ $walletBalance", // Replace with actual wallet balance if needed
//               style: TextStyle(color: Colors.black, fontSize: 16),
//             ),
//           ],
//         ),
//       ),
//       body: SafeArea(
//         child: isLoading
//             ? const Center(
//                 child: CircularProgressIndicator(color: Colors.amber),
//               )
//             : options.isEmpty
//             ? const Center(
//                 child: Text(
//                   "Something went wrong.\nPlease try again later",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(fontSize: 16, color: Colors.black54),
//                 ),
//               )
//             : Padding(
//                 padding: const EdgeInsets.all(40),
//                 child: GridView.count(
//                   crossAxisCount: 2,
//                   mainAxisSpacing: 16,
//                   crossAxisSpacing: 16,
//                   children: options.map((item) => _optionItem(item)).toList(),
//                 ),
//               ),
//       ),
//     );
//   }
//
//   Widget _optionItem(KingStarlineBidType item) {
//     final String screenTitle = "KingStarline Game";
//
//     return InkWell(
//       onTap: () {
//         log(
//           'Tapped on: ${item.translatedTitle} (Original Title: ${item.title}, Type: ${item.type})',
//         );
//         // IMPORTANT: Use item.type.toLowerCase().trim() for the switch cases
//         // as the API 'type' field provides a more consistent identifier.
//         switch (item.type.toLowerCase().trim()) {
//           case 'singledigits':
//           case 'spmotor':
//           case 'dpmotor':
//           case 'triplepana':
//           case 'doublepana':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => SingleDigitBetScreen(
//                   title:
//                       "$screenTitle, ${item.translatedTitle}", // Recommended: Use translatedTitle for display
//                   gameId: item.id,
//                   gameName: item
//                       .title, // Keep original title for internal game logic if needed
//                   gameCategoryType:
//                       item.type, // This is the new, correct parameter name
//                 ),
//               ),
//             );
//             break;
//
//           case 'singledigitsbulk':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => SingleDigitsBulkScreen(
//                   title: "$screenTitle, ${item.translatedTitle}",
//                   gameName: item.title,
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'jodi':
//           case 'panelgroup':
//           case 'singlepanabulk':
//           case 'doublepanabulk':
//           case 'groupdigit':
//           case 'twodigitpanna':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => JodiBidScreen(
//                   title: "$screenTitle, ${item.translatedTitle}",
//                   gameType: item.type,
//                   gameId: item.id,
//                   gameName: item.title,
//                 ),
//               ),
//             );
//             break;
//
//           case 'jodibulk':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => JodiBulkScreen(
//                   screenTitle: "$screenTitle, ${item.translatedTitle}",
//                   gameType: item.type,
//                   gameId: item.id,
//                   gameName: item.title,
//                 ),
//               ),
//             );
//             break;
//
//           case 'singlepana':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => SinglePannaScreen(
//                   title: "$screenTitle, ${item.translatedTitle}",
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'twodigitspanel':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => TwoDigitPanelScreen(
//                   title: "$screenTitle, ${item.translatedTitle}",
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'groupjodi':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => GroupJodiScreen(
//                   title: "$screenTitle, ${item.translatedTitle}",
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'digitbasedjodi':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => DigitBasedBoardScreen(
//                   title: "$screenTitle, ${item.translatedTitle}",
//                   gameId: item.id
//                       .toString(), // Ensure gameId is String if required by DigitBasedBoardScreen
//                   gameType: item.type,
//                   gameName: item.title,
//                 ),
//               ),
//             );
//             break;
//
//           case 'oddeven':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => OddEvenBoardScreen(
//                   title: "$screenTitle, ${item.translatedTitle}",
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'choicepannaspdp':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => ChoiceSpDpTpBoardScreen(
//                   screenTitle: "$screenTitle, ${item.translatedTitle}",
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'spdptp':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => SpDpTpBoardScreen(
//                   screenTitle: "$screenTitle, ${item.translatedTitle}",
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'redbracket':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => RedBracketBoardScreen(
//                   screenTitle: "$screenTitle, ${item.translatedTitle}",
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'halfsangama':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => HalfSangamABoardScreen(
//                   screenTitle: "$screenTitle, ${item.translatedTitle}",
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'halfsangamb':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => HalfSangamBBoardScreen(
//                   screenTitle: "$screenTitle, ${item.translatedTitle}",
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'fullsangam':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => FullSangamBoardScreen(
//                   screenTitle: "$screenTitle, ${item.translatedTitle}",
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           default:
//             // This will catch any types not explicitly handled above
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text(
//                   "No screen configured for game type: '${item.type}' (Original: '${item.title}')",
//                 ),
//               ),
//             );
//             log(
//               "Unhandled game type: ${item.type} (Original title: ${item.title})",
//             );
//         }
//       },
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.grey.shade300,
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 6,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               width: 80,
//               height: 80,
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 shape: BoxShape.circle,
//                 border: Border.all(color: Colors.grey.shade300),
//               ),
//               child: Image.network(
//                 item.image,
//                 width: 40,
//                 height: 40,
//                 fit: BoxFit.contain,
//                 errorBuilder: (context, error, stackTrace) {
//                   log(
//                     'Image load error for ${item.title}: ${item.image} | $error',
//                   );
//                   return const Icon(
//                     Icons.broken_image,
//                     size: 40,
//                     color: Colors.red,
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 12),
//             Text(
//               item.translatedTitle,
//               textAlign: TextAlign.center,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black87,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
