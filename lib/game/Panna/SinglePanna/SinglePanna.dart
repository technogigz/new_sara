import 'dart:async'; // Added for Timer in AnimatedMessageBar logic
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:new_sara/ulits/Constents.dart'; // Retained your original import path

import '../../../components/BidConfirmationDialog.dart';

// AnimatedMessageBar component
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

class SinglePannaScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType;
  final String gameName; // Added gameName for API endpoint logic

  const SinglePannaScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
    this.gameName = "", // Default empty
  }) : super(key: key);

  @override
  State<SinglePannaScreen> createState() => _SinglePannaScreenState();
}

class _SinglePannaScreenState extends State<SinglePannaScreen> {
  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final List<String> gameTypes = ['Open', 'Close'];
  String selectedGameType = 'Close';

  List<Map<String, String>> bids = [];
  int walletBalance = 0;
  late String accessToken;
  late String registerId;

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadSavedBids();
    // No need to call _loadWalletBalance explicitly here if _loadInitialData covers it.
    // The listener below will handle updates.
    GetStorage().listenKey('walletBalance', (value) {
      setState(() {
        if (value is int) {
          walletBalance = value;
        } else if (value is String) {
          walletBalance = int.tryParse(value) ?? 0;
        } else {
          walletBalance = 0;
        }
      });
    });
  }

  void _loadInitialData() {
    final box = GetStorage();
    accessToken = box.read('accessToken') ?? '';
    registerId = box.read('registerId') ?? '';
    final dynamic storedValue = box.read('walletBalance');

    if (storedValue != null) {
      if (storedValue is int) {
        walletBalance = storedValue;
      } else if (storedValue is String) {
        walletBalance = int.tryParse(storedValue) ?? 0;
      } else {
        walletBalance = 0;
      }
    } else {
      walletBalance = 1000;
      box.write('walletBalance', walletBalance);
    }
  }

  @override
  void dispose() {
    digitController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void _loadSavedBids() {
    final box = GetStorage();
    final savedBids = box.read<List>('placedBids');
    if (savedBids != null) {
      setState(() {
        bids = savedBids
            .map((item) {
              if (item is Map) {
                return {
                  'digit': item['digit']?.toString() ?? '',
                  'amount': item['amount']?.toString() ?? '',
                  'type': item['type']?.toString() ?? '',
                };
              }
              return <String, String>{};
            })
            .where((map) => map.isNotEmpty)
            .toList();
      });
    }
  }

  void _saveBids() {
    GetStorage().write('placedBids', bids);
  }

  void _showMessage(String message, {bool isError = false}) {
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

  Future<void> _addBid() async {
    _clearMessage();
    final digit = digitController.text.trim();
    final amount = amountController.text.trim();

    if (digit.isEmpty || amount.isEmpty) {
      _showMessage('Please fill in all fields', isError: true);
      return;
    }

    final intAmount = int.tryParse(amount);
    if (intAmount == null || intAmount <= 0) {
      _showMessage('Enter a valid amount', isError: true);
      return;
    }

    setState(() {
      bids.add({'digit': digit, 'amount': amount, 'type': selectedGameType});
      _saveBids();
      digitController.clear();
      amountController.clear();
    });

    _showMessage(
      'Bid added to list: Digit $digit, Amount $amount, Type $selectedGameType',
    );
  }

  void _showBidConfirmationDialog() {
    _clearMessage();
    if (bids.isEmpty) {
      _showMessage('Please add at least one bid to confirm.', isError: true);
      return;
    }

    int totalPoints = bids.fold(
      0,
      (sum, bid) => sum + (int.tryParse(bid['amount'] ?? '0') ?? 0),
    );

    if (totalPoints > walletBalance) {
      _showMessage('Insufficient wallet balance for all bids.', isError: true);
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
          gameTitle: widget.title,
          gameDate: formattedDate,
          bids: bids,
          totalBids: bids.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            Navigator.pop(dialogContext); // Dismiss the confirmation dialog
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                bids.clear();
              });
              _saveBids();
              _showMessage('Bids placed successfully!', isError: false);
            }
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    String url;
    if (widget.gameName.toLowerCase().contains('jackpot')) {
      url = '${Constant.apiEndpoint}place-jackpot-bid';
    } else if (widget.gameName.toLowerCase().contains('starline')) {
      url = '${Constant.apiEndpoint}place-starline-bid';
    } else {
      url = '${Constant.apiEndpoint}place-bid';
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      _showMessage('Authentication error. Please log in again.', isError: true);
      return false;
    }

    final headers = {
      'deviceId': 'qwert',
      'deviceName': 'sm2233',
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final List<Map<String, dynamic>> bidPayload = bids.map((entry) {
      String sessionType = entry["type"] ?? "";
      String digit = entry["digit"] ?? "";
      int bidAmount = int.tryParse(entry["amount"] ?? '0') ?? 0;

      return {
        "sessionType": sessionType == "Open"
            ? "OPEN"
            : "CLOSE", // Ensure uppercase for API
        "digit": digit,
        "pana":
            "", // Not applicable for Single Panna, assuming this field isn't needed or is empty
        "bidAmount": bidAmount,
      };
    }).toList();

    final body = {
      "registerId": registerId,
      "gameId": widget.gameId,
      "bidAmount": _getTotalPoints(),
      "gameType": widget.gameType,
      "bid": bidPayload,
    };

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

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      final Map<String, dynamic> responseBody = json.decode(response.body);

      if (response.statusCode == 200 && responseBody['status'] == true) {
        int currentWallet = walletBalance;
        int deductedAmount = _getTotalPoints();
        int newWalletBalance = currentWallet - deductedAmount;
        GetStorage().write('walletBalance', newWalletBalance.toString());
        setState(() {
          walletBalance = newWalletBalance;
        });
        return true;
      } else {
        String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
        _showMessage('Bid submission failed: $errorMessage', isError: true);
        return false;
      }
    } catch (e) {
      _showMessage('Network error during bid submission: $e', isError: true);
      return false;
    }
  }

  Widget _inputRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          field,
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return SizedBox(
      height: 35,
      width: 150,
      child: DropdownButtonFormField<String>(
        value: selectedGameType,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.amber, width: 2),
          ),
        ),
        items: gameTypes.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(type, style: GoogleFonts.poppins()),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => selectedGameType = value);
          }
        },
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint) {
    return SizedBox(
      height: 35,
      width: 150,
      child: TextFormField(
        controller: controller,
        cursorColor: Colors.amber,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onTap: _clearMessage,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.amber, width: 2),
          ),
        ),
        style: GoogleFonts.poppins(fontSize: 14),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Digit",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              "Amount",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              "Game Type",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  void _removeBid(int index) {
    _clearMessage();
    setState(() {
      bids.removeAt(index);
    });
    _saveBids();
    _showMessage('Bid removed from list.');
  }

  int _getTotalPoints() {
    return bids.fold(
      0,
      (sum, bid) => sum + (int.tryParse(bid['amount'] ?? '0') ?? 0),
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
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
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
                Image.asset(
                  'assets/images/wallet_icon.png', // Ensure this asset path is correct
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  "$walletBalance",
                  style: GoogleFonts.poppins(color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _inputRow("Select Game Type:", _buildDropdown()),
                _inputRow(
                  "Enter Single Digit:",
                  _buildInputField(digitController, "Bid Digits"),
                ),
                _inputRow(
                  "Enter Points:",
                  _buildInputField(amountController, "Enter Amount"),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 35,
                    width: 150,
                    child: ElevatedButton(
                      onPressed: _addBid,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        "ADD BID",
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                _buildTableHeader(),
                Divider(color: Colors.grey.shade300),
                Expanded(
                  child: bids.isEmpty
                      ? Center(
                          child: Text(
                            "No Bids Added",
                            style: GoogleFonts.poppins(color: Colors.black38),
                          ),
                        )
                      : ListView.builder(
                          itemCount: bids.length,
                          itemBuilder: (context, index) {
                            final bid = bids[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        bid['digit']!,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        bid['amount']!,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        bid['type']!,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () => _removeBid(index),
                                    ),
                                  ],
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
                              'Total Bids:',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '${bids.length}',
                              style: GoogleFonts.poppins(
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
                              'Total Amount:',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '${_getTotalPoints()}',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: _showBidConfirmationDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'SUBMIT',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
    );
  }
}
