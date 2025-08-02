import 'dart:async';
import 'dart:developer';

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

class StarlineDPMotorsScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType;
  final int gameId;
  final String gameName;

  const StarlineDPMotorsScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
  });

  @override
  State<StarlineDPMotorsScreen> createState() => _StarlineDPMotorsScreenState();
}

class _StarlineDPMotorsScreenState extends State<StarlineDPMotorsScreen> {
  // Game type is now fixed to 'Open'
  final String selectedGameBetType = "Open";

  final TextEditingController bidController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  List<String> digitOptions = [
    "112",
    "113",
    "114",
    "115",
    "116",
    "117",
    "118",
    "119",
    "122",
    "133",
    "144",
    "155",
    "166",
    "177",
    "188",
    "199",
    "223",
    "224",
    "225",
    "226",
    "227",
    "228",
    "229",
    "233",
    "244",
    "255",
    "266",
    "277",
    "288",
    "299",
    "334",
    "335",
    "336",
    "337",
    "338",
    "339",
    "344",
    "355",
    "366",
    "377",
    "388",
    "399",
    "445",
    "446",
    "447",
    "448",
    "449",
    "455",
    "466",
    "477",
    "488",
    "499",
    "556",
    "557",
    "558",
    "559",
    "566",
    "577",
    "588",
    "599",
    "667",
    "668",
    "669",
    "677",
    "688",
    "699",
    "778",
    "779",
    "788",
    "799",
    "889",
    "899",
    "110",
    "220",
    "330",
    "440",
    "550",
    "660",
    "770",
    "880",
    "990",
    "133",
    "144",
    "155",
    "166",
    "177",
    "188",
    "199",
    "233",
    "244",
    "255",
    "266",
    "277",
    "288",
    "299",
    "344",
    "355",
    "366",
    "377",
    "388",
    "399",
    "455",
    "466",
    "477",
    "488",
    "499",
    "566",
    "577",
    "588",
    "599",
    "677",
    "688",
    "699",
    "788",
    "799",
    "899",
  ];
  List<String> filteredDigitOptions = [];
  bool _isDigitSuggestionsVisible = false;

