import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../StarlineBidService.dart';

class StarlineSingleDigitBetScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType;
  final int gameId;
  final String gameName;
  final bool selectionStatus;

  const StarlineSingleDigitBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
    required this.selectionStatus,
  });

  @override
  State<StarlineSingleDigitBetScreen> createState() =>
      _StarlineSingleDigitBetScreenState();
}

class _StarlineSingleDigitBetScreenState
    extends State<StarlineSingleDigitBetScreen> {
  final String selectedGameBetType = 'Open';

  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();
  final List<String> digitOptions = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ];
  List<String> filteredDigitOptions = [];
  bool _isDigitSuggestionsVisible = false;

  List<Map<String, String>> addedEntries = [];
  late GetStorage storage = GetStorage();
  late StarlineBidService _bidService;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance;
  bool _isApiCalling = false;

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  final UserController userController = Get.put(UserController());

  @override
  void initState() {
    super.initState();
    _bidService = StarlineBidService(storage);
    _loadInitialData();
    digitController.addListener(_onDigitChanged);
  }

  void _onDigitChanged() {
    final text = digitController.text;
    if (text.isEmpty) {
      setState(() {
        filteredDigitOptions = [];
        _isDigitSuggestionsVisible = false;
      });
      return;
    }

    setState(() {
      filteredDigitOptions = digitOptions
          .where((option) => option.startsWith(text))
          .toList();
      _isDigitSuggestionsVisible = filteredDigitOptions.isNotEmpty;
    });
  }

  Future<void> _loadInitialData() async {
    registerId = storage.read('registerId') ?? '';
    accountStatus = storage.read('accountStatus') ?? false;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    double walletBalanceDouble = double.parse(
      userController.walletBalance.value,
    );
    walletBalance = walletBalanceDouble.toInt();
  }

  @override
  void dispose() {
    digitController.removeListener(_onDigitChanged);
    digitController.dispose();
    pointsController.dispose();
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
    _messageDismissTimer = Timer(const Duration(seconds: 3), _clearMessage);
  }

  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
    _messageDismissTimer?.cancel();
  }

  void _addEntry() {
    _clearMessage();
    if (_isApiCalling) return;

    final digit = digitController.text.trim();
    final points = pointsController.text.trim();

    if (digit.isEmpty) {
      _showMessage('Please enter a digit.', isError: true);
      return;
    }

    if (digit.length != 1 || !digitOptions.contains(digit)) {
      _showMessage('Please enter a valid single digit (0-9).', isError: true);
      return;
    }

    if (points.isEmpty) {
      _showMessage('Please enter an Amount.', isError: true);
      return;
    }

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    int currentTotalPoints = _getTotalPoints();
    int pointsForThisBid = parsedPoints;

    final existingEntryIndex = addedEntries.indexWhere(
      (entry) =>
          entry['digit'] == digit && entry['type'] == selectedGameBetType,
    );

    if (existingEntryIndex != -1) {
      currentTotalPoints -=
          (int.tryParse(addedEntries[existingEntryIndex]['points']!) ?? 0);
    }

    int totalPointsWithNewBid = currentTotalPoints + pointsForThisBid;

    if (totalPointsWithNewBid > walletBalance) {
      _showMessage(
        'Insufficient wallet balance to place these bids.',
        isError: true,
      );
      return;
    }

    setState(() {
      if (existingEntryIndex != -1) {
        addedEntries[existingEntryIndex]['points'] = pointsForThisBid
            .toString();
        _showMessage('Updated points for Digit: $digit.');
      } else {
        addedEntries.add({
          "digit": digit,
          "points": points,
          "type": selectedGameBetType,
        });
        _showMessage('Added bid: Digit $digit, Points $points.');
      }
      digitController.clear();
      pointsController.clear();
    });
  }

  void _removeEntry(int index) {
    _clearMessage();
    if (_isApiCalling) return;
    setState(() {
      final removedEntry = addedEntries[index];
      addedEntries.removeAt(index);
      _showMessage('Removed bid: Digit ${removedEntry['digit']}.');
    });
  }

  int _getTotalPoints() {
    return addedEntries.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  void _showConfirmationDialog() {
    FocusScope.of(context).unfocus(); // Close keyboard
    _clearMessage();

    if (addedEntries.isEmpty) {
      _showMessage(
        'Please add at least one bid before submitting.',
        isError: true,
      );
      return;
    }

    final bidsForConfirmation = addedEntries
        .map((entry) => {'digit': entry['digit']!, 'points': entry['points']!})
        .toList();

    final int totalPointsForConfirmation = bidsForConfirmation.fold<int>(
      0,
      (sum, bid) => sum + int.tryParse(bid['points'] ?? '0')!,
    );

    final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.title,
          gameDate: formattedDate,
          bids: bidsForConfirmation,
          totalBids: bidsForConfirmation.length,
          totalBidsAmount: totalPointsForConfirmation,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction:
              (walletBalance - totalPointsForConfirmation).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameCategoryType,
          onConfirm: () async {
            Navigator.of(
              dialogContext,
            ).pop(); // ✅ Close confirmation dialog first
            await Future.delayed(
              const Duration(milliseconds: 100),
            ); // ✅ Avoid render issues
            await _placeFinalBids(); // ✅ Then submit the bids
          },
        );
      },
    );
  }

  Future<void> _placeFinalBids() async {
    if (!mounted) return;

    // Start API call
    setState(() {
      _isApiCalling = true;
    });
    _clearMessage();
    FocusScope.of(context).unfocus(); // Dismiss keyboard if open

    if (addedEntries.isEmpty) {
      _showMessage('No bids to submit.', isError: true);
      if (!mounted) return;
      setState(() {
        _isApiCalling = false;
      });
      return;
    }

    final String? accessToken = storage.read('accessToken');
    final String? deviceId = storage.read('deviceId');
    final String? deviceName = storage.read('deviceName');

    if (accessToken == null || deviceId == null || deviceName == null) {
      _showMessage('Authentication error. Please log in again.', isError: true);
      if (!mounted) return;
      setState(() {
        _isApiCalling = false;
      });
      return;
    }

    Map<String, String> bidAmounts = {};
    int totalBidAmount = 0;
    for (var bid in addedEntries) {
      final digit = bid['digit'];
      final points = bid['points'];
      if (digit != null && points != null) {
        bidAmounts[digit] = points;
        totalBidAmount += int.tryParse(points) ?? 0;
      }
    }

    try {
      final response = await _bidService.placeFinalBids(
        gameName: widget.title,
        accessToken: accessToken,
        registerId: registerId,
        deviceId: deviceId,
        deviceName: deviceName,
        accountStatus: accountStatus,
        bidAmounts: bidAmounts,
        selectedGameType: selectedGameBetType,
        gameId: widget.gameId,
        gameType: widget.gameCategoryType,
        totalBidAmount: totalBidAmount,
      );

      if (!mounted) return;

      if (response['status'] == true) {
        final int newBalance = walletBalance - totalBidAmount;

        setState(() {
          walletBalance = newBalance;
          addedEntries.clear();
          digitController.clear();
          pointsController.clear();
        });

        await _bidService.updateWalletBalance(newBalance);

        _showMessage('All bids submitted successfully!');

        // Show success dialog AFTER state is updated
        if (!mounted) return;
        await Future.delayed(
          const Duration(milliseconds: 150),
        ); // Small delay to avoid build issues
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const BidSuccessDialog(),
        );
      } else {
        String errorMessage = response['msg'] ?? 'Unknown error occurred.';
        _showMessage(errorMessage, isError: true);

        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 150));
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => BidFailureDialog(errorMessage: errorMessage),
        );
      }
    } catch (e) {
      log("Bid submission error: $e");
      _showMessage(
        'An unexpected error occurred: ${e.toString()}',
        isError: true,
      );

      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 150));
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            BidFailureDialog(errorMessage: 'An unexpected error occurred: $e'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApiCalling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isApiCalling,
      child: Scaffold(
        backgroundColor: Colors.grey.shade200,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.grey.shade300,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: _isApiCalling ? Colors.grey : Colors.black,
            ),
            onPressed: _isApiCalling ? null : () => Navigator.pop(context),
          ),
          title: Text(
            widget.title,
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 15,
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
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        _inputRow(
                          "Enter Single Digit:",
                          _buildDigitInputField(),
                        ),
                        const SizedBox(height: 12),
                        _inputRow(
                          "Enter Points:",
                          _buildTextField(
                            pointsController,
                            "Enter Amount",
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isApiCalling
                                  ? Colors.grey
                                  : Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: _isApiCalling ? null : _addEntry,
                            child: _isApiCalling
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
                                    "ADD BID",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                  const Divider(thickness: 1),
                  if (addedEntries.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Digit",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "Amount",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  if (addedEntries.isNotEmpty) const Divider(thickness: 1),
                  Expanded(
                    child: addedEntries.isEmpty
                        ? const Center(child: Text("No data added yet"))
                        : ListView.builder(
                            itemCount: addedEntries.length,
                            itemBuilder: (_, index) {
                              final entry = addedEntries[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry['digit']!,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry['points']!,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    const SizedBox(width: 48),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: _isApiCalling
                                          ? null
                                          : () => _removeEntry(index),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  if (addedEntries.isNotEmpty) _buildBottomBar(),
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
      ),
    );
  }

  Widget _inputRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(flex: 3, child: field),
        ],
      ),
    );
  }

  Widget _buildDigitInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 35,
          child: TextFormField(
            controller: digitController,
            cursorColor: Colors.orange,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(fontSize: 14),
            inputFormatters: [
              LengthLimitingTextInputFormatter(1),
              FilteringTextInputFormatter.digitsOnly,
            ],
            onTap: _clearMessage,
            enabled: !_isApiCalling,
            decoration: InputDecoration(
              hintText: "Enter Digit",
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 0,
              ),
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
                borderSide: const BorderSide(color: Colors.orange, width: 2),
              ),
            ),
          ),
        ),
        if (_isDigitSuggestionsVisible)
          Container(
            width: 150,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: filteredDigitOptions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  title: Text(filteredDigitOptions[index]),
                  onTap: () {
                    setState(() {
                      digitController.text = filteredDigitOptions[index];
                      _isDigitSuggestionsVisible = false;
                      FocusScope.of(context).unfocus();
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      width: 150,
      height: 35,
      child: TextFormField(
        controller: controller,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: inputFormatters,
        onTap: _clearMessage,
        enabled: !_isApiCalling,
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
            borderSide: const BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.orange, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    int totalBids = addedEntries.length;
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
            onPressed: (_isApiCalling || addedEntries.isEmpty)
                ? null
                : _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: (_isApiCalling || addedEntries.isEmpty)
                  ? Colors.grey
                  : Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: _isApiCalling
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
