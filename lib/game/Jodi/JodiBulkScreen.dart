// imports
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../BidService.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';

class JodiBulkScreen extends StatefulWidget {
  final String screenTitle;
  final String gameType;
  final int gameId;
  final String gameName;

  const JodiBulkScreen({
    Key? key,
    required this.screenTitle,
    required this.gameType,
    required this.gameId,
    required this.gameName,
  }) : super(key: key);

  @override
  State<JodiBulkScreen> createState() => _JodiBulkScreenState();
}

class _JodiBulkScreenState extends State<JodiBulkScreen> {
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _jodiDigitController = TextEditingController();
  final GetStorage storage = GetStorage();
  final BidService bidService = BidService(GetStorage());
  final _bidService = BidService(GetStorage());

  List<Map<String, String>> _bids = [];
  String _accessToken = '';
  String _registerId = '';
  bool _accountStatus = false;
  String _walletBalance = '0';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;
  bool _isSubmitting = false;

  final String _deviceId = 'test_device_id_flutter_jodibulk';
  final String _deviceName = 'test_device_name_flutter_jodibulk';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupStorageListeners();
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _jodiDigitController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _accessToken = storage.read('accessToken') ?? '';
    _registerId = storage.read('registerId') ?? '';
    _accountStatus = storage.read('accountStatus') ?? false;
    _walletBalance = storage.read('walletBalance')?.toString() ?? '0';
    setState(() {});
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

    storage.listenKey('walletBalance', (value) {
      if (mounted) setState(() => _walletBalance = value?.toString() ?? '0');
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    _messageDismissTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    _messageDismissTimer = Timer(const Duration(seconds: 3), _clearMessage);
  }

  void _clearMessage() {
    if (mounted) setState(() => _messageToShow = null);
  }

  void _addBidAutomatically() {
    _clearMessage();
    if (_isSubmitting) return;

    final digit = _jodiDigitController.text.trim();
    final points = _pointsController.text.trim();

    if (digit.length != 2 || int.tryParse(digit) == null) {
      _showMessage(
        'Jodi digit must be exactly 2 numbers (00-99).',
        isError: true,
      );
      return;
    }

    if (int.parse(digit) < 0 || int.parse(digit) > 99) {
      _showMessage('Jodi must be a number between 00 and 99.', isError: true);
      return;
    }

    if (points.isEmpty || int.tryParse(points) == null) {
      _showMessage('Please enter valid points.', isError: true);
      return;
    }

    final int parsedPoints = int.parse(points);
    final int currentWalletBalance = int.tryParse(_walletBalance) ?? 0;

    if (parsedPoints > currentWalletBalance) {
      _showMessage('Insufficient wallet balance for this bid.', isError: true);
      return;
    }

    bool alreadyExists = _bids.any(
      (entry) =>
          entry['digit'] == digit && entry['gameType'] == widget.gameType,
    );

    if (!alreadyExists) {
      setState(() {
        _bids.add({
          "digit": digit,
          "points": points,
          "gameType": widget.gameType,
          "type": "Jodi",
        });
        _jodiDigitController.clear();
        _pointsController.clear();
        _showMessage('Jodi $digit with $points points added.', isError: false);
      });
    } else {
      _showMessage(
        'Jodi $digit already added for this game type.',
        isError: true,
      );
    }
  }

  void _removeBid(int index) {
    if (_isSubmitting) return;
    setState(() {
      final Map<String, String> removedBid = _bids.removeAt(index);
      _showMessage('Jodi ${removedBid['digit']} removed.', isError: false);
    });
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (_bids.isEmpty) {
      _showMessage(
        'Please add at least one bid before submitting.',
        isError: true,
      );
      return;
    }

    final int totalPoints = _getTotalPoints();
    final int currentWalletBalance = int.tryParse(_walletBalance) ?? 0;

    if (currentWalletBalance < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place these bids.',
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
          gameTitle: "${widget.gameName} - ${widget.gameType}",
          gameDate: formattedDate,
          bids: _bids
              .map(
                (bid) => {
                  "digit": bid['digit']!,
                  "points": bid['points']!,
                  "type": bid['type']!,
                },
              )
              .toList(),
          totalBids: _bids.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: currentWalletBalance,
          walletBalanceAfterDeduction: (currentWalletBalance - totalPoints)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () => _placeFinalBids(),
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    final result = await _bidService.placeFinalBids(
      gameName: widget.gameName,
      accessToken: _accessToken,
      registerId: _registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: _accountStatus,
      bidAmounts: _bidService.getBidAmounts(_bids),
      selectedGameType: "OPEN",
      gameId: widget.gameId,
      gameType: widget.gameType,
      totalBidAmount: _getTotalPoints(),
    );

    if (!mounted) return false;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => result['status']
            ? const BidSuccessDialog()
            : BidFailureDialog(errorMessage: result['msg']),
      );

      if (result['status'] && context.mounted) {
        final newBalance = _walletBalance - _getTotalPoints();
        setState(() {
          _walletBalance = newBalance;
        });
        await _bidService.updateWalletBalance(newBalance);
      }
    });

    return result['status'] == true;
  }

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.screenTitle,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.black,
          ),
          const SizedBox(width: 6),
          Center(
            child: Text(
              _walletBalance, // Use private variable here
              style: const TextStyle(
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
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Enter Points:',
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                        SizedBox(
                          width: 150,
                          height: 40,
                          child: TextField(
                            cursorColor: Colors.amber,
                            controller: _pointsController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onTap: _clearMessage,
                            decoration: InputDecoration(
                              hintText: 'Enter Amount',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Colors.amber,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Enter Jodi Digit:',
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                        SizedBox(
                          width: 150,
                          height: 40,
                          child: TextField(
                            cursorColor: Colors.amber,
                            controller:
                                _jodiDigitController, // Use renamed controller
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(2),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onTap: _clearMessage,
                            onChanged: (value) {
                              if (value.length == 2 &&
                                  _pointsController.text.isNotEmpty) {
                                _addBidAutomatically();
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Bid Digits',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Colors.amber,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
              const Divider(thickness: 1),
              if (_bids.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Digit',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Amount',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Game Type',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              if (_bids.isNotEmpty) const Divider(thickness: 1),
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
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      bid['digit'] ?? '',
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      bid['points'] ?? '',
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      bid['type'] ?? bid['gameType'] ?? '',
                                      style: GoogleFonts.poppins(
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _removeBid(index),
                                  ),
                                ],
                              ),
                            ),
                          );
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
    );
  }

  Widget _buildBottomBar() {
    int totalBids = _bids.length;
    int totalPoints = _getTotalPoints();

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
                style: GoogleFonts.poppins(
                  fontSize: 14,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Points',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '$totalPoints',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSubmitting ? Colors.grey : Colors.orange[700],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'SUBMIT',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  operator -(int other) {}
}
