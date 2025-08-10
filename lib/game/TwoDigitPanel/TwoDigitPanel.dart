import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../ulits/Constents.dart';

class Bid {
  final String digit;
  final String amount;
  final String type;
  final String pana;

  Bid({
    required this.digit,
    required this.amount,
    required this.type,
    required this.pana,
  });
}

class TwoDigitPanelScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType;

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

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  bool _isAddBidApiCalling = false;
  bool _isSubmitBidApiCalling = false;

  final UserController userController = Get.put(UserController());

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    double _walletBalance = double.parse(userController.walletBalance.value);
    walletBalance = _walletBalance.toInt();
  }

  @override
  void dispose() {
    digitController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
  }

  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  Future<void> addBid() async {
    _clearMessage();
    if (_isAddBidApiCalling || _isSubmitBidApiCalling) return;

    final digit = digitController.text.trim();
    final amount = amountController.text.trim();

    if (digit.isEmpty || int.tryParse(digit) == null || digit.length != 2) {
      _showMessage('Please enter a two-digit number (00-99).', isError: true);
      return;
    }
    int? parsedDigit = int.tryParse(digit);
    if (parsedDigit == null || parsedDigit < 0 || parsedDigit > 99) {
      _showMessage('Digit must be between 00 and 99.', isError: true);
      return;
    }

    int? parsedAmount = int.tryParse(amount);
    if (parsedAmount == null || parsedAmount < 10 || parsedAmount > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    // Check if the total amount of new bids exceeds the wallet balance
    // since the API returns multiple panas with the same amount
    if (parsedAmount > walletBalance && walletBalance != 0) {
      _showMessage(
        'Insufficient wallet balance to add this bid.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isAddBidApiCalling = true;
    });

    final url = Uri.parse('${Constant.apiEndpoint}two-digits-panel-pana');
    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final body = jsonEncode({
      "digit": parsedDigit,
      "sessionType": "open",
      "amount": parsedAmount,
    });

    log(
      'CURL Command for Two-Digits-Panel-Pana API:\ncurl -X POST \\\n  $url \\',
    );
    headers.forEach((key, value) {
      log('  -H "$key: $value" \\');
    });
    log('  -d \'$body\'');

    try {
      final response = await http.post(url, headers: headers, body: body);
      final responseData = json.decode(response.body);

      log("API Response for Two-Digits-Panel-Pana: $responseData");

      if (response.statusCode == 200 && responseData['status'] == true) {
        final List<dynamic> info = responseData['info'] ?? [];
        if (info.isNotEmpty) {
          setState(() {
            int bidsAddedCount = 0;
            for (var item in info) {
              final String pana = item['pana'].toString();
              final String panaAmount = item['amount'].toString();

              bool foundAndUpdated = false;
              for (int i = 0; i < bids.length; i++) {
                if (bids[i].pana == pana) {
                  // If a bid for this pana already exists, update its amount.
                  // The API response returns the new total amount for the pana.
                  bids[i] = Bid(
                    digit: digit,
                    amount: panaAmount,
                    type: "OPEN",
                    pana: pana,
                  );
                  foundAndUpdated = true;
                  break;
                }
              }

              if (!foundAndUpdated) {
                // If the bid for this pana does not exist, add a new one.
                bids.add(
                  Bid(
                    digit: digit,
                    amount: panaAmount,
                    type: "OPEN",
                    pana: pana,
                  ),
                );
                bidsAddedCount++;
              }
            }
            if (bidsAddedCount > 0) {
              _showMessage(
                '$bidsAddedCount unique panas added for 2-Digit $digit!',
              );
            } else {
              _showMessage(
                'Amounts updated for existing panas of 2-Digit $digit.',
                isError: false,
              );
            }
          });
          digitController.clear();
          amountController.clear();
        } else {
          _showMessage(
            'No panas found for 2-Digit $digit with the given amount.',
            isError: true,
          );
        }
      } else {
        String errorMessage =
            responseData['msg'] ??
            'Failed to fetch panas. Unknown error occurred.';
        _showMessage('Failed to add bid: $errorMessage', isError: true);
        log(
          'API Error for Two-Digits-Panel-Pana: Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      log('Network error fetching two-digits-panel-pana: $e');
      _showMessage('Network error: $e', isError: true);
    } finally {
      setState(() {
        _isAddBidApiCalling = false;
      });
    }
  }

  void deleteBid(int index) {
    _clearMessage();
    if (_isAddBidApiCalling || _isSubmitBidApiCalling) return;
    setState(() {
      final removedPana = bids[index].pana;
      bids.removeAt(index);
      _showMessage('Bid for Pana $removedPana removed from list.');
    });
  }

  int get totalAmount =>
      bids.fold(0, (sum, bid) => sum + (int.tryParse(bid.amount) ?? 0));

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

    List<Map<String, String>> bidsForDialog = bids.map((bid) {
      log(
        'Bid Digit: ${bid.digit}, Bid Amount: ${bid.amount}, Bid Type: ${bid.type}, Bid Pana: ${bid.pana}',
      );

      return {
        'digit': bid.digit,
        'amount': bid.amount,
        'type': bid.type,
        'pana': bid.pana,
      };
    }).toList();

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
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
            setState(() {
              _isSubmitBidApiCalling = true;
            });
            try {
              bool success = await _placeFinalBids();
              if (mounted) {
                if (success) {
                  await showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (BuildContext context) => const BidSuccessDialog(),
                  );
                  setState(() {
                    bids.clear();
                  });
                } else {
                  await showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (BuildContext context) => BidFailureDialog(
                      errorMessage: _messageToShow ?? 'Bid submission failed.',
                    ),
                  );
                }
              }
            } catch (e) {
              log(
                "Error during final bid submission in confirmation dialog: $e",
              );
              if (mounted) {
                _showMessage('An unexpected error occurred: $e', isError: true);
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isSubmitBidApiCalling = false;
                });
              }
            }
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    String url;
    if (widget.title.toLowerCase().contains('jackpot')) {
      url = '${Constant.apiEndpoint}place-jackpot-bid';
    } else if (widget.title.toLowerCase().contains('starline')) {
      url = '${Constant.apiEndpoint}place-starline-bid';
    } else {
      url = '${Constant.apiEndpoint}place-bid';
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      _showMessage('Authentication error. Please log in again.', isError: true);
      return false;
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final List<Map<String, dynamic>> bidPayload = bids.map((bid) {
      return {
        "sessionType": bid.type.toUpperCase(),
        "digit": bid.digit,
        "pana": bid.pana,
        "bidAmount": int.tryParse(bid.amount) ?? 0,
      };
    }).toList();

    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId,
      "bidAmount": totalAmount,
      "gameType": widget.gameType,
      "bid": bidPayload,
    });

    log('CURL Command for Final Bid Submission:\ncurl -X POST \\\n  $url \\');
    headers.forEach((key, value) {
      log('  -H "$key: $value" \\');
    });
    log('  -d \'$body\'');

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
        int currentWallet = walletBalance;
        int deductedAmount = totalAmount;
        int newWalletBalance = currentWallet - deductedAmount;
        storage.write('walletBalance', newWalletBalance.toString());
        setState(() {
          walletBalance = newWalletBalance;
        });
        _showMessage('All bids submitted successfully!');
        return true;
      } else {
        String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
        _showMessage('Bid submission failed: $errorMessage', isError: true);
        return false;
      }
    } catch (e) {
      log('Network error during bid submission: $e');
      _showMessage('Network error during bid submission: $e', isError: true);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAnyApiCalling = _isAddBidApiCalling || _isSubmitBidApiCalling;

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
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
        actions: [
          Image.asset(
            "assets/images/ic_wallet.png",
            width: 22,
            height: 22,
            color: Colors.black,
          ),
          const SizedBox(width: 6),
          Center(
            child: Text(
              userController.walletBalance.value,
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
      body: SafeArea(
        child: Stack(
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
                                'Enter Two Digits:',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                            SizedBox(height: 50),
                            Text(
                              'Enter Points:',
                              style: TextStyle(fontSize: 14),
                            ),
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
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                onTap: _clearMessage,
                                enabled: !isAnyApiCalling,
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
                                      color: Colors.orange,
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
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                onTap: _clearMessage,
                                enabled: !isAnyApiCalling,
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
                                      color: Colors.orange,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: isAnyApiCalling ? null : addBid,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isAnyApiCalling
                                    ? Colors.grey
                                    : Colors.orange,
                                minimumSize: const Size(80, 45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: _isAddBidApiCalling
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
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
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pana', // Changed label to Pana
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 40),
                        Expanded(
                          child: Text(
                            'Amount',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 40),
                        Expanded(
                          child: Text(
                            'Type',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Spacer(),
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
                                  horizontal: 10,
                                  vertical: 0,
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
                                        Expanded(child: Text(bid.pana)),
                                        Expanded(child: Text(bid.amount)),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Text(bid.type),
                                              const Spacer(),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.orange,
                                                ),
                                                onPressed: isAnyApiCalling
                                                    ? null
                                                    : () => deleteBid(index),
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
                              SizedBox(width: 40),
                              const Text(
                                "Bid",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text("${bids.length}"),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Column(
                            children: [
                              const Text(
                                "Total",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text("$totalAmount"),
                            ],
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: isAnyApiCalling
                                ? null
                                : _showConfirmationDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isAnyApiCalling
                                  ? Colors.grey
                                  : Colors.orange,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSubmitBidApiCalling
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'SUBMIT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
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
      ),
    );
  }
}
