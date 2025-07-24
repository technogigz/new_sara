import 'dart:async'; // For Timer (needed for API calls, if you add delays or timeouts)
import 'dart:convert';
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../ulits/Constents.dart'; // Make sure this path is correct

class JodiBidScreen extends StatefulWidget {
  final String title;
  final String gameType;
  final int gameId;
  final String gameName;

  const JodiBidScreen({
    Key? key,
    required this.title,
    required this.gameType,
    required this.gameId,
    required this.gameName,
  }) : super(key: key);

  @override
  State<JodiBidScreen> createState() => _JodiBidScreenState();
}

class _JodiBidScreenState extends State<JodiBidScreen> {
  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  Color digitBorderColor = Colors.black;
  Color amountBorderColor = Colors.black;

  List<Map<String, String>> bids = [];

  late GetStorage storage;
  late String accessToken;
  late String registerId;
  late int walletBalance;
  bool accountStatus = false;
  bool _isWalletLoading = true;

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  // --- Custom Message Display State ---
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey(); // Key to force rebuild/re-animation
  // --- End Custom Message Display State ---

  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _loadInitialData();
    _setupStorageListeners();
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = storage.read('accountStatus') ?? false;

    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is String) {
      walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else if (storedWalletBalance is int) {
      walletBalance = storedWalletBalance;
    } else {
      walletBalance = 0;
    }

    setState(() {
      _isWalletLoading = false;
    });
  }

  void _setupStorageListeners() {
    storage.listenKey('accessToken', (value) {
      setState(() {
        accessToken = value ?? '';
      });
    });
    storage.listenKey('registerId', (value) {
      setState(() {
        registerId = value ?? '';
      });
    });
    storage.listenKey('accountStatus', (value) {
      setState(() {
        accountStatus = value ?? false;
      });
    });
    storage.listenKey('walletBalance', (value) {
      setState(() {
        if (value is String) {
          walletBalance = int.tryParse(value) ?? 0;
        } else if (value is int) {
          walletBalance = value;
        } else {
          walletBalance = 0;
        }
        _isWalletLoading = false;
      });
    });
  }

  // --- Custom Message Display Method ---
  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey =
          UniqueKey(); // Force AnimatedMessageBar to re-initialize and animate
    });
  }

  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }
  // --- End Custom Message Display Method ---

  @override
  void dispose() {
    digitController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void _addBid() {
    setState(() {
      String jodi = digitController.text.trim();
      String amount = amountController.text.trim();

      if (jodi.isEmpty && amount.isEmpty) {
        _showMessage('Please enter both Jodi and Amount.', isError: true);
        return;
      }

      if (jodi.isEmpty) {
        _showMessage('Please enter Jodi.', isError: true);
        return;
      }

      if (amount.isEmpty) {
        _showMessage('Please enter Amount.', isError: true);
        return;
      }

      // Validation for 2-digit Jodi
      if (jodi.length != 2 || int.tryParse(jodi) == null) {
        _showMessage('Please enter a valid 2-digit Jodi.', isError: true);
        return;
      }

      int? parsedAmount = int.tryParse(amount);
      if (parsedAmount == null || parsedAmount < 10 || parsedAmount > 1000) {
        _showMessage('Amount must be between 10 and 1000.', isError: true);
        return;
      }

      // Check for duplicate Jodi
      bool isDuplicate = bids.any((bid) => bid['digit'] == jodi);
      if (isDuplicate) {
        _showMessage('Jodi $jodi already exists in the list.', isError: true);
        return;
      }

      bids.add({
        'digit': jodi,
        'amount': amount,
        'type': widget.gameType, // Use widget.gameType as bid type
      });
      digitController.clear();
      amountController.clear();
      digitBorderColor = Colors.black;
      amountBorderColor = Colors.black;
      _showMessage('Bid for Jodi $jodi added successfully!', isError: false);
    });
  }

  void _removeBid(int index) {
    setState(() {
      String removedJodi = bids[index]['digit']!;
      bids.removeAt(index);
      _showMessage(
        'Bid for Jodi $removedJodi removed from list.',
        isError: false,
      );
    });
  }

  Widget _inputRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          field,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required Color borderColor,
    required VoidCallback onTap,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      height: 35,
      width: 150,
      child: TextFormField(
        controller: controller,
        readOnly: false,
        onTap: () {
          onTap(); // Call the passed onTap function
          _clearMessage(); // Clear message when input field is tapped
        },
        cursorColor: Colors.amber,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 14),
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.amber, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildAddBidButton() {
    return SizedBox(
      height: 35,
      width: 150,
      child: ElevatedButton(
        onPressed: _addBid,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 0,
        ),
        child: const Text(
          "ADD BID",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8.0, left: 16, right: 16),
      child: Row(
        children: const [
          Expanded(
            child: Text("Jodi", style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              "Amount",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              "Game Type",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBidItem(Map<String, String> bid, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                bid['digit']!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                bid['amount']!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                bid['type']!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeBid(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    int totalBids = bids.length;
    int totalPoints = bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bids',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              Text(
                '$totalBids',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Points',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              Text(
                '$totalPoints',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              _showConfirmationDialog(totalPoints);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: const Text(
              'SUBMIT',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff2f2f2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.black),
                const SizedBox(width: 4),
                _isWalletLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "$walletBalance",
                        style: const TextStyle(color: Colors.black),
                      ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        // Use Stack to overlay the message bar
        children: [
          Column(
            children: [
              // Message bar will be here, directly below AppBar visually
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _inputRow(
                      "Enter Jodi:",
                      _buildInputField(
                        controller: digitController,
                        hint: "Enter Jodi",
                        borderColor: digitBorderColor,
                        onTap: () {
                          setState(() {
                            digitBorderColor = Colors.amber;
                            amountBorderColor = Colors.black;
                          });
                        },
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(2),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    _inputRow(
                      "Enter Points:",
                      _buildInputField(
                        controller: amountController,
                        hint: "Enter Amount",
                        borderColor: amountBorderColor,
                        onTap: () {
                          setState(() {
                            amountBorderColor = Colors.amber;
                            digitBorderColor = Colors.black;
                          });
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildAddBidButton(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              _buildTableHeader(),
              const Divider(),
              Expanded(
                child: bids.isEmpty
                    ? Center(
                        child: Text(
                          'No bids yet. Add some data!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: bids.length,
                        itemBuilder: (context, index) {
                          return _buildBidItem(bids[index], index);
                        },
                      ),
              ),
              if (bids.isNotEmpty) _buildBottomBar(),
            ],
          ),
          // --- Custom Message Display Area (AnimatedMessageBar) ---
          if (_messageToShow != null) // Only render if there's a message
            Positioned(
              top: 0, // Position at the top of the Stack
              left: 0,
              right: 0,
              child: AnimatedMessageBar(
                key: _messageBarKey, // Use key to force re-animation
                message: _messageToShow!,
                isError: _isErrorForMessage,
                onDismissed:
                    _clearMessage, // Callback to clear message when animation finishes
              ),
            ),
          // --- End Custom Message Display Area ---
        ],
      ),
    );
  }

  // Helper to get bid amount from either 'points' or 'amount' key
  int _getBidAmount(Map<String, String> bid) {
    final String? pointsString = bid['points'];
    final String? amountString = bid['amount'];

    if (pointsString != null && pointsString.isNotEmpty) {
      return int.tryParse(pointsString) ?? 0;
    } else if (amountString != null && amountString.isNotEmpty) {
      return int.tryParse(amountString) ?? 0;
    }
    return 0;
  }

  // API Calling Logic (moved back here from BidConfirmationDialog)
  Future<bool> _placeGeneralBid() async {
    final url = '${Constant.apiEndpoint}place-bid';
    String? accessToken = storage.read('accessToken');
    String? registerId = storage.read('registerId');

    if (accessToken == null ||
        accessToken.isEmpty ||
        registerId == null ||
        registerId.isEmpty) {
      log("🚨 Error: Access Token or Register ID is missing.");
      _showMessage('Authentication error. Please log in again.', isError: true);
      return false;
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final List<Map<String, dynamic>> bidPayload = bids.map((bid) {
      String sessionType = bid["type"] ?? "";
      String digit = bid["digit"] ?? "";
      int bidAmount = _getBidAmount(bid);

      if (bid["type"] != null && bid["type"]!.contains('(')) {
        final String fullType = bid["type"]!;
        final int startIndex = fullType.indexOf('(') + 1;
        final int endIndex = fullType.indexOf(')');
        if (startIndex > 0 && endIndex > startIndex) {
          sessionType = fullType.substring(startIndex, endIndex).toUpperCase();
        }
      }

      return {
        "sessionType": sessionType,
        "digit": digit,
        "pana": digit,
        "bidAmount": bidAmount,
      };
    }).toList();

    final body = {
      "registerId": registerId,
      "gameId": widget.gameId.toString(),
      "bidAmount": bids.fold(
        0,
        (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
      ),
      "gameType": widget.gameType,
      "bid": bidPayload,
    };

    log("Sending General Bid Request to: $url");
    log("Headers: $headers");
    log("Body: ${jsonEncode(body)}");

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['status'] == true) {
        // Update wallet balance in storage
        final int newWalletBalance =
            walletBalance -
            bids.fold(
              0,
              (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
            );
        storage.write('walletBalance', newWalletBalance);
        _showMessage(
          responseBody['msg'] ?? "General bid placed successfully!",
          isError: false,
        );
        log("✅ General bid placed successfully. Response: $responseBody");
        return true;
      } else {
        String errorMessage =
            responseBody['msg'] ??
            "Failed to place general bid. Unknown error.";
        _showMessage(errorMessage, isError: true);
        log(
          "❌ Failed to place general bid. Status: ${response.statusCode}, Body: ${response.body}",
        );
        return false;
      }
    } catch (e) {
      _showMessage("Network error or server unavailable: $e", isError: true);
      log("🚨 Error placing general bid: $e");
      return false;
    }
  }

  Future<bool> _placeStarlineBid() async {
    final url = '${Constant.apiEndpoint}place-starline-bid';
    String? accessToken = storage.read('accessToken');
    String? registerId = storage.read('registerId');

    if (accessToken == null ||
        accessToken.isEmpty ||
        registerId == null ||
        registerId.isEmpty) {
      log("🚨 Error: Access Token or Register ID is missing.");
      _showMessage('Authentication error. Please log in again.', isError: true);
      return false;
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final List<Map<String, dynamic>> bidPayload = bids.map((bid) {
      String sessionType = "";
      String digit = bid["digit"] ?? "";
      int bidAmount = _getBidAmount(bid);

      if (bid["type"] != null && bid["type"]!.contains('(')) {
        final String fullType = bid["type"]!;
        final int startIndex = fullType.indexOf('(') + 1;
        final int endIndex = fullType.indexOf(')');
        if (startIndex > 0 && endIndex > startIndex) {
          sessionType = fullType.substring(startIndex, endIndex).toUpperCase();
        }
      }

      return {
        "sessionType": sessionType,
        "digit": digit,
        "pana": digit,
        "bidAmount": bidAmount,
      };
    }).toList();

    final body = {
      "registerId": registerId,
      "gameId": widget.gameId.toString(),
      "bidAmount": bids.fold(
        0,
        (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
      ),
      "gameType": widget.gameType,
      "bid": bidPayload,
    };

    log("Sending Starline Bid Request to: $url");
    log("Headers: $headers");
    log("Body: ${jsonEncode(body)}");

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['status'] == true) {
        final int newWalletBalance =
            walletBalance -
            bids.fold(
              0,
              (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
            );
        storage.write('walletBalance', newWalletBalance);
        _showMessage(
          responseBody['msg'] ?? "Starline bid placed successfully!",
          isError: false,
        );
        log("✅ Starline bid placed successfully. Response: $responseBody");
        return true;
      } else {
        String errorMessage =
            responseBody['msg'] ??
            "Failed to place Starline bid. Unknown error.";
        _showMessage(errorMessage, isError: true);
        log(
          "❌ Failed to place Starline bid. Status: ${response.statusCode}, Body: ${response.body}",
        );
        return false;
      }
    } catch (e) {
      _showMessage("Network error or server unavailable: $e", isError: true);
      log("🚨 Error placing Starline bid: $e");
      return false;
    }
  }

  Future<bool> _placeJackpotBid() async {
    final url = '${Constant.apiEndpoint}place-jackpot-bid';
    String? accessToken = storage.read('accessToken');
    String? registerId = storage.read('registerId');

    if (accessToken == null ||
        accessToken.isEmpty ||
        registerId == null ||
        registerId.isEmpty) {
      log("🚨 Error: Access Token or Register ID is missing.");
      _showMessage('Authentication error. Please log in again.', isError: true);
      return false;
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final List<Map<String, dynamic>> bidPayload = bids.map((bid) {
      String sessionType = "";
      String digit = bid["digit"] ?? "";
      int bidAmount = _getBidAmount(bid);

      if (bid["type"] != null && bid["type"]!.contains('(')) {
        final String fullType = bid["type"]!;
        final int startIndex = fullType.indexOf('(') + 1;
        final int endIndex = fullType.indexOf(')');
        if (startIndex > 0 && endIndex > startIndex) {
          sessionType = fullType.substring(startIndex, endIndex).toUpperCase();
        }
      }

      return {
        "sessionType": sessionType,
        "digit": digit,
        "pana": digit,
        "bidAmount": bidAmount,
      };
    }).toList();

    final body = {
      "registerId": registerId,
      "gameId": widget.gameId.toString(),
      "bidAmount": bids.fold(
        0,
        (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
      ),
      "gameType": widget.gameType,
      "bid": bidPayload,
    };

    log("Sending Jackpot Bid Request to: $url");
    log("Headers: $headers");
    log("Body: ${jsonEncode(body)}");

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['status'] == true) {
        final int newWalletBalance =
            walletBalance -
            bids.fold(
              0,
              (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
            );
        storage.write('walletBalance', newWalletBalance);
        _showMessage(
          responseBody['msg'] ?? "Jackpot bid placed successfully!",
          isError: false,
        );
        log("✅ Jackpot bid placed successfully. Response: $responseBody");
        return true;
      } else {
        String errorMessage =
            responseBody['msg'] ??
            "Failed to place Jackpot bid. Unknown error.";
        _showMessage(errorMessage, isError: true);
        log(
          "❌ Failed to place Jackpot bid. Status: ${response.statusCode}, Body: ${response.body}",
        );
        return false;
      }
    } catch (e) {
      _showMessage("Network error or server unavailable: $e", isError: true);
      log("🚨 Error placing Jackpot bid: $e");
      return false;
    }
  }

  void _showConfirmationDialog(int totalPoints) {
    if (bids.isEmpty) {
      _showMessage(
        'No bids added yet. Please add bids before submitting.',
        isError: true,
      );
      return;
    }

    if (totalPoints > walletBalance) {
      _showMessage(
        'Insufficient wallet balance to submit all bids.',
        isError: true,
      );
      return;
    }

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle:
              "${widget.gameName}, ${widget.gameType}", // Removed date here as it's separate
          gameDate: formattedDate, // Passed separately
          bids: bids,
          totalBids: bids.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            Navigator.of(dialogContext).pop(true);

            bool success = false;
            try {
              final lowerTitle = widget.gameName
                  .toLowerCase(); // Use widget.gameName to determine API

              if (lowerTitle.contains('jackpot')) {
                success = await _placeJackpotBid();
              } else if (lowerTitle.contains('starline')) {
                success = await _placeStarlineBid();
              } else {
                success = await _placeGeneralBid();
              }

              if (success) {
                setState(() {
                  bids.clear(); // Clear bids on successful submission
                });
              }
              // The success/failure message is now handled directly within the API methods via _showMessage
            } catch (e) {
              log("🚨 Error during bid confirmation process: $e");
              _showMessage(
                "An unexpected error occurred during submission: $e",
                isError: true,
              );
            }
          },
        );
      },
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
//
// import '../../components/BidConfirmationDialog.dart'; // For TextInputFormatter
//
// class JodiBidScreen extends StatefulWidget {
//   final String title;
//
//   const JodiBidScreen({
//     Key? key,
//     required this.title,
//     required String gameType,
//     required int gameId,
//   }) : super(key: key);
//
//   @override
//   State<JodiBidScreen> createState() => _JodiBidScreenState();
// }
//
// class _JodiBidScreenState extends State<JodiBidScreen> {
//   final TextEditingController digitController = TextEditingController();
//   final TextEditingController amountController = TextEditingController();
//
//   Color digitBorderColor = Colors.black;
//   Color amountBorderColor = Colors.black;
//
//   // List to store bids (placeholder for functionality)
//   List<Map<String, String>> bids = [];
//
//   @override
//   void dispose() {
//     digitController.dispose();
//     amountController.dispose();
//     super.dispose();
//   }
//
//   // Function to add a new bid (basic implementation)
//   void _addBid() {
//     setState(() {
//       String jodi = digitController.text
//           .trim(); // Renamed 'digit' to 'jodi' for clarity
//       String amount = amountController.text.trim();
//
//       if (jodi.isNotEmpty && amount.isNotEmpty) {
//         // Validation for 2-digit Jodi
//         if (jodi.length == 2 && int.tryParse(jodi) != null) {
//           bids.add({
//             'digit': jodi,
//             'amount': amount,
//             'gameType': 'JODI',
//           }); // Changed gameType to 'JODI'
//           digitController.clear();
//           amountController.clear();
//           digitBorderColor = Colors.black; // Reset border color
//           amountBorderColor = Colors.black; // Reset border color
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Please enter a valid 2-digit Jodi.')),
//           );
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Please enter both Jodi and Amount.')),
//         );
//       }
//     });
//   }
//
//   // Function to remove a bid
//   void _removeBid(int index) {
//     setState(() {
//       bids.removeAt(index);
//     });
//   }
//
//   // Helper widget for input rows
//   Widget _inputRow(String label, Widget field) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
//           ),
//           field,
//         ],
//       ),
//     );
//   }
//
//   // Helper widget to build input fields
//   Widget _buildInputField({
//     required TextEditingController controller,
//     required String hint,
//     required Color borderColor,
//     required VoidCallback onTap,
//     List<TextInputFormatter>? inputFormatters, // Added for formatters
//   }) {
//     return SizedBox(
//       height: 35,
//       width: 150,
//       child: TextFormField(
//         controller: controller,
//         readOnly: false,
//         onTap: onTap,
//         cursorColor: Colors.amber,
//         keyboardType: TextInputType.number,
//         style: const TextStyle(fontSize: 14),
//         inputFormatters: inputFormatters, // Apply formatters
//         decoration: InputDecoration(
//           hintText: hint,
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 0,
//           ),
//           filled: true,
//           fillColor: Colors.white,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: BorderSide(color: borderColor),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: BorderSide(color: borderColor),
//           ),
//           focusedBorder: OutlineInputBorder(
//             // Add focused border for amber color
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.amber, width: 2),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Helper widget for the "ADD BID" button
//   Widget _buildAddBidButton() {
//     return SizedBox(
//       height: 35,
//       width: 150,
//       child: ElevatedButton(
//         onPressed: _addBid, // Call the _addBid function
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.orange[700],
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
//           elevation: 0,
//         ),
//         child: const Text(
//           "ADD BID",
//           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//         ),
//       ),
//     );
//   }
//
//   // Helper widget for the table header
//   Widget _buildTableHeader() {
//     return Padding(
//       padding: const EdgeInsets.only(
//         top: 20,
//         bottom: 8.0,
//         left: 16,
//         right: 16,
//       ), // Added horizontal padding
//       child: Row(
//         children: const [
//           Expanded(
//             child: Text(
//               "Jodi",
//               style: TextStyle(fontWeight: FontWeight.w500),
//             ), // Changed label to Jodi
//           ),
//           Expanded(
//             child: Text(
//               "Amount",
//               style: TextStyle(fontWeight: FontWeight.w500),
//             ),
//           ),
//           Expanded(
//             child: Text(
//               "Game Type",
//               style: TextStyle(fontWeight: FontWeight.w500),
//             ),
//           ),
//           SizedBox(width: 48), // Space for delete icon
//         ],
//       ),
//     );
//   }
//
//   // Helper widget to build each bid item in the list
//   Widget _buildBidItem(Map<String, String> bid, int index) {
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 4),
//       // Removed horizontal padding from Container, will add to Row inside
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.2),
//             spreadRadius: 1,
//             blurRadius: 3,
//             offset: const Offset(0, 1),
//           ),
//         ],
//       ),
//       child: Padding(
//         // Added Padding here to align content
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//         child: Row(
//           children: [
//             Expanded(
//               child: Text(
//                 bid['digit']!,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//             Expanded(
//               child: Text(
//                 bid['amount']!,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//             Expanded(
//               child: Text(
//                 bid['gameType']!,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                   color: Colors.green[700],
//                 ),
//               ),
//             ),
//             IconButton(
//               icon: const Icon(Icons.delete, color: Colors.red),
//               onPressed: () => _removeBid(index),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Helper for bottom bar
//   Widget _buildBottomBar() {
//     int totalBids = bids.length;
//     int totalPoints = bids.fold(
//       0,
//       (sum, item) => sum + int.tryParse(item['amount'] ?? '0')!,
//     );
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.3),
//             spreadRadius: 2,
//             blurRadius: 5,
//             offset: const Offset(0, -3),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Bids',
//                 style: TextStyle(fontSize: 14, color: Colors.grey[700]),
//               ),
//               Text(
//                 '$totalBids',
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Points',
//                 style: TextStyle(fontSize: 14, color: Colors.grey[700]),
//               ),
//               Text(
//                 '$totalPoints',
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           ElevatedButton(
//             onPressed: () {
//               //   Show the confirmation dialog
//               _showConfirmationDialog();
//             },
//             child: const Text(
//               'SUBMIT',
//               style: TextStyle(color: Colors.white, fontSize: 16),
//             ),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.orange[700],
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               elevation: 3,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xfff2f2f2),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
//         ),
//         title: Text(
//           widget.title.toUpperCase(),
//           style: const TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//             color: Colors.black,
//           ),
//         ),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 16),
//             child: Row(
//               children: [
//                 const Icon(
//                   Icons.account_balance_wallet,
//                   color: Colors.black,
//                 ), // Replaced Image.asset
//                 const SizedBox(width: 4),
//                 const Text("5", style: TextStyle(color: Colors.black)),
//               ],
//             ),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _inputRow(
//                   "Enter Jodi:", // Changed label
//                   _buildInputField(
//                     controller: digitController,
//                     hint: "Enter Jodi", // Changed hint
//                     borderColor: digitBorderColor,
//                     onTap: () {
//                       setState(() {
//                         digitBorderColor = Colors.amber;
//                         amountBorderColor =
//                             Colors.black; // Reset other field's border
//                       });
//                     },
//                     inputFormatters: [
//                       LengthLimitingTextInputFormatter(2), // Allow 2 digits
//                       FilteringTextInputFormatter
//                           .digitsOnly, // Allow only digits
//                     ],
//                   ),
//                 ),
//                 _inputRow(
//                   "Enter Points:",
//                   _buildInputField(
//                     controller: amountController,
//                     hint: "Enter Amount",
//                     borderColor: amountBorderColor,
//                     onTap: () {
//                       setState(() {
//                         amountBorderColor = Colors.amber;
//                         digitBorderColor =
//                             Colors.black; // Reset other field's border
//                       });
//                     },
//                     inputFormatters: [
//                       FilteringTextInputFormatter
//                           .digitsOnly, // Allow only digits
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 Align(
//                   alignment: Alignment.centerRight,
//                   child: _buildAddBidButton(),
//                 ),
//               ],
//             ),
//           ),
//           const Divider(), // Divider after input section
//           _buildTableHeader(),
//           const Divider(), // Divider after table header
//           Expanded(
//             child: bids.isEmpty
//                 ? Center(
//                     child: Text(
//                       'No bids yet. Add some data!',
//                       style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//                     ),
//                   )
//                 : ListView.builder(
//                     itemCount: bids.length,
//                     itemBuilder: (context, index) {
//                       return _buildBidItem(bids[index], index);
//                     },
//                   ),
//           ),
//           if (bids.isNotEmpty)
//             _buildBottomBar(), // Conditionally show bottom bar
//         ],
//       ),
//     );
//   }
//
//   void _showConfirmationDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return BidConfirmationDialog(
//           gameTitle: widget.title,
//           bids: bids,
//           totalBids: bids.length,
//           totalBidsAmount: totalPoints,
//           walletBalanceBeforeDeduction: walletBalance,
//           walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
//           gameId: widget.gameId,
//         );
//       },
//     );
//   }
// }
