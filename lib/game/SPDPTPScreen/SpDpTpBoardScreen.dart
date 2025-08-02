import 'dart:async';
import 'dart:developer'; // For log
import 'dart:math' hide log; // For Random number generation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:marquee/marquee.dart';

import '../../BidService.dart'; // Import BidService (ensure this path is correct)
import '../../components/AnimatedMessageBar.dart'; // Ensure this path is correct
import '../../components/BidConfirmationDialog.dart'; // Ensure this path is correct
import '../../components/BidFailureDialog.dart'; // For API failure dialog (ensure this path is correct)
import '../../components/BidSuccessDialog.dart'; // For API success dialog (ensure this path is correct)

class SpDpTpBoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;
  final String gameType;
  final bool openSessionStatus;

  const SpDpTpBoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId,
    required this.gameType,
    required this.openSessionStatus,
  }) : super(key: key);

  @override
  State<SpDpTpBoardScreen> createState() => _SpDpTpBoardScreenState();
}

class _SpDpTpBoardScreenState extends State<SpDpTpBoardScreen> {
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _pannaController = TextEditingController();

  bool _isSPSelected = false;
  bool _isDPSelected = false;
  bool _isTPSelected = false;

  String? _selectedGameTypeOption;

  List<Map<String, String>> _bids = [];
  final Random _random = Random();

  late int walletBalance;
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  final GetStorage storage = GetStorage();

  late BidService _bidService;

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  bool _isApiCalling = false;

  @override
  void initState() {
    super.initState();
    _bidService = BidService(storage);
    _loadInitialData();
    _setupStorageListeners();
    // Set initial dropdown value based on session status
    if (widget.openSessionStatus) {
      _selectedGameTypeOption = 'OPEN';
    } else {
      _selectedGameTypeOption = 'CLOSE';
    }
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = storage.read('accountStatus') ?? false;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is int) {
      walletBalance = storedWalletBalance;
    } else if (storedWalletBalance is String) {
      walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else {
      walletBalance = 0;
    }
  }

