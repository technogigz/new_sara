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
  String translatedTitle;

  JackpotBidType({
    required this.id,
    required this.title,
    required this.image,
    required this.type,
    this.translatedTitle = '',
  });

  factory JackpotBidType.fromJson(Map<String, dynamic> json) {
    return JackpotBidType(
      id: json['id'] ?? 0,
      title: json['name'] ?? '',
      image: json['image'] ?? '',
      type: json['type'] ?? '',
    );
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
  String selectedLanguage = GetStorage().read("selectedLanguage") ?? "en";

  @override
  void initState() {
    super.initState();
    fetchJackpotBidTypes();
  }

  Future<void> fetchJackpotBidTypes() async {
    final url = Uri.parse('https://sara777.win/api/v1/jackpot-game-bid-type');
    String? bearerToken = GetStorage().read("accessToken");
    if (bearerToken == null) {
      log('Error: Access token not found in GetStorage.');
      setState(() {
        isLoading = false;
      });
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
        log('Full API Response Data: ${jsonEncode(data)}');
        final List<dynamic> list = data['info'] ?? [];

        List<JackpotBidType> translatedList = [];

        for (var item in list) {
          try {
            var option = JackpotBidType.fromJson(item);
            option.translatedTitle = await TranslationHelper.translate(
              option.title,
              selectedLanguage,
            );
            translatedList.add(option);
          } catch (e) {
            log(
              'Error parsing JackpotBidType from JSON item: $item. Error: $e',
            );
          }
        }

        setState(() {
          options = translatedList;
          isLoading = false;
        });
      } else {
        log("API Error: ${response.statusCode}, ${response.body}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      log("Exception during API call: $e");
      setState(() => isLoading = false);
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
            const Text(
              "5", // Replace with actual wallet balance if needed
              style: TextStyle(color: Colors.black, fontSize: 16),
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
    final String screenTitle = "Jackpot Game";

    return InkWell(
      onTap: () {
        log('Tapped on: ${item.translatedTitle} (${item.title})');
        log('Tapped on: ${item.translatedTitle} (${item.title.toLowerCase()})');
        switch (item.title.toLowerCase().trim()) {
          case 'singledigits':
          case 'spmotor':
          case 'dpmotor':
          case 'triplepana':
          case 'doublepana':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SingleDigitBetScreen(
                  title:
                      "$screenTitle, ${item.translatedTitle}", // Recommended: Use translatedTitle for display
                  gameId: item.id,
                  gameName: item
                      .title, // Keep original title for internal game logic if needed
                  gameCategoryType:
                      item.type, // This is the new, correct parameter name
                ),
              ),
            );
            break;

          case 'singledigitsbulk':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SingleDigitsBulkScreen(
                  title: "$screenTitle, ${item.title}",
                  gameName: item.title,
                  selectedGameType: item.type,
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          case 'jodi':
          case 'panelgroup':
          case 'singlepanabulk':
          case 'groupdigit':
          case 'twodigitpanna':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JodiBidScreen(
                  title: "$screenTitle, ${item.title}",
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          case 'jodibulk':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JodiBulkScreen(
                  screenTitle: "$screenTitle, ${item.title}",
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          case 'singlepana':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SinglePannaScreen(
                  title: "$screenTitle, ${item.title}",
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
                  title: "$screenTitle, ${item.title}",
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
                  title: "$screenTitle, ${item.title}",
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
                  title: "$screenTitle, ${item.title}",
                  gameId: item.id as String,
                  gameType: item.type,
                ),
              ),
            );
            break;

          case 'oddeven':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OddEvenBoardScreen(
                  title: "$screenTitle, ${item.title}",
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
                  screenTitle: "$screenTitle, ${item.title}",
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
                  screenTitle: "$screenTitle, ${item.title}",
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
                  screenTitle: "$screenTitle, ${item.title}",
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
                  screenTitle: "$screenTitle, ${item.title}",
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
                  screenTitle: "$screenTitle, ${item.title}",
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
                  screenTitle: "$screenTitle, ${item.title}",
                  gameType: item.type,
                  gameId: item.id,
                ),
              ),
            );
            break;

          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("No screen available for ${item.title}")),
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
