import 'dart:async';
import 'dart:developer'; // For log() function

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:new_sara/BidService.dart'; // Ensure this path is correct

import '../../../Helper/UserController.dart';
import '../../../components/AnimatedMessageBar.dart';
import '../../../components/BidConfirmationDialog.dart';
import '../../../components/BidFailureDialog.dart';
import '../../../components/BidSuccessDialog.dart';

class DoublePanaBetScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType;
  final int gameId;
  final String gameName;
  final bool selectionStatus;

  const DoublePanaBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
    required this.selectionStatus,
  });

  @override
  State<DoublePanaBetScreen> createState() => _DoublePanaBetScreenState();
}

class _DoublePanaBetScreenState extends State<DoublePanaBetScreen> {
  List<String> gameTypesOptions = [];

  // Initialize selectedGameBetType to avoid LateInitializationError
  String selectedGameBetType = "Open";

  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  List<String> doublePanaOptions = [
    "100",
    "110",
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
    "200",
    "220",
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
    "300",
    "330",
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
    "400",
    "440",
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
    "500",
    "550",
    "556",
    "557",
    "558",
    "559",
    "566",
    "577",
    "588",
    "599",
    "600",
    "660",
    "667",
    "668",
    "669",
    "677",
    "688",
    "699",
    "700",
    "770",
    "778",
    "779",
    "788",
    "799",
    "800",
    "880",
    "889",
    "899",
    "900",
    "990",
  ];
  List<String> filteredDigitOptions = [];
  bool _isDigitSuggestionsVisible = false;

  List<Map<String, String>> addedEntries = [];
  late GetStorage storage;
  late BidService _bidService;

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
  Timer? _messageDismissTimer;

  bool _isApiCalling = false;

  final UserController userController = Get.put(UserController());

  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _bidService = BidService(storage);
    _loadInitialData();
    double walletBalanceDouble = double.parse(
      userController.walletBalance.value,
    );
    walletBalance = walletBalanceDouble.toInt();

