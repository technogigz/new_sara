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

class JackpotBidType {
  final int id;
  final String title;
  final String image;
  final String type;
  String translatedTitle; // This will hold the translated title

  JackpotBidType({
    required this.id,
    required this.title,
    required this.image,
    required this.type,
    this.translatedTitle = '', // Initialize with empty string
  });

  factory JackpotBidType.fromJson(Map<String, dynamic> json) {
    return JackpotBidType(
      id: json['id'] ?? 0,
      title: json['name'] ?? '',
      image: json['image'] ?? '',
      type: json['type'] ?? '',
    );
  }

  // Method to update translated title after fetching
  void updateTranslatedTitle(String newTitle) {
    translatedTitle = newTitle;
  }
}

class JackpotJodiOptionsScreen extends StatefulWidget {
  final String gameTime;

  const JackpotJodiOptionsScreen({super.key, required this.gameTime});

  @override
  State<JackpotJodiOptionsScreen> createState() =>
      _JackpotJodiOptionsScreenState();
}

class _JackpotJodiOptionsScreenState extends State<JackpotJodiOptionsScreen> {
  List<JackpotBidType> options = [];
  bool isLoading = true;

  final GetStorage _storage = GetStorage();
  late String _currentLanguageCode; // Renamed for clarity
  int _walletBalance = 0; // Renamed for clarity and private

  // In-memory cache for translations within this screen's scope
  final Map<String, String> _translationCache = {};

  @override
  void initState() {
    super.initState();

    _currentLanguageCode = _storage.read('selectedLanguage') ?? 'en';
    _loadWalletBalance(); // Initial load of wallet balance

    // Listen for language changes
    _storage.listenKey('selectedLanguage', (value) {
      if (value != null && value is String) {
        if (value != _currentLanguageCode) {
          setState(() {
            _currentLanguageCode = value;
            _translationCache.clear(); // Clear cache on language change
            // Re-fetch and re-translate all options
            fetchJackpotBidTypes();
          });
        }
      }
    });

    // Listen for wallet balance changes
    _storage.listenKey('walletBalance', (value) {
      setState(() {
        _loadWalletBalance(); // Reload wallet balance on change
      });
    });

    fetchJackpotBidTypes(); // Initial fetch
  }

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

  // Helper method to get translated text, leveraging cache
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

