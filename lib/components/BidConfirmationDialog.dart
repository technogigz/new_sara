import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../ulits/Constents.dart'; // Ensure this path is correct

class BidConfirmationDialog extends StatelessWidget {
  final String gameTitle;
  final String gameDate;
  final List<Map<String, String>> bids;
  final int totalBids;
  final int totalBidsAmount;
  final int walletBalanceBeforeDeduction;
  final String? walletBalanceAfterDeduction;
  final String gameId;
  final String gameType; // This will determine which API to call

  const BidConfirmationDialog({
    Key? key,
    required this.gameTitle,
    required this.gameDate,
    required this.bids,
    required this.totalBids,
    required this.totalBidsAmount,
    required this.walletBalanceBeforeDeduction,
    this.walletBalanceAfterDeduction,
    required this.gameId,
    required this.gameType,
  }) : super(key: key);

  // Common headers for all API calls
  Map<String, String> _getHeaders(String accessToken) {
    // Replace with actual device ID, name (These often come from device info packages)
    const String deviceId = 'your_device_id_here'; // Get actual device ID
    const String deviceName = 'your_device_name_here'; // Get actual device name

    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'accessStatus': '1', // Assuming '1' means active
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  /// Places a bid for Normal Games (Jodi, Single, Pana, Sangam, etc.)
  Future<void> _placeNormalGameBid(
    BuildContext context,
    List<Map<String, String>> bidsToSubmit,
    int totalAmount,
    String gameIdValue,
    String gameTypeValue,
    String accessToken,
    String registerId,
  ) async {
    final String apiUrl = Constant.normalGamePlaceBidEndpoint;

    List<Map<String, dynamic>> transformedBids = bidsToSubmit.map((bid) {
      String sessionType = bid['type'] ?? '';
      String digitValue = bid['digit'] ?? '';
      String panaValue = ''; // Default to empty string for non-pana bids

      // If the game type indicates a Pana or Sangam, then 'digit' is actually the pana value
      if (gameTypeValue.toLowerCase().contains('pana') ||
          gameTypeValue.toLowerCase().contains('sangam')) {
        panaValue = digitValue;
        digitValue = ''; // Clear digit if it's a pana bid
      }

      return {
        "sessionType": sessionType,
        "digit":
            digitValue, // This will be the actual digit for single, jodi, etc.
        "pana":
            panaValue, // This will be the pana for pana/sangam, empty otherwise
        "bidAmount": int.tryParse(bid['points'] ?? '0') ?? 0,
      };
    }).toList();

    final Map<String, dynamic> requestBody = {
      "registerId": registerId,
      "gameId": gameIdValue,
      "bidAmount": totalAmount,
      "gameType": gameTypeValue,
      "bid": transformedBids, // Array of bid objects
    };

    await _sendBidRequest(
      context,
      apiUrl,
      requestBody,
      accessToken,
      'Normal Game',
    );
  }

  /// Places a bid for King Starline Games
  Future<void> _placeStarlineBid(
    BuildContext context,
    List<Map<String, String>> bidsToSubmit,
    int totalAmount,
    String gameIdValue,
    String gameTypeValue,
    String accessToken,
    String registerId,
  ) async {
    final String apiUrl = Constant.starlinePlaceBidEndpoint;

    List<Map<String, dynamic>> transformedBids = bidsToSubmit.map((bid) {
      String sessionType =
          bid['type'] ?? 'Open'; // Default for Starline if not specified
      return {
        "sessionType":
            sessionType, // Adjust if Starline has unique session types
        "digit": bid['digit'] ?? '',
        "bidAmount": int.tryParse(bid['points'] ?? '0') ?? 0,
        // Add other Starline specific fields like 'timeSlot' if required by API
      };
    }).toList();

    final Map<String, dynamic> requestBody = {
      "registerId": registerId,
      "gameId": gameIdValue,
      "totalBidAmount": totalAmount,
      "gameType": gameTypeValue,
      "starlineBids": transformedBids, // Assuming key is 'starlineBids'
    };

    await _sendBidRequest(
      context,
      apiUrl,
      requestBody,
      accessToken,
      'King Starline',
    );
  }

  /// Places a bid for King Jackpot Games
  Future<void> _placeJackpotBid(
    BuildContext context,
    List<Map<String, String>> bidsToSubmit,
    int totalAmount,
    String gameIdValue,
    String gameTypeValue,
    String accessToken,
    String registerId,
  ) async {
    final String apiUrl = Constant.jackpotPlaceBidEndpoint;

    List<Map<String, dynamic>> transformedBids = bidsToSubmit.map((bid) {
      String sessionType =
          bid['type'] ?? 'Open'; // Default for Jackpot if not specified
      return {
        "sessionType":
            sessionType, // Adjust if Jackpot has unique session types
        "digit": bid['digit'] ?? '',
        "bidAmount": int.tryParse(bid['points'] ?? '0') ?? 0,
        // Add other Jackpot specific fields if required by API
      };
    }).toList();

    final Map<String, dynamic> requestBody = {
      "registerId": registerId,
      "gameId": gameIdValue,
      "totalBidAmount": totalAmount,
      "gameType": gameTypeValue,
      "jackpotBids": transformedBids, // Assuming key is 'jackpotBids'
    };

    await _sendBidRequest(
      context,
      apiUrl,
      requestBody,
      accessToken,
      'King Jackpot',
    );
  }

  /// Generic function to send the HTTP bid request
  Future<void> _sendBidRequest(
    BuildContext context,
    String apiUrl,
    Map<String, dynamic> requestBody,
    String accessToken,
    String gameCategory, // For logging purposes
  ) async {
    log('Sending $gameCategory API Request to: $apiUrl');
    log('Request Headers: ${jsonEncode(_getHeaders(accessToken))}');
    log('Request Body: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _getHeaders(accessToken),
        body: jsonEncode(requestBody),
      );

      final responseData = jsonDecode(response.body);
      log('API Response Status Code: ${response.statusCode}');
      log('API Response Body: $responseData');

      if (response.statusCode == 200) {
        final String message =
            responseData['message'] ?? 'Bids confirmed successfully!';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        Navigator.of(context).pop(true); // Pop with 'true' to indicate success
      } else {
        // Log the full response body for non-200 status codes
        log('Error Response Body for $gameCategory: ${response.body}');
        final String errorMessage =
            responseData['message'] ??
            'Failed to confirm bids. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $errorMessage (Status: ${response.statusCode})',
            ), // Include status code in error message
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(
          context,
        ).pop(false); // Pop with 'false' to indicate failure
      }
    } catch (e) {
      log('Exception during $gameCategory API call: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
      Navigator.of(context).pop(false); // Pop with 'false' on exception
    }
  }

