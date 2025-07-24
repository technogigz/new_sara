import 'dart:async';
import 'dart:convert';
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Import for date formatting

import '../../components/BidConfirmationDialog.dart';
import '../../ulits/Constents.dart'; // Import the Constants file

// AnimatedMessageBar component
// If this component is already defined in a separate file (e.g., components/animated_message_bar.dart)
// then you should import it and remove this duplicate definition.
class AnimatedMessageBar extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback? onDismissed;

  const AnimatedMessageBar({
    Key? key,
    required this.message,
    this.isError = false,
    this.onDismissed,
  }) : super(key: key);

  @override
  _AnimatedMessageBarState createState() => _AnimatedMessageBarState();
}

class _AnimatedMessageBarState extends State<AnimatedMessageBar> {
  double _height = 0.0;
  Timer? _visibilityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showBar();
    });
  }

  void _showBar() {
    if (!mounted) return;
    setState(() {
      _height = 48.0;
    });

    _visibilityTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _height = 0.0;
      });
      Timer(const Duration(milliseconds: 300), () {
        if (mounted && widget.onDismissed != null) {
          widget.onDismissed!();
        }
      });
    });
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      height: _height,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      color: widget.isError ? Colors.red : Colors.green,
      alignment: Alignment.center,
      child: _height > 0.0
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(
                    widget.isError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

// Bid class for managing bid data
class Bid {
  final String digit;
  final String amount;
  final String
  type; // This will be used for sessionType in API (e.g., 'OPEN' or 'CLOSE')
  final String
  pana; // Not directly used for 2-digit, but needed for API payload consistency

  Bid({
    required this.digit,
    required this.amount,
    required this.type,
    this.pana = '',
  });
}

class TwoDigitPanelScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType; // e.g., "Single Digit", "Jodi", etc.

  const TwoDigitPanelScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
  }) : super(key: key);

  @override
  _TwoDigitPanelScreenState createState() => _TwoDigitPanelScreenState();
}

class _TwoDigitPanelScreenState extends State<TwoDigitPanelScreen> {
  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  List<Bid> bids = [];

  late GetStorage storage = GetStorage();
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance;