  Future<void> fetchJackpotBidTypes() async {
    setState(() {
      isLoading = true; // Set loading state to true before fetching
    });

    final url = Uri.parse('https://sara777.win/api/v1/jackpot-game-bid-type');
    String? bearerToken = _storage.read("accessToken"); // Use _storage instance

    if (bearerToken == null || bearerToken.isEmpty) {
      log('Error: Access token not found or is empty.');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      // Optionally show an error message to the user
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
        log('Full Jackpot API Response Data: ${jsonEncode(data)}');

        if (data['status'] == true && data['info'] != null) {
          final List<dynamic> list = data['info'];
          List<JackpotBidType> fetchedOptions = [];

          for (var itemJson in list) {
            try {
              var option = JackpotBidType.fromJson(itemJson);
              fetchedOptions.add(option);
            } catch (e) {
              log(
                'Error parsing JackpotBidType from JSON item: $itemJson. Error: $e',
              );
            }
          }

          // Trigger translation for all fetched items
          List<JackpotBidType> translatedOptions = await Future.wait(
            fetchedOptions.map((option) async {
              option.updateTranslatedTitle(
                await _getTranslatedText(option.title),
              );
              return option;
            }).toList(),
          );

          if (mounted) {
            setState(() {
              options = translatedOptions;
              isLoading = false;
            });
          }
        } else {
          log(
            "Jackpot API Response Status Not True or Info Missing: ${json.encode(data)}",
          );
          if (mounted) {
            setState(() {
              options =
                  []; // Clear options if API status is false or info is missing
              isLoading = false;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No jackpot bid types found.')),
          );
        }
      } else {
        log("Jackpot API Error: ${response.statusCode}, ${response.body}");
        if (mounted) {
          setState(() => isLoading = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load jackpot bid types: ${response.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      log("Exception during Jackpot API call: $e");
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
              widget.gameTime,
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
                  "No jackpot bid types available or failed to load.",
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

  Widget _optionItem(JackpotBidType item) {
    // Translate "Jackpot Game" once if needed, or get it from a constant
    // For simplicity, let's assume 'Jackpot Game' is a fixed string for now.
    // If it needs to be translated dynamically as well, you'd call _getTranslatedText('Jackpot Game') here.
    const String screenTitle = "Jackpot Game";

    return InkWell(
      onTap: () {
        log('Tapped on: ${item.translatedTitle} (Original: ${item.title})');
        // Use item.type.toLowerCase().trim() for robust comparison
        switch (item.type.toLowerCase().trim()) {
          case 'singledigits':
          case 'spmotor':
          case 'dpmotor':
          case 'triplepana':
          case 'doublepana':
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
          case 'singlepanabulk': // Corrected case for bulk single pana
          case 'doublepanabulk': // Corrected case for bulk double pana
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
                  log('Image load error: ${item.image} | $error');
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
//
// class JackpotBidType {
//   final int id;
//   final String title;
//   final String image;
//   final String type;
//   String translatedTitle;
//
//   JackpotBidType({
//     required this.id,
//     required this.title,
//     required this.image,
//     required this.type,
//     this.translatedTitle = '',
//   });
//
//   factory JackpotBidType.fromJson(Map<String, dynamic> json) {
//     return JackpotBidType(
//       id: json['id'] ?? 0,
//       title: json['name'] ?? '',
//       image: json['image'] ?? '',
//       type: json['type'] ?? '',
//     );
//   }
// }
//
// class JackpotJodiOptionsScreen extends StatefulWidget {
//   final String gameTime;
//
//   const JackpotJodiOptionsScreen({super.key, required this.gameTime});
//
//   @override
//   State<JackpotJodiOptionsScreen> createState() =>
//       _JackpotJodiOptionsScreenState();
// }
//
// class _JackpotJodiOptionsScreenState extends State<JackpotJodiOptionsScreen> {
//   List<JackpotBidType> options = [];
//   bool isLoading = true;
//
//   final GetStorage _storage = GetStorage();
//   late String selectedLanguage;
//   int walletBalance = 0; // No need for late here, initialized directly
//
//   @override
//   void initState() {
//     super.initState();
//
//     fetchJackpotBidTypes();
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
//   Future<void> fetchJackpotBidTypes() async {
//     final url = Uri.parse('https://sara777.win/api/v1/jackpot-game-bid-type');
//     String? bearerToken = GetStorage().read("accessToken");
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
//         List<JackpotBidType> translatedList = [];
//
//         for (var item in list) {
//           try {
//             var option = JackpotBidType.fromJson(item);
//             option.translatedTitle = await TranslationHelper.translate(
//               option.title,
//               selectedLanguage,
//             );
//             translatedList.add(option);
//           } catch (e) {
//             log(
//               'Error parsing JackpotBidType from JSON item: $item. Error: $e',
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
//               "assets/images/wallet_icon.png",
//               color: Colors.black,
//               width: 24,
//               height: 24,
//             ),
//             const SizedBox(width: 4),
//             Text(
//               "₹ $walletBalance", // Replace with actual wallet balance if needed
//               style: const TextStyle(color: Colors.black, fontSize: 16),
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
//                   "No jackpot bid types available or failed to load.",
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
//   Widget _optionItem(JackpotBidType item) {
//     final String screenTitle = "Jackpot Game";
//
//     return InkWell(
//       onTap: () {
//         log('Tapped on: ${item.translatedTitle} (${item.title})');
//         log('Tapped on: ${item.translatedTitle} (${item.title.toLowerCase()})');
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
//                   log('Image load error: ${item.image} | $error');
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