  // The main _placeBid method now acts as a dispatcher
  Future<void> _placeBid(BuildContext context) async {
    // Corrected the key to "accessToken" (double 's')
    final String? accessToken = GetStorage().read("accessToken");
    final String? registerId = GetStorage().read("registerId");

    if (accessToken == null || registerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication error. Please log in again.'),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    if (bids.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No bids to submit.')));
      return;
    }

    // Determine which specific bid placement method to call
    if (gameType.toLowerCase().contains('starline')) {
      // Use toLowerCase for robust checking
      await _placeStarlineBid(
        context,
        bids,
        totalBidsAmount,
        gameId,
        gameType,
        accessToken,
        registerId,
      );
    } else if (gameType.toLowerCase().contains('jackpot')) {
      // Use toLowerCase for robust checking
      await _placeJackpotBid(
        context,
        bids,
        totalBidsAmount,
        gameId,
        gameType,
        accessToken,
        registerId,
      );
    } else {
      // Default to Normal Game bid if not Starline or Jackpot
      // This covers Jodi, Single, Pana, Sangam, etc.
      await _placeNormalGameBid(
        context,
        bids,
        totalBidsAmount,
        gameId,
        gameType,
        accessToken,
        registerId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int finalWalletBalanceAfterDeduction =
        int.tryParse(walletBalanceAfterDeduction ?? '') ??
        (walletBalanceBeforeDeduction - totalBidsAmount);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$gameTitle - $gameDate',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Digits',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Points',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Type',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(thickness: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: bids.length,
                itemBuilder: (context, index) {
                  final bid = bids[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            bid['digit'] ?? '',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            bid['points'] ?? '',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            bid['type'] ?? '',
                            style: GoogleFonts.poppins(
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(thickness: 1),
            const SizedBox(height: 16),
            _buildSummaryRow('Total Bids', totalBids.toString()),
            _buildSummaryRow('Total Bids Amount', totalBidsAmount.toString()),
            _buildSummaryRow(
              'Wallet Balance Before Deduction',
              walletBalanceBeforeDeduction.toString(),
            ),
            _buildSummaryRow(
              'Wallet Balance After Deduction',
              finalWalletBalanceAfterDeduction.toString(),
              isNegative: finalWalletBalanceAfterDeduction < 0,
            ),
            const SizedBox(height: 16),
            Text(
              'Note: Bid Once Played Can Not Be Cancelled',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _placeBid(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Submit',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isNegative ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