    _setInitialGameTypeOptions();
    log(
      'DoublePanaBetScreen: initState called. Initial selectionStatus: ${widget.selectionStatus}, gameTypesOptions: $gameTypesOptions, selectedGameBetType: $selectedGameBetType',
    );
    digitController.addListener(_onDigitChanged);
  }

  void _setInitialGameTypeOptions() {
    setState(() {
      // NEW LOGIC BASED ON YOUR REQUEST:
      if (widget.selectionStatus == false) {
        // If selectionStatus is false
        gameTypesOptions = ["Close"]; // Show only "Close"
        log(
          'DoublePanaBetScreen: selectionStatus is FALSE, gameTypesOptions set to: $gameTypesOptions',
        );
      } else {
        // Else (if selectionStatus is true)
        gameTypesOptions = ["Open", "Close"]; // Show both "Open" and "Close"
        log(
          'DoublePanaBetScreen: selectionStatus is TRUE, gameTypesOptions set to: $gameTypesOptions',
        );
      }

      // Ensure selectedGameBetType is always one of the valid options after gameTypesOptions changes
      // This handles cases where the previously selected type might no longer be available.
      if (!gameTypesOptions.contains(selectedGameBetType)) {
        selectedGameBetType =
            gameTypesOptions.first; // Set to the first available option
        log(
          'DoublePanaBetScreen: selectedGameBetType reset to: $selectedGameBetType as previous was invalid.',
        );
      } else {
        log(
          'DoublePanaBetScreen: selectedGameBetType is already valid: $selectedGameBetType',
        );
      }
    });
  }

  void _onDigitChanged() {
    final query = digitController.text.trim();
    if (query.isNotEmpty) {
      setState(() {
        filteredDigitOptions = doublePanaOptions
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
    accountStatus = userController.accountStatus.value;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is int) {
      walletBalance = storedWalletBalance;
    } else if (storedWalletBalance is String) {
      walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else {
      walletBalance = 0;
    }
    log(
      'DoublePanaBetScreen: Initial data loaded - accessToken: ${accessToken.isNotEmpty}, registerId: ${registerId.isNotEmpty}, accountStatus: $accountStatus, walletBalance: $walletBalance',
    );
  }

  @override
  void didUpdateWidget(covariant DoublePanaBetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    log(
      'DoublePanaBetScreen: didUpdateWidget called. Old selectionStatus: ${oldWidget.selectionStatus}, New selectionStatus: ${widget.selectionStatus}',
    );
    // Update options if selectionStatus changes
    if (widget.selectionStatus != oldWidget.selectionStatus) {
      log(
        'DoublePanaBetScreen: selectionStatus changed! Recalculating game type options.',
      );
      _setInitialGameTypeOptions();
    }
  }

  @override
  void dispose() {
    digitController.removeListener(_onDigitChanged);
    digitController.dispose();
    pointsController.dispose();
    _messageDismissTimer?.cancel();
    log('DoublePanaBetScreen: dispose called.');
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
    log('DoublePanaBetScreen: Showing message: "$message" (isError: $isError)');
  }

  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
    log('DoublePanaBetScreen: Message cleared.');
  }

  void _addEntry() {
    _clearMessage();
    if (_isApiCalling) return;

    final digit = digitController.text.trim();
    final points = pointsController.text.trim();

    if (digit.isEmpty || digit.length != 3 || int.tryParse(digit) == null) {
      _showMessage('Enter a valid 3-digit number.', isError: true);
      return;
    }

    if (!doublePanaOptions.contains(digit)) {
      _showMessage('Invalid Double Patti number.', isError: true);
      return;
    }

    if (points.isEmpty) {
      _showMessage('Please enter an amount.', isError: true);
      return;
    }

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    final newEntry = {
      "digit": digit,
      "amount": points,
      "type": selectedGameBetType,
      "gameType": widget.gameCategoryType,
    };

    final existingIndex = addedEntries.indexWhere(
      (e) => e['digit'] == digit && e['type'] == selectedGameBetType,
    );

    setState(() {
      if (existingIndex != -1) {
        int existing = int.parse(addedEntries[existingIndex]['amount']!);
        addedEntries[existingIndex]['amount'] = (existing + parsedPoints)
            .toString();
        _showMessage("Updated bid for $digit.");
      } else {
        addedEntries.add(newEntry);
        _showMessage("Added bid: $digit - $points points");
      }
      digitController.clear();
      pointsController.clear();
      _isDigitSuggestionsVisible = false;
    });
    log('DoublePanaBetScreen: _addEntry called. Added entries: $addedEntries');
  }

  void _removeEntry(int index) {
    _clearMessage();
    if (_isApiCalling) return;

    setState(() {
      final removed = addedEntries[index];
      addedEntries.removeAt(index);
      _showMessage("Removed bid: ${removed['digit']}");
    });
    log(
      'DoublePanaBetScreen: _removeEntry called. Remaining entries: $addedEntries',
    );
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

  Future<bool> _placeFinalBids() async {
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

    log(
      'DoublePanaBetScreen: bidPayload (Map<String,String>) being sent to BidService: $bidPayload',
    );
    log(
      'DoublePanaBetScreen: currentBatchTotalPoints: $currentBatchTotalPoints',
    );

    if (bidPayload.isEmpty) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'No valid bids for the selected game type.',
        ),
      );
      log('DoublePanaBetScreen: Bid failed - No valid bids.');
      return false;
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      if (!mounted) return false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Authentication error. Please log in again.',
        ),
      );
      log('DoublePanaBetScreen: Bid failed - Authentication error.');
      return false;
    }

    try {
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

      if (!mounted) return false;

      if (result['status'] == true) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );

        final responseData = result['data'];
        if (responseData != null &&
            responseData.containsKey('updatedWalletBalance')) {
          final dynamic updatedBalanceRaw =
              responseData['updatedWalletBalance'];
          final int updatedBalance =
              int.tryParse(updatedBalanceRaw.toString()) ??
              (walletBalance - currentBatchTotalPoints);
          if (mounted) {
            setState(() {
              walletBalance = updatedBalance;
            });
          }
          _bidService.updateWalletBalance(updatedBalance);
          log(
            'DoublePanaBetScreen: Bid success! Wallet updated from API: $updatedBalance',
          );
        } else {
          final newWalletBalance = walletBalance - currentBatchTotalPoints;
          if (mounted) {
            setState(() {
              walletBalance = newWalletBalance;
            });
          }
          _bidService.updateWalletBalance(newWalletBalance);
          log(
            'DoublePanaBetScreen: Bid success! Wallet updated locally: $newWalletBalance',
          );
        }

        if (mounted) {
          setState(() {
            addedEntries.removeWhere(
              (element) =>
                  (element["type"] ?? "").toUpperCase() ==
                  selectedGameBetType.toUpperCase(),
            );
          });
          log(
            'DoublePanaBetScreen: Removed successful bids from addedEntries: $addedEntries',
          );
        }
        return true;
      } else {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(
            errorMessage: result['msg'] ?? 'Something went wrong',
          ),
        );
        log('DoublePanaBetScreen: Bid failed - API message: ${result['msg']}');
        return false;
      }
    } catch (e) {
      log(
        'DoublePanaBetScreen: Error during bid placement: $e',
        name: 'DoublePanaBetScreenBidError',
      );
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

  void _showConfirmationDialog() {
    _clearMessage();

    final int totalPointsForCurrentType = _getTotalPointsForSelectedGameType();

    if (totalPointsForCurrentType == 0) {
      _showMessage(
        "No bids added for the selected game type to submit.",
        isError: true,
      );
      log(
        'DoublePanaBetScreen: Confirmation denied - No bids for current type.',
      );
      return;
    }

    if (walletBalance < totalPointsForCurrentType) {
      _showMessage(
        "Insufficient wallet balance for selected game type.",
        isError: true,
      );
      log(
        'DoublePanaBetScreen: Confirmation denied - Insufficient balance. Wallet: $walletBalance, Required: $totalPointsForCurrentType',
      );
      return;
    }

    final formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    final List<Map<String, String>> bidsToShowInDialog = addedEntries
        .where(
          (entry) =>
              (entry["type"] ?? "").toUpperCase() ==
              selectedGameBetType.toUpperCase(),
        )
        .toList();
    log(
      'DoublePanaBetScreen: Showing confirmation dialog for ${bidsToShowInDialog.length} bids, total points: $totalPointsForCurrentType',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BidConfirmationDialog(
        gameTitle: widget.gameName,
        gameDate: formattedDate,
        bids: bidsToShowInDialog.map((bid) {
          return {
            "digit": bid['digit']!,
            "points": bid['amount']!,
            "type": "${bid['gameType']} (${bid['type']})",
            "pana": bid['digit']!,
          };
        }).toList(),
        totalBids: bidsToShowInDialog.length,
        totalBidsAmount: totalPointsForCurrentType,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - totalPointsForCurrentType)
            .toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameCategoryType,
        onConfirm: () async {
          // Navigator.of(context).pop(); // Dialog is popped internally by BidConfirmationDialog on confirm
          log(
            'DoublePanaBetScreen: Bid confirmation accepted. Initiating final bid placement.',
          );
          setState(() => _isApiCalling = true);
          await _placeFinalBids();
          if (mounted) setState(() => _isApiCalling = false);
          log('DoublePanaBetScreen: Final bid placement process completed.');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Log the current state before building
    log(
      'DoublePanaBetScreen: Building widget. Current gameTypesOptions: $gameTypesOptions, selectedGameBetType: $selectedGameBetType',
    );

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
                      _inputRow("Select Game Type:", _buildDropdown()),
                      const SizedBox(height: 12),
                      _inputRow(
                        "Enter 3-Digit Number:",
                        _buildDigitInputField(),
                      ),
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
                                    digitController.text = suggestion;
                                    _isDigitSuggestionsVisible = false;
                                    digitController.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(
                                            offset: digitController.text.length,
                                          ),
                                        );
                                  });
                                  log(
                                    'DoublePanaBetScreen: Digit suggestion selected: $suggestion',
                                  );
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
                      ? Center(
                          child: Text(
                            "No bids added yet",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
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

  Widget _buildDropdown() {
    // Ensure gameTypesOptions is not empty before building dropdown
    // This check also prevents issues if, for some reason, it becomes empty
    if (gameTypesOptions.isEmpty) {
      log(
        'DoublePanaBetScreen: gameTypesOptions is empty, showing placeholder dropdown.',
      );
      return SizedBox(
        width: 150,
        height: 35,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black54),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(
              "No options",
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 150,
      height: 35,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black54),
          borderRadius: BorderRadius.circular(30),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            // Ensure selectedGameBetType is always one of the valid options
            // This re-check helps if external changes somehow invalidate it.
            value: gameTypesOptions.contains(selectedGameBetType)
                ? selectedGameBetType
                : gameTypesOptions.first,
            // Fallback to the first item if current value is not in options
            icon: const Icon(Icons.keyboard_arrow_down),
            onChanged: _isApiCalling
                ? null
                : (String? newValue) {
                    setState(() {
                      if (newValue != null) {
                        selectedGameBetType = newValue;
                        _clearMessage();
                        log(
                          'DoublePanaBetScreen: Dropdown value changed to: $newValue',
                        );
                      }
                    });
                  },
            items: gameTypesOptions.map<DropdownMenuItem<String>>((
              String value,
            ) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: GoogleFonts.poppins(fontSize: 14)),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDigitInputField() {
    return SizedBox(
      width: double.infinity,
      height: 35,
      child: TextFormField(
        controller: digitController,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: [
          LengthLimitingTextInputFormatter(3),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: () {
          _clearMessage();
          if (digitController.text.isNotEmpty) {
            _onDigitChanged();
          }
          log(
            'DoublePanaBetScreen: Digit input field tapped. Current text: ${digitController.text}',
          );
        },
        onChanged: (value) {
          _onDigitChanged();
          log('DoublePanaBetScreen: Digit input field changed: $value');
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
                    color: Colors.white,
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
