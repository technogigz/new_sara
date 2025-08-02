import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../BidService.dart'; // Import BidService
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';

class TPMotorsBetScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType;
  final int gameId;
  final String gameName;
  final bool selectionStatus; // This controls the dropdown options

  const TPMotorsBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
    required this.selectionStatus,
  });

  @override
  State<TPMotorsBetScreen> createState() => _TPMotorsBetScreenState();
}

class _TPMotorsBetScreenState extends State<TPMotorsBetScreen> {
  late String selectedGameBetType;

  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  List<String> triplePanaOptions = [
    "111",
    "222",
    "333",
    "444",
    "555",
    "666",
    "777",
    "888",
    "999",
    "000",
  ];
  List<String> filteredDigitOptions = [];
  bool _isDigitSuggestionsVisible = false;

  List<Map<String, String>> addedEntries = [];
  late GetStorage storage;
  late BidService _bidService; // Declare BidService

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
  Timer? _messageDismissTimer; // Keep Timer for message bar dismissal

  bool _isApiCalling = false;

  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _bidService = BidService(storage); // Initialize BidService
    _loadInitialData();
    _setupStorageListeners();

    digitController.addListener(_onDigitChanged);

    // Initialize selectedGameBetType based on selectionStatus
    selectedGameBetType = widget.selectionStatus ? "Open" : "Close";
  }

  void _onDigitChanged() {
    final query = digitController.text.trim();
    if (query.isNotEmpty) {
      setState(() {
        filteredDigitOptions = triplePanaOptions
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
    digitController.removeListener(_onDigitChanged);
    digitController.dispose();
    pointsController.dispose();
    _messageDismissTimer?.cancel(); // Cancel timer
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    _messageDismissTimer?.cancel(); // Cancel any existing timer
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey(); // Update key to trigger animation
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

    final digit = digitController.text.trim();
    final points = pointsController.text.trim();

    if (digit.isEmpty || digit.length != 3 || int.tryParse(digit) == null) {
      _showMessage('Enter a valid 3-digit number.', isError: true);
      return;
    }

    if (!triplePanaOptions.contains(digit)) {
      _showMessage('Invalid Triple Patti number.', isError: true);
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

    // Use consistent keys ("digit", "amount", "type", "gameType")
    final newEntry = {
      "digit": digit,
      "amount":
          points, // Renamed from "points" to "amount" for consistency with BidService
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
  }

  void _removeEntry(int index) {
    _clearMessage();
    if (_isApiCalling) return;

    setState(() {
      final removed = addedEntries[index];
      addedEntries.removeAt(index);
      _showMessage("Removed bid: ${removed['digit']}");
    });
  }

  int _getTotalPoints() {
    // Calculates total points for ALL added entries
    return addedEntries.fold(
      0,
      (sum, item) =>
          sum + (int.tryParse(item['amount'] ?? '0') ?? 0), // Use 'amount'
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

    // Filter and prepare bids for the currently selected game type
    for (var entry in addedEntries) {
      if ((entry["type"] ?? "").toUpperCase() ==
          selectedGameBetType.toUpperCase()) {
        String digit = entry["digit"] ?? "";
        String amount = entry["amount"] ?? "0"; // Use 'amount'

        if (digit.isNotEmpty && int.tryParse(amount) != null) {
          bidPayload[digit] = amount;
          currentBatchTotalPoints += int.parse(amount);
        }
      }
    }

    log(
      'bidPayload (Map<String,String>) being sent to BidService: $bidPayload',
      name: 'TPMotorsBetScreen',
    );
    log(
      'currentBatchTotalPoints: $currentBatchTotalPoints',
      name: 'TPMotorsBetScreen',
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

        final dynamic updatedBalanceRaw = result['updatedWalletBalance'];
        final int updatedBalance =
            int.tryParse(updatedBalanceRaw.toString()) ??
            (walletBalance - currentBatchTotalPoints);
        setState(() {
          walletBalance = updatedBalance;
        });
        _bidService.updateWalletBalance(updatedBalance);

        setState(() {
          // Remove only bids of the currently selected game type after successful submission
          addedEntries.removeWhere(
            (element) =>
                (element["type"] ?? "").toUpperCase() ==
                selectedGameBetType.toUpperCase(),
          );
        });
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
      log('Error during bid placement: $e', name: 'TPMotorsBetScreenBidError');
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
    if (_isApiCalling) return;

    final int totalPointsForCurrentType = _getTotalPointsForSelectedGameType();

    if (totalPointsForCurrentType == 0) {
      _showMessage(
        "No bids added for the selected game type to submit.",
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
              "points": bid['amount']!, // Use 'amount' here
              "type":
                  "${bid['gameType']} (${bid['type']})", // Corrected concatenation
              "pana": bid['digit']!,
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
            // Navigator.pop(dialogContext); // Dialog is dismissed within _placeFinalBids
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

  @override
  Widget build(BuildContext context) {
    // Dynamically set available game type options
    List<String> availableGameTypes = [];
    if (widget.selectionStatus) {
      availableGameTypes.add("Open");
    }
    availableGameTypes.add("Close"); // Close is always an option

    // Ensure selectedGameBetType is still a valid option if selectionStatus changed
    if (!availableGameTypes.contains(selectedGameBetType)) {
      selectedGameBetType = availableGameTypes.first;
    }

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
                    _inputRow(
                      "Select Game Type:",
                      _buildDropdown(availableGameTypes),
                    ),
                    const SizedBox(height: 12),
                    _inputRow(
                      "Enter 3-Digit Triple Panna:",
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
                                    entry['amount']!, // Use 'amount'
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${entry['gameType']} (${entry['type']})', // Corrected display
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

  // Modified _buildDropdown to accept available options
  Widget _buildDropdown(List<String> options) {
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
            value: selectedGameBetType,
            icon: const Icon(Icons.keyboard_arrow_down),
            onChanged: _isApiCalling
                ? null
                : (String? newValue) {
                    setState(() {
                      selectedGameBetType = newValue!;
                      _clearMessage();
                    });
                  },
            items: options.map<DropdownMenuItem<String>>((String value) {
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
          _onDigitChanged();
        },
        onChanged: (value) {
          _onDigitChanged();
        },
        enabled: !_isApiCalling,
        decoration: InputDecoration(
          hintText: "Enter 3-Digit Triple Panna",
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

// import 'dart:async';
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
//
// import '../../BidService.dart'; // Import BidService
// import '../../components/AnimatedMessageBar.dart';
// import '../../components/BidConfirmationDialog.dart';
// import '../../components/BidFailureDialog.dart';
// import '../../components/BidSuccessDialog.dart';
//
// class TPMotorsBetScreen extends StatefulWidget {
//   final String title;
//   final String gameCategoryType;
//   final int gameId;
//   final String gameName;
//   final bool selectionStatus;
//
//   const TPMotorsBetScreen({
//     super.key,
//     required this.title,
//     required this.gameId,
//     required this.gameName,
//     required this.gameCategoryType,
//     required this.selectionStatus,
//   });
//
//   @override
//   State<TPMotorsBetScreen> createState() => _TPMotorsBetScreenState();
// }
//
// class _TPMotorsBetScreenState extends State<TPMotorsBetScreen> {
//   final List<String> gameTypesOptions = const ["Open", "Close"];
//   late String selectedGameBetType;
//
//   final TextEditingController digitController = TextEditingController();
//   final TextEditingController pointsController = TextEditingController();
//
//   List<String> triplePanaOptions = [
//     "111",
//     "222",
//     "333",
//     "444",
//     "555",
//     "666",
//     "777",
//     "888",
//     "999",
//     "000",
//   ];
//   List<String> filteredDigitOptions = [];
//   bool _isDigitSuggestionsVisible = false;
//
//   List<Map<String, String>> addedEntries = [];
//   late GetStorage storage;
//   late BidService _bidService; // Declare BidService
//
//   late String accessToken;
//   late String registerId;
//   late String preferredLanguage;
//   bool accountStatus = false;
//   late int walletBalance;
//
//   final String _deviceId = 'test_device_id_flutter';
//   final String _deviceName = 'test_device_name_flutter';
//
//   String? _messageToShow;
//   bool _isErrorForMessage = false;
//   Key _messageBarKey = UniqueKey();
//   Timer? _messageDismissTimer; // Keep Timer for message bar dismissal
//
//   bool _isApiCalling = false;
//
//   @override
//   void initState() {
//     super.initState();
//     storage = GetStorage();
//     _bidService = BidService(storage); // Initialize BidService
//     _loadInitialData();
//     _setupStorageListeners();
//
//     digitController.addListener(_onDigitChanged);
//     selectedGameBetType = gameTypesOptions[0];
//   }
//
//   void _onDigitChanged() {
//     final query = digitController.text.trim();
//     if (query.isNotEmpty) {
//       setState(() {
//         filteredDigitOptions = triplePanaOptions
//             .where((digit) => digit.startsWith(query))
//             .toList();
//         _isDigitSuggestionsVisible = filteredDigitOptions.isNotEmpty;
//       });
//     } else {
//       setState(() {
//         filteredDigitOptions = [];
//         _isDigitSuggestionsVisible = false;
//       });
//     }
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
//     digitController.removeListener(_onDigitChanged);
//     digitController.dispose();
//     pointsController.dispose();
//     _messageDismissTimer?.cancel(); // Cancel timer
//     super.dispose();
//   }
//
//   void _showMessage(String message, {bool isError = false}) {
//     _messageDismissTimer?.cancel(); // Cancel any existing timer
//     if (!mounted) return;
//     setState(() {
//       _messageToShow = message;
//       _isErrorForMessage = isError;
//       _messageBarKey = UniqueKey(); // Update key to trigger animation
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
//   void _addEntry() {
//     _clearMessage();
//     if (_isApiCalling) return;
//
//     final digit = digitController.text.trim();
//     final points = pointsController.text.trim();
//
//     if (digit.isEmpty || digit.length != 3 || int.tryParse(digit) == null) {
//       _showMessage('Enter a valid 3-digit number.', isError: true);
//       return;
//     }
//
//     if (!triplePanaOptions.contains(digit)) {
//       _showMessage('Invalid Triple Patti number.', isError: true);
//       return;
//     }
//
//     if (points.isEmpty) {
//       _showMessage('Please enter an amount.', isError: true);
//       return;
//     }
//
//     int? parsedPoints = int.tryParse(points);
//     if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
//       _showMessage('Points must be between 10 and 1000.', isError: true);
//       return;
//     }
//
//     // Use consistent keys ("digit", "amount", "type", "gameType")
//     final newEntry = {
//       "digit": digit,
//       "amount":
//           points, // Renamed from "points" to "amount" for consistency with BidService
//       "type": selectedGameBetType,
//       "gameType": widget.gameCategoryType,
//     };
//
//     final existingIndex = addedEntries.indexWhere(
//       (e) => e['digit'] == digit && e['type'] == selectedGameBetType,
//     );
//
//     setState(() {
//       if (existingIndex != -1) {
//         int existing = int.parse(addedEntries[existingIndex]['amount']!);
//         addedEntries[existingIndex]['amount'] = (existing + parsedPoints)
//             .toString();
//         _showMessage("Updated bid for $digit.");
//       } else {
//         addedEntries.add(newEntry);
//         _showMessage("Added bid: $digit - $points points");
//       }
//       digitController.clear();
//       pointsController.clear();
//       _isDigitSuggestionsVisible = false;
//     });
//   }
//
//   void _removeEntry(int index) {
//     _clearMessage();
//     if (_isApiCalling) return;
//
//     setState(() {
//       final removed = addedEntries[index];
//       addedEntries.removeAt(index);
//       _showMessage("Removed bid: ${removed['digit']}");
//     });
//   }
//
//   int _getTotalPoints() {
//     // Calculates total points for ALL added entries
//     return addedEntries.fold(
//       0,
//       (sum, item) =>
//           sum + (int.tryParse(item['amount'] ?? '0') ?? 0), // Use 'amount'
//     );
//   }
//
//   int _getTotalPointsForSelectedGameType() {
//     return addedEntries
//         .where(
//           (entry) =>
//               (entry["type"] ?? "").toUpperCase() ==
//               selectedGameBetType.toUpperCase(),
//         )
//         .fold(
//           0,
//           (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
//         );
//   }
//
//   Future<bool> _placeFinalBids() async {
//     final Map<String, String> bidPayload = {};
//     int currentBatchTotalPoints = 0;
//
//     // Filter and prepare bids for the currently selected game type
//     for (var entry in addedEntries) {
//       if ((entry["type"] ?? "").toUpperCase() ==
//           selectedGameBetType.toUpperCase()) {
//         String digit = entry["digit"] ?? "";
//         String amount = entry["amount"] ?? "0"; // Use 'amount'
//
//         if (digit.isNotEmpty && int.tryParse(amount) != null) {
//           bidPayload[digit] = amount;
//           currentBatchTotalPoints += int.parse(amount);
//         }
//       }
//     }
//
//     log(
//       'bidPayload (Map<String,String>) being sent to BidService: $bidPayload',
//       name: 'TPMotorsBetScreen',
//     );
//     log(
//       'currentBatchTotalPoints: $currentBatchTotalPoints',
//       name: 'TPMotorsBetScreen',
//     );
//
//     if (bidPayload.isEmpty) {
//       if (!mounted) return false;
//       await showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => const BidFailureDialog(
//           errorMessage: 'No valid bids for the selected game type.',
//         ),
//       );
//       return false;
//     }
//
//     if (accessToken.isEmpty || registerId.isEmpty) {
//       if (!mounted) return false;
//
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
//     try {
//       final result = await _bidService.placeFinalBids(
//         gameName: widget.gameName,
//         accessToken: accessToken,
//         registerId: registerId,
//         deviceId: _deviceId,
//         deviceName: _deviceName,
//         accountStatus: accountStatus,
//         bidAmounts: bidPayload,
//         selectedGameType: selectedGameBetType,
//         gameId: widget.gameId,
//         gameType: widget.gameCategoryType,
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
//         });
//         _bidService.updateWalletBalance(updatedBalance);
//
//         setState(() {
//           // Remove only bids of the currently selected game type after successful submission
//           addedEntries.removeWhere(
//             (element) =>
//                 (element["type"] ?? "").toUpperCase() ==
//                 selectedGameBetType.toUpperCase(),
//           );
//         });
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
//       log('Error during bid placement: $e', name: 'TPMotorsBetScreenBidError');
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
//   void _showConfirmationDialog() {
//     _clearMessage();
//     if (_isApiCalling) return;
//
//     final int totalPointsForCurrentType = _getTotalPointsForSelectedGameType();
//
//     if (totalPointsForCurrentType == 0) {
//       _showMessage(
//         "No bids added for the selected game type to submit.",
//         isError: true,
//       );
//       return;
//     }
//
//     if (walletBalance < totalPointsForCurrentType) {
//       _showMessage(
//         'Insufficient wallet balance for selected game type.',
//         isError: true,
//       );
//       return;
//     }
//
//     final String formattedDate = DateFormat(
//       'dd MMM yyyy, hh:mm a',
//     ).format(DateTime.now());
//
//     final List<Map<String, String>> bidsToShowInDialog = addedEntries
//         .where(
//           (entry) =>
//               (entry["type"] ?? "").toUpperCase() ==
//               selectedGameBetType.toUpperCase(),
//         )
//         .toList();
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return BidConfirmationDialog(
//           gameTitle: widget.gameName,
//           gameDate: formattedDate,
//           bids: bidsToShowInDialog.map((bid) {
//             return {
//               "digit": bid['digit']!,
//               "points": bid['amount']!, // Use 'amount' here
//               "type":
//                   "${bid['gameType']} (${bid['type']})", // Corrected concatenation
//               "pana": bid['digit']!,
//             };
//           }).toList(),
//           totalBids: bidsToShowInDialog.length,
//           totalBidsAmount: totalPointsForCurrentType,
//           walletBalanceBeforeDeduction: walletBalance,
//           walletBalanceAfterDeduction:
//               (walletBalance - totalPointsForCurrentType).toString(),
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameCategoryType,
//           onConfirm: () async {
//             // Navigator.pop(dialogContext);
//             setState(() {
//               _isApiCalling = true;
//             });
//             await _placeFinalBids();
//             if (mounted) {
//               setState(() {
//                 _isApiCalling = false;
//               });
//             }
//           },
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade200,
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.grey.shade300,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           widget.title,
//           style: GoogleFonts.poppins(
//             color: Colors.black,
//             fontWeight: FontWeight.w600,
//             fontSize: 15,
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
//               walletBalance.toString(),
//               style: const TextStyle(
//                 color: Colors.black,
//                 fontWeight: FontWeight.bold,
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
//                   horizontal: 16,
//                   vertical: 12,
//                 ),
//                 child: Column(
//                   children: [
//                     _inputRow("Select Game Type:", _buildDropdown()),
//                     const SizedBox(height: 12),
//                     _inputRow(
//                       "Enter 3-Digit Triple Panna:",
//                       _buildDigitInputField(),
//                     ),
//                     if (_isDigitSuggestionsVisible &&
//                         filteredDigitOptions.isNotEmpty)
//                       Container(
//                         margin: const EdgeInsets.only(top: 8),
//                         constraints: const BoxConstraints(maxHeight: 200),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(8),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.grey.withOpacity(0.2),
//                               spreadRadius: 2,
//                               blurRadius: 5,
//                             ),
//                           ],
//                         ),
//                         child: ListView.builder(
//                           shrinkWrap: true,
//                           itemCount: filteredDigitOptions.length,
//                           itemBuilder: (context, index) {
//                             final suggestion = filteredDigitOptions[index];
//                             return ListTile(
//                               title: Text(suggestion),
//                               onTap: () {
//                                 setState(() {
//                                   digitController.text = suggestion;
//                                   _isDigitSuggestionsVisible = false;
//                                   digitController.selection =
//                                       TextSelection.fromPosition(
//                                         TextPosition(
//                                           offset: digitController.text.length,
//                                         ),
//                                       );
//                                 });
//                               },
//                             );
//                           },
//                         ),
//                       ),
//                     const SizedBox(height: 12),
//                     _inputRow(
//                       "Enter Points:",
//                       _buildTextField(
//                         pointsController,
//                         "Enter Amount",
//                         inputFormatters: [
//                           FilteringTextInputFormatter.digitsOnly,
//                           LengthLimitingTextInputFormatter(4),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 20),
//                     SizedBox(
//                       width: double.infinity,
//                       height: 45,
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.orange,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                         ),
//                         onPressed: _isApiCalling ? null : _addEntry,
//                         child: _isApiCalling
//                             ? const CircularProgressIndicator(
//                                 color: Colors.white,
//                                 strokeWidth: 2,
//                               )
//                             : const Text(
//                                 "ADD BID",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                       ),
//                     ),
//                     const SizedBox(height: 18),
//                   ],
//                 ),
//               ),
//               const Divider(thickness: 1),
//               if (addedEntries.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 8,
//                   ),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           "Digit",
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         child: Text(
//                           "Amount",
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         child: Text(
//                           "Game Type",
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 48),
//                     ],
//                   ),
//                 ),
//               if (addedEntries.isNotEmpty) const Divider(thickness: 1),
//               Expanded(
//                 child: addedEntries.isEmpty
//                     ? const Center(child: Text("No data added yet"))
//                     : ListView.builder(
//                         itemCount: addedEntries.length,
//                         itemBuilder: (_, index) {
//                           final entry = addedEntries[index];
//                           return Padding(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 16,
//                               vertical: 6,
//                             ),
//                             child: Row(
//                               children: [
//                                 Expanded(
//                                   child: Text(
//                                     entry['digit']!,
//                                     style: GoogleFonts.poppins(),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   child: Text(
//                                     entry['amount']!, // Use 'amount'
//                                     style: GoogleFonts.poppins(),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   child: Text(
//                                     '${entry['gameType']} (${entry['type']})', // Corrected display
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
//                                       : () => _removeEntry(index),
//                                 ),
//                               ],
//                             ),
//                           );
//                         },
//                       ),
//               ),
//               if (addedEntries.isNotEmpty) _buildBottomBar(),
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
//   Widget _inputRow(String label, Widget field) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 1),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             flex: 2,
//             child: Padding(
//               padding: const EdgeInsets.only(top: 8.0),
//               child: Text(
//                 label,
//                 style: GoogleFonts.poppins(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//           ),
//           Expanded(flex: 3, child: field),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDropdown() {
//     return SizedBox(
//       width: 150,
//       height: 35,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           border: Border.all(color: Colors.black54),
//           borderRadius: BorderRadius.circular(30),
//         ),
//         child: DropdownButtonHideUnderline(
//           child: DropdownButton<String>(
//             isExpanded: true,
//             value: selectedGameBetType,
//             icon: const Icon(Icons.keyboard_arrow_down),
//             onChanged: _isApiCalling
//                 ? null
//                 : (String? newValue) {
//                     setState(() {
//                       selectedGameBetType = newValue!;
//                       _clearMessage();
//                     });
//                   },
//             items: gameTypesOptions.map<DropdownMenuItem<String>>((
//               String value,
//             ) {
//               return DropdownMenuItem<String>(
//                 value: value,
//                 child: Text(value, style: GoogleFonts.poppins(fontSize: 14)),
//               );
//             }).toList(),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDigitInputField() {
//     return SizedBox(
//       width: double.infinity,
//       height: 35,
//       child: TextFormField(
//         controller: digitController,
//         cursorColor: Colors.orange,
//         keyboardType: TextInputType.number,
//         style: GoogleFonts.poppins(fontSize: 14),
//         inputFormatters: [
//           LengthLimitingTextInputFormatter(3),
//           FilteringTextInputFormatter.digitsOnly,
//         ],
//         onTap: () {
//           _clearMessage();
//           _onDigitChanged();
//         },
//         onChanged: (value) {
//           _onDigitChanged();
//         },
//         enabled: !_isApiCalling,
//         decoration: InputDecoration(
//           hintText: "Enter 3-Digit Triple Panna",
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 0,
//           ),
//           filled: true,
//           fillColor: Colors.white,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.black),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.black),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.orange, width: 2),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTextField(
//     TextEditingController controller,
//     String hint, {
//     List<TextInputFormatter>? inputFormatters,
//   }) {
//     return SizedBox(
//       width: 150,
//       height: 35,
//       child: TextFormField(
//         controller: controller,
//         cursorColor: Colors.orange,
//         keyboardType: TextInputType.number,
//         style: GoogleFonts.poppins(fontSize: 14),
//         inputFormatters: inputFormatters,
//         onTap: _clearMessage,
//         enabled: !_isApiCalling,
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
//             borderSide: const BorderSide(color: Colors.black),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.black),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.orange, width: 2),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildBottomBar() {
//     int totalBids = addedEntries.length;
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
//             onPressed:
//                 (_isApiCalling || _getTotalPointsForSelectedGameType() == 0)
//                 ? null
//                 : _showConfirmationDialog,
//             style: ElevatedButton.styleFrom(
//               backgroundColor:
//                   (_isApiCalling || _getTotalPointsForSelectedGameType() == 0)
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
