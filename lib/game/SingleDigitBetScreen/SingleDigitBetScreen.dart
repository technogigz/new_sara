import 'dart:async'; // For Timer
import 'dart:convert'; // For jsonEncode, json.decode
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // For API calls
import 'package:intl/intl.dart'; // Import for date formatting

import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../ulits/Constents.dart'; // Import the Constants file for API endpoint

// AnimatedMessageBar component (Ensure this is a common component or defined here)
// If this component is already defined in a separate file (e.g., components/animated_message_bar.dart)
// then you should import it and remove this duplicate definition.
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
  // Renamed for clarity: this is the *category* of the game (e.g., "singleDigits")
  final String gameCategoryType;
  final int gameId;
  final String gameName;

  const SingleDigitBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType, // Using this as the main game type identifier
  });

  @override
  State<SingleDigitBetScreen> createState() => _SingleDigitBetScreenState();
}

class _SingleDigitBetScreenState extends State<SingleDigitBetScreen> {
  // These are the actual options for the dropdown (Open/Close)
  final List<String> gameTypesOptions = ["Open", "Close"];
  // This will hold the currently selected value in the dropdown (e.g., "Open" or "Close")
  late String selectedGameBetType;

  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  List<Map<String, String>> addedEntries = [];
  late GetStorage storage = GetStorage();
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance;

