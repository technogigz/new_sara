import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:new_sara/ulits/Constents.dart'; // Ensure this path is correct for Constant.apiEndpoint

import '../../../BidService.dart'; // Assuming BidService is in the root lib folder
import '../../../components/AnimatedMessageBar.dart';
import '../../../components/BidConfirmationDialog.dart';
import '../../../components/BidFailureDialog.dart';
import '../../../components/BidSuccessDialog.dart';

// Enum to represent whether the Patti is for 'Open' or 'Close'
enum PattiDayType { open, close }

// Main StatefulWidget for the Single Panna Bulk Board
class SinglePannaBulkBoardScreen extends StatefulWidget {
  final String title; // Title for the screen (e.g., "Single Panna Board")
  final int gameId; // ID of the game
  final String gameName; // Name of the game (e.g., "KALYAN", "STARLINE MAIN")
  final String gameType; // Type of the game (e.g., "singlePana")

  const SinglePannaBulkBoardScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameType,
  }) : super(key: key);

  @override
  State<SinglePannaBulkBoardScreen> createState() =>
      _SinglePannaBulkBoardScreenState();
}

// State class for SinglePannaBulkBoardScreen
class _SinglePannaBulkBoardScreenState
    extends State<SinglePannaBulkBoardScreen> {
  // State variables for UI and logic
  PattiDayType _selectedPattiDayType =
      PattiDayType.close; // Default selection for open/close
  final TextEditingController _pointsController =
      TextEditingController(); // Controller for points input

  // Stores the bids: Key is the 'pana' (e.g., "127"),
  // Value is a Map containing "points", "dayType", and the "singleDigit" derived from pana.
  Map<String, Map<String, String>> _bids = {};

  // GetStorage instance for local data persistence
  late GetStorage storage;
  // User data from storage
  late String _accessToken;
  late String _registerId;
  bool _accountStatus = false;
  late int _walletBalance;

  // UI state indicators
  bool _isApiCalling =
      false; // Indicates if an API call (like adding a bulk bid or final submission) is in progress
  bool _isWalletLoading = true; // Indicates if wallet balance is being loaded

  // Device information for API headers
  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  // --- AnimatedMessageBar State Management ---
  String? _messageToShow; // Message to display in the custom message bar
  bool _isErrorForMessage = false; // Whether the message is an error
  Key _messageBarKey =
      UniqueKey(); // Key to force re-animation of the message bar
  // --- End AnimatedMessageBar State Management ---

  @override
  void initState() {
    super.initState();
    storage = GetStorage(); // Initialize GetStorage
    _loadInitialData(); // Load user data and wallet balance
    _setupStorageListeners(); // Set up listeners for storage changes
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
    _pointsController.dispose(); // Dispose the TextEditingController
    super.dispose();
  }

  // --- AnimatedMessageBar Helper Methods ---
  // Displays a message using the custom AnimatedMessageBar
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return; // Only update state if the widget is mounted
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey(); // Assign new key to trigger animation
    });
  }

  // Clears the displayed message
  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }
  // --- End AnimatedMessageBar Helper Methods ---

  // Handles pressing a number button on the custom number pad
  Future<void> _onNumberPressed(String digit) async {
    _clearMessage(); // Clear any previous messages
    if (_isApiCalling) return; // Prevent multiple API calls at once

    final points = _pointsController.text.trim();
    final String requestSessionType =
        _selectedPattiDayType == PattiDayType.close ? 'close' : 'open';

    // Input validation
    if (points.isEmpty) {
      _showMessage('Please enter points to place a bid.', isError: true);
      return;
    }

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    // Wallet balance check is primarily done before final submission,
    // but a quick check here prevents unnecessary API calls
    if (parsedPoints > _walletBalance && _walletBalance != 0) {
      _showMessage(
        'Insufficient wallet balance to add this bid.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isApiCalling = true; // Set API calling state to true
    });

    // Construct API URL and headers
    final url = Uri.parse('${Constant.apiEndpoint}single-pana-bulk');
    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': _accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

    // Construct request body for the bulk API call
    final body = jsonEncode({
      "game_id": widget.gameId,
      "register_id": _registerId,
      "session_type": requestSessionType,
      "digit": digit,
      "amount": parsedPoints,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final responseData = json.decode(response.body);

      log("API Response for Single Pana Bulk: $responseData");

      if (response.statusCode == 200 && responseData['status'] == true) {
        final List<dynamic> info = responseData['info'] ?? [];
        if (info.isNotEmpty) {
          setState(() {
            for (var item in info) {
              final String pana = item['pana'].toString();
              final String amount = item['amount'].toString();
              String bidDisplayType;
              final String? apiSessionType = item['sessionType']?.toString();
              // IMPORTANT: Assuming the 'single-pana-bulk' API returns a 'digit'
              // field for each pana in the 'info' array. If not, you need to
              // derive the single digit from the pana (e.g., sum of digits % 10).
              final String derivedSingleDigit =
                  item['digit']?.toString() ??
                  _deriveSingleDigitFromPana(pana); // Fallback to derivation

              if (apiSessionType != null && apiSessionType.isNotEmpty) {
                bidDisplayType = apiSessionType;
              } else {
                bidDisplayType = requestSessionType;
              }

              // Store the full pana as the key, and the derived single digit
              _bids[pana] = {
                "points": amount,
                "dayType": bidDisplayType.toLowerCase(),
                "singleDigit":
                    derivedSingleDigit, // Store the single digit for later submission
              };
            }
          });
          _showMessage(
            '${info.length} bids for digit $digit added successfully!',
          );
        } else {
          _showMessage('No panas returned for this digit.', isError: true);
        }
      } else {
        log(
          "API Error for Single Pana Bulk: Status: ${response.statusCode}, Body: ${response.body}",
        );
        _showMessage(
          'Failed to add bid: ${responseData['msg'] ?? 'Unknown error'}',
          isError: true,
        );
      }
    } catch (e) {
      log("Network/Other Error placing Single Pana Bulk bid: $e");
      _showMessage('Network error: $e', isError: true);
    } finally {
      setState(() {
        _isApiCalling = false; // Reset API calling state
      });
    }
  }

  // Helper function to derive single digit from pana (e.g., "127" -> "0")
  String _deriveSingleDigitFromPana(String pana) {
    if (pana.length != 3) return ""; // Or handle error appropriately
    try {
      int sum = 0;
      for (int i = 0; i < pana.length; i++) {
        sum += int.parse(pana[i]);
      }
      return (sum % 10).toString();
    } catch (e) {
      log(
        "Error deriving single digit from pana '$pana': $e",
        name: 'PanaDerivationError',
      );
      return ""; // Return empty or handle as error
    }
  }

  // Removes a bid from the local list
  void _removeBid(String pana) {
    _clearMessage();
    if (_isApiCalling) return; // Prevent removing during API submission
    setState(() {
      _bids.remove(pana);
    });
    _showMessage('Bid for Pana $pana removed from list.');
  }

  // Calculates the total points for all bids in the list
  int _getTotalPoints() {
    return _bids.values
        .map((bid) => int.tryParse(bid['points'] ?? '0') ?? 0)
        .fold(0, (sum, points) => sum + points);
  }

  // Shows the confirmation dialog and then initiates final bid submission
  void _showConfirmationDialogAndSubmitBids() {
    _clearMessage(); // Clear any existing messages
    if (_isApiCalling) return; // Prevent multiple submissions

    if (_bids.isEmpty) {
      _showMessage(
        'No bids added yet. Please add bids before submitting.',
        isError: true,
      );
      return;
    }

    final int totalPointsToSubmit = _getTotalPoints();

    if (totalPointsToSubmit > _walletBalance) {
      _showMessage(
        'Insufficient wallet balance to submit all bids.',
        isError: true,
      );
      return;
    }

    // Prepare bids data for the confirmation dialog
    List<Map<String, String>> bidsForConfirmationDialog = [];
    _bids.forEach((pana, bidData) {
      bidsForConfirmationDialog.add({
        "digit":
            bidData['singleDigit']!, // Use the stored single digit for display
        "points": bidData['points']!,
        "type": bidData['dayType']!.toUpperCase(), // Display type (OPEN/CLOSE)
        "pana": pana, // This is the full pana for display
      });
    });

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    // Show the confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: false, // User must interact with buttons
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle:
              "${widget.gameName}, ${widget.gameType}-${DateFormat('dd-MM-yyyy').format(DateTime.now())}",
          gameDate: formattedDate,
          bids: bidsForConfirmationDialog,
          totalBids: _bids.length,
          totalBidsAmount: totalPointsToSubmit,
          walletBalanceBeforeDeduction: _walletBalance,
          walletBalanceAfterDeduction: (_walletBalance - totalPointsToSubmit)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            // Navigator.pop(dialogContext); // Dismiss the confirmation dialog

            setState(() {
              _isApiCalling =
                  true; // Set API calling state for final submission
            });

            try {
              bool success =
                  await _placeFinalBids(); // Call the final submission logic

              // Show overall success/failure dialog based on the result from _placeFinalBids
              if (mounted) {
                if (success) {
                  await showDialog(
                    context: context,
                    barrierDismissible:
                        false, // Can be true if you want to allow dismissing after success
                    builder: (BuildContext context) => const BidSuccessDialog(),
                  );
                } else {
                  // _placeFinalBids already shows specific messages,
                  // so this failure dialog can be generic or custom.
                  await showDialog(
                    context: context,
                    barrierDismissible:
                        false, // Can be true if you want to allow dismissing after failure
                    builder: (BuildContext context) => BidFailureDialog(
                      errorMessage:
                          "Some bids failed to place. Please check messages.",
                    ),
                  );
                }
              }
            } catch (e) {
              log("Error during final bid submission: $e");
              if (mounted) {
                _showMessage(
                  'An unexpected error occurred during bid submission: $e',
                  isError: true,
                );
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isApiCalling = false; // Reset API calling state
                });
              }
            }
          },
        );
      },
    );
  }

  // --- REFACTORED Final Bid Submission Logic ---
  // This function now uses BidService to send all collected bids in a single API call.
  Future<bool> _placeFinalBids() async {
    final bidService = BidService(storage); // Instantiate BidService

    if (_accessToken.isEmpty || _registerId.isEmpty) {
      _showMessage('Authentication error. Please log in again.', isError: true);
      return false;
    }

    if (_bids.isEmpty) {
      _showMessage('No bids to submit.', isError: true);
      return false;
    }

    // Prepare bidAmounts: Map<String, String> for BidService
    // Keys are Pana numbers (digits), values are points (amounts)
    final Map<String, String> bidAmountsForService = {};
    _bids.forEach((pana, bidData) {
      bidAmountsForService[pana] = bidData['points']!;
    });

    final int totalPointsToSubmit = _getTotalPoints();

    log(
      'Attempting consolidated final bid submission. Total points: $totalPointsToSubmit, Bids count: ${_bids.length}',
      name: 'ConsolidatedBidSubmission',
    );

    try {
      final result = await bidService.placeFinalBids(
        gameName: widget.gameName,
        accessToken: _accessToken,
        registerId: _registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: _accountStatus,
        bidAmounts:
            bidAmountsForService, // Pass the prepared Map<String, String>
        selectedGameType: _selectedPattiDayType == PattiDayType.close
            ? 'CLOSE'
            : 'OPEN', // Use the selected day type for the entire batch
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: totalPointsToSubmit,
      );

      if (result['status'] == true) {
        log(
          'Consolidated bid submission successful.',
          name: 'ConsolidatedBidSubmission',
        );
        // Update wallet balance locally and in storage
        final int newWalletBalance = _walletBalance - totalPointsToSubmit;
        await bidService.updateWalletBalance(newWalletBalance);
        if (mounted) {
          setState(() {
            _walletBalance = newWalletBalance;
            _bids
                .clear(); // Clear all bids after successful consolidated submission
          });
        }
        _showMessage('All bids submitted successfully!');
        return true;
      } else {
        String errorMessage =
            result['msg'] ?? 'Something went wrong during bid submission.';
        _showMessage('Bid submission failed: $errorMessage', isError: true);
        log(
          'Consolidated bid submission failed: $errorMessage',
          name: 'ConsolidatedBidSubmission',
          error: result,
        );
        return false;
      }
    } catch (e) {
      log(
        'Error during consolidated bid submission: $e',
        name: 'ConsolidatedBidSubmissionError',
      );
      _showMessage('An unexpected network error occurred: $e', isError: true);
      return false;
    }
  }

  // Builds the custom number pad for selecting single digits (0-9)
  Widget _buildNumberPad() {
    final numbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: numbers.map((number) {
        return GestureDetector(
          // Disable tap if an API call is in progress
          onTap: _isApiCalling ? null : () => _onNumberPressed(number),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isApiCalling
                      ? Colors.grey
                      : Colors.amber, // Dim if disabled
                  borderRadius: BorderRadius.circular(8),
                  boxShadow:
                      _isApiCalling // Less prominent shadow if disabled
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
            ],
          ),
        );
      }).toList(),
    );
  }

  // Builds a single bid entry item for display in the list
  Widget _buildBidEntryItem(String pana, String points, String type) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                pana, // Display the full pana
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
                type.toUpperCase(), // Display type (OPEN/CLOSE)
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
              // Disable removal if an API call is in progress
              onPressed: _isApiCalling ? null : () => _removeBid(pana),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the persistent bottom bar showing total bids, points, and submit button
  Widget _buildBottomBar() {
    int totalBidsCount = _bids.length;
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
                'Bids', // Changed from 'Bid' for better clarity
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '$totalBidsCount',
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
                'Points', // Changed from 'Total' for better clarity
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
            // Disable button if an API call is in progress
            onPressed: _isApiCalling
                ? null
                : _showConfirmationDialogAndSubmitBids,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isApiCalling
                  ? Colors.grey
                  : Colors.amber, // Dim if disabled
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
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
                Image.asset(
                  "assets/images/wallet_icon.png",
                  color: Colors.black,
                  height: 24,
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
                        "${_walletBalance.toString()}",
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
              ],
            ),
          ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Game Type:',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        ToggleButtons(
                          isSelected: [
                            _selectedPattiDayType == PattiDayType.close,
                            _selectedPattiDayType == PattiDayType.open,
                          ],
                          onPressed: (int index) {
                            if (_isApiCalling)
                              return; // Disable selection during API call
                            setState(() {
                              if (index == 0) {
                                _selectedPattiDayType = PattiDayType.close;
                              } else {
                                _selectedPattiDayType = PattiDayType.open;
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(30),
                          selectedColor: Colors.white,
                          fillColor: Colors.amber,
                          color: Colors.black,
                          borderColor: Colors.black,
                          selectedBorderColor: Colors.amber,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: Text(
                                'Close',
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: Text(
                                'Open',
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Enter Points:',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          height: 40,
                          child: TextFormField(
                            controller: _pointsController,
                            cursorColor: Colors.amber,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            style: GoogleFonts.poppins(fontSize: 14),
                            onTap: _clearMessage, // Clear message on tap
                            enabled: !_isApiCalling, // Disable during API call
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
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
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
                    const SizedBox(height: 30),
                    Center(
                      child: _isApiCalling
                          ? const CircularProgressIndicator(color: Colors.amber)
                          : _buildNumberPad(),
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
                        flex: 2,
                        child: Text(
                          'Pana',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Amount',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
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
                          'No bids placed yet. Click a number to add a bid!',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _bids.length,
                        itemBuilder: (context, index) {
                          final pana = _bids.keys.elementAt(index);
                          final bidData = _bids[pana]!;
                          return _buildBidEntryItem(
                            pana,
                            bidData['points']!,
                            bidData['dayType']!,
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
}

// import 'dart:async';
// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:new_sara/ulits/Constents.dart'; // Ensure this path is correct for Constant.apiEndpoint
//
// import '../../../components/AnimatedMessageBar.dart';
// import '../../../components/BidConfirmationDialog.dart';
// import '../../../components/BidFailureDialog.dart'; // Assuming you have this
// import '../../../components/BidSuccessDialog.dart'; // Assuming you have this
//
// // Enum to represent whether the Patti is for 'Open' or 'Close'
// enum PattiDayType { open, close }
//
// // Main StatefulWidget for the Single Panna Bulk Board
// class SinglePannaBulkBoardScreen extends StatefulWidget {
//   final String title; // Title for the screen (e.g., "Single Panna Board")
//   final int gameId; // ID of the game
//   final String gameName; // Name of the game (e.g., "KALYAN", "STARLINE MAIN")
//   final String gameType; // Type of the game (e.g., "singlePana")
//
//   const SinglePannaBulkBoardScreen({
//     Key? key,
//     required this.title,
//     required this.gameId,
//     required this.gameName,
//     required this.gameType,
//   }) : super(key: key);
//
//   @override
//   State<SinglePannaBulkBoardScreen> createState() =>
//       _SinglePannaBulkBoardScreenState();
// }
//
// // State class for SinglePannaBulkBoardScreen
// class _SinglePannaBulkBoardScreenState
//     extends State<SinglePannaBulkBoardScreen> {
//   // State variables for UI and logic
//   PattiDayType _selectedPattiDayType =
//       PattiDayType.close; // Default selection for open/close
//   final TextEditingController _pointsController =
//       TextEditingController(); // Controller for points input
//
//   // Stores the bids: Key is the 'pana' (e.g., "127"),
//   // Value is a Map containing "points", "dayType", and the "singleDigit" derived from pana.
//   // Storing `singleDigit` is crucial for the API payload.
//   Map<String, Map<String, String>> _bids = {};
//
//   // GetStorage instance for local data persistence
//   late GetStorage storage;
//   // User data from storage
//   late String _accessToken;
//   late String _registerId;
//   bool _accountStatus = false;
//   late int _walletBalance;
//
//   // UI state indicators
//   bool _isApiCalling =
//       false; // Indicates if an API call (like adding a bulk bid or final submission) is in progress
//   bool _isWalletLoading = true; // Indicates if wallet balance is being loaded
//
//   // Device information for API headers
//   final String _deviceId = 'test_device_id_flutter';
//   final String _deviceName = 'test_device_name_flutter';
//
//   // --- AnimatedMessageBar State Management ---
//   String? _messageToShow; // Message to display in the custom message bar
//   bool _isErrorForMessage = false; // Whether the message is an error
//   Key _messageBarKey =
//       UniqueKey(); // Key to force re-animation of the message bar
//   // --- End AnimatedMessageBar State Management ---
//
//   @override
//   void initState() {
//     super.initState();
//     storage = GetStorage(); // Initialize GetStorage
//     _loadInitialData(); // Load user data and wallet balance
//     _setupStorageListeners(); // Set up listeners for storage changes
//   }
//
//   // Asynchronously loads initial user data and wallet balance from GetStorage
//   Future<void> _loadInitialData() async {
//     _accessToken = storage.read('accessToken') ?? '';
//     _registerId = storage.read('registerId') ?? '';
//     _accountStatus = storage.read('accountStatus') ?? false;
//
//     // Safely parse wallet balance, handling both String and int types
//     final dynamic storedWalletBalance = storage.read('walletBalance');
//     if (storedWalletBalance is String) {
//       _walletBalance = int.tryParse(storedWalletBalance) ?? 0;
//     } else if (storedWalletBalance is int) {
//       _walletBalance = storedWalletBalance;
//     } else {
//       _walletBalance = 0;
//     }
//
//     setState(() {
//       _isWalletLoading = false; // Mark wallet loading as complete
//     });
//   }
//
//   // Sets up listeners for changes in specific GetStorage keys, updating UI state
//   void _setupStorageListeners() {
//     storage.listenKey('accessToken', (value) {
//       if (mounted) {
//         setState(() {
//           _accessToken = value ?? '';
//         });
//       }
//     });
//     storage.listenKey('registerId', (value) {
//       if (mounted) {
//         setState(() {
//           _registerId = value ?? '';
//         });
//       }
//     });
//     storage.listenKey('accountStatus', (value) {
//       if (mounted) {
//         setState(() {
//           _accountStatus = value ?? false;
//         });
//       }
//     });
//     storage.listenKey('walletBalance', (value) {
//       if (mounted) {
//         setState(() {
//           if (value is String) {
//             _walletBalance = int.tryParse(value) ?? 0;
//           } else if (value is int) {
//             _walletBalance = value;
//           } else {
//             _walletBalance = 0;
//           }
//           _isWalletLoading = false;
//         });
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _pointsController.dispose(); // Dispose the TextEditingController
//     super.dispose();
//   }
//
//   // --- AnimatedMessageBar Helper Methods ---
//   // Displays a message using the custom AnimatedMessageBar
//   void _showMessage(String message, {bool isError = false}) {
//     if (!mounted) return; // Only update state if the widget is mounted
//     setState(() {
//       _messageToShow = message;
//       _isErrorForMessage = isError;
//       _messageBarKey = UniqueKey(); // Assign new key to trigger animation
//     });
//   }
//
//   // Clears the displayed message
//   void _clearMessage() {
//     if (mounted) {
//       setState(() {
//         _messageToShow = null;
//       });
//     }
//   }
//   // --- End AnimatedMessageBar Helper Methods ---
//
//   // Handles pressing a number button on the custom number pad
//   Future<void> _onNumberPressed(String digit) async {
//     _clearMessage(); // Clear any previous messages
//     if (_isApiCalling) return; // Prevent multiple API calls at once
//
//     final points = _pointsController.text.trim();
//     final String requestSessionType =
//         _selectedPattiDayType == PattiDayType.close ? 'close' : 'open';
//
//     // Input validation
//     if (points.isEmpty) {
//       _showMessage('Please enter points to place a bid.', isError: true);
//       return;
//     }
//
//     int? parsedPoints = int.tryParse(points);
//     if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
//       _showMessage('Points must be between 10 and 1000.', isError: true);
//       return;
//     }
//
//     if (parsedPoints > _walletBalance) {
//       _showMessage('Insufficient wallet balance.', isError: true);
//       return;
//     }
//
//     setState(() {
//       _isApiCalling = true; // Set API calling state to true
//     });
//
//     // Construct API URL and headers
//     final url = Uri.parse('${Constant.apiEndpoint}single-pana-bulk');
//     final headers = {
//       'deviceId': _deviceId,
//       'deviceName': _deviceName,
//       'accessStatus': _accountStatus ? '1' : '0',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $_accessToken',
//     };
//
//     // Construct request body for the bulk API call
//     final body = jsonEncode({
//       "game_id": widget.gameId,
//       "register_id": _registerId,
//       "session_type": requestSessionType,
//       "digit": digit,
//       "amount": parsedPoints,
//     });
//
//     try {
//       final response = await http.post(url, headers: headers, body: body);
//       final responseData = json.decode(response.body);
//
//       log("API Response for Single Pana Bulk: $responseData");
//
//       if (response.statusCode == 200 && responseData['status'] == true) {
//         final List<dynamic> info = responseData['info'] ?? [];
//         if (info.isNotEmpty) {
//           setState(() {
//             for (var item in info) {
//               final String pana = item['pana'].toString();
//               final String amount = item['amount'].toString();
//               String bidDisplayType;
//               final String? apiSessionType = item['sessionType']?.toString();
//               // IMPORTANT: Assuming the 'single-pana-bulk' API returns a 'digit'
//               // field for each pana in the 'info' array. If not, you need to
//               // derive the single digit from the pana (e.g., sum of digits % 10).
//               final String derivedSingleDigit =
//                   item['digit']?.toString() ??
//                   _deriveSingleDigitFromPana(pana); // Fallback to derivation
//
//               if (apiSessionType != null && apiSessionType.isNotEmpty) {
//                 bidDisplayType = apiSessionType;
//               } else {
//                 bidDisplayType = requestSessionType;
//               }
//
//               // Store the full pana as the key, and the derived single digit
//               _bids[pana] = {
//                 "points": amount,
//                 "dayType": bidDisplayType.toLowerCase(),
//                 "singleDigit":
//                     derivedSingleDigit, // Store the single digit for later submission
//               };
//             }
//           });
//           _showMessage(
//             '${info.length} bids for digit $digit added successfully!',
//           );
//         } else {
//           _showMessage('No panas returned for this digit.', isError: true);
//         }
//       } else {
//         log(
//           "API Error for Single Pana Bulk: Status: ${response.statusCode}, Body: ${response.body}",
//         );
//         _showMessage(
//           'Failed to add bid: ${responseData['msg'] ?? 'Unknown error'}',
//           isError: true,
//         );
//       }
//     } catch (e) {
//       log("Network/Other Error placing Single Pana Bulk bid: $e");
//       _showMessage('Network error: $e', isError: true);
//     } finally {
//       setState(() {
//         _isApiCalling = false; // Reset API calling state
//       });
//     }
//   }
//
//   // Helper function to derive single digit from pana (e.g., "127" -> "0")
//   String _deriveSingleDigitFromPana(String pana) {
//     if (pana.length != 3) return ""; // Or handle error appropriately
//     try {
//       int sum = 0;
//       for (int i = 0; i < pana.length; i++) {
//         sum += int.parse(pana[i]);
//       }
//       return (sum % 10).toString();
//     } catch (e) {
//       log(
//         "Error deriving single digit from pana '$pana': $e",
//         name: 'PanaDerivationError',
//       );
//       return ""; // Return empty or handle as error
//     }
//   }
//
//   // Removes a bid from the local list
//   void _removeBid(String pana) {
//     _clearMessage();
//     if (_isApiCalling) return; // Prevent removing during API submission
//     setState(() {
//       _bids.remove(pana);
//     });
//     _showMessage('Bid for Pana $pana removed from list.');
//   }
//
//   // Calculates the total points for all bids in the list
//   int _getTotalPoints() {
//     return _bids.values
//         .map((bid) => int.tryParse(bid['points'] ?? '0') ?? 0)
//         .fold(0, (sum, points) => sum + points);
//   }
//
//   // Shows the confirmation dialog and then initiates final bid submission
//   void _showConfirmationDialogAndSubmitBids() {
//     _clearMessage(); // Clear any existing messages
//     if (_isApiCalling) return; // Prevent multiple submissions
//
//     if (_bids.isEmpty) {
//       _showMessage(
//         'No bids added yet. Please add bids before submitting.',
//         isError: true,
//       );
//       return;
//     }
//
//     final int totalPointsToSubmit = _getTotalPoints();
//
//     if (totalPointsToSubmit > _walletBalance) {
//       _showMessage(
//         'Insufficient wallet balance to submit all bids.',
//         isError: true,
//       );
//       return;
//     }
//
//     // Prepare bids data for the confirmation dialog
//     List<Map<String, String>> bidsForConfirmationDialog = [];
//     _bids.forEach((pana, bidData) {
//       bidsForConfirmationDialog.add({
//         "digit":
//             bidData['singleDigit']!, // Use the stored single digit for display
//         "points": bidData['points']!,
//         "type": bidData['dayType']!.toUpperCase(), // Display type (OPEN/CLOSE)
//         "pana": pana, // This is the full pana for display
//       });
//     });
//
//     final String formattedDate = DateFormat(
//       'dd MMM yyyy, hh:mm a',
//     ).format(DateTime.now());
//
//     // Show the confirmation dialog
//     showDialog(
//       context: context,
//       barrierDismissible: false, // User must interact with buttons
//       builder: (BuildContext dialogContext) {
//         return BidConfirmationDialog(
//           gameTitle:
//               "${widget.gameName}, ${widget.gameType}-${DateFormat('dd-MM-yyyy').format(DateTime.now())}",
//           gameDate: formattedDate,
//           bids: bidsForConfirmationDialog,
//           totalBids: _bids.length,
//           totalBidsAmount: totalPointsToSubmit,
//           walletBalanceBeforeDeduction: _walletBalance,
//           walletBalanceAfterDeduction: (_walletBalance - totalPointsToSubmit)
//               .toString(),
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameType,
//           onConfirm: () async {
//             Navigator.pop(dialogContext); // Dismiss the confirmation dialog
//
//             setState(() {
//               _isApiCalling =
//                   true; // Set API calling state for final submission
//             });
//
//             bool success = false;
//             try {
//               success =
//                   await _placeFinalBids(); // Call the final submission logic
//               if (success) {
//                 // _bids.clear() is now handled within _placeFinalBids if successful
//                 // Overall success message is handled by BidSuccessDialog
//                 showDialog(
//                   context: context,
//                   barrierDismissible: true,
//                   builder: (BuildContext context) => BidSuccessDialog(),
//                 );
//               } else {
//                 // Overall failure message is handled by BidFailureDialog
//                 showDialog(
//                   context: context,
//                   barrierDismissible: true,
//                   builder: (BuildContext context) => BidFailureDialog(),
//                 );
//               }
//             } catch (e) {
//               log("Error during final bid submission: $e");
//               _showMessage('An unexpected error occurred: $e', isError: true);
//             } finally {
//               if (mounted) {
//                 setState(() {
//                   _isApiCalling = false; // Reset API calling state
//                 });
//               }
//             }
//           },
//         );
//       },
//     );
//   }
//
//   // --- Final Bid Submission Logic ---
//   // This function iterates through all collected bids and sends them
//   // individually to the appropriate API endpoint.
//   Future<bool> _placeFinalBids() async {
//     bool allBidsSuccessful = true; // Flag to track overall success
//
//     log(
//       'Starting final bid submission process. Total bids to process: ${_bids.length}',
//       name: 'FinalBidSubmission',
//     );
//
//     // Determine the base API URL (jackpot/starline/regular) based on gameName
//     String baseUrl;
//     if (widget.gameName.toLowerCase().contains('jackpot')) {
//       baseUrl = '${Constant.apiEndpoint}place-jackpot-bid';
//     } else if (widget.gameName.toLowerCase().contains('starline')) {
//       baseUrl = '${Constant.apiEndpoint}place-starline-bid';
//     } else {
//       baseUrl = '${Constant.apiEndpoint}place-bid';
//     }
//
//     // Define common request headers
//     final headers = {
//       'deviceId': _deviceId,
//       'deviceName': _deviceName,
//       'accessStatus': _accountStatus
//           ? '1'
//           : '0', // Convert boolean to string '1' or '0'
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $_accessToken',
//     };
//
//     // Make a copy of _bids to iterate over, as _bids might be cleared if all successful
//     final Map<String, Map<String, String>> bidsToProcess = Map.from(_bids);
//
//     // Iterate over each bid in the _bids map and send individual requests
//     for (var entry in bidsToProcess.entries) {
//       final String currentPanaFromKey =
//           entry.key; // This is the Pana, like "127"
//       final Map<String, dynamic> bidDetails = entry.value;
//
//       final String sessionType = bidDetails["dayType"]?.toUpperCase() ?? "";
//       final int bidAmount = int.tryParse(bidDetails["points"] ?? '0') ?? 0;
//
//       // Retrieve the single digit that was stored alongside the pana
//       final String singleDigitForThisPana = bidDetails["singleDigit"] ?? "";
//       // The actual pana value is the key itself
//       final String actualPana = currentPanaFromKey;
//
//       // Construct the single bid object for the 'bid' field
//       final Map<String, dynamic> singleBidPayload = {
//         "sessionType": sessionType,
//         "digit": singleDigitForThisPana, // Send the derived single digit
//         "pana": actualPana, // Send the full Pana
//         "bidAmount": bidAmount,
//       };
//
//       // Construct the full request body for this individual bid
//       final body = jsonEncode({
//         "registerId": _registerId,
//         "gameId": widget.gameId
//             .toString(), // Ensure gameId is a string as per curl example
//         "bidAmount":
//             bidAmount, // This is the amount for the current individual bid
//         "gameType": widget.gameType, // Use the original gameCategoryType
//         "bid": [
//           singleBidPayload,
//         ], // IMPORTANT: 'bid' should be a LIST of bid objects
//       });
//
//       // Log the cURL command and headers for debugging purposes for each bid
//       String curlCommand = 'curl -X POST \\';
//       curlCommand += '\n  $baseUrl \\';
//       headers.forEach((key, value) {
//         curlCommand += '\n  -H "$key: $value" \\';
//       });
//       curlCommand += '\n  -d \'$body\'';
//
//       log(
//         'CURL Command for Individual Bid Submission (Pana: $currentPanaFromKey):\n$curlCommand',
//         name: 'FinalBidSubmission',
//       );
//       log(
//         'Request Headers for Individual Bid Submission: $headers',
//         name: 'FinalBidSubmission',
//       );
//       log(
//         'Request Body for Individual Bid Submission: $body',
//         name: 'FinalBidSubmission',
//       );
//
//       // Make the API call for the current bid
//       try {
//         final response = await http.post(
//           Uri.parse(baseUrl),
//           headers: headers,
//           body: body,
//         );
//
//         final Map<String, dynamic> responseBody = json.decode(response.body);
//
//         // Handle the API response for the current bid
//         if (response.statusCode == 200 && responseBody['status'] == true) {
//           log(
//             "Bid Status for Pana $currentPanaFromKey: ${response.statusCode}",
//           );
//           // Deduct points for this successful bid
//           int newWalletBalance = _walletBalance - bidAmount;
//           await storage.write('walletBalance', newWalletBalance.toString());
//
//           // Update UI wallet balance only if mounted
//           if (mounted) {
//             setState(() {
//               _walletBalance = newWalletBalance;
//             });
//           }
//           log(
//             'Bid for Pana $currentPanaFromKey successful. Wallet updated: $_walletBalance',
//             name: 'FinalBidSubmission',
//           );
//         } else {
//           String errorMessage =
//               responseBody['msg'] ?? "Unknown error occurred.";
//           _showMessage(
//             'Bid for Pana $currentPanaFromKey failed: $errorMessage',
//             isError: true,
//           );
//           allBidsSuccessful = false; // Mark overall as failed if any bid fails
//           log(
//             'Bid for Pana $currentPanaFromKey failed: $errorMessage',
//             name: 'FinalBidSubmission',
//             error: responseBody,
//           );
//           // Don't break, try to submit remaining bids
//         }
//       } catch (e) {
//         _showMessage(
//           'Network error for Pana $currentPanaFromKey: $e',
//           isError: true,
//         );
//         allBidsSuccessful = false; // Mark overall as failed on network error
//         log(
//           'Network error for Pana $currentPanaFromKey: $e',
//           name: 'FinalBidSubmission',
//           error: e,
//         );
//         // Don't break, try to submit remaining bids
//       }
//     }
//
//     // After processing all bids, if all were successful, clear the local bids
//     if (allBidsSuccessful) {
//       // Show overall success dialog
//       if (mounted) {
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (BuildContext dialogContext) => const BidSuccessDialog(),
//         );
//         _bids.clear(); // Clear the bids after successful submission
//       }
//       log(
//         'All bids processed. Bids cleared locally.',
//         name: 'FinalBidSubmission',
//       );
//     } else {
//       // Show overall failure dialog if any bid failed
//       if (mounted) {
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (BuildContext dialogContext) => BidFailureDialog(
//             errorMessage: "Some bids failed to place. Please check messages.",
//           ),
//         );
//       }
//       log(
//         'Some bids failed. Bids not cleared locally.',
//         name: 'FinalBidSubmission',
//       );
//     }
//
//     return allBidsSuccessful; // Return overall success status
//   }
//
//   // Builds the custom number pad for selecting single digits (0-9)
//   Widget _buildNumberPad() {
//     final numbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
//
//     return Wrap(
//       spacing: 10, // Adjusted for better visual spacing
//       runSpacing: 10, // Adjusted for better visual spacing
//       alignment: WrapAlignment.center,
//       children: numbers.map((number) {
//         return GestureDetector(
//           // Disable tap if an API call is in progress
//           onTap: _isApiCalling ? null : () => _onNumberPressed(number),
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               Container(
//                 width: 60,
//                 height: 60,
//                 alignment: Alignment.center,
//                 decoration: BoxDecoration(
//                   color: _isApiCalling
//                       ? Colors.grey
//                       : Colors.amber, // Dim if disabled
//                   borderRadius: BorderRadius.circular(8),
//                   boxShadow:
//                       _isApiCalling // Less prominent shadow if disabled
//                       ? []
//                       : [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.2),
//                             spreadRadius: 1,
//                             blurRadius: 3,
//                             offset: const Offset(0, 2),
//                           ),
//                         ],
//                 ),
//                 child: Text(
//                   number,
//                   style: GoogleFonts.poppins(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       }).toList(),
//     );
//   }
//
//   // Builds a single bid entry item for display in the list
//   Widget _buildBidEntryItem(String pana, String points, String type) {
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//       elevation: 1,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
//         child: Row(
//           children: [
//             Expanded(
//               flex: 2,
//               child: Text(
//                 pana, // Display the full pana
//                 style: GoogleFonts.poppins(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//             Expanded(
//               flex: 3,
//               child: Text(
//                 points,
//                 style: GoogleFonts.poppins(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//             Expanded(
//               flex: 2,
//               child: Text(
//                 type.toUpperCase(), // Display type (OPEN/CLOSE)
//                 style: GoogleFonts.poppins(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                   color: type.toLowerCase() == 'open'
//                       ? Colors.blue[700] // Differentiate open/close visually
//                       : Colors.green[700],
//                 ),
//               ),
//             ),
//             IconButton(
//               icon: const Icon(Icons.delete, color: Colors.red),
//               // Disable removal if an API call is in progress
//               onPressed: _isApiCalling ? null : () => _removeBid(pana),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Builds the persistent bottom bar showing total bids, points, and submit button
//   Widget _buildBottomBar() {
//     int totalBidsCount = _bids.length;
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
//                 'Bids', // Changed from 'Bid' for better clarity
//                 style: GoogleFonts.poppins(
//                   fontSize: 14,
//                   color: Colors.grey[700],
//                 ),
//               ),
//               Text(
//                 '$totalBidsCount',
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
//                 'Points', // Changed from 'Total' for better clarity
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
//             // Disable button if an API call is in progress
//             onPressed: _isApiCalling
//                 ? null
//                 : _showConfirmationDialogAndSubmitBids,
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
//                 ? const SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                     ),
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
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade100,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
//         ),
//         title: Text(
//           widget.title,
//           style: GoogleFonts.poppins(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//             color: Colors.black,
//           ),
//         ),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 16),
//             child: Row(
//               children: [
//                 Image.asset(
//                   "assets/images/wallet_icon.png",
//                   color: Colors.black,
//                   height: 24,
//                 ),
//                 const SizedBox(width: 4),
//                 _isWalletLoading
//                     ? const SizedBox(
//                         width: 20,
//                         height: 20,
//                         child: CircularProgressIndicator(
//                           color: Colors.black,
//                           strokeWidth: 2,
//                         ),
//                       )
//                     : Text(
//                         "${_walletBalance.toString()}",
//                         style: GoogleFonts.poppins(
//                           color: Colors.black,
//                           fontSize: 16,
//                         ),
//                       ),
//               ],
//             ),
//           ),
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
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Select Game Type:',
//                           style: GoogleFonts.poppins(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         ToggleButtons(
//                           isSelected: [
//                             _selectedPattiDayType == PattiDayType.close,
//                             _selectedPattiDayType == PattiDayType.open,
//                           ],
//                           onPressed: (int index) {
//                             if (_isApiCalling)
//                               return; // Disable selection during API call
//                             setState(() {
//                               if (index == 0) {
//                                 _selectedPattiDayType = PattiDayType.close;
//                               } else {
//                                 _selectedPattiDayType = PattiDayType.open;
//                               }
//                             });
//                           },
//                           borderRadius: BorderRadius.circular(30),
//                           selectedColor: Colors.white,
//                           fillColor: Colors.amber,
//                           color: Colors.black,
//                           borderColor: Colors.black,
//                           selectedBorderColor: Colors.amber,
//                           children: <Widget>[
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 20,
//                                 vertical: 8,
//                               ),
//                               child: Text(
//                                 'Close',
//                                 style: GoogleFonts.poppins(fontSize: 14),
//                               ),
//                             ),
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 20,
//                                 vertical: 8,
//                               ),
//                               child: Text(
//                                 'Open',
//                                 style: GoogleFonts.poppins(fontSize: 14),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Enter Points:',
//                           style: GoogleFonts.poppins(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         SizedBox(
//                           width: 150,
//                           height: 40,
//                           child: TextFormField(
//                             controller: _pointsController,
//                             cursorColor: Colors.amber,
//                             keyboardType: TextInputType.number,
//                             inputFormatters: [
//                               FilteringTextInputFormatter.digitsOnly,
//                               LengthLimitingTextInputFormatter(4),
//                             ],
//                             style: GoogleFonts.poppins(fontSize: 14),
//                             onTap: _clearMessage, // Clear message on tap
//                             enabled: !_isApiCalling, // Disable during API call
//                             decoration: InputDecoration(
//                               hintText: 'Enter Amount',
//                               contentPadding: const EdgeInsets.symmetric(
//                                 horizontal: 16,
//                                 vertical: 0,
//                               ),
//                               filled: true,
//                               fillColor: Colors.white,
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(30),
//                                 borderSide: const BorderSide(
//                                   color: Colors.black,
//                                 ),
//                               ),
//                               enabledBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(30),
//                                 borderSide: const BorderSide(
//                                   color: Colors.black,
//                                 ),
//                               ),
//                               focusedBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(30),
//                                 borderSide: const BorderSide(
//                                   color: Colors.amber,
//                                   width: 2,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 30),
//                     Center(
//                       child: _isApiCalling
//                           ? const CircularProgressIndicator(color: Colors.amber)
//                           : _buildNumberPad(),
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
//                         flex: 2,
//                         child: Text(
//                           'Pana',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         flex: 3,
//                         child: Text(
//                           'Amount',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         flex: 2,
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
//                           'No bids placed yet. Click a number to add a bid!',
//                           style: GoogleFonts.poppins(color: Colors.grey),
//                         ),
//                       )
//                     : ListView.builder(
//                         itemCount: _bids.length,
//                         itemBuilder: (context, index) {
//                           final pana = _bids.keys.elementAt(index);
//                           final bidData = _bids[pana]!;
//                           return _buildBidEntryItem(
//                             pana,
//                             bidData['points']!,
//                             bidData['dayType']!,
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
// }