  // Placeholder for device info. In a real app, these would be dynamic.
  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  // State management for AnimatedMessageBar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupStorageListeners();
  }

  // Load initial data from GetStorage
  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = storage.read('accountStatus') ?? false;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is String) {
      walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else if (storedWalletBalance is int) {
      walletBalance = storedWalletBalance;
    } else {
      walletBalance = 0;
    }
  }

  // Set up listeners for GetStorage keys
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

    storage.listenKey('selectedLanguage', (value) {
      setState(() {
        preferredLanguage = value ?? 'en';
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
      });
    });
  }

  @override
  void dispose() {
    digitController.dispose();
    amountController.dispose();
    super.dispose();
  }

  // Helper method to show messages using AnimatedMessageBar
  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey(); // Update key to trigger animation
    });
  }

  // Helper method to clear the message bar
  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  // Add a bid to the list
  void addBid() {
    _clearMessage();
    final digit = digitController.text.trim();
    final amount = amountController.text.trim();

    // Input validation for digit
    if (digit.isEmpty || int.tryParse(digit) == null || digit.length != 1) {
      _showMessage('Please enter a single digit (0-9).', isError: true);
      return;
    }
    int? parsedDigit = int.tryParse(digit);
    if (parsedDigit == null || parsedDigit < 0 || parsedDigit > 9) {
      _showMessage('Digit must be between 0 and 9.', isError: true);
      return;
    }

    // Input validation for amount
    int? parsedAmount = int.tryParse(amount);
    if (parsedAmount == null || parsedAmount < 10 || parsedAmount > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    setState(() {
      int existingIndex = bids.indexWhere((bid) => bid.digit == digit);

      if (existingIndex != -1) {
        // If bid for this digit already exists, update its amount
        bids[existingIndex] = Bid(
          digit: digit,
          amount: (int.parse(bids[existingIndex].amount) + parsedAmount)
              .toString(),
          type: bids[existingIndex].type, // Keep existing type
        );
        _showMessage('Updated points for Digit $digit.');
      } else {
        // Add new bid
        bids.add(
          Bid(digit: digit, amount: amount, type: 'OPEN'),
        ); // Defaulting to 'OPEN'
        _showMessage('Added bid: Digit $digit with $amount points.');
      }

      digitController.clear();
      amountController.clear();
    });
  }

  // Delete a bid from the list
  void deleteBid(int index) {
    _clearMessage();
    setState(() {
      final removedDigit = bids[index].digit;
      bids.removeAt(index);
      _showMessage('Bid for Digit $removedDigit removed from list.');
    });
  }

  // Calculate total amount of all bids
  int get totalAmount =>
      bids.fold(0, (sum, bid) => sum + (int.tryParse(bid.amount) ?? 0));

  // Show bid confirmation dialog
  void _showConfirmationDialog() {
    _clearMessage();
    if (bids.isEmpty) {
      _showMessage('Please add bids before submitting.', isError: true);
      return;
    }

    int currentTotalPoints = totalAmount;

    if (walletBalance < currentTotalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
      return;
    }

    // Prepare bids data for the confirmation dialog
    List<Map<String, String>> bidsForDialog = bids.map((bid) {
      return {
        'digit': bid.digit,
        'amount': bid.amount,
        'gameType': bid.type,
        'pana': bid.pana, // Include pana even if empty
      };
    }).toList();

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false, // User must interact with the dialog
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.title,
          gameDate: formattedDate,
          bids: bidsForDialog,
          totalBids: bids.length,
          totalBidsAmount: currentTotalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - currentTotalPoints)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            Navigator.pop(dialogContext); // Dismiss the confirmation dialog
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                bids.clear(); // Clear bids on successful submission
              });
              _showMessage('Bids placed successfully!');
            }
          },
        );
      },
    );
  }

  // Place final bids via API
  Future<bool> _placeFinalBids() async {
    String url;
    // Determine the correct API endpoint based on game name or type
    // You might need to adjust this logic based on your backend's specific endpoints
    if (widget.title.toLowerCase().contains('jackpot')) {
      url = '${Constant.apiEndpoint}place-jackpot-bid';
    } else if (widget.title.toLowerCase().contains('starline')) {
      url = '${Constant.apiEndpoint}place-starline-bid';
    } else {
      url = '${Constant.apiEndpoint}place-bid'; // General bid placement
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      _showMessage('Authentication error. Please log in again.', isError: true);
      return false;
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0', // Convert bool to '1' or '0'
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final List<Map<String, dynamic>> bidPayload = bids.map((bid) {
      return {
        "sessionType": bid.type.toUpperCase(), // e.g., "OPEN"
        "digit": bid.digit,
        "pana": bid.pana, // Will be empty string for Single Digit/2-Digit
        "bidAmount": int.tryParse(bid.amount) ?? 0,
      };
    }).toList();

    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId,
      "bidAmount": totalAmount,
      "gameType":
          widget.gameType, // Use the gameType from the widget's properties
      "bid": bidPayload,
    });

    // Log the cURL and headers here
    String curlCommand = 'curl -X POST \\';
    curlCommand += '\n  ${Uri.parse(url)} \\';
    headers.forEach((key, value) {
      curlCommand += '\n  -H "$key: $value" \\';
    });
    curlCommand += '\n  -d \'$body\'';

    log('CURL Command for Final Bid Submission:\n$curlCommand');
    log('Request Headers for Final Bid Submission: $headers');
    log('Request Body for Final Bid Submission: $body');

    log('Placing final bids to URL: $url');
    log('Request Body: $body');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      final Map<String, dynamic> responseBody = json.decode(response.body);

      log('API Response for Final Bid Submission: ${responseBody}');

      if (response.statusCode == 200 && responseBody['status'] == true) {
        // Update wallet balance in GetStorage and local state on successful bid
        int currentWallet = walletBalance;
        int deductedAmount = totalAmount;
        int newWalletBalance = currentWallet - deductedAmount;
        storage.write(
          'walletBalance',
          newWalletBalance.toString(),
        ); // Update storage
        setState(() {
          walletBalance = newWalletBalance; // Update local state
        });
        return true; // Indicate success
      } else {
        String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
        _showMessage('Bid submission failed: $errorMessage', isError: true);
        return false; // Indicate failure
      }
    } catch (e) {
      log('Network error during bid submission: $e');
      _showMessage('Network error during bid submission: $e', isError: true);
      return false; // Indicate failure
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: const BackButton(),
        actions: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.black,
          ),
          const SizedBox(width: 6),
          Center(
            child: Text(
              walletBalance.toString(),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 6.0),
                            child: Text(
                              'Enter Single Digit:',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          SizedBox(height: 50),
                          Text('Enter Points:', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        children: [
                          SizedBox(
                            height: 40,
                            width: 180,
                            child: TextField(
                              controller: digitController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(
                                  1,
                                ), // Limit to 1 digit
                              ],
                              onTap: _clearMessage, // Clear message on tap
                              decoration: InputDecoration(
                                hintText: 'Bid Digits',
                                hintStyle: const TextStyle(fontSize: 14),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                    color: Colors.amber,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 40,
                            width: 180,
                            child: TextField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(
                                  4,
                                ), // Max 4 digits for points (1000)
                              ],
                              onTap: _clearMessage, // Clear message on tap
                              decoration: InputDecoration(
                                hintText: 'Enter Amount',
                                hintStyle: const TextStyle(fontSize: 14),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                    color: Colors.amber,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: addBid,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              minimumSize: const Size(80, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'ADD BID',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        child: Text(
                          'Digit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Amount',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Game Type',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: bids.isEmpty
                      ? const Center(child: Text('No bids yet'))
                      : ListView.builder(
                          itemCount: bids.length,
                          itemBuilder: (context, index) {
                            final bid = bids[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(bid.digit)),
                                      Expanded(child: Text(bid.amount)),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(bid.type), // Use bid.type here
                                            const Spacer(),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.amber,
                                              ),
                                              onPressed: () => deleteBid(index),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (bids.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            const Text(
                              "Bid",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text("${bids.length}"),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Column(
                          children: [
                            const Text(
                              "Total",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text("$totalAmount"),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _showConfirmationDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'SUBMIT',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_messageToShow != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedMessageBar(
                key: _messageBarKey,
                message: _messageToShow!,
                isError: _isErrorForMessage,
                onDismissed: _clearMessage,
              ),
            ),
        ],
      ),
    );
  }
}
