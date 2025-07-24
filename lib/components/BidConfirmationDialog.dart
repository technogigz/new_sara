// BidConfirmationDialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// BidSuccessDialog.dart और BidFailureDialog.dart को अब यहां से इंपोर्ट करने की जरूरत नहीं है
// क्योंकि वे JodiBidScreen में उपयोग किए जाएंगे।

class BidConfirmationDialog extends StatelessWidget {
  final String gameTitle;
  final String gameDate;
  final List<Map<String, String>> bids;
  final int totalBids;
  final int totalBidsAmount;
  final int walletBalanceBeforeDeduction;
  final String? walletBalanceAfterDeduction;
  final String gameId;
  final String gameType;
  final VoidCallback onConfirm; // <--- Changed to VoidCallback

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
    required this.onConfirm, // <--- onConfirm is now a VoidCallback
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Safely parse walletBalanceAfterDeduction
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
                  final displayPoints = bid['points'] ?? bid['amount'] ?? '';
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
                            displayPoints,
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
                      Navigator.of(context).pop(); // Simply pop the dialog
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
                      Navigator.of(context).pop(); // Pop the dialog
                      onConfirm(); // <--- Call the onConfirm callback
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

// import 'dart:async'; // Import for Timer
// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:new_sara/ulits/Constents.dart';
//
// // Import the new dialogs
// import 'BidFailureDialog.dart';
// import 'BidSuccessDialog.dart';
//
// class BidConfirmationDialog extends StatelessWidget {
//   final String gameTitle;
//   final String gameDate;
//   final List<Map<String, String>> bids;
//   final int totalBids;
//   final int totalBidsAmount;
//   final int walletBalanceBeforeDeduction;
//   final String? walletBalanceAfterDeduction;
//   final String gameId;
//   final String gameType;
//
//   const BidConfirmationDialog({
//     Key? key,
//     required this.gameTitle,
//     required this.gameDate,
//     required this.bids,
//     required this.totalBids,
//     required this.totalBidsAmount,
//     required this.walletBalanceBeforeDeduction,
//     this.walletBalanceAfterDeduction,
//     required this.gameId,
//     required this.gameType,
//     required Future<Null> Function() onConfirm,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     // Safely parse walletBalanceAfterDeduction
//     final int finalWalletBalanceAfterDeduction =
//         int.tryParse(walletBalanceAfterDeduction ?? '') ??
//         (walletBalanceBeforeDeduction - totalBidsAmount);
//
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       elevation: 0,
//       backgroundColor: Colors.transparent,
//       child: Container(
//         padding: const EdgeInsets.all(16.0),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Container(
//               padding: const EdgeInsets.symmetric(vertical: 12.0),
//               decoration: BoxDecoration(
//                 color: Colors.amber,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Text(
//                 '$gameTitle - $gameDate',
//                 textAlign: TextAlign.center,
//                 style: GoogleFonts.poppins(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//             Padding(
//               padding: const EdgeInsets.symmetric(
//                 horizontal: 8.0,
//                 vertical: 4.0,
//               ),
//               child: Row(
//                 children: [
//                   Expanded(
//                     flex: 2,
//                     child: Text(
//                       'Digits',
//                       style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                   Expanded(
//                     flex: 2,
//                     child: Text(
//                       'Points', // Display label remains 'Points'
//                       style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                   Expanded(
//                     flex: 1,
//                     child: Text(
//                       'Type',
//                       style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const Divider(thickness: 1),
//
//             ConstrainedBox(
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.3,
//               ),
//               child: ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: bids.length,
//                 itemBuilder: (context, index) {
//                   final bid = bids[index];
//                   // Prioritize 'points', fallback to 'amount' if 'points' is null/empty
//                   final displayPoints = bid['points'] ?? bid['amount'] ?? '';
//                   print(
//                     'Bid: Digit: ${bid['digit']}, Display Points: $displayPoints, Type: ${bid['type']}',
//                   );
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8.0,
//                       vertical: 4.0,
//                     ),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           flex: 2,
//                           child: Text(
//                             bid['digit'] ?? '',
//                             style: GoogleFonts.poppins(),
//                           ),
//                         ),
//                         Expanded(
//                           flex: 2,
//                           child: Text(
//                             displayPoints, // Use the determined displayPoints
//                             style: GoogleFonts.poppins(),
//                           ),
//                         ),
//                         Expanded(
//                           flex: 1,
//                           child: Text(
//                             bid['type'] ?? '',
//                             style: GoogleFonts.poppins(
//                               color: Colors.green[700],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),
//             const Divider(thickness: 1),
//             const SizedBox(height: 16),
//             _buildSummaryRow('Total Bids', totalBids.toString()),
//             _buildSummaryRow('Total Bids Amount', totalBidsAmount.toString()),
//             _buildSummaryRow(
//               'Wallet Balance Before Deduction',
//               walletBalanceBeforeDeduction.toString(),
//             ),
//             _buildSummaryRow(
//               'Wallet Balance After Deduction',
//               finalWalletBalanceAfterDeduction.toString(),
//               isNegative: finalWalletBalanceAfterDeduction < 0,
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'Note: Bid Once Played Can Not Be Cancelled',
//               textAlign: TextAlign.center,
//               style: GoogleFonts.poppins(
//                 fontSize: 12,
//                 color: Colors.red,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             const SizedBox(height: 20),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(
//                         context,
//                       ).pop(false); // Pop with false on Cancel
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.grey,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       padding: const EdgeInsets.symmetric(vertical: 12),
//                     ),
//                     child: Text(
//                       'Cancel',
//                       style: GoogleFonts.poppins(
//                         color: Colors.white,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: () async {
//                       // Dismiss the confirmation dialog immediately upon "Submit" click
//                       // This makes the transition to success/failure dialog smoother.
//                       Navigator.of(context).pop(
//                         false,
//                       ); // Pop with false initially, will be overridden by success dialog
//
//                       bool success = false;
//                       String?
//                       errorMessage; // To capture specific error messages
//
//                       try {
//                         final lowerTitle = gameTitle.toLowerCase();
//
//                         if (lowerTitle.contains('jackpot')) {
//                           success = await _placeJackpotBid();
//                         } else if (lowerTitle.contains('starline')) {
//                           success = await _placeStarlineBid();
//                         } else {
//                           success = await _placeGeneralBid();
//                         }
//                       } catch (e) {
//                         success = false;
//                         errorMessage = "An unexpected error occurred: $e";
//                       }
//
//                       // Show the success or failure dialog
//                       if (success) {
//                         showDialog(
//                           context: context,
//                           barrierDismissible:
//                               false, // Prevent dismissal by tapping outside
//                           builder: (BuildContext dialogContext) {
//                             // Auto-dismiss after 3 seconds
//                             Timer(const Duration(seconds: 3), () {
//                               if (Navigator.of(dialogContext).canPop()) {
//                                 Navigator.of(dialogContext).pop(
//                                   true,
//                                 ); // Pop with true to indicate overall success
//                               }
//                             });
//                             return const BidSuccessDialog();
//                           },
//                         );
//                       } else {
//                         showDialog(
//                           context: context,
//                           barrierDismissible:
//                               false, // Prevent dismissal by tapping outside
//                           builder: (BuildContext dialogContext) {
//                             // Auto-dismiss after 3 seconds
//                             Timer(const Duration(seconds: 3), () {
//                               if (Navigator.of(dialogContext).canPop()) {
//                                 Navigator.of(dialogContext).pop(
//                                   false,
//                                 ); // Pop with false to indicate overall failure
//                               }
//                             });
//                             return BidFailureDialog(
//                               errorMessage:
//                                   errorMessage ??
//                                   'Failed to place bid. Please try again.',
//                             );
//                           },
//                         );
//                       }
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.amber,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       padding: const EdgeInsets.symmetric(vertical: 12),
//                     ),
//                     child: Text(
//                       'Submit',
//                       style: GoogleFonts.poppins(
//                         color: Colors.white,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSummaryRow(
//     String label,
//     String value, {
//     bool isNegative = false,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
//           ),
//           Text(
//             value,
//             style: GoogleFonts.poppins(
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//               color: isNegative ? Colors.red : Colors.black,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // Helper to get bid amount from either 'points' or 'amount' key
//   int _getBidAmount(Map<String, String> bid) {
//     // Try 'points' first, then 'amount', default to '0'
//     final String? pointsString = bid['points'];
//     final String? amountString = bid['amount'];
//
//     if (pointsString != null && pointsString.isNotEmpty) {
//       return int.tryParse(pointsString) ?? 0;
//     } else if (amountString != null && amountString.isNotEmpty) {
//       return int.tryParse(amountString) ?? 0;
//     }
//     return 0;
//   }
//
//   // Modified to return Future<bool> indicating success/failure
//   Future<bool> _placeGeneralBid() async {
//     final url = '${Constant.apiEndpoint}place-bid'; // Use Constents
//     GetStorage storage = GetStorage();
//     String? accessToken = storage.read('accessToken'); // Nullable
//     String? registerId = storage.read('registerId'); // Nullable
//
//     if (accessToken == null || accessToken.isEmpty) {
//       print("🚨 Error: Access Token is missing.");
//       return false;
//     }
//     if (registerId == null || registerId.isEmpty) {
//       print("🚨 Error: Register ID is missing.");
//       return false;
//     }
//
//     final headers = {
//       'deviceId': 'qwert', // Placeholder
//       'deviceName': 'sm2233', // Placeholder
//       'accessStatus': '1', // Placeholder
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $accessToken',
//     };
//
//     final List<Map<String, dynamic>> bidPayload = bids.map((bid) {
//       String sessionType = bid["type"] ?? "";
//       String digit = bid["digit"] ?? "";
//       // FIX: Use the helper function to get bid amount
//       int bidAmount = _getBidAmount(bid);
//
//       // Extract sessionType from the 'type' field if it's formatted like "SP (OPEN)"
//       if (bid["type"] != null && bid["type"]!.contains('(')) {
//         final String fullType = bid["type"]!;
//         final int startIndex = fullType.indexOf('(') + 1;
//         final int endIndex = fullType.indexOf(')');
//         if (startIndex > 0 && endIndex > startIndex) {
//           sessionType = fullType.substring(startIndex, endIndex).toUpperCase();
//         }
//       }
//
//       return {
//         "sessionType": sessionType, // 'OPEN' or 'CLOSE'
//         "digit": digit,
//         "pana": digit, // Assuming pana is the same as digit for SP/DP/TP
//         "bidAmount": bidAmount,
//       };
//     }).toList();
//
//     final body = {
//       "registerId": registerId,
//       "gameId": gameId,
//       "bidAmount": totalBidsAmount,
//       "gameType":
//           gameType, // This gameType seems to be the main game type (e.g., "Main Bazaar")
//       "bid": bidPayload, // The transformed bids list
//     };
//
//     print("Sending General Bid Request to: $url");
//     print("Headers: $headers");
//     print("Body: ${jsonEncode(body)}");
//
//     try {
//       final response = await http.post(
//         Uri.parse(url),
//         headers: headers,
//         body: jsonEncode(body),
//       );
//
//       final Map<String, dynamic> responseBody = jsonDecode(response.body);
//
//       if (response.statusCode == 200 && responseBody['status'] == true) {
//         // Update wallet balance in GetStorage only on successful bid submission
//         if (walletBalanceAfterDeduction != null) {
//           storage.write(
//             'walletBalance',
//             int.tryParse(walletBalanceAfterDeduction!),
//           );
//         }
//         print("✅ General bid placed successfully");
//         print("Response Body: $responseBody");
//         return true; // Indicate success
//       } else {
//         String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
//         print("❌ Failed to place general bid: $errorMessage");
//         print("Status: ${response.statusCode}, Body: ${response.body}");
//         return false; // Indicate failure
//       }
//     } catch (e) {
//       print("🚨 Error placing general bid: $e");
//       return false; // Indicate failure due to exception
//     }
//   }
//
//   Future<bool> _placeStarlineBid() async {
//     final url = '${Constant.apiEndpoint}place-starline-bid'; // Use Constents
//     GetStorage storage = GetStorage();
//     String? accessToken = storage.read('accessToken');
//     String? registerId = storage.read('registerId');
//
//     if (accessToken == null || accessToken.isEmpty) {
//       print("🚨 Error: Access Token is missing.");
//       return false;
//     }
//     if (registerId == null || registerId.isEmpty) {
//       print("🚨 Error: Register ID is missing.");
//       return false;
//     }
//
//     final headers = {
//       'deviceId': 'qwert',
//       'deviceName': 'sm2233',
//       'accessStatus': '1',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $accessToken',
//     };
//
//     final List<Map<String, dynamic>> bidPayload = bids.map((bid) {
//       String sessionType =
//           ""; // Starline bids might not have 'sessionType' or it's different
//       String digit = bid["digit"] ?? "";
//       // FIX: Use the helper function to get bid amount
//       int bidAmount = _getBidAmount(bid);
//
//       // Starline might not use the (OPEN)/(CLOSE) format for 'type'
//       // You might need to adjust sessionType based on Starline-specific logic
//       // For now, setting it based on current logic, but verify with Starline API.
//       if (bid["type"] != null && bid["type"]!.contains('(')) {
//         final String fullType = bid["type"]!;
//         final int startIndex = fullType.indexOf('(') + 1;
//         final int endIndex = fullType.indexOf(')');
//         if (startIndex > 0 && endIndex > startIndex) {
//           sessionType = fullType.substring(startIndex, endIndex).toUpperCase();
//         }
//       }
//
//       return {
//         "sessionType":
//             sessionType, // Confirm if Starline API uses this or needs a different value
//         "digit": digit,
//         "pana": digit,
//         "bidAmount": bidAmount,
//       };
//     }).toList();
//
//     final body = {
//       "registerId": registerId,
//       "gameId": gameId,
//       "bidAmount": totalBidsAmount,
//       "gameType":
//           gameType, // This gameType refers to the main Starline game (e.g., "Milan Starline")
//       "bid": bidPayload,
//     };
//
//     print("Sending Starline Bid Request to: $url");
//     print("Headers: $headers");
//     print("Body: ${jsonEncode(body)}");
//
//     try {
//       final response = await http.post(
//         Uri.parse(url),
//         headers: headers,
//         body: jsonEncode(body),
//       );
//
//       final Map<String, dynamic> responseBody = jsonDecode(response.body);
//
//       if (response.statusCode == 200 && responseBody['status'] == true) {
//         if (walletBalanceAfterDeduction != null) {
//           storage.write(
//             'walletBalance',
//             int.tryParse(walletBalanceAfterDeduction!),
//           );
//         }
//         print("✅ Starline bid placed successfully");
//         print("Response Body: $responseBody");
//         return true;
//       } else {
//         String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
//         print("❌ Failed to place Starline bid: $errorMessage");
//         print("Status: ${response.statusCode}, Body: ${response.body}");
//         return false;
//       }
//     } catch (e) {
//       print("🚨 Error placing Starline bid: $e");
//       return false;
//     }
//   }
//
//   Future<bool> _placeJackpotBid() async {
//     final url = '${Constant.apiEndpoint}place-jackpot-bid'; // Use Constents
//     GetStorage storage = GetStorage();
//     String? accessToken = storage.read('accessToken');
//     String? registerId = storage.read('registerId');
//
//     if (accessToken == null || accessToken.isEmpty) {
//       print("🚨 Error: Access Token is missing.");
//       return false;
//     }
//     if (registerId == null || registerId.isEmpty) {
//       print("🚨 Error: Register ID is missing.");
//       return false;
//     }
//
//     final headers = {
//       'deviceId': 'qwert',
//       'deviceName': 'sm2233',
//       'accessStatus': '1',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $accessToken',
//     };
//
//     final List<Map<String, dynamic>> bidPayload = bids.map((bid) {
//       String sessionType =
//           ""; // Jackpot bids might not have 'sessionType' or it's different
//       String digit = bid["digit"] ?? "";
//       // FIX: Use the helper function to get bid amount
//       int bidAmount = _getBidAmount(bid);
//
//       // Jackpot might not use the (OPEN)/(CLOSE) format for 'type'
//       // You might need to adjust sessionType based on Jackpot-specific logic
//       if (bid["type"] != null && bid["type"]!.contains('(')) {
//         final String fullType = bid["type"]!;
//         final int startIndex = fullType.indexOf('(') + 1;
//         final int endIndex = fullType.indexOf(')');
//         if (startIndex > 0 && endIndex > startIndex) {
//           sessionType = fullType.substring(startIndex, endIndex).toUpperCase();
//         }
//       }
//
//       return {
//         "sessionType":
//             sessionType, // Confirm if Jackpot API uses this or needs a different value
//         "digit": digit,
//         "pana": digit,
//         "bidAmount": bidAmount,
//       };
//     }).toList();
//
//     final body = {
//       "registerId": registerId,
//       "gameId": gameId,
//       "bidAmount": totalBidsAmount,
//       "gameType": gameType, // This gameType refers to the main Jackpot game
//       "bid": bidPayload,
//     };
//
//     print("Sending Jackpot Bid Request to: $url");
//     print("Headers: $headers");
//     print("Body: ${jsonEncode(body)}");
//
//     try {
//       final response = await http.post(
//         Uri.parse(url),
//         headers: headers,
//         body: jsonEncode(body),
//       );
//
//       final Map<String, dynamic> responseBody = jsonDecode(response.body);
//
//       if (response.statusCode == 200 && responseBody['status'] == true) {
//         if (walletBalanceAfterDeduction != null) {
//           storage.write(
//             'walletBalance',
//             int.tryParse(walletBalanceAfterDeduction!),
//           );
//         }
//         print("✅ Jackpot bid placed successfully");
//         print("Response Body: $responseBody");
//         return true;
//       } else {
//         String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
//         print("❌ Failed to place jackpot bid: $errorMessage");
//         print("Status: ${response.statusCode}, Body: ${response.body}");
//         return false;
//       }
//     } catch (e) {
//       print("🚨 Error placing jackpot bid: $e");
//       return false;
//     }
//   }
// }
