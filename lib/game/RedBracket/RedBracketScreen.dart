import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../BidService.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';

enum BracketType { half, full }

class RedBracketBoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;
  final String gameType;

  const RedBracketBoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId,
    required this.gameType,
  }) : super(key: key);

  @override
  State<RedBracketBoardScreen> createState() => _RedBracketBoardScreenState();
}

class _RedBracketBoardScreenState extends State<RedBracketBoardScreen> {
  final TextEditingController _amountController = TextEditingController();

  List<Map<String, String>> _bids = [];
  BracketType _bracketType = BracketType.half;

  late GetStorage storage = GetStorage();
  late String _accessToken;
  late String _registerId;
  late String _preferredLanguage;
  bool _accountStatus = false;
  late int _walletBalance;
  bool _isApiCalling = false;

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  late BidService _bidService;

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupStorageListeners();
    _bidService = BidService(storage);
  }

  Future<void> _loadInitialData() async {
    _accessToken = storage.read('accessToken') ?? '';
    _registerId = storage.read('registerId') ?? '';
    _accountStatus = storage.read('accountStatus') ?? false;
    _preferredLanguage = storage.read('selectedLanguage') ?? 'en';
    _walletBalance = int.tryParse(storage.read('walletBalance') ?? '0') ?? 0;
  }

  void _setupStorageListeners() {
    storage.listenKey('accessToken', (value) {
      if (mounted) setState(() => _accessToken = value ?? '');
    });
    storage.listenKey('registerId', (value) {
      if (mounted) setState(() => _registerId = value ?? '');
    });
    storage.listenKey('accountStatus', (value) {
      if (mounted) setState(() => _accountStatus = value ?? false);
    });
    storage.listenKey('selectedLanguage', (value) {
      if (mounted) setState(() => _preferredLanguage = value ?? 'en');
    });
    storage.listenKey('walletBalance', (value) {
      if (mounted)
        setState(() => _walletBalance = int.tryParse(value ?? '0') ?? 0);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
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

  Future<void> _addBid() async {
    if (_isApiCalling) return;
    _clearMessage();

    final amount = _amountController.text.trim();

    if (amount.isEmpty) {
      _showMessage('Please enter an amount.', isError: true);
      return;
    }

    int? parsedAmount = int.tryParse(amount);

    if (parsedAmount == null) {
      _showMessage('Please enter a valid number for amount.', isError: true);
      return;
    }

    String typeForApi = _bracketType == BracketType.half
        ? "halfBracket"
        : "fullBracket";
    String gameTypeDisplay = _bracketType == BracketType.half
        ? "HALF BRACKET"
        : "FULL BRACKET";

    setState(() {
      _isApiCalling = true;
    });

    final String url = 'https://sara777.win/api/v1/red-bracket-jodi';

    if (_accessToken.isEmpty) {
      _showMessage('Authentication error. Please log in again.', isError: true);
      setState(() {
        _isApiCalling = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
          'deviceId': _deviceId,
          'deviceName': _deviceName,
          'accessStatus': _accountStatus ? '1' : '0',
        },
        body: jsonEncode({'type': typeForApi, 'amount': parsedAmount}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['status'] == true) {
        final List<dynamic> newBidsFromApi = responseBody['info'];

        setState(() {
          for (var bidData in newBidsFromApi) {
            String digit = bidData['pana'].toString();
            String amount = bidData['amount'].toString();

            // Find existing bid with the same digit and game type
            int existingIndex = _bids.indexWhere(
              (bid) =>
                  bid['digit'] == digit && bid['gameType'] == gameTypeDisplay,
            );

            if (existingIndex != -1) {
              // If bid already exists, update its amount
              _bids[existingIndex]['amount'] = amount;
            } else {
              // Otherwise, add a new bid
              _bids.add({
                "digit": digit,
                "amount": amount,
                "gameType": gameTypeDisplay,
              });
            }
          }
          _showMessage(
            'Bids added/updated successfully from API.',
            isError: false,
          );
        });

        _amountController.clear();
      } else {
        String errorMessage = responseBody['msg'] ?? 'Failed to add bid.';
        _showMessage(errorMessage, isError: true);
      }
    } catch (e) {
      _showMessage('An error occurred: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isApiCalling = false;
        });
      }
    }
  }

  void _removeBid(int index) {
    if (_isApiCalling) return;
    _clearMessage();
    setState(() {
      final removedDigit = _bids[index]['digit'];
      _bids.removeAt(index);
      _showMessage('Bid for Digit $removedDigit removed from list.');
    });
  }

  int _getTotalAmount() {
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
    );
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    if (_bids.isEmpty) {
      _showMessage('Please add at least one bid.', isError: true);
      return;
    }

    final int totalPoints = _getTotalAmount();

    if (_walletBalance < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
      return;
    }

    List<Map<String, String>> bidsForDialog = _bids.map((bid) {
      return {
        "digit": bid['digit']!,
        "pana": "",
        "points": bid['amount']!,
        "type": bid['gameType']!,
        "jodi": bid['digit']!,
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
          gameTitle: widget.screenTitle,
          gameDate: formattedDate,
          bids: bidsForDialog,
          totalBids: bidsForDialog.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: _walletBalance,
          walletBalanceAfterDeduction: (_walletBalance - totalPoints)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            setState(() {
              _isApiCalling = true;
            });
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                _bids.clear();
              });
            }
            if (mounted) {
              setState(() {
                _isApiCalling = false;
              });
            }
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    if (_accessToken.isEmpty || _registerId.isEmpty) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return const BidFailureDialog(
              errorMessage: 'Authentication error. Please log in again.',
            );
          },
        );
      }
      return false;
    }

    Map<String, String> bidAmountsForService = {};
    for (var bid in _bids) {
      bidAmountsForService[bid['digit']!] = bid['amount']!;
    }

    final response = await _bidService.placeFinalBids(
      gameName: widget.screenTitle,
      accessToken: _accessToken,
      registerId: _registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: _accountStatus,
      bidAmounts: bidAmountsForService,
      selectedGameType: _bracketType == BracketType.half
          ? "HALF BRACKET"
          : "FULL BRACKET",
      gameId: widget.gameId,
      gameType: widget.gameType,
      totalBidAmount: _getTotalAmount(),
    );

    if (response['status'] == true) {
      int currentWallet = _walletBalance;
      int deductedAmount = _getTotalAmount();
      int newWalletBalance = currentWallet - deductedAmount;
      await _bidService.updateWalletBalance(newWalletBalance);

      if (mounted) {
        setState(() {
          _walletBalance = newWalletBalance;
        });
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return const BidSuccessDialog();
          },
        );
      }
      return true;
    } else {
      String errorMessage = response['msg'] ?? "Unknown error occurred.";
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return BidFailureDialog(errorMessage: errorMessage);
          },
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.screenTitle,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.black,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  _walletBalance.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildBracketRadio(BracketType.half, 'Half Bracket'),
                          const SizedBox(width: 20),
                          _buildBracketRadio(BracketType.full, 'Full Bracket'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            "Enter Amount",
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _amountController,
                              hintText: 'Enter Amount',
                              isAmountField: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _addBid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: _isApiCalling
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                )
                              : Text(
                                  "ADD BID",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(thickness: 1, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Digit',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Amount',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Game Type',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
                const Divider(thickness: 1, height: 1),
                Expanded(
                  child: _bids.isEmpty
                      ? Center(
                          child: Text(
                            'No Bids Placed',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _bids.length,
                          itemBuilder: (context, index) {
                            final bid = _bids[index];
                            return _buildBidListItem(index, bid);
                          },
                        ),
                ),
                if (_bids.isNotEmpty) _buildBottomBar(),
              ],
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

  Widget _buildBracketRadio(BracketType type, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<BracketType>(
          value: type,
          groupValue: _bracketType,
          onChanged: (BracketType? value) {
            if (value != null) {
              setState(() {
                _bracketType = value;
              });
            }
          },
          activeColor: Colors.orange,
        ),
        Text(label, style: GoogleFonts.poppins()),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required bool isAmountField,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        hintText: hintText,
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.orange, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onTap: _clearMessage,
    );
  }

  Widget _buildBidListItem(int index, Map<String, String> bid) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(bid['digit']!, style: GoogleFonts.poppins())),
          Expanded(child: Text(bid['amount']!, style: GoogleFonts.poppins())),
          Expanded(child: Text(bid['gameType']!, style: GoogleFonts.poppins())),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeBid(index),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    int totalBids = _bids.length;
    int totalAmount = _getTotalAmount();

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
          Row(
            children: [
              Text(
                'Bids: ',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '$totalBids',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'Total: ',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '$totalAmount',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: Text(
              'SUBMIT',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
