// lib/screens/dp_motors_bet_screen.dart
import 'dart:async'; // For Timer

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:new_sara/BidsServicesBulk.dart';

import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';

class DPMotorsBetScreen extends StatefulWidget {
  final String title; // This is the screen title, e.g., "Motor Patti"
  final String gameCategoryType; // e.g., "Double Patti"
  final int gameId;
  final String gameName; // e.g., "Kalyan Morning" or "Starline Express"

  const DPMotorsBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName, // Pass the market name here
    required this.gameCategoryType, // Pass the specific game type here, e.g., "Double Patti"
  });

  @override
  State<DPMotorsBetScreen> createState() => _DPMotorsBetScreenState();
}

class _DPMotorsBetScreenState extends State<DPMotorsBetScreen> {
  final List<String> gameTypesOptions = const ["Open", "Close"];
  late String selectedGameBetType;

  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  // --- New State Variables for Suggestions (Double Patti specific) ---
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
  // --- End New State Variables ---

  // Update addedEntries to match the standardized format for BidService
  List<Map<String, String>> addedEntries = [];
  late GetStorage storage;
  late BidServiceBulk _bidService; // Declare BidService
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
  Timer? _messageDismissTimer; // For auto-dismissing messages

  // State variable to track API call status
  bool _isApiCalling = false;

  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _bidService = BidServiceBulk(storage); // Initialize BidService
    _loadInitialData();
    _setupStorageListeners();

    // --- Add listener for digitController ---
    digitController.addListener(_onDigitChanged);
    // --- End Add listener ---

    selectedGameBetType = gameTypesOptions[0]; // Default to Open
  }

  // --- New _onDigitChanged method for filtering Double Patti ---
  void _onDigitChanged() {
    final query = digitController.text.trim();
    if (query.isNotEmpty) {
      setState(() {
        // Filter based on startsWith
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
  // --- End _onDigitChanged method ---

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
    // --- Remove listener for digitController ---
    digitController.removeListener(_onDigitChanged);
    // --- End Remove listener ---
    digitController.dispose();
    pointsController.dispose();
    _messageDismissTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    _messageDismissTimer?.cancel(); // Clear any existing timer

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

    if (digit.isEmpty) {
      _showMessage('Please enter a 3-digit number.', isError: true);
      return;
    }

    if (digit.length != 3 || int.tryParse(digit) == null) {
      _showMessage(
        'Please enter a valid 3-digit number (e.g., 123).',
        isError: true,
      );
      return;
    }

    // --- Validate if the digit is in the Double_Pana list ---
    if (!doublePanaOptions.contains(digit)) {
      _showMessage(
        'Invalid 3-digit number. Not a valid Double Patti.',
        isError: true,
      );
      return;
    }
    // --- End Validation ---

    if (points.isEmpty) {
      _showMessage('Please enter an Amount.', isError: true);
      return;
    }

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    // Prepare the new entry in the standardized format for `addedEntries`
    final newEntry = {
      "bidDigit": digit,
      "bidPoints": points,
      "sessionType": selectedGameBetType,
      "gameTypeCategory":
          widget.gameCategoryType, // This will be "Double Patti"
    };

    final existingIndex = addedEntries.indexWhere(
      (entry) =>
          entry['bidDigit'] == newEntry['bidDigit'] &&
          entry['sessionType'] == newEntry['sessionType'],
    );

    setState(() {
      if (existingIndex != -1) {
        final currentPoints = int.parse(
          addedEntries[existingIndex]['bidPoints']!,
        );
        addedEntries[existingIndex]['bidPoints'] =
            (currentPoints + parsedPoints).toString();
        _showMessage(
          'Updated points for ${widget.gameCategoryType}: $digit, Type: $selectedGameBetType.',
        );
      } else {
        addedEntries.add(newEntry);
        _showMessage(
          'Added bid: ${widget.gameCategoryType} $digit, Points $points, Type $selectedGameBetType.',
        );
      }
      digitController.clear();
      pointsController.clear();
      _isDigitSuggestionsVisible = false; // Hide suggestions after adding
    });
  }

  void _removeEntry(int index) {
    _clearMessage();
    if (_isApiCalling) return;

    setState(() {
      final removedEntry = addedEntries[index];
      addedEntries.removeAt(index);
      _showMessage(
        'Removed bid: ${removedEntry['gameTypeCategory']} ${removedEntry['bidDigit']}, Type ${removedEntry['sessionType']}.',
      );
    });
  }

  int _getTotalPoints() {
    return addedEntries.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['bidPoints'] ?? '0') ?? 0),
    );
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    if (addedEntries.isEmpty) {
      _showMessage('Please add at least one bid.', isError: true);
      return;
    }

    final int totalPoints = _getTotalPoints();

    if (walletBalance < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
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
          gameTitle: widget.gameName, // Use gameName for market title
          gameDate: formattedDate,
          bids: addedEntries.map((bid) {
            // Map `addedEntries` to `BidConfirmationDialog`'s expected format
            // Assuming BidConfirmationDialog also needs 'pana' for patti types
            return {
              "digit": bid['bidDigit']!, // The panna
              "points": bid['bidPoints']!,
              "type":
                  '${bid['gameTypeCategory']} (${bid['sessionType']})', // Combined for display
              "pana": bid['bidDigit']!, // For DPMotors, the digit is the pana
            };
          }).toList(),
          totalBids: addedEntries.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget
              .gameCategoryType, // The specific game type like "Double Patti"
          onConfirm: () async {
            Navigator.pop(dialogContext);
            setState(() {
              _isApiCalling = true;
            });
            final Map<String, dynamic> result = await _placeFinalBids();
            if (result['status'] == true) {
              setState(() {
                addedEntries.clear(); // Clear bids only on success
              });
              // _showMessage(result['msg'], isError: false); // Handled by success dialog
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const BidSuccessDialog();
                  },
                );
              }
            } else {
              // _showMessage(
              //   result['msg'] ?? "Bid submission failed. Please try again.",
              //   isError: true,
              // ); // Handled by failure dialog
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return BidFailureDialog(
                      errorMessage:
                          result['msg'] ??
                          "Bid submission failed. Please try again.",
                    );
                  },
                );
              }
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

  // Refactored to use the common BidService
  Future<Map<String, dynamic>> _placeFinalBids() async {
    // addedEntries is already in the standardized format expected by BidService
    final Map<String, dynamic> result = await _bidService.placeFinalBids(
      gameName: widget.gameName, // e.g., "Kalyan Morning"
      accessToken: accessToken,
      registerId: registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: accountStatus,
      bids: addedEntries, // Pass the standardized list directly
      gameId: widget.gameId,
      totalBidAmount: _getTotalPoints(),
      gameType: widget.gameCategoryType,
      selectedSessionType: selectedGameBetType,
    );

    return result; // BidService returns a map with 'status' and 'msg'
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
          widget.title, // Title of the screen, e.g., "Motor Patti"
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 15,
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
                    // Game Type Dropdown
                    _inputRow("Select Game Type:", _buildDropdown()),
                    const SizedBox(height: 12),
                    // Digit Input Field with suggestions
                    _inputRow("Enter 3-Digit Number:", _buildDigitInputField()),
                    // --- Added suggestions list conditionally ---
                    if (_isDigitSuggestionsVisible &&
                        filteredDigitOptions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        constraints: const BoxConstraints(
                          maxHeight: 200,
                        ), // Limit height
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
                                  _isDigitSuggestionsVisible =
                                      false; // Hide on selection
                                  // Move cursor to end of text
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
                    // --- End Added suggestions list ---
                    const SizedBox(
                      height: 12,
                    ), // Adjust spacing after digit input
                    // Points Input Field
                    _inputRow(
                      "Enter Points:",
                      _buildTextField(
                        pointsController,
                        "Enter Amount",
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(
                            4,
                          ), // Max 4 digits for points
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: _isApiCalling
                            ? null
                            : _addEntry, // Disable if API is calling
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
              // List Headers
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
              // List of Added Entries
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
                                    entry['bidDigit']!, // Use standardized key
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry['bidPoints']!, // Use standardized key
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${entry['gameTypeCategory']} (${entry['sessionType']})', // Use standardized keys
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
                                      : () => _removeEntry(
                                          index,
                                        ), // Disable if API is calling
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              // Bottom Summary Bar
              if (addedEntries.isNotEmpty) _buildBottomBar(),
            ],
          ),
          // Animated Message Bar
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

  Widget _buildDropdown() {
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

  // Updated to accept 3-digit input and show suggestions
  Widget _buildDigitInputField() {
    return SizedBox(
      width: double.infinity,
      height: 35,
      child: TextFormField(
        controller: digitController,
        cursorColor: Colors.amber,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: [
          LengthLimitingTextInputFormatter(3),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: () {
          _clearMessage();
          // Trigger suggestions on tap if text is present
          if (digitController.text.isNotEmpty) {
            _onDigitChanged();
          }
        },
        onChanged: (value) {
          _onDigitChanged(); // Filter suggestions as user types
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
            borderSide: const BorderSide(color: Colors.amber, width: 2),
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
        cursorColor: Colors.amber,
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
            borderSide: const BorderSide(color: Colors.amber, width: 2),
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
                : _showConfirmationDialog, // Disable if API is calling or no bids
            style: ElevatedButton.styleFrom(
              backgroundColor: _isApiCalling || addedEntries.isEmpty
                  ? Colors.grey
                  : Colors.amber, // Dim if disabled
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

// import 'dart:async'; // For Timer
// import 'dart:convert'; // For jsonEncode, json.decode
// import 'dart:developer'; // For log
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http; // For API calls
// import 'package:intl/intl.dart'; // Import for date formatting
//
// import '../../components/AnimatedMessageBar.dart';
// import '../../components/BidConfirmationDialog.dart';
// import '../../components/BidFailureDialog.dart';
// import '../../components/BidSuccessDialog.dart';
// import '../../ulits/Constents.dart'; // Import the Constants file for API endpoint
//
// class DPMotorsBetScreen extends StatefulWidget {
//   final String title;
//   final String gameCategoryType;
//   final int gameId;
//   final String gameName;
//
//   const DPMotorsBetScreen({
//     super.key,
//     required this.title,
//     required this.gameId,
//     required this.gameName,
//     required this.gameCategoryType,
//   });
//
//   @override
//   State<DPMotorsBetScreen> createState() => _DPMotorsBetScreenState();
// }
//
// class _DPMotorsBetScreenState extends State<DPMotorsBetScreen> {
//   final List<String> gameTypesOptions = const ["Open", "Close"];
//   late String selectedGameBetType;
//
//   final TextEditingController digitController = TextEditingController();
//   final TextEditingController pointsController = TextEditingController();
//
//   // --- New State Variables for Suggestions (Double Patti specific) ---
//   List<String> doublePanaOptions = [
//     "100",
//     "110",
//     "112",
//     "113",
//     "114",
//     "115",
//     "116",
//     "117",
//     "118",
//     "119",
//     "122",
//     "133",
//     "144",
//     "155",
//     "166",
//     "177",
//     "188",
//     "199",
//     "200",
//     "220",
//     "223",
//     "224",
//     "225",
//     "226",
//     "227",
//     "228",
//     "229",
//     "233",
//     "244",
//     "255",
//     "266",
//     "277",
//     "288",
//     "299",
//     "300",
//     "330",
//     "334",
//     "335",
//     "336",
//     "337",
//     "338",
//     "339",
//     "344",
//     "355",
//     "366",
//     "377",
//     "388",
//     "399",
//     "400",
//     "440",
//     "445",
//     "446",
//     "447",
//     "448",
//     "449",
//     "455",
//     "466",
//     "477",
//     "488",
//     "499",
//     "500",
//     "550",
//     "556",
//     "557",
//     "558",
//     "559",
//     "566",
//     "577",
//     "588",
//     "599",
//     "600",
//     "660",
//     "667",
//     "668",
//     "669",
//     "677",
//     "688",
//     "699",
//     "700",
//     "770",
//     "778",
//     "779",
//     "788",
//     "799",
//     "800",
//     "880",
//     "889",
//     "899",
//     "900",
//     "990",
//   ];
//   List<String> filteredDigitOptions = [];
//   bool _isDigitSuggestionsVisible = false;
//   // --- End New State Variables ---
//
//   List<Map<String, String>> addedEntries = [];
//   late GetStorage storage;
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
//
//   // State variable to track API call status
//   bool _isApiCalling = false;
//
//   @override
//   void initState() {
//     super.initState();
//     storage = GetStorage();
//     _loadInitialData();
//     _setupStorageListeners();
//
//     // --- Add listener for digitController ---
//     digitController.addListener(_onDigitChanged);
//     // --- End Add listener ---
//
//     selectedGameBetType = gameTypesOptions[0];
//   }
//
//   // --- New _onDigitChanged method for filtering Double Patti ---
//   void _onDigitChanged() {
//     final query = digitController.text.trim();
//     if (query.isNotEmpty) {
//       setState(() {
//         filteredDigitOptions = doublePanaOptions
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
//   // --- End _onDigitChanged method ---
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
//     // --- Remove listener for digitController ---
//     digitController.removeListener(_onDigitChanged);
//     // --- End Remove listener ---
//     digitController.dispose();
//     pointsController.dispose();
//     super.dispose();
//   }
//
//   void _showMessage(String message, {bool isError = false}) {
//     setState(() {
//       _messageToShow = message;
//       _isErrorForMessage = isError;
//       _messageBarKey = UniqueKey();
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
//     if (_isApiCalling) return;
//
//     final digit = digitController.text.trim();
//     final points = pointsController.text.trim();
//
//     if (digit.isEmpty) {
//       _showMessage('Please enter a 3-digit number.', isError: true);
//       return;
//     }
//
//     if (digit.length != 3 || int.tryParse(digit) == null) {
//       _showMessage(
//         'Please enter a valid 3-digit number (e.g., 123).',
//         isError: true,
//       );
//       return;
//     }
//
//     // --- Validate if the digit is in the Double_Pana list ---
//     if (!doublePanaOptions.contains(digit)) {
//       _showMessage(
//         'Invalid 3-digit number. Not a valid Double Patti.',
//         isError: true,
//       );
//       return;
//     }
//     // --- End Validation ---
//
//     if (points.isEmpty) {
//       _showMessage('Please enter an Amount.', isError: true);
//       return;
//     }
//
//     int? parsedPoints = int.tryParse(points);
//     if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
//       _showMessage('Points must be between 10 and 1000.', isError: true);
//       return;
//     }
//
//     final existingIndex = addedEntries.indexWhere(
//       (entry) =>
//           entry['digit'] == digit && entry['type'] == selectedGameBetType,
//     );
//
//     setState(() {
//       if (existingIndex != -1) {
//         final currentPoints = int.parse(addedEntries[existingIndex]['points']!);
//         addedEntries[existingIndex]['points'] = (currentPoints + parsedPoints)
//             .toString();
//         _showMessage(
//           'Updated points for Motor Patti: $digit, Type: $selectedGameBetType.',
//         );
//       } else {
//         addedEntries.add({
//           "digit": digit,
//           "points": points,
//           "type": selectedGameBetType,
//         });
//         _showMessage(
//           'Added bid: Motor Patti $digit, Points $points, Type $selectedGameBetType.',
//         );
//       }
//       digitController.clear();
//       pointsController.clear();
//       _isDigitSuggestionsVisible = false; // Hide suggestions after adding
//     });
//   }
//
//   void _removeEntry(int index) {
//     if (_isApiCalling) return;
//
//     setState(() {
//       final removedEntry = addedEntries[index];
//       addedEntries.removeAt(index);
//       _showMessage(
//         'Removed bid: Motor Patti ${removedEntry['digit']}, Type ${removedEntry['type']}.',
//       );
//     });
//   }
//
//   int _getTotalPoints() {
//     return addedEntries.fold(
//       0,
//       (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
//     );
//   }
//
//   void _showConfirmationDialog() {
//     _clearMessage();
//     if (_isApiCalling) return;
//
//     if (addedEntries.isEmpty) {
//       _showMessage('Please add at least one bid.', isError: true);
//       return;
//     }
//
//     final int totalPoints = _getTotalPoints();
//
//     if (walletBalance < totalPoints) {
//       _showMessage(
//         'Insufficient wallet balance to place this bid.',
//         isError: true,
//       );
//       return;
//     }
//
//     final String formattedDate = DateFormat(
//       'dd MMM yyyy, hh:mm a',
//     ).format(DateTime.now());
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return BidConfirmationDialog(
//           gameTitle: widget.gameName,
//           gameDate: formattedDate,
//           bids: addedEntries.map((bid) {
//             return {
//               "digit": bid['digit']!,
//               "points": bid['points']!,
//               "type": bid['type']!,
//               "pana": bid['digit']!,
//             };
//           }).toList(),
//           totalBids: addedEntries.length,
//           totalBidsAmount: totalPoints,
//           walletBalanceBeforeDeduction: walletBalance,
//           walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameCategoryType,
//           onConfirm: () async {
//             Navigator.pop(dialogContext);
//             setState(() {
//               _isApiCalling = true;
//             });
//             bool success = await _placeFinalBids();
//             if (success) {
//               setState(() {
//                 addedEntries.clear();
//               });
//             }
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
//   Future<bool> _placeFinalBids() async {
//     String url;
//     final gameCategory = widget.gameCategoryType.toLowerCase();
//
//     if (gameCategory.contains('jackpot')) {
//       url = '${Constant.apiEndpoint}place-jackpot-bid';
//     } else if (gameCategory.contains('starline')) {
//       url = '${Constant.apiEndpoint}place-starline-bid';
//     } else {
//       url = '${Constant.apiEndpoint}place-bid';
//     }
//
//     if (accessToken.isEmpty || registerId.isEmpty) {
//       if (mounted) {
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (BuildContext context) {
//             return const BidFailureDialog(
//               errorMessage: 'Authentication error. Please log in again.',
//             );
//           },
//         );
//       }
//       return false;
//     }
//
//     final headers = {
//       'deviceId': _deviceId,
//       'deviceName': _deviceName,
//       'accessStatus': accountStatus ? '1' : '0',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $accessToken',
//     };
//
//     final List<Map<String, dynamic>> bidPayload = addedEntries.map((entry) {
//       final String bidDigit = entry['digit'] ?? '';
//       final int bidAmount = int.tryParse(entry['points'] ?? '0') ?? 0;
//
//       return {
//         "sessionType": entry['type']?.toUpperCase() ?? '',
//         "digit": bidDigit,
//         "pana": bidDigit,
//         "bidAmount": bidAmount,
//       };
//     }).toList();
//
//     final body = jsonEncode({
//       "registerId": registerId,
//       "gameId": widget.gameId,
//       "bidAmount": _getTotalPoints(),
//       "gameType": gameCategory,
//       "bid": bidPayload,
//     });
//
//     log('Placing bid to URL: $url');
//     log('Request Headers: $headers');
//     log('Request Body: $body');
//
//     try {
//       final response = await http.post(
//         Uri.parse(url),
//         headers: headers,
//         body: body,
//       );
//
//       final Map<String, dynamic> responseBody = json.decode(response.body);
//       log('API Response: $responseBody');
//
//       if (response.statusCode == 200 && responseBody['status'] == true) {
//         int newWalletBalance = walletBalance - _getTotalPoints();
//         await storage.write('walletBalance', newWalletBalance);
//
//         if (mounted) {
//           setState(() {
//             walletBalance = newWalletBalance;
//           });
//           showDialog(
//             context: context,
//             barrierDismissible: false,
//             builder: (BuildContext context) {
//               return const BidSuccessDialog();
//             },
//           );
//         }
//         return true;
//       } else {
//         String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
//         if (mounted) {
//           showDialog(
//             context: context,
//             barrierDismissible: false,
//             builder: (BuildContext context) {
//               return BidFailureDialog(errorMessage: errorMessage);
//             },
//           );
//         }
//         return false;
//       }
//     } catch (e) {
//       log('Error during bid submission: $e');
//       if (mounted) {
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (BuildContext context) {
//             return const BidFailureDialog(
//               errorMessage:
//                   'Network error. Please check your internet connection.',
//             );
//           },
//         );
//       }
//       return false;
//     }
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
//                     // Game Type Dropdown
//                     _inputRow("Select Game Type:", _buildDropdown()),
//                     const SizedBox(height: 12),
//                     // Digit Input Field with suggestions
//                     _inputRow("Enter 3-Digit Number:", _buildDigitInputField()),
//                     // --- Added suggestions list conditionally ---
//                     if (_isDigitSuggestionsVisible &&
//                         filteredDigitOptions.isNotEmpty)
//                       Container(
//                         margin: const EdgeInsets.only(top: 8),
//                         constraints: const BoxConstraints(
//                           maxHeight: 200,
//                         ), // Limit height
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
//                                   _isDigitSuggestionsVisible =
//                                       false; // Hide on selection
//                                   // Move cursor to end of text
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
//                     // --- End Added suggestions list ---
//                     const SizedBox(
//                       height: 12,
//                     ), // Adjust spacing after digit input
//                     // Points Input Field
//                     _inputRow(
//                       "Enter Points:",
//                       _buildTextField(
//                         pointsController,
//                         "Enter Amount",
//                         inputFormatters: [
//                           FilteringTextInputFormatter.digitsOnly,
//                           LengthLimitingTextInputFormatter(
//                             4,
//                           ), // Max 4 digits for points
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 20),
//                     SizedBox(
//                       width: double.infinity,
//                       height: 45,
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.amber,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                         ),
//                         onPressed: _isApiCalling
//                             ? null
//                             : _addEntry, // Disable if API is calling
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
//               // List Headers
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
//               // List of Added Entries
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
//                                     entry['points']!,
//                                     style: GoogleFonts.poppins(),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   child: Text(
//                                     entry['type']!,
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
//                                       : () => _removeEntry(
//                                           index,
//                                         ), // Disable if API is calling
//                                 ),
//                               ],
//                             ),
//                           );
//                         },
//                       ),
//               ),
//               // Bottom Summary Bar
//               if (addedEntries.isNotEmpty) _buildBottomBar(),
//             ],
//           ),
//           // Animated Message Bar
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
//   // Updated to accept 3-digit input and show suggestions
//   Widget _buildDigitInputField() {
//     return SizedBox(
//       width: double.infinity,
//       height: 35,
//       child: TextFormField(
//         controller: digitController,
//         cursorColor: Colors.amber,
//         keyboardType: TextInputType.number,
//         style: GoogleFonts.poppins(fontSize: 14),
//         inputFormatters: [
//           LengthLimitingTextInputFormatter(3),
//           FilteringTextInputFormatter.digitsOnly,
//         ],
//         onTap: () {
//           _clearMessage();
//           _onDigitChanged(); // Trigger suggestions on tap if text is present
//         },
//         onChanged: (value) {
//           _onDigitChanged(); // Filter suggestions as user types
//         },
//         enabled: !_isApiCalling,
//         decoration: InputDecoration(
//           hintText: "Enter 3-Digit Number",
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
//             borderSide: const BorderSide(color: Colors.amber, width: 2),
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
//         cursorColor: Colors.amber,
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
//             borderSide: const BorderSide(color: Colors.amber, width: 2),
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
//             onPressed: _isApiCalling
//                 ? null
//                 : _showConfirmationDialog, // Disable if API is calling
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _isApiCalling
//                   ? Colors.grey
//                   : Colors.amber, // Dim if disabled
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