  void _setupStorageListeners() {
    storage.listenKey('accessToken', (value) {
      if (mounted) setState(() => accessToken = value ?? '');
    });
    storage.listenKey('registerId', (value) {
      if (mounted) setState(() => registerId = value ?? '');
    });
    storage.listenKey('accountStatus', (value) {
      if (mounted) setState(() => accountStatus = value ?? false);
    });
    storage.listenKey('selectedLanguage', (value) {
      if (mounted) setState(() => preferredLanguage = value ?? 'en');
    });
    storage.listenKey('walletBalance', (value) {
      if (mounted) {
        setState(() {
          if (value is int) {
            walletBalance = value;
          } else if (value is String) {
            walletBalance = int.tryParse(value) ?? 0;
          } else {
            walletBalance = 0;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _pannaController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    _messageDismissTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    _messageDismissTimer = Timer(const Duration(seconds: 3), () {
      _clearMessage();
    });
  }

  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
    );
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;
    if (_bids.isEmpty) {
      _showMessage('Please add bids before submitting.', isError: true);
      return;
    }

    int currentTotalPoints = _getTotalPoints();

    if (walletBalance < currentTotalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
      return;
    }

    final List<Map<String, String>> validBids = _bids
        .where((bid) {
          return bid['digit'] != null &&
              bid['digit']!.isNotEmpty &&
              bid['amount'] != null &&
              bid['amount']!.isNotEmpty &&
              bid['gameType'] != null &&
              bid['gameType']!.isNotEmpty;
        })
        .map((bid) {
          return {
            'digit': bid['digit']!,
            'points': bid['amount']!,
            'type': bid['gameType']!,
            'pana': bid['digit']!,
            'jodi': '',
          };
        })
        .toList();

    if (validBids.isEmpty) {
      _showMessage('No valid bids to submit.', isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.screenTitle,
          bids: validBids,
          totalBids: validBids.length,
          totalBidsAmount: currentTotalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - currentTotalPoints)
              .toString(),
          gameDate: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            // Navigator.pop(dialogContext); // Dismiss the confirmation dialog
            setState(() {
              _isApiCalling = true;
            });
            await _placeFinalBids();
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
    final Map<String, String> bidPayload = {};
    int currentBatchTotalPoints = _getTotalPoints();

    if (accessToken.isEmpty || registerId.isEmpty) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Authentication error. Please log in again.',
        ),
      );
      return false;
    }

    for (var bid in _bids) {
      String digit = bid["digit"] ?? "";
      String amount = bid["amount"] ?? "0";

      if (digit.isNotEmpty && int.tryParse(amount) != null) {
        bidPayload[digit] = amount;
      }
    }

    if (bidPayload.isEmpty) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const BidFailureDialog(errorMessage: 'No valid bids to submit.'),
      );
      return false;
    }

    try {
      final result = await _bidService.placeFinalBids(
        gameName: widget.screenTitle,
        accessToken: accessToken,
        registerId: registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: accountStatus,
        bidAmounts: bidPayload,
        selectedGameType: _selectedGameTypeOption!,
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: currentBatchTotalPoints,
      );

      if (!mounted) return false;

      if (result['status'] == true) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );

        final dynamic updatedBalanceRaw = result['updatedWalletBalance'];
        final int updatedBalance =
            int.tryParse(updatedBalanceRaw.toString()) ??
            (walletBalance - currentBatchTotalPoints);
        setState(() {
          walletBalance = updatedBalance;
          _bids.clear();
        });
        _bidService.updateWalletBalance(updatedBalance);
        return true;
      } else {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(
            errorMessage: result['msg'] ?? 'Something went wrong',
          ),
        );
        return false;
      }
    } catch (e) {
      log('Error during bid placement: $e', name: 'SpDpTpBoardScreenBidError');
      if (!mounted) return false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'An unexpected error occurred during bid submission.',
        ),
      );
      return false;
    }
  }

  bool _isValidSpPanna(String panna) {
    if (panna.length != 3) return false;
    Set<String> uniqueDigits = panna.split('').toSet();
    return uniqueDigits.length == 3;
  }

  bool _isValidDpPanna(String panna) {
    if (panna.length != 3) return false;
    List<String> digits = panna.split('');
    Map<String, int> freq = {};
    for (var d in digits) {
      freq[d] = (freq[d] ?? 0) + 1;
    }
    return freq.length == 2 && freq.values.contains(2);
  }

  bool _isValidTpPanna(String panna) {
    if (panna.length != 3) return false;
    return panna[0] == panna[1] && panna[1] == panna[2];
  }

  void _removeBid(int index) {
    _clearMessage();
    if (_isApiCalling) return;

    setState(() {
      final removedBid = _bids.removeAt(index);
      _showMessage(
        'Removed bid: ${removedBid['gameType']} ${removedBid['digit']}.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    String marketName = widget.screenTitle.split(' - ')[0];

    // Determine the dropdown items dynamically
    List<DropdownMenuItem<String>> dropdownItems = [];
    if (widget.openSessionStatus) {
      dropdownItems.add(
        DropdownMenuItem<String>(
          value: 'OPEN',
          child: SizedBox(
            width: 150,
            height: 20,
            child: Marquee(
              text: '$marketName OPEN',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black, // Active color
              ),
              scrollAxis: Axis.horizontal,
              blankSpace: 40.0,
              velocity: 30.0,
              pauseAfterRound: const Duration(seconds: 1),
              startPadding: 10.0,
              accelerationDuration: const Duration(seconds: 1),
              accelerationCurve: Curves.linear,
              decelerationDuration: const Duration(milliseconds: 500),
              decelerationCurve: Curves.easeOut,
            ),
          ),
        ),
      );
    }
    // 'CLOSE' option is always added
    dropdownItems.add(
      DropdownMenuItem<String>(
        value: 'CLOSE',
        child: SizedBox(
          width: 150,
          height: 20,
          child: Marquee(
            text: '$marketName CLOSE',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black, // Active color
            ),
            scrollAxis: Axis.horizontal,
            blankSpace: 40.0,
            velocity: 30.0,
            pauseAfterRound: const Duration(seconds: 1),
            startPadding: 10.0,
            accelerationDuration: const Duration(seconds: 1),
            accelerationCurve: Curves.linear,
            decelerationDuration: const Duration(milliseconds: 500),
            decelerationCurve: Curves.easeOut,
          ),
        ),
      ),
    );

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
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
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
              walletBalance.toString(),
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
                          'Select Game Type',
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                        SizedBox(
                          width: 150,
                          height: 40,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedGameTypeOption,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.orange,
                                ),
                                onChanged: _isApiCalling
                                    ? null
                                    : (String? newValue) {
                                        setState(() {
                                          _selectedGameTypeOption = newValue;
                                          _clearMessage();
                                        });
                                      },
                                items:
                                    dropdownItems, // Use the dynamically built list
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Checkbox(
                                value: _isSPSelected,
                                onChanged: _isApiCalling
                                    ? null
                                    : (bool? value) {
                                        setState(() {
                                          _isSPSelected = value!;
                                          if (value) {
                                            _isDPSelected = false;
                                            _isTPSelected = false;
                                          }
                                          _clearMessage();
                                        });
                                      },
                                activeColor: Colors.orange,
                              ),
                              Text(
                                'SP',
                                style: GoogleFonts.poppins(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Checkbox(
                                value: _isDPSelected,
                                onChanged: _isApiCalling
                                    ? null
                                    : (bool? value) {
                                        setState(() {
                                          _isDPSelected = value!;
                                          if (value) {
                                            _isSPSelected = false;
                                            _isTPSelected = false;
                                          }
                                          _clearMessage();
                                        });
                                      },
                                activeColor: Colors.orange,
                              ),
                              Text(
                                'DP',
                                style: GoogleFonts.poppins(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Checkbox(
                                value: _isTPSelected,
                                onChanged: _isApiCalling
                                    ? null
                                    : (bool? value) {
                                        setState(() {
                                          _isTPSelected = value!;
                                          if (value) {
                                            _isSPSelected = false;
                                            _isTPSelected = false;
                                          }
                                          _clearMessage();
                                        });
                                      },
                                activeColor: Colors.orange,
                              ),
                              Text(
                                'TP',
                                style: GoogleFonts.poppins(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Enter Panna:',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(
                          width: 150,
                          height: 40,
                          child: TextField(
                            cursorColor: Colors.orange,
                            controller: _pannaController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(3),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              hintText: 'Enter Panna',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(color: Colors.black),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(color: Colors.black),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.orange,
                                  width: 2,
                                ),
                              ),
                            ),
                            onTap: _clearMessage,
                            enabled: !_isApiCalling,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Enter Points:',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(
                          width: 150,
                          height: 40,
                          child: TextField(
                            cursorColor: Colors.orange,
                            controller: _pointsController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'Enter Amount',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(color: Colors.black),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(color: Colors.black),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.orange,
                                  width: 2,
                                ),
                              ),
                            ),
                            onTap: _clearMessage,
                            enabled: !_isApiCalling,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 150,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _isApiCalling ? null : _addBid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isApiCalling
                                ? Colors.grey
                                : Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: _isApiCalling
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                              : Text(
                                  "ADD",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
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
                                      '${bid['gameType']}',
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
                                    onPressed: _isApiCalling
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

  void _addBid() {
    _clearMessage();
    if (_isApiCalling) return;

    final panna = _pannaController.text.trim();
    final points = _pointsController.text.trim();

    String gameCategory = '';
    int selectedCount = 0;
    if (_isSPSelected) {
      gameCategory = 'SP';
      selectedCount++;
    }
    if (_isDPSelected) {
      gameCategory = 'DP';
      selectedCount++;
    }
    if (_isTPSelected) {
      gameCategory = 'TP';
      selectedCount++;
    }

    if (selectedCount == 0) {
      _showMessage('Please select SP, DP, or TP.', isError: true);
      return;
    }
    if (selectedCount > 1) {
      _showMessage('Please select only one of SP, DP, or TP.', isError: true);
      return;
    }

    if (panna.isEmpty) {
      _showMessage('Please enter a Panna.', isError: true);
      return;
    }

    if (panna.length != 3) {
      _showMessage('Panna must be 3 digits.', isError: true);
      return;
    }

    bool isValidPanna = false;
    if (gameCategory == 'SP') {
      isValidPanna = _isValidSpPanna(panna);
    } else if (gameCategory == 'DP') {
      isValidPanna = _isValidDpPanna(panna);
    } else if (gameCategory == 'TP') {
      isValidPanna = _isValidTpPanna(panna);
    }

    if (!isValidPanna) {
      _showMessage(
        'Invalid Panna for $gameCategory. Please check the digits.',
        isError: true,
      );
      return;
    }

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10) {
      _showMessage('Points must be at least 10.', isError: true);
      return;
    }

    if (_bids.any(
      (bid) =>
          bid['digit'] == panna &&
          bid['gameType'] == gameCategory &&
          bid['amount'] == points,
    )) {
      _showMessage(
        'Bid for $gameCategory $panna with $points points already added.',
        isError: true,
      );
      return;
    }
    if (_bids.any(
      (bid) => bid['digit'] == panna && bid['gameType'] == gameCategory,
    )) {
      _showMessage(
        'Bid for $gameCategory $panna is already added with a different amount. Please remove it first to add with new amount.',
        isError: true,
      );
      return;
    }

    setState(() {
      _bids.add({"digit": panna, "amount": points, "gameType": gameCategory});
      _pannaController.clear();
      _pointsController.clear();
      _showMessage('Bid for $gameCategory $panna added successfully.');
    });
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
            onPressed: _isApiCalling || _bids.isEmpty
                ? null
                : _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isApiCalling || _bids.isEmpty
                  ? Colors.grey
                  : Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: _isApiCalling
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
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

// import 'dart:async';
// import 'dart:developer'; // For log
// import 'dart:math' hide log; // For Random number generation
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // For TextInputFormatter
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
// import 'package:intl/intl.dart'; // Import for date formatting
// import 'package:marquee/marquee.dart';
//
// import '../../BidService.dart'; // Import BidService
// import '../../components/AnimatedMessageBar.dart';
// import '../../components/BidConfirmationDialog.dart';
// import '../../components/BidFailureDialog.dart'; // For API failure dialog
// import '../../components/BidSuccessDialog.dart'; // For API success dialog
//
// class SpDpTpBoardScreen extends StatefulWidget {
//   final String screenTitle;
//   final int gameId;
//   final String gameType;
//   final bool openSessionStatus;
//
//   const SpDpTpBoardScreen({
//     Key? key,
//     required this.screenTitle,
//     required this.gameId,
//     required this.gameType,
//     required this.openSessionStatus,
//   }) : super(key: key);
//
//   @override
//   State<SpDpTpBoardScreen> createState() => _SpDpTpBoardScreenState();
// }
//
// class _SpDpTpBoardScreenState extends State<SpDpTpBoardScreen> {
//   final TextEditingController _pointsController = TextEditingController();
//   final TextEditingController _pannaController = TextEditingController();
//
//   bool _isSPSelected = false;
//   bool _isDPSelected = false;
//   bool _isTPSelected = false;
//
//   String? _selectedGameTypeOption = 'OPEN'; // Changed to OPEN/CLOSE options
//
//   List<Map<String, String>> _bids = [];
//   final Random _random = Random();
//
//   late int walletBalance; // Changed to int
//   late String accessToken;
//   late String registerId;
//   late String preferredLanguage;
//   bool accountStatus = false;
//   final GetStorage storage = GetStorage();
//
//   late BidService _bidService; // Declare BidService
//
//   final String _deviceId = 'test_device_id_flutter'; // Example device ID
//   final String _deviceName = 'test_device_name_flutter'; // Example device name
//
//   String? _messageToShow;
//   bool _isErrorForMessage = false;
//   Key _messageBarKey = UniqueKey();
//   Timer? _messageDismissTimer; // Timer for message bar dismissal
//
//   bool _isApiCalling = false; // State for API call in progress
//
//   @override
//   void initState() {
//     super.initState();
//     _bidService = BidService(storage); // Initialize BidService
//     _loadInitialData();
//     _setupStorageListeners();
//   }
//
//   Future<void> _loadInitialData() async {
//     accessToken = storage.read('accessToken') ?? '';
//     registerId = storage.read('registerId') ?? '';
//     accountStatus = storage.read('accountStatus') ?? false;
//     preferredLanguage = storage.read('selectedLanguage') ?? 'en';
//
//     final dynamic storedWalletBalance = storage.read('walletBalance');
//     if (storedWalletBalance is int) {
//       walletBalance = storedWalletBalance;
//     } else if (storedWalletBalance is String) {
//       walletBalance = int.tryParse(storedWalletBalance) ?? 0;
//     } else {
//       walletBalance = 0;
//     }
//   }
//
//   void _setupStorageListeners() {
//     storage.listenKey('accessToken', (value) {
//       if (mounted) setState(() => accessToken = value ?? '');
//     });
//     storage.listenKey('registerId', (value) {
//       if (mounted) setState(() => registerId = value ?? '');
//     });
//     storage.listenKey('accountStatus', (value) {
//       if (mounted) setState(() => accountStatus = value ?? false);
//     });
//     storage.listenKey('selectedLanguage', (value) {
//       if (mounted) setState(() => preferredLanguage = value ?? 'en');
//     });
//     storage.listenKey('walletBalance', (value) {
//       if (mounted) {
//         setState(() {
//           if (value is int) {
//             walletBalance = value;
//           } else if (value is String) {
//             walletBalance = int.tryParse(value) ?? 0;
//           } else {
//             walletBalance = 0;
//           }
//         });
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _pointsController.dispose();
//     _pannaController.dispose();
//     _messageDismissTimer?.cancel(); // Cancel timer on dispose
//     super.dispose();
//   }
//
//   void _showMessage(String message, {bool isError = false}) {
//     _messageDismissTimer?.cancel();
//     if (!mounted) return;
//     setState(() {
//       _messageToShow = message;
//       _isErrorForMessage = isError;
//       _messageBarKey = UniqueKey();
//     });
//     _messageDismissTimer = Timer(const Duration(seconds: 3), () {
//       _clearMessage();
//     });
//   }
//
//   void _clearMessage() {
//     if (mounted) {
//       setState(() {
//         _messageToShow = null;
//       });
//     }
//   }
//
//   int _getTotalPoints() {
//     return _bids.fold(
//       0,
//       (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
//     );
//   }
//
//   void _showConfirmationDialog() {
//     _clearMessage();
//     if (_isApiCalling) return; // Prevent multiple clicks during API call
//     if (_bids.isEmpty) {
//       _showMessage('Please add bids before submitting.', isError: true);
//       return;
//     }
//
//     int currentTotalPoints = _getTotalPoints();
//
//     if (walletBalance < currentTotalPoints) {
//       _showMessage(
//         'Insufficient wallet balance to place this bid.',
//         isError: true,
//       );
//       return;
//     }
//
//     final List<Map<String, String>> validBids = _bids
//         .where((bid) {
//           return bid['digit'] != null &&
//               bid['digit']!.isNotEmpty &&
//               bid['amount'] != null &&
//               bid['amount']!.isNotEmpty &&
//               bid['gameType'] != null &&
//               bid['gameType']!.isNotEmpty;
//         })
//         .map((bid) {
//           return {
//             'digit': bid['digit']!,
//             'points': bid['amount']!,
//             'type': bid['gameType']!,
//             'pana': bid['digit']!, // For SpDpTp, digit is the pana
//             'jodi': '', // Not applicable
//           };
//         })
//         .toList();
//
//     if (validBids.isEmpty) {
//       _showMessage('No valid bids to submit.', isError: true);
//       return;
//     }
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return BidConfirmationDialog(
//           gameTitle: widget.screenTitle,
//           bids: validBids,
//           totalBids: validBids.length,
//           totalBidsAmount: currentTotalPoints,
//           walletBalanceBeforeDeduction: walletBalance,
//           walletBalanceAfterDeduction: (walletBalance - currentTotalPoints)
//               .toString(),
//           gameDate: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameType,
//           onConfirm: () async {
//             // Navigator.pop(dialogContext); // Dismiss the confirmation dialog
//             setState(() {
//               _isApiCalling = true; // Set loading state
//             });
//             await _placeFinalBids();
//             if (mounted) {
//               setState(() {
//                 _isApiCalling = false; // Reset loading state
//               });
//             }
//           },
//         );
//       },
//     );
//   }
//
//   Future<bool> _placeFinalBids() async {
//     final Map<String, String> bidPayload = {};
//     int currentBatchTotalPoints =
//         _getTotalPoints(); // Total points of all bids added
//
//     if (accessToken.isEmpty || registerId.isEmpty) {
//       if (!mounted) return false;
//       await showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => const BidFailureDialog(
//           errorMessage: 'Authentication error. Please log in again.',
//         ),
//       );
//       return false;
//     }
//
//     // Populate bidPayload from _bids list
//     for (var bid in _bids) {
//       String digit = bid["digit"] ?? "";
//       String amount = bid["amount"] ?? "0";
//
//       if (digit.isNotEmpty && int.tryParse(amount) != null) {
//         bidPayload[digit] = amount;
//       }
//     }
//
//     if (bidPayload.isEmpty) {
//       if (!mounted) return false;
//       await showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) =>
//             const BidFailureDialog(errorMessage: 'No valid bids to submit.'),
//       );
//       return false;
//     }
//
//     try {
//       final result = await _bidService.placeFinalBids(
//         gameName: widget.screenTitle, // Use screenTitle as gameName
//         accessToken: accessToken,
//         registerId: registerId,
//         deviceId: _deviceId,
//         deviceName: _deviceName,
//         accountStatus: accountStatus,
//         bidAmounts: bidPayload,
//         selectedGameType: _selectedGameTypeOption!, // "OPEN" or "CLOSE"
//         gameId: widget.gameId,
//         gameType: widget.gameType, // This will be "SP", "DP", "TP"
//         totalBidAmount: currentBatchTotalPoints,
//       );
//
//       if (!mounted) return false;
//
//       if (result['status'] == true) {
//         await showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (_) => const BidSuccessDialog(),
//         );
//
//         final dynamic updatedBalanceRaw = result['updatedWalletBalance'];
//         final int updatedBalance =
//             int.tryParse(updatedBalanceRaw.toString()) ??
//             (walletBalance - currentBatchTotalPoints);
//         setState(() {
//           walletBalance = updatedBalance;
//           _bids.clear(); // Clear bids on successful submission
//         });
//         _bidService.updateWalletBalance(updatedBalance);
//         return true;
//       } else {
//         await showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (_) => BidFailureDialog(
//             errorMessage: result['msg'] ?? 'Something went wrong',
//           ),
//         );
//         return false;
//       }
//     } catch (e) {
//       log('Error during bid placement: $e', name: 'SpDpTpBoardScreenBidError');
//       if (!mounted) return false;
//
//       await showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => const BidFailureDialog(
//           errorMessage: 'An unexpected error occurred during bid submission.',
//         ),
//       );
//       return false;
//     }
//   }
//
//   bool _isValidSpPanna(String panna) {
//     if (panna.length != 3) return false;
//     Set<String> uniqueDigits = panna.split('').toSet();
//     return uniqueDigits.length == 3;
//   }
//
//   bool _isValidDpPanna(String panna) {
//     if (panna.length != 3) return false;
//     List<String> digits = panna.split('');
//     Map<String, int> freq = {};
//     for (var d in digits) {
//       freq[d] = (freq[d] ?? 0) + 1;
//     }
//     return freq.length == 2 && freq.values.contains(2);
//   }
//
//   bool _isValidTpPanna(String panna) {
//     if (panna.length != 3) return false;
//     return panna[0] == panna[1] && panna[1] == panna[2];
//   }
//
//   void _addTenRandomBids() {
//     _clearMessage();
//     if (_isApiCalling) return;
//
//     final points = _pointsController.text.trim();
//
//     int? parsedPoints = int.tryParse(points);
//     if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
//       _showMessage(
//         'Points must be between 10 and 1000 for random bids.',
//         isError: true,
//       );
//       return;
//     }
//
//     String gameCategory = '';
//     int selectedCount = 0;
//     if (_isSPSelected) {
//       gameCategory = 'SP';
//       selectedCount++;
//     }
//     if (_isDPSelected) {
//       gameCategory = 'DP';
//       selectedCount++;
//     }
//     if (_isTPSelected) {
//       gameCategory = 'TP';
//       selectedCount++;
//     }
//
//     if (selectedCount == 0) {
//       _showMessage(
//         'Please select SP, DP, or TP for random bids.',
//         isError: true,
//       );
//       return;
//     }
//     if (selectedCount > 1) {
//       _showMessage(
//         'Please select only one of SP, DP, or TP for random bids.',
//         isError: true,
//       );
//       return;
//     }
//
//     setState(() {
//       int bidsAdded = 0;
//       int maxAttemptsPerBid = 200;
//
//       while (bidsAdded < 10) {
//         String generatedPanna = '';
//         bool isValid = false;
//         int attempts = 0;
//
//         while (!isValid && attempts < maxAttemptsPerBid) {
//           attempts++;
//           String candidatePanna = _random
//               .nextInt(1000)
//               .toString()
//               .padLeft(3, '0');
//
//           if (gameCategory == 'SP') {
//             isValid = _isValidSpPanna(candidatePanna);
//           } else if (gameCategory == 'DP') {
//             isValid = _isValidDpPanna(candidatePanna);
//           } else if (gameCategory == 'TP') {
//             isValid = _isValidTpPanna(candidatePanna);
//           }
//
//           if (isValid &&
//               _bids.any(
//                 (bid) =>
//                     bid['digit'] == candidatePanna &&
//                     bid['gameType'] == gameCategory,
//               )) {
//             isValid =
//                 false; // Ensure generated panna is unique among current bids
//           }
//
//           if (isValid) {
//             generatedPanna = candidatePanna;
//           }
//         }
//
//         if (isValid) {
//           _bids.add({
//             "digit": generatedPanna,
//             "amount": points,
//             "gameType": gameCategory,
//           });
//           bidsAdded++;
//         } else if (attempts >= maxAttemptsPerBid) {
//           _showMessage(
//             'Could not generate 10 unique $gameCategory bids. Added $bidsAdded bids.',
//             isError: true,
//           );
//           break; // Exit if unable to generate unique bids after many attempts
//         }
//       }
//       if (bidsAdded > 0) {
//         _showMessage('Added $bidsAdded random bids of type $gameCategory.');
//       }
//
//       _pannaController.clear();
//       _pointsController.clear();
//     });
//   }
//
//   void _removeBid(int index) {
//     _clearMessage();
//     if (_isApiCalling) return;
//
//     setState(() {
//       final removedBid = _bids.removeAt(index);
//       _showMessage(
//         'Removed bid: ${removedBid['gameType']} ${removedBid['digit']}.',
//       );
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F5F5),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 1,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           widget.screenTitle,
//           style: GoogleFonts.poppins(
//             color: Colors.black,
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         actions: [
//           const Icon(
//             Icons.account_balance_wallet_outlined,
//             color: Colors.black,
//           ),
//           const SizedBox(width: 6),
//           Center(
//             child: Text(
//               walletBalance.toString(), // Display walletBalance as String
//               style: const TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//         ],
//       ),
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               Padding(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16.0,
//                   vertical: 12.0,
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Select Game Type',
//                           style: GoogleFonts.poppins(fontSize: 16),
//                         ),
//                         SizedBox(
//                           width: 150,
//                           height: 40,
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 12),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               border: Border.all(color: Colors.black),
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                             child: DropdownButtonHideUnderline(
//                               child: DropdownButton<String>(
//                                 isExpanded: true,
//                                 value: _selectedGameTypeOption,
//                                 icon: const Icon(
//                                   Icons.keyboard_arrow_down,
//                                   color: Colors.orange,
//                                 ),
//                                 onChanged: _isApiCalling
//                                     ? null
//                                     : (String? newValue) {
//                                         setState(() {
//                                           _selectedGameTypeOption = newValue;
//                                           _clearMessage();
//                                         });
//                                       },
//                                 items: <String>['OPEN', 'CLOSE']
//                                     .map<DropdownMenuItem<String>>((
//                                       String value,
//                                     ) {
//                                       return DropdownMenuItem<String>(
//                                         value: value,
//                                         child: SizedBox(
//                                           width: 150,
//                                           height: 20,
//                                           child: Marquee(
//                                             text: value == 'OPEN'
//                                                 ? '${widget.screenTitle.split(' - ')[0]} OPEN'
//                                                 : '${widget.screenTitle.split(' - ')[0]} CLOSE',
//                                             style: GoogleFonts.poppins(
//                                               fontSize: 14,
//                                             ),
//                                             scrollAxis: Axis.horizontal,
//                                             blankSpace: 40.0,
//                                             velocity: 30.0,
//                                             pauseAfterRound: const Duration(
//                                               seconds: 1,
//                                             ),
//                                             startPadding: 10.0,
//                                             accelerationDuration:
//                                                 const Duration(seconds: 1),
//                                             accelerationCurve: Curves.linear,
//                                             decelerationDuration:
//                                                 const Duration(
//                                                   milliseconds: 500,
//                                                 ),
//                                             decelerationCurve: Curves.easeOut,
//                                           ),
//                                         ),
//                                       );
//                                     })
//                                     .toList(),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Row(
//                             children: [
//                               Checkbox(
//                                 value: _isSPSelected,
//                                 onChanged: _isApiCalling
//                                     ? null
//                                     : (bool? value) {
//                                         setState(() {
//                                           _isSPSelected = value!;
//                                           if (value) {
//                                             _isDPSelected = false;
//                                             _isTPSelected = false;
//                                           }
//                                           _clearMessage();
//                                         });
//                                       },
//                                 activeColor: Colors.orange,
//                               ),
//                               Text(
//                                 'SP',
//                                 style: GoogleFonts.poppins(fontSize: 16),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Expanded(
//                           child: Row(
//                             children: [
//                               Checkbox(
//                                 value: _isDPSelected,
//                                 onChanged: _isApiCalling
//                                     ? null
//                                     : (bool? value) {
//                                         setState(() {
//                                           _isDPSelected = value!;
//                                           if (value) {
//                                             _isSPSelected = false;
//                                             _isTPSelected = false;
//                                           }
//                                           _clearMessage();
//                                         });
//                                       },
//                                 activeColor: Colors.orange,
//                               ),
//                               Text(
//                                 'DP',
//                                 style: GoogleFonts.poppins(fontSize: 16),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Expanded(
//                           child: Row(
//                             children: [
//                               Checkbox(
//                                 value: _isTPSelected,
//                                 onChanged: _isApiCalling
//                                     ? null
//                                     : (bool? value) {
//                                         setState(() {
//                                           _isTPSelected = value!;
//                                           if (value) {
//                                             _isSPSelected = false;
//                                             _isDPSelected = false;
//                                           }
//                                           _clearMessage();
//                                         });
//                                       },
//                                 activeColor: Colors.orange,
//                               ),
//                               Text(
//                                 'TP',
//                                 style: GoogleFonts.poppins(fontSize: 16),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         const Text(
//                           'Enter Single Digits:',
//                           style: TextStyle(fontSize: 16),
//                         ),
//                         SizedBox(
//                           width: 150,
//                           height: 40,
//                           child: TextField(
//                             cursorColor: Colors.orange,
//                             controller: _pannaController,
//                             keyboardType: TextInputType.number,
//                             inputFormatters: [
//                               LengthLimitingTextInputFormatter(1),
//                               FilteringTextInputFormatter.digitsOnly,
//                             ],
//                             decoration: const InputDecoration(
//                               hintText: 'Bid Digits',
//                               contentPadding: EdgeInsets.symmetric(
//                                 horizontal: 12,
//                               ),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.all(
//                                   Radius.circular(20),
//                                 ),
//                                 borderSide: BorderSide(color: Colors.black),
//                               ),
//                               enabledBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.all(
//                                   Radius.circular(20),
//                                 ),
//                                 borderSide: BorderSide(color: Colors.black),
//                               ),
//                               focusedBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.all(
//                                   Radius.circular(20),
//                                 ),
//                                 borderSide: BorderSide(
//                                   color: Colors.orange,
//                                   width: 2,
//                                 ),
//                               ),
//                             ),
//                             onTap: _clearMessage,
//                             enabled: !_isApiCalling, // Disable during API call
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         const Text(
//                           'Enter Points:',
//                           style: TextStyle(fontSize: 16),
//                         ),
//                         SizedBox(
//                           width: 150,
//                           height: 40,
//                           child: TextField(
//                             cursorColor: Colors.orange,
//                             controller: _pointsController,
//                             keyboardType: TextInputType.number,
//                             inputFormatters: [
//                               FilteringTextInputFormatter.digitsOnly,
//                               LengthLimitingTextInputFormatter(4),
//                             ],
//                             decoration: const InputDecoration(
//                               hintText: 'Enter Amount',
//                               contentPadding: EdgeInsets.symmetric(
//                                 horizontal: 12,
//                               ),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.all(
//                                   Radius.circular(20),
//                                 ),
//                                 borderSide: BorderSide(color: Colors.black),
//                               ),
//                               enabledBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.all(
//                                   Radius.circular(20),
//                                 ),
//                                 borderSide: BorderSide(color: Colors.black),
//                               ),
//                               focusedBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.all(
//                                   Radius.circular(20),
//                                 ),
//                                 borderSide: BorderSide(
//                                   color: Colors.orange,
//                                   width: 2,
//                                 ),
//                               ),
//                             ),
//                             onTap: _clearMessage,
//                             enabled: !_isApiCalling, // Disable during API call
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 15),
//                     Align(
//                       alignment: Alignment.centerRight,
//                       child: SizedBox(
//                         width: 150,
//                         height: 45,
//                         child: ElevatedButton(
//                           onPressed: _isApiCalling ? null : _addTenRandomBids,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: _isApiCalling
//                                 ? Colors.grey
//                                 : Colors.orange,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(6),
//                             ),
//                           ),
//                           child: _isApiCalling
//                               ? const CircularProgressIndicator(
//                                   color: Colors.white,
//                                   strokeWidth: 2,
//                                 )
//                               : Text(
//                                   "ADD",
//                                   textAlign: TextAlign.center,
//                                   style: GoogleFonts.poppins(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.w600,
//                                     letterSpacing: 0.5,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const Divider(thickness: 1),
//               if (_bids.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16.0,
//                     vertical: 8.0,
//                   ),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           'Digit',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         child: Text(
//                           'Amount',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         child: Text(
//                           'Game Type',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 48),
//                     ],
//                   ),
//                 ),
//               if (_bids.isNotEmpty) const Divider(thickness: 1),
//               Expanded(
//                 child: _bids.isEmpty
//                     ? Center(
//                         child: Text(
//                           'No Bids Placed',
//                           style: GoogleFonts.poppins(color: Colors.grey),
//                         ),
//                       )
//                     : ListView.builder(
//                         itemCount: _bids.length,
//                         itemBuilder: (context, index) {
//                           final bid = _bids[index];
//                           return Container(
//                             margin: const EdgeInsets.symmetric(
//                               horizontal: 10,
//                               vertical: 4,
//                             ),
//                             padding: const EdgeInsets.all(8),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(8),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.grey.withOpacity(0.2),
//                                   spreadRadius: 1,
//                                   blurRadius: 3,
//                                   offset: const Offset(0, 2),
//                                 ),
//                               ],
//                             ),
//                             child: Row(
//                               children: [
//                                 Expanded(
//                                   child: Text(
//                                     bid['digit']!,
//                                     style: GoogleFonts.poppins(),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   child: Text(
//                                     bid['amount']!,
//                                     style: GoogleFonts.poppins(),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   child: Text(
//                                     '${bid['gameType']}',
//                                     style: GoogleFonts.poppins(),
//                                   ),
//                                 ),
//                                 IconButton(
//                                   icon: const Icon(
//                                     Icons.delete,
//                                     color: Colors.red,
//                                   ),
//                                   onPressed: _isApiCalling
//                                       ? null
//                                       : () => _removeBid(index),
//                                 ),
//                               ],
//                             ),
//                           );
//                         },
//                       ),
//               ),
//               if (_bids.isNotEmpty) _buildBottomBar(),
//             ],
//           ),
//           if (_messageToShow != null)
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               child: AnimatedMessageBar(
//                 key: _messageBarKey,
//                 message: _messageToShow!,
//                 isError: _isErrorForMessage,
//                 onDismissed: _clearMessage,
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildBottomBar() {
//     int totalBids = _bids.length;
//     int totalPoints = _getTotalPoints();
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
//                 style: GoogleFonts.poppins(
//                   fontSize: 14,
//                   color: Colors.grey[700],
//                 ),
//               ),
//               Text(
//                 '$totalBids',
//                 style: GoogleFonts.poppins(
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
//                 style: GoogleFonts.poppins(
//                   fontSize: 14,
//                   color: Colors.grey[700],
//                 ),
//               ),
//               Text(
//                 '$totalPoints',
//                 style: GoogleFonts.poppins(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           ElevatedButton(
//             onPressed: _isApiCalling || _bids.isEmpty
//                 ? null
//                 : _showConfirmationDialog,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _isApiCalling || _bids.isEmpty
//                   ? Colors.grey
//                   : Colors.orange,
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               elevation: 3,
//             ),
//             child: _isApiCalling
//                 ? const CircularProgressIndicator(
//                     color: Colors.white,
//                     strokeWidth: 2,
//                   )
//                 : Text(
//                     'SUBMIT',
//                     style: GoogleFonts.poppins(
//                       color: Colors.white,
//                       fontSize: 16,
//                     ),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }
