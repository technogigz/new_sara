import 'dart:async'; // For Timer
import 'dart:convert'; // For jsonEncode, json.decode
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // For API calls
import 'package:intl/intl.dart'; // Import for date formatting

import '../../../../components/BidConfirmationDialog.dart';
import '../../../../components/BidFailureDialog.dart';
import '../../../../components/BidSuccessDialog.dart';
import '../../../ulits/Constents.dart'; // Retained your original import path

// AnimatedMessageBar component (Ensure this is a common component or defined here)
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

class SingleDigitBetScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType;
  final int gameId;
  final String gameName;

  const SingleDigitBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
  });

  @override
  State<SingleDigitBetScreen> createState() => _SingleDigitBetScreenState();
}

class _SingleDigitBetScreenState extends State<SingleDigitBetScreen> {
  final List<String> gameTypesOptions = ["Open", "Close"];
  late String selectedGameBetType;

  // --- MODIFIED: Using a text controller for digit input with suggestions ---
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupStorageListeners();
    // --- NEW: Listener for digit input to show suggestions ---
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

    selectedGameBetType = gameTypesOptions[0];
  }

  void _setupStorageListeners() {
    storage.listenKey('accessToken', (value) {
      setState(() => accessToken = value ?? '');
    });
    storage.listenKey('registerId', (value) {
      setState(() => registerId = value ?? '');
    });
    storage.listenKey('accountStatus', (value) {
      setState(() => accountStatus = value ?? false);
    });
    storage.listenKey('selectedLanguage', (value) {
      setState(() => preferredLanguage = value ?? 'en');
    });
    storage.listenKey('walletBalance', (value) {
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

  @override
  void dispose() {
    // --- MODIFIED: Added digitController.dispose() ---
    digitController.removeListener(_onDigitChanged);
    digitController.dispose();
    pointsController.dispose();
    super.dispose();
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

  void _addEntry() {
    _clearMessage();
    // --- MODIFIED: Using digitController.text ---
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

    final existingIndex = addedEntries.indexWhere(
      (entry) =>
          entry['digit'] == digit && entry['type'] == selectedGameBetType,
    );

    setState(() {
      if (existingIndex != -1) {
        final currentPoints = int.parse(addedEntries[existingIndex]['points']!);
        addedEntries[existingIndex]['points'] = (currentPoints + parsedPoints)
            .toString();
        _showMessage(
          'Updated points for Digit: $digit, Type: $selectedGameBetType.',
        );
      } else {
        addedEntries.add({
          "digit": digit,
          "points": points,
          "type": selectedGameBetType,
        });
        _showMessage(
          'Added bid: Digit $digit, Points $points, Type $selectedGameBetType.',
        );
      }
      // --- MODIFIED: Clear controllers ---
      digitController.clear();
      pointsController.clear();
    });
  }

  void _removeEntry(int index) {
    _clearMessage();
    setState(() {
      final removedEntry = addedEntries[index];
      addedEntries.removeAt(index);
      _showMessage(
        'Removed bid: Digit ${removedEntry['digit']}, Type ${removedEntry['type']}.',
      );
    });
  }

  int _getTotalPoints() {
    return addedEntries.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  void _showConfirmationDialog() {
    _clearMessage();
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
          gameTitle: widget.title,
          gameDate: formattedDate,
          bids: addedEntries.map((bid) {
            return {
              "digit": bid['digit']!,
              "points": bid['points']!,
              "type": bid['type']!,
            };
          }).toList(),
          totalBids: addedEntries.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameCategoryType,
          onConfirm: () async {
            Navigator.pop(dialogContext);
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                addedEntries.clear();
              });
              _showMessage('Bids placed successfully!');
            }
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    // 1. Determine the API URL based on game category
    String url;
    final gameCategory = widget.gameCategoryType.toLowerCase();

    if (gameCategory.contains('jackpot')) {
      url = '${Constant.apiEndpoint}place-jackpot-bid';
    } else if (gameCategory.contains('starline')) {
      url = '${Constant.apiEndpoint}place-starline-bid';
    } else {
      url = '${Constant.apiEndpoint}place-bid';
    }

    // 2. Define request headers
    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus
          ? '1'
          : '0', // Convert boolean to string '1' or '0'
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    // 3. Construct the bid payload according to the API structure
    final List<Map<String, dynamic>> bidPayload = addedEntries.map((entry) {
      final String bidDigit = entry['digit'] ?? '';
      final int bidAmount = int.tryParse(entry['points'] ?? '0') ?? 0;
      final int pana =
          int.tryParse(entry['pana'] ?? '0') ??
          0; // Assume 'pana' is coming from entry

      return {
        "sessionType":
            entry['type']?.toUpperCase() ?? '', // Ensure type is uppercase
        "digit": bidDigit, // Directly use the digit value
        "pana": pana, // Use the 'pana' value if provided
        "bidAmount": bidAmount,
      };
    }).toList();

    // 4. Construct the full request body according to the API specification
    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId,
      "bidAmount": _getTotalPoints(), // This is the total bid amount
      "gameType": widget.gameCategoryType, // Use the original gameCategoryType
      "bid": bidPayload,
    });

    // Log request details for debugging
    log('Placing bid to URL: $url');
    log('Request Headers: $headers');
    log('Request Body: $body');

    // 5. Make the API call
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      final Map<String, dynamic> responseBody = json.decode(response.body);
      log('API Response: $responseBody');

      // 6. Handle API response
      if (response.statusCode == 200 && responseBody['status'] == true) {
        // Update wallet balance
        int newWalletBalance = walletBalance - _getTotalPoints();
        storage.write('walletBalance', newWalletBalance.toString());

        setState(() {
          walletBalance = newWalletBalance;
        });

        // Show success dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return const BidSuccessDialog();
          },
        );
        return true;
      } else {
        // Handle API-specific errors
        String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return BidFailureDialog(errorMessage: errorMessage);
          },
        );
        return false;
      }
    } catch (e) {
      // Handle network or parsing errors
      log('Error during bid submission: $e');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return BidFailureDialog(errorMessage: 'Error: ${e.toString()}');
        },
      );
      return false;
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
                    _inputRow("Select Game Type:", _buildDropdown()),
                    const SizedBox(height: 12),
                    // --- MODIFIED: Using the new digit input field with suggestions ---
                    _inputRow("Enter Single Digit:", _buildDigitInputField()),
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
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: _addEntry,
                        child: const Text(
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
                                    entry['points']!,
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry['type']!,
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeEntry(index),
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
            onChanged: (String? newValue) {
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

  // --- NEW: Text field with filtered suggestions ---
  Widget _buildDigitInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 35,
          child: TextFormField(
            controller: digitController,
            cursorColor: Colors.amber,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(fontSize: 14),
            inputFormatters: [
              LengthLimitingTextInputFormatter(1),
              FilteringTextInputFormatter.digitsOnly,
            ],
            onTap: _clearMessage,
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
                borderSide: const BorderSide(color: Colors.amber, width: 2),
              ),
            ),
          ),
        ),
        if (_isDigitSuggestionsVisible)
          Container(
            width: 150,
            height: 35,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 3,
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
                      FocusScope.of(context).unfocus(); // Hide keyboard
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
        cursorColor: Colors.amber,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: inputFormatters,
        onTap: _clearMessage,
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
            onPressed: _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
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
