import 'dart:convert';
import 'dart:developer';

import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/ulits/Constents.dart';

class BidService {
  final GetStorage _storage;

  BidService(this._storage);

  Future<Map<String, dynamic>> placeFinalBids({
    required String gameName,
    required String accessToken,
    required String registerId,
    required String deviceId,
    required String deviceName,
    required bool accountStatus,
    required Map<String, String> bidAmounts,
    required String selectedGameType,
    required int gameId,
    required String gameType,
    required int totalBidAmount,
  }) async {
    String apiUrl;
    if (gameName.toLowerCase().contains('jackpot')) {
      apiUrl = '${Constant.apiEndpoint}place-jackpot-bid';
    } else if (gameName.toLowerCase().contains('starline')) {
      apiUrl = '${Constant.apiEndpoint}place-starline-bid';
    } else {
      apiUrl = '${Constant.apiEndpoint}place-bid';
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      return {
        'status': false,
        'msg': 'Authentication error. Please log in again.',
      };
    }

    final headers = {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final List<Map<String, dynamic>> bidPayloadList = [];
    bidAmounts.forEach((digit, amount) {
      bidPayloadList.add({
        "sessionType": selectedGameType.toUpperCase(),
        "digit": digit,
        "pana": "",
        "bidAmount": int.tryParse(amount) ?? 0,
      });
    });

    final body = {
      "registerId": registerId,
      "gameId": gameId.toString(),
      "bidAmount": totalBidAmount,
      "gameType": gameType,
      "bid": bidPayloadList,
    };

    // --- Logging cURL command for debugging ---
    String curlCommand = 'curl -X POST \\\n  $apiUrl \\';
    headers.forEach((key, value) {
      curlCommand += '\n  -H "$key: $value" \\';
    });
    curlCommand += '\n  -d \'${jsonEncode(body)}\'';

    log('CURL Command for Final Bid Submission:\n$curlCommand', name: 'BidAPI');
    log('Request Headers for Final Bid Submission: $headers', name: 'BidAPI');
    log(
      'Request Body for Final Bid Submission: ${jsonEncode(body)}',
      name: 'BidAPI',
    );

    // --- End logging ---
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(body),
      );

      log('Response Status Code: ${response.statusCode}', name: 'BidAPI');
      log('Response Body: ${response.body}', name: 'BidAPI');

      final Map<String, dynamic> responseBody = json.decode(response.body);

      if (response.statusCode == 200 && responseBody['status'] == true) {
        return {'status': true, 'data': responseBody};
      } else {
        return {
          'status': false,
          'msg': responseBody['msg'] ?? "Unknown error occurred.",
        };
      }
    } catch (e) {
      log('Network error during bid submission: $e', name: 'BidAPIError');
      return {
        'status': false,
        'msg': 'Network error. Please check your internet connection.',
      };
    }
  }

  Future<void> updateWalletBalance(int newBalance) async {
    await _storage.write('walletBalance', newBalance.toString());
  }

  getBidAmounts(List<Map<String, String>> bids) {
    Map<String, String> bidAmounts = {};
    for (var bid in bids) {
      bidAmounts[bid['digit']!] = bid['amount']!;
    }
    return bidAmounts;
  }
}
