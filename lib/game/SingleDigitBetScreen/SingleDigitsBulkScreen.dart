import 'dart:async'; // For Timer
import 'dart:convert';
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../ulits/Constents.dart'; // Assuming Constent.apiEndpoint is correct

// AnimatedMessageBar component (remains largely the same, optimized for reusability)
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

class SingleDigitsBulkScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameName;
  final String gameType; // This should be like "singleDigits"

  const SingleDigitsBulkScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameType,
  }) : super(key: key);

  @override
  State<SingleDigitsBulkScreen> createState() => _SingleDigitsBulkScreenState();
}

class _SingleDigitsBulkScreenState extends State<SingleDigitsBulkScreen> {
  String selectedGameType = 'Open'; // This refers to sessionType (Open/Close)
  final List<String> gameTypes = ['Open', 'Close'];

  final TextEditingController pointsController = TextEditingController();

  Color dropdownBorderColor = Colors.black;
  Color textFieldBorderColor = Colors.black;

  // bidAmounts maps digit (e.g., "7") to amount (e.g., "100")
  Map<String, String> bidAmounts = {};
  late GetStorage storage;

  late String _accessToken; // Renamed to private to match common convention
  late String _registerId; // Renamed to private
  bool _accountStatus = false; // Renamed to private
  int _walletBalance = 0; // Renamed to private, directly storing int

  // --- AnimatedMessageBar State Management ---
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  // --- End AnimatedMessageBar State Management ---

  bool _isApiCalling = false; // To show loading during API calls
  bool _isWalletLoading = true; // Added for initial wallet loading state

  // Device info (can be loaded from storage or directly assigned for testing)
  String _deviceId = 'test_device_id_flutter';
  String _deviceName = 'test_device_name_flutter';

  @override
  void initState() {
    super.initState();
    storage = GetStorage(); // Initialize GetStorage
    _loadInitialData();
    _setupStorageListeners();
  }

  // Asynchronously loads initial user data and wallet balance from GetStorage
  Future<void> _loadInitialData() async {
    _accessToken = storage.read('accessToken') ?? '';
    _registerId = storage.read('registerId') ?? '';
    _accountStatus = storage.read('accountStatus') ?? false;

    // Safely parse wallet balance, handling both String and int types
    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is String) {
      _walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else if (storedWalletBalance is int) {
      _walletBalance = storedWalletBalance;
    } else {
      _walletBalance = 0;
    }

    setState(() {
      _isWalletLoading = false; // Mark wallet loading as complete
    });
  }