  List<Map<String, String>> addedEntries = [];
  late GetStorage storage;
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance;

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
    storage = GetStorage();
    _bidService = BidService(storage);
    _loadInitialData();
    _setupStorageListeners();
    bidController.addListener(_onDigitChanged);
  }

  void _onDigitChanged() {
    final query = bidController.text.trim();
    if (query.isNotEmpty) {
      setState(() {
        filteredDigitOptions = digitOptions
            .where((digit) => digit.startsWith(query))
            .toList();
        _isDigitSuggestionsVisible = filteredDigitOptions.isNotEmpty;
      });
    } else {
      setState(() {
        filteredDigitOptions = [];
        _isDigitSuggestionsVisible = false;
      });
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
    bidController.removeListener(_onDigitChanged);
    bidController.dispose();
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

  void _addEntry() {
    _clearMessage();
    if (_isApiCalling) return;

    final digit = bidController.text.trim();
    final amount = pointsController.text.trim();

    if (digit.isEmpty) {
      _showMessage('Please enter a 3-digit number.', isError: true);
      return;
    }

    if (digit.length != 3 || int.tryParse(digit) == null) {
      _showMessage('Please enter a valid 3-digit number.', isError: true);
      return;
    }

    // Check if the entered digit is a valid DP number
    final Set<String> uniqueDigits = digit.split('').toSet();
    final isDPMotor =
        uniqueDigits.length == 2 &&
        digit
            .split('')
            .any((d) => digit.split('').where((e) => e == d).length == 2);

    if (!isDPMotor || !digitOptions.contains(digit)) {
      _showMessage(
        'Invalid 3-digit number. Not a valid Double Patti.',
        isError: true,
      );
      return;
    }

    if (amount.isEmpty) {
      _showMessage('Please enter an Amount.', isError: true);
      return;
    }

    int? parsedAmount = int.tryParse(amount);
    if (parsedAmount == null || parsedAmount < 10 || parsedAmount > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    final existingIndex = addedEntries.indexWhere(
      (entry) =>
          entry['digit'] == digit && entry['type'] == selectedGameBetType,
    );

    setState(() {
      if (existingIndex != -1) {
        final currentAmount = int.parse(addedEntries[existingIndex]['amount']!);
        addedEntries[existingIndex]['amount'] = (currentAmount + parsedAmount)
            .toString();
        _showMessage(
          'Updated points for Double Patti: $digit, Type: $selectedGameBetType.',
        );
      } else {
        addedEntries.add({
          "digit": digit,
          "amount": amount,
          "type": selectedGameBetType,
          "gameType": widget.gameCategoryType,
        });
        _showMessage(
          'Added bid: Double Patti $digit, Points $amount, Type $selectedGameBetType.',
        );
      }
      bidController.clear();
      pointsController.clear();
      _isDigitSuggestionsVisible = false;
    });
  }

  void _removeEntry(int index) {
    _clearMessage();
    if (_isApiCalling) return;

    setState(() {
      final removedEntry = addedEntries[index];
      addedEntries.removeAt(index);
      _showMessage(
        'Removed bid: Double Patti ${removedEntry['digit']}, Type ${removedEntry['type']}.',
      );
    });
  }

  int _getTotalPoints() {
    return addedEntries.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
    );
  }

  int _getTotalPointsForSelectedGameType() {
    return addedEntries
        .where(
          (entry) =>
              (entry["type"] ?? "").toUpperCase() ==
              selectedGameBetType.toUpperCase(),
        )
        .fold(
          0,
          (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
        );
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    final int totalPointsForCurrentType = _getTotalPointsForSelectedGameType();

    if (totalPointsForCurrentType == 0) {
      _showMessage(
        'No bids added for the selected game type to submit.',
        isError: true,
      );
      return;
    }

    if (walletBalance < totalPointsForCurrentType) {
      _showMessage(
        'Insufficient wallet balance for selected game type.',
        isError: true,
      );
      return;
    }

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    final List<Map<String, String>> bidsToShowInDialog = addedEntries
        .where(
          (entry) =>
              (entry["type"] ?? "").toUpperCase() ==
              selectedGameBetType.toUpperCase(),
        )
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.gameName,
          gameDate: formattedDate,
          bids: bidsToShowInDialog.map((bid) {
            return {
              "digit": bid['digit']!,
              "points": bid['amount']!,
              "type": "${bid['gameType']} (${bid['type']})",
              "pana": bid['digit']!,
              "jodi": "",
            };
          }).toList(),
          totalBids: bidsToShowInDialog.length,
          totalBidsAmount: totalPointsForCurrentType,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction:
              (walletBalance - totalPointsForCurrentType).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameCategoryType,
          onConfirm: () async {
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
    // Initial check for mounted state
    if (!mounted) return false;

    final Map<String, String> bidPayload = {};
    int currentBatchTotalPoints = 0;

    for (var entry in addedEntries) {
      if ((entry["type"] ?? "").toUpperCase() ==
          selectedGameBetType.toUpperCase()) {
        String digit = entry["digit"] ?? "";
        String amount = entry["amount"] ?? "0";

        if (digit.isNotEmpty && int.tryParse(amount) != null) {
          bidPayload[digit] = amount;
          currentBatchTotalPoints += int.parse(amount);
        }
      }
    }

    // Handle case where there are no valid bids
    if (bidPayload.isEmpty) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'No valid bids for the selected game type.',
        ),
      );
      return false;
    }

    // Handle authentication errors
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

    try {
      // Attempt to place the bids
      final result = await _bidService.placeFinalBids(
        gameName: widget.gameName,
        accessToken: accessToken,
        registerId: registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: accountStatus,
        bidAmounts: bidPayload,
        selectedGameType: selectedGameBetType,
        gameId: widget.gameId,
        gameType: widget.gameCategoryType,
        totalBidAmount: currentBatchTotalPoints,
      );

      // CRITICAL: Check `mounted` again after the network call
      if (!mounted) return false;

      // Check the result from the API
      if (result['status'] == true) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );

        // Handle successful bid logic
        final dynamic updatedBalanceRaw = result['updatedWalletBalance'];
        final int updatedBalance =
            int.tryParse(updatedBalanceRaw.toString()) ??
            (walletBalance - currentBatchTotalPoints);

        // Update wallet balance and bid list
        setState(() {
          walletBalance = updatedBalance;
          addedEntries.removeWhere(
            (element) =>
                (element["type"] ?? "").toUpperCase() ==
                selectedGameBetType.toUpperCase(),
          );
        });

        // Update wallet balance in service
        await _bidService.updateWalletBalance(updatedBalance);

        return true; // Return true on success
      } else {
        // Show failure dialog with a specific error message
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(
            errorMessage: result['msg'] ?? 'Something went wrong',
          ),
        );
        return false; // Return false on API failure
      }
    } catch (e) {
      // Log the error and show a generic failure dialog
      log(
        'Error during bid placement: $e',
        name: 'StarlineDPMotorsScreenBidError',
      );
      if (!mounted) return false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'An unexpected error occurred during bid submission.',
        ),
      );
      return false; // Return false on exception
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey.shade300,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
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
      body: Stack(
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
                    _inputRow("Enter 3-Digit Number:", _buildBidInputField()),
                    if (_isDigitSuggestionsVisible &&
                        filteredDigitOptions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 2,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredDigitOptions.length,
                          itemBuilder: (context, index) {
                            final suggestion = filteredDigitOptions[index];
                            return ListTile(
                              title: Text(suggestion),
                              onTap: () {
                                setState(() {
                                  bidController.text = suggestion;
                                  _isDigitSuggestionsVisible = false;
                                  bidController.selection =
                                      TextSelection.fromPosition(
                                        TextPosition(
                                          offset: bidController.text.length,
                                        ),
                                      );
                                });
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    _inputRow(
                      "Enter Points:",
                      _buildTextField(
                        pointsController,
                        "Enter Amount",
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: _isApiCalling ? null : _addEntry,
                        child: _isApiCalling
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
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
                      Expanded(
                        child: Text(
                          "Game Type",
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
                                    entry['amount']!,
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${entry['gameType']} (${entry['type']})',
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
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

  Widget _buildStaticGameType() {
    return SizedBox(
      width: 150,
      height: 35,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black54),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          selectedGameBetType,
          style: GoogleFonts.poppins(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildBidInputField() {
    return SizedBox(
      width: double.infinity,
      height: 35,
      child: TextFormField(
        controller: bidController,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: [
          LengthLimitingTextInputFormatter(3),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: () {
          _clearMessage();
          _onDigitChanged();
        },
        onChanged: (value) {
          _onDigitChanged();
        },
        enabled: !_isApiCalling,
        decoration: InputDecoration(
          hintText: "Enter 3-Digit Number",
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
            onPressed:
                (_isApiCalling || _getTotalPointsForSelectedGameType() == 0)
                ? null
                : _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  (_isApiCalling || _getTotalPointsForSelectedGameType() == 0)
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