  // Placeholder for device info. In a real app, these would be dynamic.
  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  // State management for AnimatedMessageBar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey(); // Key to force rebuild/re-animation

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupStorageListeners();
  }

  // Load initial data from GetStorage
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
      walletBalance = 0; // Default to 0 if it's not an int or a valid string
    }

    selectedGameBetType = gameTypesOptions[0]; // Set default to "Open"
  }

  // Set up listeners for GetStorage keys
  void _setupStorageListeners() {
    storage.listenKey('accessToken', (value) {
      setState(() {
        accessToken = value ?? '';
      });
    });

    storage.listenKey('registerId', (value) {
      setState(() {
        registerId = value ?? '';
      });
    });

    storage.listenKey('accountStatus', (value) {
      setState(() {
        accountStatus = value ?? false;
      });
    });

    storage.listenKey('selectedLanguage', (value) {
      setState(() {
        preferredLanguage = value ?? 'en';
      });
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
    digitController.dispose();
    pointsController.dispose();
    super.dispose();
  }

  // Helper method to show messages using AnimatedMessageBar
  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey(); // Update key to trigger animation
    });
  }

  // Helper method to clear the message bar
  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  void _addEntry() {
    _clearMessage(); // Clear any previous messages
    final digit = digitController.text.trim();
    final points = pointsController.text.trim();

    if (digit.isEmpty || points.isEmpty) {
      _showMessage('Please enter both Digit and Amount.', isError: true);
      return;
    }

    // Validate digit: must be a single digit (0-9)
    if (digit.length != 1 || int.tryParse(digit) == null) {
      _showMessage(
        'Please enter a single digit (0-9) for Bid Digits.',
        isError: true,
      );
      return;
    }

    // Validate points: must be a number between 10 and 1000
    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    // Check for existing bid with same digit and type
    final existingIndex = addedEntries.indexWhere(
      (entry) =>
          entry['digit'] == digit && entry['type'] == selectedGameBetType,
    );

    setState(() {
      if (existingIndex != -1) {
        // Update existing entry
        final currentPoints = int.parse(addedEntries[existingIndex]['points']!);
        addedEntries[existingIndex]['points'] = (currentPoints + parsedPoints)
            .toString();
        _showMessage(
          'Updated points for Digit: $digit, Type: $selectedGameBetType.',
        );
      } else {
        // Add new entry
        addedEntries.add({
          "digit": digit,
          "points": points,
          "type": selectedGameBetType,
        });
        _showMessage(
          'Added bid: Digit $digit, Points $points, Type $selectedGameBetType.',
        );
      }
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
      (sum, item) => int.tryParse(item['points'] ?? '0') == null
          ? sum
          : sum + int.parse(item['points']!),
    );
  }

  void _showConfirmationDialog() {
    _clearMessage(); // Clear any previous messages
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
      barrierDismissible: false, // User must interact with the dialog
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.gameName,
          gameDate: formattedDate,
          bids: addedEntries.map((bid) {
            return {
              "digit": bid['digit']!,
              "points": bid['points']!,
              "type": bid['type']!, // This will be "Open" or "Close"
            };
          }).toList(),
          totalBids: addedEntries.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameCategoryType, // e.g., "singleDigits"
          onConfirm: () async {
            Navigator.pop(dialogContext); // Dismiss the confirmation dialog
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                addedEntries.clear(); // Clear bids on successful submission
              });
              _showMessage('Bids placed successfully!');
            }
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    String url;
    // Determine the correct API endpoint based on game category
    if (widget.gameCategoryType.toLowerCase().contains('jackpot')) {
      url = '${Constant.apiEndpoint}place-jackpot-bid';
    } else if (widget.gameCategoryType.toLowerCase().contains('starline')) {
      url = '${Constant.apiEndpoint}place-starline-bid';
    } else {
      url = '${Constant.apiEndpoint}place-bid'; // General bid placement
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      // Check mounted before showing dialog
      if (!mounted) return false; // Important: Exit if widget is not mounted
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return const BidFailureDialog(
            errorMessage: 'Authentication error. Please log in again.',
          );
        },
      );
      return false;
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0', // Convert bool to '1' or '0'
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final List<Map<String, dynamic>> bidPayload = addedEntries.map((entry) {
      return {
        "sessionType": entry['type']!.toUpperCase(), // "OPEN" or "CLOSE"
        "digit": entry['digit']!,
        "bidAmount": int.tryParse(entry['points'] ?? '0') ?? 0,
      };
    }).toList();

    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId,
      "bidAmount": _getTotalPoints(),
      "gameType": widget.gameCategoryType, // e.g., "singleDigits"
      "bid": bidPayload,
    });

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
        body: body,
      );

      final Map<String, dynamic> responseBody = json.decode(response.body);

      log('API Response for Final Bid Submission: ${responseBody}');

      if (response.statusCode == 200 && responseBody['status'] == true) {
        // Update wallet balance in GetStorage and local state on successful bid
        log('Bid submission successful. ${responseBody['msg']}');
        int currentWallet = walletBalance;
        int deductedAmount = _getTotalPoints();
        int newWalletBalance = currentWallet - deductedAmount;
        storage.write(
          'walletBalance',
          newWalletBalance.toString(),
        ); // Update storage

        // Check mounted before calling setState
        if (mounted) {
          setState(() {
            walletBalance = newWalletBalance; // Update local state
          });
        }

        // Check mounted before showing dialog
        if (!mounted) return true; // Important: Exit if widget is not mounted
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return const BidSuccessDialog();
          },
        );
        return true; // Indicate success
      } else {
        String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
        // Check mounted before showing dialog
        if (!mounted) return false; // Important: Exit if widget is not mounted
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return BidFailureDialog(errorMessage: errorMessage);
          },
        );
        return false; // Indicate failure
      }
    } catch (e) {
      log('Network error during bid submission: $e');
      // Check mounted before showing dialog
      if (!mounted) return false; // Important: Exit if widget is not mounted
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return BidFailureDialog(
            errorMessage:
                'Network error during bid submission: ${e.toString()}',
          );
        },
      );
      return false; // Indicate failure
    }
  }

  // Future<bool> _placeFinalBids() async {
  //   String url;
  //   // Determine the correct API endpoint based on game category
  //   if (widget.gameCategoryType.toLowerCase().contains('jackpot')) {
  //     url = '${Constant.apiEndpoint}place-jackpot-bid';
  //   } else if (widget.gameCategoryType.toLowerCase().contains('starline')) {
  //     url = '${Constant.apiEndpoint}place-starline-bid';
  //   } else {
  //     url = '${Constant.apiEndpoint}place-bid'; // General bid placement
  //   }
  //
  //   if (accessToken.isEmpty || registerId.isEmpty) {
  //     // Using the failure dialog here
  //     showDialog(
  //       context: context,
  //       builder: (BuildContext context) {
  //         return const BidFailureDialog(
  //           errorMessage: 'Authentication error. Please log in again.',
  //         );
  //       },
  //     );
  //     return false;
  //   }
  //
  //   final headers = {
  //     'deviceId': _deviceId,
  //     'deviceName': _deviceName,
  //     'accessStatus': accountStatus ? '1' : '0', // Convert bool to '1' or '0'
  //     'Content-Type': 'application/json',
  //     'Authorization': 'Bearer $accessToken',
  //   };
  //
  //   final List<Map<String, dynamic>> bidPayload = addedEntries.map((entry) {
  //     return {
  //       "sessionType": entry['type']!.toUpperCase(), // "OPEN" or "CLOSE"
  //       "digit": entry['digit']!,
  //       "bidAmount": int.tryParse(entry['points'] ?? '0') ?? 0,
  //     };
  //   }).toList();
  //
  //   final body = jsonEncode({
  //     "registerId": registerId,
  //     "gameId": widget.gameId,
  //     "bidAmount": _getTotalPoints(),
  //     "gameType": widget.gameCategoryType, // e.g., "singleDigits"
  //     "bid": bidPayload,
  //   });
  //
  //   // Log the cURL and headers here
  //   String curlCommand = 'curl -X POST \\';
  //   curlCommand += '\n  ${Uri.parse(url)} \\';
  //   headers.forEach((key, value) {
  //     curlCommand += '\n  -H "$key: $value" \\';
  //   });
  //   curlCommand += '\n  -d \'$body\'';
  //
  //   log('CURL Command for Final Bid Submission:\n$curlCommand');
  //   log('Request Headers for Final Bid Submission: $headers');
  //   log('Request Body for Final Bid Submission: $body');
  //
  //   try {
  //     final response = await http.post(
  //       Uri.parse(url),
  //       headers: headers,
  //       body: body,
  //     );
  //
  //     final Map<String, dynamic> responseBody = json.decode(response.body);
  //
  //     log('API Response for Final Bid Submission: ${responseBody}');
  //
  //     if (response.statusCode == 200 && responseBody['status'] == true) {
  //       // Update wallet balance in GetStorage and local state on successful bid
  //       log('Bid submission successful. ${responseBody['msg']}');
  //       int currentWallet = walletBalance;
  //       int deductedAmount = _getTotalPoints();
  //       int newWalletBalance = currentWallet - deductedAmount;
  //       storage.write(
  //         'walletBalance',
  //         newWalletBalance.toString(),
  //       ); // Update storage
  //       setState(() {
  //         walletBalance = newWalletBalance; // Update local state
  //       });
  //
  //       // Show success dialog
  //       showDialog(
  //         context: context,
  //         builder: (BuildContext context) {
  //           return const BidSuccessDialog();
  //         },
  //       );
  //       return true; // Indicate success
  //     } else {
  //       String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
  //       // Show failure dialog with specific error message
  //       showDialog(
  //         context: context,
  //         builder: (BuildContext context) {
  //           return BidFailureDialog(errorMessage: errorMessage);
  //         },
  //       );
  //       return false; // Indicate failure
  //     }
  //   } catch (e) {
  //     log('Network error during bid submission: $e');
  //     // Show failure dialog for network errors
  //     showDialog(
  //       context: context,
  //       builder: (BuildContext context) {
  //         return BidFailureDialog(
  //           errorMessage:
  //               'Network error during bid submission: ${e.toString()}',
  //         );
  //       },
  //     );
  //     return false; // Indicate failure
  //   }
  // }

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
              walletBalance.toString(), // Display actual wallet balance
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
                    _inputRow(
                      "Enter Single Digit:",
                      _buildTextField(
                        digitController,
                        "Bid Digits",
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(1),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
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
                            letterSpacing: 0.5,
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
          // AnimatedMessageBar positioned at the top
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
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
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
                _clearMessage(); // Clear message on dropdown change
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
        onTap: _clearMessage, // Clear message on tap
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
            onPressed: _showConfirmationDialog, // Call the new method
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