  // Sets up listeners for changes in specific GetStorage keys, updating UI state
  void _setupStorageListeners() {
    storage.listenKey('accessToken', (value) {
      if (mounted) {
        setState(() {
          _accessToken = value ?? '';
        });
      }
    });
    storage.listenKey('registerId', (value) {
      if (mounted) {
        setState(() {
          _registerId = value ?? '';
        });
      }
    });
    storage.listenKey('accountStatus', (value) {
      if (mounted) {
        setState(() {
          _accountStatus = value ?? false;
        });
      }
    });
    storage.listenKey('walletBalance', (value) {
      if (mounted) {
        setState(() {
          if (value is String) {
            _walletBalance = int.tryParse(value) ?? 0;
          } else if (value is int) {
            _walletBalance = value;
          } else {
            _walletBalance = 0;
          }
          _isWalletLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    pointsController.dispose();
    super.dispose();
  }

  // --- AnimatedMessageBar Helper Methods ---
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey(); // Force rebuild of message bar
    });
  }

  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }
  // --- End AnimatedMessageBar Helper Methods ---

  void onNumberPressed(String number) {
    _clearMessage();
    if (_isApiCalling) return; // Prevent adding bids while API is in progress

    final amount = pointsController.text.trim();
    if (amount.isEmpty) {
      _showMessage('Please enter an amount first.', isError: true);
      return;
    }

    int? parsedAmount = int.tryParse(amount);
    if (parsedAmount == null || parsedAmount < 10 || parsedAmount > 1000) {
      // Assuming a max bid of 1000, adjust as per your rules
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    if (parsedAmount > _walletBalance) {
      _showMessage(
        'Insufficient wallet balance to add this bid.',
        isError: true,
      );
      return;
    }

    // Check if bid for this digit already exists to update or add
    if (bidAmounts.containsKey(number)) {
      _showMessage(
        'Bid for Digit $number already exists. Updating amount.',
        isError: false,
      );
    } else {
      _showMessage('Added bid for Digit: $number, Amount: $amount');
    }

    setState(() {
      bidAmounts[number] = amount;
    });
  }

  int _getTotalPoints() {
    return bidAmounts.values
        .map((e) => int.tryParse(e) ?? 0)
        .fold(0, (a, b) => a + b);
  }

  // --- Confirmation Dialog and Final Bid Submission ---
  void _showConfirmationDialog() {
    _clearMessage();
    if (bidAmounts.isEmpty) {
      _showMessage('Please add at least one bid.', isError: true);
      return;
    }

    final int totalPoints = _getTotalPoints();

    if (_walletBalance < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place these bids.',
        isError: true,
      );
      return;
    }

    List<Map<String, String>> bidsForDialog = [];
    bidAmounts.forEach((digit, amount) {
      bidsForDialog.add({
        "digit": digit,
        "points": amount,
        "type": selectedGameType,
        "pana": "", // For single digits, pana is empty or not applicable
      });
    });

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle:
              "${widget.gameName}, ${widget.gameType} - ${DateFormat('dd-MM-yyyy').format(DateTime.now())}",
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
            Navigator.pop(dialogContext); // Dismiss the confirmation dialog

            setState(() {
              _isApiCalling = true; // Show loading indicator
            });

            bool success =
                await _placeFinalBids(); // Call the actual API submission

            setState(() {
              _isApiCalling = false; // Hide loading indicator
              if (success) {
                // Wallet balance updated in _placeFinalBids already
                bidAmounts.clear(); // Clear bids only on success
                _showMessage('Bids submitted successfully!');
                // Success dialog is shown from _placeFinalBids
              } else {
                // Failure dialog is shown from _placeFinalBids
              }
            });
          },
        );
      },
    );
  }

  // Future<bool> _placeFinalBids() async {
  //   String apiUrl;
  //   if (widget.gameName.toLowerCase().contains('jackpot')) {
  //     apiUrl = '${Constant.apiEndpoint}place-jackpot-bid';
  //   } else if (widget.gameName.toLowerCase().contains('starline')) {
  //     apiUrl = '${Constant.apiEndpoint}place-starline-bid';
  //   } else {
  //     apiUrl = '${Constant.apiEndpoint}place-bid';
  //   }
  //
  //   if (_accessToken.isEmpty || _registerId.isEmpty) {
  //     if (mounted) {
  //       showDialog(
  //         context: context,
  //         builder: (BuildContext context) {
  //           return const BidFailureDialog(
  //             errorMessage: 'Authentication error. Please log in again.',
  //           );
  //         },
  //       );
  //     }
  //     return false;
  //   }
  //
  //   final headers = {
  //     'deviceId': _deviceId,
  //     'deviceName': _deviceName,
  //     'accessStatus': _accountStatus ? '1' : '0', // Convert bool to '1' or '0'
  //     'Content-Type': 'application/json',
  //     'Authorization': 'Bearer $_accessToken',
  //   };
  //
  //   // --- IMPORTANT: Prepare the LIST of individual bid objects for the API ---
  //   final List<Map<String, dynamic>> bidPayloadList = [];
  //   bidAmounts.forEach((digit, amount) {
  //     bidPayloadList.add({
  //       "sessionType": selectedGameType.toUpperCase(),
  //       "digit": digit, // For single digits, 'digit' holds the actual digit
  //       "pana": "", // For single digits, 'pana' is empty or not applicable
  //       "bidAmount": int.tryParse(amount) ?? 0,
  //     });
  //   });
  //
  //   final int totalBidAmount =
  //       _getTotalPoints(); // Total points for all bids being submitted
  //
  //   final body = {
  //     "registerId": _registerId,
  //     "gameId": widget.gameId.toString(), // Ensure gameId is string
  //     "bidAmount":
  //         totalBidAmount, // This is the TOTAL amount for this bulk submission
  //     "gameType": widget.gameType,
  //     "bid": bidPayloadList, // This is the list of individual bids
  //   };
  //
  //   // --- Logging cURL command for debugging ---
  //   String curlCommand = 'curl -X POST \\\n  $apiUrl \\';
  //   headers.forEach((key, value) {
  //     curlCommand += '\n  -H "$key: $value" \\';
  //   });
  //   curlCommand += '\n  -d \'${jsonEncode(body)}\'';
  //
  //   log('CURL Command for Final Bid Submission:\n$curlCommand', name: 'BidAPI');
  //   log('Request Headers for Final Bid Submission: $headers', name: 'BidAPI');
  //   log(
  //     'Request Body for Final Bid Submission: ${jsonEncode(body)}',
  //     name: 'BidAPI',
  //   );
  //   // --- End logging ---
  //
  //   try {
  //     final response = await http.post(
  //       Uri.parse(apiUrl),
  //       headers: headers,
  //       body: jsonEncode(body),
  //     );
  //
  //     log('Response Status Code: ${response.statusCode}', name: 'BidAPI');
  //     log('Response Body: ${response.body}', name: 'BidAPI');
  //
  //     final Map<String, dynamic> responseBody = json.decode(response.body);
  //     log('Resonse responseBody: ${response.statusCode}', name: 'responseBody');
  //     log(
  //       'Resonse responseBody: ${responseBody['status']}',
  //       name: 'responseBody',
  //     );
  //     if (mounted) {
  //       if (response.statusCode == 200 && responseBody['status'] == true) {
  //         // Update wallpet balance in GetStorage and state
  //         int newWalletBalance = _walletBalance - totalBidAmount;
  //         await storage.write(
  //           'walletBalance',
  //           newWalletBalance.toString(),
  //         ); // Use await for storage write
  //
  //         showDialog(
  //           context: context,
  //           barrierDismissible: false,
  //           builder: (BuildContext dialogContext) {
  //             return const BidSuccessDialog();
  //           },
  //         );
  //
  //         setState(() {
  //           _walletBalance = newWalletBalance;
  //         });
  //         // Show success dialog
  //
  //         return true; // Indicate success
  //       } else {
  //         String errorMessage =
  //             responseBody['msg'] ?? "Unknown error occurred.";
  //         showDialog(
  //           context: context,
  //           builder: (BuildContext dialogContext) {
  //             return BidFailureDialog(errorMessage: errorMessage);
  //           },
  //         );
  //         return false; // Indicate failure
  //       }
  //     }
  //     return false; // Should not be reached if mounted, but for completeness
  //   } catch (e) {
  //     log('Network error during bid submission: $e', name: 'BidAPIError');
  //     return false; // Indicate failure
  //   }
  // }

  Future<bool> _placeFinalBids() async {
    String apiUrl;
    if (widget.gameName.toLowerCase().contains('jackpot')) {
      apiUrl = '${Constant.apiEndpoint}place-jackpot-bid';
    } else if (widget.gameName.toLowerCase().contains('starline')) {
      apiUrl = '${Constant.apiEndpoint}place-starline-bid';
    } else {
      apiUrl = '${Constant.apiEndpoint}place-bid';
    }

    if (_accessToken.isEmpty || _registerId.isEmpty) {
      if (mounted) {
        // Await the dialog to ensure it's shown before returning
        await showDialog(
          // Added await here
          context: context,
          builder: (BuildContext context) {
            return const BidFailureDialog(
              errorMessage: 'Authentication error. Please log in again.',
            );
          },
        );
      }
      return false;
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': _accountStatus ? '1' : '0', // Convert bool to '1' or '0'
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

    // --- IMPORTANT: Prepare the LIST of individual bid objects for the API ---
    final List<Map<String, dynamic>> bidPayloadList = [];
    bidAmounts.forEach((digit, amount) {
      bidPayloadList.add({
        "sessionType": selectedGameType.toUpperCase(),
        "digit": digit, // For single digits, 'digit' holds the actual digit
        "pana": "", // For single digits, 'pana' is empty or not applicable
        "bidAmount": int.tryParse(amount) ?? 0,
      });
    });

    final int totalBidAmount =
        _getTotalPoints(); // Total points for all bids being submitted

    final body = {
      "registerId": _registerId,
      "gameId": widget.gameId.toString(), // Ensure gameId is string
      "bidAmount":
          totalBidAmount, // This is the TOTAL amount for this bulk submission
      "gameType": widget.gameType,
      "bid": bidPayloadList, // This is the list of individual bids
    };

    // --- Logging cURL command for debugging ---
    String curlCommand = 'curl -X POST \\\n  $apiUrl \\';
    headers.forEach((key, value) {
      curlCommand += '\n  -H "$key: $value" \\';
    });
    curlCommand += '\n  -d \'${jsonEncode(body)}\'';

    log('CURL Command for Final Bid Submission:\n$curlCommand', name: 'BidAPI');
    log('Request Headers for Final Bid Submission: $headers', name: 'BidAPI');
    log(
      'Request Body for Final Bid Submission: ${jsonEncode(body)}',
      name: 'BidAPI',
    );
    // --- End logging ---

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(body),
      );

      log('Response Status Code: ${response.statusCode}', name: 'BidAPI');
      log('Response Body: ${response.body}', name: 'BidAPI');

      final Map<String, dynamic> responseBody = json.decode(response.body);
      log('Resonse responseBody: ${response.statusCode}', name: 'responseBody');
      log(
        'Resonse responseBody: ${responseBody['status']}',
        name: 'responseBody',
      );
      if (mounted) {
        if (response.statusCode == 200 && responseBody['status'] == true) {
          // Update wallpet balance in GetStorage and state
          int newWalletBalance = _walletBalance - totalBidAmount;
          await storage.write(
            'walletBalance',
            newWalletBalance.toString(),
          ); // Use await for storage write

          // Await the dialog to ensure it's shown before returning
          await showDialog(
            // Added await here
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return const BidSuccessDialog();
            },
          );

          setState(() {
            _walletBalance = newWalletBalance;
          });
          // Show success dialog

          return true; // Indicate success
        } else {
          String errorMessage =
              responseBody['msg'] ?? "Unknown error occurred.";
          // Await the dialog to ensure it's shown before returning
          await showDialog(
            // Added await here
            context: context,
            builder: (BuildContext dialogContext) {
              return BidFailureDialog(errorMessage: errorMessage);
            },
          );
          return false; // Indicate failure
        }
      }
      return false; // Should not be reached if mounted, but for completeness
    } catch (e) {
      log('Network error during bid submission: $e', name: 'BidAPIError');
      if (mounted) {
        // Ensure context is still valid if an error occurs
        await showDialog(
          // Added await here
          context: context,
          builder: (BuildContext context) {
            return const BidFailureDialog(
              errorMessage:
                  'Network error. Please check your internet connection.',
            );
          },
        );
      }
      return false; // Indicate failure
    }
  }

  Widget _buildDropdown() {
    return SizedBox(
      height: 35,
      width: 150,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: dropdownBorderColor),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedGameType,
              icon: const Icon(Icons.keyboard_arrow_down),
              onChanged: _isApiCalling
                  ? null // Disable dropdown while API call is in progress
                  : (String? newValue) {
                      setState(() {
                        selectedGameType = newValue!;
                        dropdownBorderColor = Colors.amber;
                        _clearMessage();
                      });
                    },
              items: gameTypes.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: GoogleFonts.poppins(fontSize: 14)),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return SizedBox(
      height: 35,
      width: 150,
      child: TextFormField(
        controller: pointsController,
        cursorColor: Colors.amber,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Enter Amount',
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
        onTap: () {
          setState(() {
            textFieldBorderColor = Colors.amber;
            _clearMessage();
          });
        },
        enabled: !_isApiCalling, // Disable text field during API call
      ),
    );
  }

  Widget _inputRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          field,
        ],
      ),
    );
  }

  Widget _buildNumberPad() {
    final numbers = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: numbers.map((number) {
        return GestureDetector(
          onTap: _isApiCalling
              ? null // Disable tap if an API call is in progress
              : () => onNumberPressed(number),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isApiCalling
                      ? Colors.grey
                      : Colors.amber, // Dim if disabled
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isApiCalling
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Text(
                  number,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (bidAmounts[number] != null)
                Positioned(
                  top: 4,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent, // Changed to transparent
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bidAmounts[number]!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white, // Amount text color
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalAmount = _getTotalPoints();

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // Handle wallet tap if needed
                  },
                  child: SizedBox(
                    height: 42,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Image.asset(
                          'assets/images/wallet_icon.png',
                          width: 24,
                          height: 24,
                          color: Colors.black, // Ensure icon color is visible
                        ),
                        const SizedBox(width: 4),
                        _isWalletLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                "₹${_walletBalance}", // Use _walletBalance
                                style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontSize: 16, // Consistent font size
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _inputRow("Select Game Type:", _buildDropdown()),
                _inputRow("Enter Points:", _buildTextField()),
                const SizedBox(height: 30),
                // Show CircularProgressIndicator if an API call is in progress
                _buildNumberPad(), // Number pad internally handles _isApiCalling visual state
                const SizedBox(height: 20),
                if (bidAmounts.isNotEmpty) // Only show headers if bids exist
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Digit',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Points',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Type',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // Space for delete icon
                      ],
                    ),
                  ),
                const Divider(height: 1, color: Colors.grey),
                Expanded(
                  child: bidAmounts.isEmpty
                      ? Center(
                          child: Text(
                            'No bids placed yet. Click a number to add a bid!',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: bidAmounts.length,
                          itemBuilder: (context, index) {
                            final digit = bidAmounts.keys.elementAt(index);
                            final amount = bidAmounts[digit]!;
                            return _buildBidEntryItem(
                              digit,
                              amount,
                              selectedGameType,
                            );
                          },
                        ),
                ),
              ],
            ),
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
          // Bottom total bar
          if (bidAmounts.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                          "Bids", // Changed to "Bids" for clarity
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          "${bidAmounts.length}",
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
                          "Points", // Changed to "Points" for clarity
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          "$totalAmount",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _isApiCalling
                          ? null
                          : _showConfirmationDialog, // Disable button while API is calling
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isApiCalling
                            ? Colors.grey
                            : Colors.amber, // Grey out when disabled
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24, // Consistent padding
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            8,
                          ), // Consistent border radius
                        ),
                        elevation: 3, // Consistent elevation
                      ),
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
                          : Text(
                              "SUBMIT", // Consistent text
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBidEntryItem(String digit, String points, String type) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                digit,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                points,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                type.toUpperCase(), // Display type in uppercase
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: type.toLowerCase() == 'open'
                      ? Colors.blue[700] // Differentiate open/close visually
                      : Colors.green[700],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _isApiCalling
                  ? null // Disable delete button while API is calling
                  : () {
                      setState(() {
                        final removedAmount = bidAmounts.remove(digit);
                        if (removedAmount != null) {
                          _showMessage(
                            'Removed bid for Digit: $digit, Amount: $removedAmount.',
                          );
                        }
                      });
                    },
            ),
          ],
        ),
      ),
    );
  }
}
