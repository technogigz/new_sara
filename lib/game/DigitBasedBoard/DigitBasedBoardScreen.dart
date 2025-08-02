import 'dart:async'; // For Timer
import 'dart:convert'; // For json encoding/decoding
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get_storage/get_storage.dart'; // For GetStorage
import 'package:google_fonts/google_fonts.dart'; // Added for consistent text styling (optional)
import 'package:http/http.dart' as http; // For making HTTP requests
import 'package:intl/intl.dart'; // For date formatting
import 'package:new_sara/BidsServicesBulk.dart';

import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../ulits/Constents.dart'; // Assuming Constents file exists

class DigitBasedBoardScreen extends StatefulWidget {
  final String title;
  final String gameType;
  final String gameId;
  final String gameName; // Added gameName to determine API for bid submission

  const DigitBasedBoardScreen({
    Key? key,
    required this.title,
    required this.gameType,
    required String gameId, // Changed to String as per your usage
    required this.gameName, // Required for determining API
  }) : gameId = gameId,
       super(key: key);

  @override
  _DigitBasedBoardScreenState createState() => _DigitBasedBoardScreenState();
}

class _DigitBasedBoardScreenState extends State<DigitBasedBoardScreen> {
  final TextEditingController _leftDigitController = TextEditingController();
  final TextEditingController _rightDigitController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  List<Map<String, String>> _entries = [];
  int _walletBalance = 0; // State variable for wallet balance
  bool _isSubmitting = false; // New state for submission in progress

  // --- AnimatedMessageBar State ---
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey(); // Key to force rebuild/re-animation
  Timer? _messageDismissTimer; // Timer to auto-dismiss the message
  // --- End AnimatedMessageBar State ---

  late GetStorage storage; // Initialize GetStorage
  late BidServiceBulk _bidService; // Declare BidService
  String? _accessToken;
  String? _registerId;
  bool _accountStatus = false; // Add accountStatus

  @override
  void initState() {
    super.initState();
    storage = GetStorage(); // Initialize GetStorage
    _bidService = BidServiceBulk(storage); // Initialize BidService
    _loadInitialData(); // Load wallet balance, access token, register ID
    _setupStorageListeners(); // Setup listeners for dynamic updates
  }

  @override
  void dispose() {
    _leftDigitController.dispose();
    _rightDigitController.dispose();
    _pointsController.dispose();
    _messageDismissTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _accessToken = storage.read('accessToken');
    _registerId = storage.read('registerId');
    _accountStatus =
        storage.read('accountStatus') ?? false; // Load account status

    final dynamic storedValue = storage.read('walletBalance');

    if (storedValue != null) {
      if (storedValue is int) {
        _walletBalance = storedValue;
      } else if (storedValue is String) {
        _walletBalance = int.tryParse(storedValue) ?? 0;
      } else {
        _walletBalance = 0; // Fallback for unexpected types
      }
    } else {
      _walletBalance = 0; // Default balance if nothing is stored
      // Do not set a default here if you expect it from API/login
    }
    setState(() {}); // Update UI to show loaded balance
  }

  void _setupStorageListeners() {
    storage.listenKey('accessToken', (value) {
      if (mounted) {
        setState(() {
          _accessToken = value;
        });
      }
    });
    storage.listenKey('registerId', (value) {
      if (mounted) {
        setState(() {
          _registerId = value;
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
        });
      }
    });
  }

  // Refactored to use BidService's update method
  Future<void> _updateWalletBalanceLocal(int spentAmount) async {
    final int newBalance =
        _walletBalance +
        spentAmount; // spentAmount can be negative for deduction
    await _bidService.updateWalletBalance(newBalance);
    if (mounted) {
      setState(() {
        _walletBalance = newBalance;
      });
    }
  }

  // --- AnimatedMessageBar Methods ---
  void _showMessage(String message, {bool isError = false}) {
    // Clear any existing timer
    _messageDismissTimer?.cancel();

    if (!mounted) return; // Ensure widget is still in tree

    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey =
          UniqueKey(); // Force AnimatedMessageBar to re-initialize and animate
    });

    // Start a new timer to dismiss the message after 3 seconds
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
  // --- End AnimatedMessageBar Methods ---

  Future<void> _addEntry() async {
    _clearMessage(); // Clear previous messages
    if (_isSubmitting) return; // Prevent adding entries during submission

    final String leftDigit = _leftDigitController.text.trim();
    final String rightDigit = _rightDigitController.text.trim();
    final String points = _pointsController.text.trim();

    // Client-side validation with AnimatedMessageBar
    if (leftDigit.isEmpty && rightDigit.isEmpty) {
      _showMessage('Please enter at least one digit.', isError: true);
      return;
    }

    if (points.isEmpty) {
      _showMessage('Please enter points.', isError: true);
      return;
    }

    final int intPoints = int.tryParse(points) ?? 0;
    if (intPoints <= 0) {
      _showMessage('Points must be a positive number.', isError: true);
      return;
    }

    // Validate left digit
    if (leftDigit.isNotEmpty &&
        (leftDigit.length != 1 || int.tryParse(leftDigit) == null)) {
      _showMessage('Left digit must be a single number (0-9).', isError: true);
      return;
    }

    // Validate right digit
    if (rightDigit.isNotEmpty &&
        (rightDigit.length != 1 || int.tryParse(rightDigit) == null)) {
      _showMessage('Right digit must be a single number (0-9).', isError: true);
      return;
    }

    // Determine the total amount to be deducted initially for validation
    // This logic needs to align with your API's expected behavior for 'Digit Board'
    int estimatedCost = intPoints;
    if (leftDigit.isNotEmpty && rightDigit.isEmpty) {
      estimatedCost = intPoints * 10; // Assuming 10 jodis for a single digit
    } else if (leftDigit.isEmpty && rightDigit.isNotEmpty) {
      // Assuming 10 jodis are generated for right digit 0-9
      estimatedCost = intPoints * 10;
    } else if (leftDigit.isNotEmpty && rightDigit.isNotEmpty) {
      estimatedCost = intPoints; // Single jodi
    }

    if (estimatedCost > _walletBalance) {
      _showMessage(
        'Insufficient wallet balance to add this bid.',
        isError: true,
      );
      return;
    }

    // Prepare the body for the API call to get panas
    final Map<String, dynamic> requestBody;
    if (leftDigit.isNotEmpty && rightDigit.isEmpty) {
      requestBody = {"leftDigit": int.parse(leftDigit), "amount": intPoints};
    } else if (leftDigit.isEmpty && rightDigit.isNotEmpty) {
      requestBody = {"rightDigit": int.parse(rightDigit), "amount": intPoints};
    } else if (leftDigit.isNotEmpty && rightDigit.isNotEmpty) {
      requestBody = {
        "leftDigit": int.parse(leftDigit),
        "rightDigit": int.parse(rightDigit),
        "amount": intPoints,
      };
    } else {
      _showMessage(
        'Invalid digit combination. Please provide valid digits.',
        isError: true,
      );
      return;
    }

    final url = Uri.parse('${Constant.apiEndpoint}digit-based-jodi');

    if (_accessToken == null ||
        _accessToken!.isEmpty ||
        _registerId == null ||
        _registerId!.isEmpty) {
      _showMessage("Authentication error. Please log in again.", isError: true);
      return;
    }

    final headers = {
      'deviceId': 'qwert', // Placeholder
      'deviceName': 'sm2233', // Placeholder
      'accessStatus': _accountStatus ? '1' : '0', // Use actual account status
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['status'] == true) {
        final List<dynamic> info = responseData['info'] ?? [];
        List<Map<String, String>> bidsFromApi = [];
        int totalAmountDeductedByApi = 0; // Track actual amount from API

        for (var item in info) {
          final String pana = item['pana'].toString();
          final String amount = item['amount'].toString();
          bidsFromApi.add({
            'jodi': pana, // Use 'jodi' to align with _entries structure
            'points': amount,
            'type': widget.gameType, // Use actual game type
          });
          totalAmountDeductedByApi += int.tryParse(amount) ?? 0;
        }

        if (bidsFromApi.isNotEmpty) {
          setState(() {
            _entries.addAll(bidsFromApi); // Add all received bids
            _leftDigitController.clear();
            _rightDigitController.clear();
            _pointsController.clear();
          });

          // Deduct the actual total amount returned by API
          _updateWalletBalanceLocal(-totalAmountDeductedByApi);
          _showMessage('Bid(s) added successfully!', isError: false);
        } else {
          _showMessage(
            'API response was successful but no bids were returned.',
            isError: true,
          );
        }
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return BidFailureDialog(
              errorMessage:
                  responseData['msg'] ??
                  'Something went wrong.\nPlease try again later.',
            );
          },
        );
        _showMessage(
          'API Error: ${responseData['msg'] ?? 'Unknown error'}',
          isError: true,
        );
      }
    } catch (e) {
      _showMessage('Network Error: $e', isError: true);
      log('Network error during _addEntry: $e');
    }
  }

  void _deleteEntry(int index) {
    if (_isSubmitting) return; // Prevent deleting entries during submission

    setState(() {
      final Map<String, String> removedEntry = _entries.removeAt(index);
      final int refundedPoints =
          int.tryParse(removedEntry['points'] ?? '0') ?? 0;
      // Refund points only if they were immediately deducted on _addEntry
      // If points are only deducted on final submission, remove this line.
      _updateWalletBalanceLocal(refundedPoints); // Add points back to wallet
      _showMessage('Entry ${removedEntry['jodi']} removed.', isError: false);
    });
  }

  int _getTotalBidsCount() {
    return _entries.length;
  }

  int _getTotalPoints() {
    return _entries.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  // Refactored to use BidService
  Future<bool> _placeBidFinalSubmission({
    required List<Map<String, String>> bidsToSubmit,
    required int totalAmountToSubmit,
    required String gameId,
    required String gameType,
    required String gameNameForApi,
  }) async {
    // For DigitBasedBoardScreen, the 'sessionType' in the bid payload
    // needs to be determined. It's often 'OPEN' for single/jodi.
    // If your game has specific session types for Digit Board, adjust here.
    String sessionTypeForPayload = "OPEN"; // Default or determine dynamically

    final result = await _bidService.placeFinalBids(
      gameName: gameNameForApi,
      accessToken: _accessToken ?? '',
      registerId: _registerId ?? '',
      deviceId: 'qwert', // Placeholder
      deviceName: 'sm2233', // Placeholder
      accountStatus: _accountStatus,
      bids: bidsToSubmit,
      gameType: gameType,
      gameId: int.parse(gameId),
      totalBidAmount: totalAmountToSubmit,
      selectedSessionType: sessionTypeForPayload,
    );

    if (result['status'] == true) {
      // Wallet update is now handled within BidService after successful API call
      // and then _setupStorageListeners updates local state.
      return true;
    } else {
      return false;
    }
  }

  void _showBidConfirmationDialog({
    required String gameTitle,
    required String gameDate,
    required String gameId,
    required String gameType,
    required List<Map<String, String>> bids,
    required int totalBids,
    required int totalBidsAmount,
    required int walletBalanceBeforeDeduction,
    required String walletBalanceAfterDeduction,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: gameTitle,
          gameDate: gameDate,
          gameId: gameId,
          gameType: gameType,
          bids: bids,
          totalBids: totalBids,
          totalBidsAmount: totalBidsAmount,
          walletBalanceBeforeDeduction: walletBalanceBeforeDeduction,
          walletBalanceAfterDeduction: walletBalanceAfterDeduction,
          onConfirm: () async {
            // Pop the confirmation dialog first
            // Navigator.pop(dialogContext);

            if (!mounted) return; // Check if widget is still mounted

            setState(() {
              _isSubmitting = true; // Set submission state
            });

            bool success = await _placeBidFinalSubmission(
              bidsToSubmit: _entries, // Pass the current list of entries
              totalAmountToSubmit: _getTotalPoints(),
              gameId: widget.gameId,
              gameType: widget.gameType,
              gameNameForApi: widget.gameName,
            );

            if (!mounted) return; // Check again after async operation

            if (success) {
              setState(() {
                _entries
                    .clear(); // Clear local entries on successful submission
              });
              _showMessage("All bids submitted successfully!", isError: false);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext dialogContext) =>
                    const BidSuccessDialog(),
              );
            } else {
              _showMessage(
                "Bid submission failed. Please try again.",
                isError: true,
              );
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext dialogContext) => BidFailureDialog(
                  errorMessage: "Bid submission failed. Please try again.",
                ),
              );
            }

            setState(() {
              _isSubmitting = false; // Reset submission state
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
            // Using GoogleFonts for consistency
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Image.asset(
                  "assets/images/ic_wallet.png",
                  width: 22,
                  height: 22,
                  color: Colors.black,
                ), // Using Material Icon
                const SizedBox(width: 4),
                Text(
                  '₹$_walletBalance', // Display dynamic wallet balance
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 16,
                  ), // Using GoogleFonts
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDigitInputField(
                            'Left Digit',
                            _leftDigitController,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDigitInputField(
                            'Right Digit',
                            _rightDigitController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Enter Points :',
                            style: GoogleFonts.poppins(
                              // Using GoogleFonts
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPointsInputField(_pointsController),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 150,
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : _addEntry, // Disable when submitting
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSubmitting
                                  ? Colors.grey
                                  : Colors.orange, // Grey out when disabled
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 3,
                            ),
                            child: _isSubmitting
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
                                    'ADD',
                                    style: GoogleFonts.poppins(
                                      // Using GoogleFonts
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey[400]),
              if (_entries.isNotEmpty)
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
                          'Jodi',
                          style: GoogleFonts.poppins(
                            // Using GoogleFonts
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Points',
                          style: GoogleFonts.poppins(
                            // Using GoogleFonts
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              if (_entries.isNotEmpty)
                Divider(height: 1, color: Colors.grey[400]),
              Expanded(
                child: _entries.isEmpty
                    ? Center(
                        child: Text(
                          'No entries yet. Add some data!',
                          style: GoogleFonts.poppins(
                            // Using GoogleFonts
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          return _buildEntryItem(
                            entry['jodi']!,
                            entry['points']!,
                            index,
                          );
                        },
                      ),
              ),
              if (_entries.isNotEmpty) _buildBottomBar(),
            ],
          ),
          // --- AnimatedMessageBar Positioned Here ---
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
          // --- End AnimatedMessageBar ---
        ],
      ),
    );
  }

  Widget _buildDigitInputField(String label, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        cursorColor: Colors.orange,
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: _clearMessage, // Clear message on tap
        enabled: !_isSubmitting, // Disable when submitting
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: Colors.grey[600],
          ), // Using GoogleFonts
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPointsInputField(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        cursorColor: Colors.orange,
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onTap: _clearMessage, // Clear message on tap
        enabled: !_isSubmitting, // Disable when submitting
        decoration: InputDecoration(
          hintText: 'Enter Points',
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey,
          ), // Using GoogleFonts
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryItem(String jodi, String points, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                jodi,
                style: GoogleFonts.poppins(
                  // Using GoogleFonts
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
                  // Using GoogleFonts
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _isSubmitting
                  ? null
                  : () => _deleteEntry(index), // Disable when submitting
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    int totalBids = _getTotalBidsCount();
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
                ), // Using GoogleFonts
              ),
              Text(
                '$totalBids',
                style: GoogleFonts.poppins(
                  // Using GoogleFonts
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
                ), // Using GoogleFonts
              ),
              Text(
                '$totalPoints',
                style: GoogleFonts.poppins(
                  // Using GoogleFonts
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: (_isSubmitting || _entries.isEmpty)
                ? null // Disable when submitting or no entries
                : () {
                    if (_entries.isEmpty) {
                      _showMessage(
                        'Please add some bids before submitting.',
                        isError: true,
                      );
                      return;
                    }
                    if (totalPoints > _walletBalance) {
                      _showMessage(
                        'Insufficient wallet balance to submit all bids.',
                        isError: true,
                      );
                      return;
                    }
                    // Call the confirmation dialog here
                    _showBidConfirmationDialog(
                      gameTitle: widget.title,
                      gameDate: DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(DateTime.now()),
                      gameId: widget.gameId,
                      gameType: widget.gameType,
                      bids: _entries
                          .map(
                            (e) => {
                              'digit': e['jodi']!,
                              'points': e['points']!,
                              'type': widget.gameType,
                            },
                          )
                          .toList(),
                      totalBids: totalBids,
                      totalBidsAmount: totalPoints,
                      walletBalanceBeforeDeduction: _walletBalance,
                      walletBalanceAfterDeduction:
                          (_walletBalance - totalPoints).toString(),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: (_isSubmitting || _entries.isEmpty)
                  ? Colors.grey
                  : Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: _isSubmitting
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
                    ), // Using GoogleFonts
                  ),
          ),
        ],
      ),
    );
  }
}

// import 'dart:async'; // For Timer
// import 'dart:convert'; // For json encoding/decoding
// import 'dart:developer'; // For log
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // For TextInputFormatter
// import 'package:get_storage/get_storage.dart'; // For GetStorage
// import 'package:http/http.dart' as http; // For making HTTP requests
// import 'package:intl/intl.dart'; // For date formatting
//
// import '../../components/AnimatedMessageBar.dart';
// import '../../components/BidConfirmationDialog.dart';
// import '../../components/BidFailureDialog.dart';
// import '../../components/BidSuccessDialog.dart';
// import '../../ulits/Constents.dart'; // Assuming Constents file exists
//
// class DigitBasedBoardScreen extends StatefulWidget {
//   final String title;
//   final String gameType;
//   final String gameId;
//   final String gameName; // Added gameName to determine API for bid submission
//
//   const DigitBasedBoardScreen({
//     Key? key,
//     required this.title,
//     required this.gameType,
//     required this.gameId,
//     required this.gameName, // Required for determining API
//   }) : super(key: key);
//
//   @override
//   _DigitBasedBoardScreenState createState() => _DigitBasedBoardScreenState();
// }
//
// class _DigitBasedBoardScreenState extends State<DigitBasedBoardScreen> {
//   final TextEditingController _leftDigitController = TextEditingController();
//   final TextEditingController _rightDigitController = TextEditingController();
//   final TextEditingController _pointsController = TextEditingController();
//
//   List<Map<String, String>> _entries = [];
//   int _walletBalance = 0; // State variable for wallet balance
//
//   // --- AnimatedMessageBar State ---
//   String? _messageToShow;
//   bool _isErrorForMessage = false;
//   Key _messageBarKey = UniqueKey(); // Key to force rebuild/re-animation
//   Timer? _messageDismissTimer; // Timer to auto-dismiss the message
//   // --- End AnimatedMessageBar State ---
//
//   late GetStorage storage; // Initialize GetStorage
//   String? _accessToken;
//   String? _registerId;
//
//   @override
//   void initState() {
//     super.initState();
//     storage = GetStorage(); // Initialize GetStorage
//     _loadInitialData(); // Load wallet balance, access token, register ID
//   }
//
//   @override
//   void dispose() {
//     _leftDigitController.dispose();
//     _rightDigitController.dispose();
//     _pointsController.dispose();
//     _messageDismissTimer?.cancel(); // Cancel timer on dispose
//     super.dispose();
//   }
//
//   Future<void> _loadInitialData() async {
//     _accessToken = storage.read('accessToken');
//     _registerId = storage.read('registerId');
//     final dynamic storedValue = storage.read('walletBalance');
//
//     if (storedValue != null) {
//       if (storedValue is int) {
//         _walletBalance = storedValue;
//       } else if (storedValue is String) {
//         _walletBalance = int.tryParse(storedValue) ?? 0;
//       } else {
//         _walletBalance = 0; // Fallback for unexpected types
//       }
//     } else {
//       _walletBalance = 1000; // Default balance if nothing is stored
//       storage.write(
//         'walletBalance',
//         _walletBalance,
//       ); // Save default if not present
//     }
//     setState(() {}); // Update UI to show loaded balance
//   }
//
//   void _updateWalletBalance(int spentAmount) {
//     setState(() {
//       _walletBalance -= spentAmount;
//       storage.write('walletBalance', _walletBalance); // Save updated balance
//     });
//   }
//
//   // --- AnimatedMessageBar Methods ---
//   void _showMessage(String message, {bool isError = false}) {
//     // Clear any existing timer
//     _messageDismissTimer?.cancel();
//
//     setState(() {
//       _messageToShow = message;
//       _isErrorForMessage = isError;
//       _messageBarKey =
//           UniqueKey(); // Force AnimatedMessageBar to re-initialize and animate
//     });
//
//     // Start a new timer to dismiss the message after 3 seconds
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
//   // --- End AnimatedMessageBar Methods ---
//
//   Future<void> _addEntry() async {
//     _clearMessage(); // Clear previous messages
//     final String leftDigit = _leftDigitController.text.trim();
//     final String rightDigit = _rightDigitController.text.trim();
//     final String points = _pointsController.text.trim();
//
//     // Client-side validation with AnimatedMessageBar
//     if (leftDigit.isEmpty && rightDigit.isEmpty) {
//       _showMessage('Please enter at least one digit.', isError: true);
//       return;
//     }
//
//     if (points.isEmpty) {
//       _showMessage('Please enter points.', isError: true);
//       return;
//     }
//
//     final int intPoints = int.tryParse(points) ?? 0;
//     if (intPoints <= 0) {
//       _showMessage('Points must be a positive number.', isError: true);
//       return;
//     }
//
//     // Validate left digit
//     if (leftDigit.isNotEmpty &&
//         (leftDigit.length != 1 || int.tryParse(leftDigit) == null)) {
//       _showMessage('Left digit must be a single number (0-9).', isError: true);
//       return;
//     }
//
//     // Validate right digit
//     if (rightDigit.isNotEmpty &&
//         (rightDigit.length != 1 || int.tryParse(rightDigit) == null)) {
//       _showMessage('Right digit must be a single number (0-9).', isError: true);
//       return;
//     }
//
//     // Determine the total amount to be deducted initially for validation
//     // This logic needs to align with your API's expected behavior for 'Digit Board'
//     // If backend returns multiple panas for a single leftDigit, pre-calculate that.
//     int estimatedCost = intPoints;
//     if (leftDigit.isNotEmpty && rightDigit.isEmpty) {
//       // Assuming 10 jodis are generated for left digit 0-9
//       estimatedCost = intPoints * 10;
//     } else if (leftDigit.isNotEmpty && rightDigit.isNotEmpty) {
//       estimatedCost = intPoints;
//     }
//
//     if (estimatedCost > _walletBalance) {
//       _showMessage(
//         'Insufficient wallet balance to add this bid.',
//         isError: true,
//       );
//       return;
//     }
//
//     // Prepare the body for the API call
//     final Map<String, dynamic> requestBody;
//     if (leftDigit.isNotEmpty && rightDigit.isEmpty) {
//       requestBody = {"leftDigit": int.parse(leftDigit), "amount": intPoints};
//     } else if (leftDigit.isNotEmpty && rightDigit.isNotEmpty) {
//       requestBody = {
//         "leftDigit": int.parse(leftDigit),
//         "rightDigit": int.parse(rightDigit),
//         "amount": intPoints,
//       };
//     } else {
//       _showMessage(
//         'Invalid digit combination. Please provide valid digits.',
//         isError: true,
//       );
//       return;
//     }
//
//     final url = Uri.parse('${Constant.apiEndpoint}digit-based-jodi');
//
//     if (_accessToken == null ||
//         _accessToken!.isEmpty ||
//         _registerId == null ||
//         _registerId!.isEmpty) {
//       _showMessage("Authentication error. Please log in again.", isError: true);
//       return;
//     }
//
//     final headers = {
//       'deviceId': 'qwert', // Placeholder
//       'deviceName': 'sm2233', // Placeholder
//       'accessStatus': '1', // Placeholder
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $_accessToken',
//     };
//
//     try {
//       final response = await http.post(
//         url,
//         headers: headers,
//         body: jsonEncode(requestBody),
//       );
//
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> responseData = json.decode(response.body);
//         if (responseData['status'] == true) {
//           final List<dynamic> info = responseData['info'] ?? [];
//           List<Map<String, String>> bidsFromApi = [];
//           int totalAmountDeducted = 0;
//
//           for (var item in info) {
//             final String pana = item['pana'].toString();
//             final String amount = item['amount'].toString();
//             bidsFromApi.add({
//               'digit':
//                   pana, // Changed from 'pana' to 'digit' to match BidConfirmationDialog expected key
//               'points': amount,
//               'type': 'Digit Board', // Or whatever specific type applies
//             });
//             totalAmountDeducted += int.tryParse(amount) ?? 0;
//           }
//
//           if (bidsFromApi.isNotEmpty) {
//             setState(() {
//               _entries.addAll(
//                 bidsFromApi.map(
//                   (e) => {
//                     'jodi': e['digit']!,
//                     'points': e['points']!,
//                   }, // Use 'digit' here
//                 ),
//               );
//               _leftDigitController.clear();
//               _rightDigitController.clear();
//               _pointsController.clear();
//             });
//
//             _updateWalletBalance(
//               totalAmountDeducted,
//             ); // Deduct total amount from wallet
//             _showMessage('Bid(s) added successfully!', isError: false);
//             // Show success dialog
//             showDialog(
//               context: context,
//               builder: (BuildContext context) {
//                 return const BidSuccessDialog();
//               },
//             );
//           } else {
//             // Handle the case where no bids were returned
//             _showMessage(
//               'API response was successful but no bids were returned.',
//               isError: true,
//             );
//           }
//         } else {
//           // Show failure dialog with specific error message
//           showDialog(
//             context: context,
//             builder: (BuildContext context) {
//               return BidFailureDialog(
//                 errorMessage:
//                     responseData['msg'] ??
//                     'Something went wrong.\nPlease try again latter.',
//               );
//             },
//           );
//           _showMessage(
//             'API Error: ${responseData['msg'] ?? 'Unknown error'}',
//             isError: true,
//           );
//         }
//       } else {
//         _showMessage(
//           'Server Error: ${response.statusCode} - ${response.reasonPhrase}',
//           isError: true,
//         );
//       }
//     } catch (e) {
//       _showMessage('Network Error: $e', isError: true);
//       log('Network error during _addEntry: $e'); // Log the error for debugging
//     }
//   }
//
//   void _deleteEntry(int index) {
//     setState(() {
//       final Map<String, String> removedEntry = _entries.removeAt(index);
//       // If you deduct points immediately upon adding, you might want to refund here.
//       // For now, assuming points are deducted on _addEntry or final submit.
//       _showMessage('Entry ${removedEntry['jodi']} removed.', isError: false);
//     });
//   }
//
//   int _getTotalBidsCount() {
//     return _entries.length;
//   }
//
//   int _getTotalPoints() {
//     return _entries.fold(
//       0,
//       (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
//     );
//   }
//
//   // This method now handles the API calls for final submission
//   // and updates the wallet balance based on the API response.
//   Future<bool> _placeBidFinalSubmission({
//     required List<Map<String, String>> bidsToSubmit,
//     required int totalAmountToSubmit,
//     required String gameId,
//     required String gameType,
//     required String gameNameForApi, // To determine which API endpoint to hit
//   }) async {
//     String url;
//     if (gameNameForApi.toLowerCase().contains('jackpot')) {
//       url = '${Constant.apiEndpoint}place-jackpot-bid';
//     } else if (gameNameForApi.toLowerCase().contains('starline')) {
//       url = '${Constant.apiEndpoint}place-starline-bid';
//     } else {
//       url = '${Constant.apiEndpoint}place-bid'; // General bid
//     }
//
//     if (_accessToken == null ||
//         _accessToken!.isEmpty ||
//         _registerId == null ||
//         _registerId!.isEmpty) {
//       log(
//         "🚨 Error: Access Token or Register ID is missing for final bid submission.",
//       );
//       return false;
//     }
//
//     final headers = {
//       'deviceId': 'qwert',
//       'deviceName': 'sm2233',
//       'accessStatus': '1',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $_accessToken',
//     };
//
//     final List<Map<String, dynamic>> bidPayload = bidsToSubmit.map((bid) {
//       String sessionType = bid["type"] ?? "";
//       String digit = bid["digit"] ?? "";
//       int bidAmount = int.tryParse(bid["points"] ?? bid["amount"] ?? '0') ?? 0;
//
//       if (bid["type"] != null && bid["type"]!.contains('(')) {
//         final String fullType = bid["type"]!;
//         final int startIndex = fullType.indexOf('(') + 1;
//         final int endIndex = fullType.indexOf(')');
//         if (startIndex > 0 && endIndex > startIndex) {
//           sessionType = fullType.substring(startIndex, endIndex).toUpperCase();
//         }
//       }
//
//       return {
//         "sessionType": sessionType,
//         "digit": digit,
//         "pana": digit, // Assuming pana is the same as digit for these types
//         "bidAmount": bidAmount,
//       };
//     }).toList();
//
//     final body = {
//       "registerId": _registerId,
//       "gameId": gameId,
//       "bidAmount": totalAmountToSubmit,
//       "gameType": gameType,
//       "bid": bidPayload,
//     };
//
//     // Log the cURL and headers here
//     String curlCommand = 'curl -X POST \\';
//     curlCommand += '\n  ${Uri.parse(url)} \\';
//     headers.forEach((key, value) {
//       curlCommand += '\n  -H "$key: $value" \\';
//     });
//     curlCommand += '\n  -d \'$body\'';
//
//     log('CURL Command for Final Bid Submission:\n$curlCommand');
//
//     log('Request Headers for Final Bid Submission: $headers');
//     log('Request Body for Final Bid Submission: $body');
//
//     log("Sending Final Bid Submission Request to: $url");
//     log("Headers: $headers");
//     log("Body: ${jsonEncode(body)}");
//
//     try {
//       final response = await http.post(
//         Uri.parse(url),
//         headers: headers,
//         body: jsonEncode(body),
//       );
//
//       final Map<String, dynamic> responseBody = json.decode(response.body);
//
//       if (response.statusCode == 200 && responseBody['status'] == true) {
//         // Update wallet balance in GetStorage only on successful bid submission
//         // The wallet balance deduction for individual bids is handled in _addEntry.
//         // For final submission, we just need to ensure the local wallet balance is current.
//         // It's safer to re-fetch wallet balance from API or rely on a global state management
//         // if multiple screens can affect it. For this context, we just update it.
//         // Assuming the API returns the new balance or we calculate it.
//         // Here, we calculate it based on totalAmountToSubmit.
//         _updateWalletBalance(
//           -totalAmountToSubmit,
//         ); // Deduct total amount from wallet on final success
//         log("✅ Final bid placed successfully");
//         log("Response Body: $responseBody");
//         return true;
//       } else {
//         String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
//         log("❌ Failed to place final bid: $errorMessage");
//         log("Status: ${response.statusCode}, Body: ${response.body}");
//         return false;
//       }
//     } catch (e) {
//       log("🚨 Error placing final bid: $e");
//       return false;
//     }
//   }
//
//   void _showBidConfirmationDialog({
//     required String gameTitle,
//     required String gameDate,
//     required String gameId,
//     required String gameType,
//     required List<Map<String, String>> bids,
//     required int totalBids,
//     required int totalBidsAmount,
//     required String walletBalanceBeforeDeduction,
//     String? walletBalanceAfterDeduction,
//   }) {
//     showDialog(
//       context: context,
//       barrierDismissible: false, // Prevent dismissal by tapping outside
//       builder: (BuildContext dialogContext) {
//         return BidConfirmationDialog(
//           gameTitle: gameTitle,
//           gameDate: gameDate,
//           gameId: gameId,
//           gameType: gameType,
//           bids: bids,
//           totalBids: totalBids,
//           totalBidsAmount: totalBidsAmount,
//           walletBalanceBeforeDeduction:
//               int.tryParse(walletBalanceBeforeDeduction) ?? 0,
//           walletBalanceAfterDeduction: walletBalanceAfterDeduction,
//           // onConfirm callback is now passed to BidConfirmationDialog
//           onConfirm: () async {
//             // This callback is executed when 'Submit' is pressed in BidConfirmationDialog
//             // The BidConfirmationDialog will pop itself before calling this.
//             bool success = await _placeBidFinalSubmission(
//               bidsToSubmit: bids,
//               totalAmountToSubmit: totalBidsAmount,
//               gameId: gameId,
//               gameType: gameType,
//               gameNameForApi: widget.gameName, // Pass gameName to determine API
//             );
//
//             if (success) {
//               setState(() {
//                 _entries
//                     .clear(); // Clear local entries on successful submission
//               });
//               _showMessage("All bids submitted successfully!", isError: false);
//             } else {
//               _showMessage(
//                 "Bid submission failed. Please try again.",
//                 isError: true,
//               );
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
//       backgroundColor: Colors.grey[200],
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//         title: Text(
//           widget.title,
//           style: const TextStyle(
//             color: Colors.black,
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 16.0),
//             child: Row(
//               children: [
//                 Image.asset(
//                   "assets/images/wallet_icon.png", // Ensure this path is correct
//                   height: 24,
//                   color: Colors.black,
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   '$_walletBalance', // Display dynamic wallet balance
//                   style: const TextStyle(color: Colors.black, fontSize: 16),
//                 ),
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
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _buildDigitInputField(
//                             'Left Digit',
//                             _leftDigitController,
//                           ),
//                         ),
//                         const SizedBox(width: 16),
//                         Expanded(
//                           child: _buildDigitInputField(
//                             'Right Digit',
//                             _rightDigitController,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         const Expanded(
//                           child: Text(
//                             'Enter Points :',
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: _buildPointsInputField(_pointsController),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.end,
//                       children: [
//                         SizedBox(
//                           width: 150,
//                           child: ElevatedButton(
//                             onPressed: _addEntry,
//                             child: const Text(
//                               'ADD',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 16,
//                               ),
//                             ),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.orange,
//                               padding: const EdgeInsets.symmetric(vertical: 12),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               elevation: 3,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               Divider(height: 1, color: Colors.grey[400]),
//               if (_entries.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16.0,
//                     vertical: 8.0,
//                   ),
//                   child: Row(
//                     children: [
//                       const Expanded(
//                         flex: 2,
//                         child: Text(
//                           'Jodi',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                       const Expanded(
//                         flex: 3,
//                         child: Text(
//                           'Points',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 48),
//                     ],
//                   ),
//                 ),
//               if (_entries.isNotEmpty)
//                 Divider(height: 1, color: Colors.grey[400]),
//               Expanded(
//                 child: _entries.isEmpty
//                     ? Center(
//                         child: Text(
//                           'No entries yet. Add some data!',
//                           style: TextStyle(
//                             fontSize: 16,
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                       )
//                     : ListView.builder(
//                         itemCount: _entries.length,
//                         itemBuilder: (context, index) {
//                           final entry = _entries[index];
//                           return _buildEntryItem(
//                             entry['jodi']!,
//                             entry['points']!,
//                             index,
//                           );
//                         },
//                       ),
//               ),
//               if (_entries.isNotEmpty) _buildBottomBar(),
//             ],
//           ),
//           // --- AnimatedMessageBar Positioned Here ---
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
//           // --- End AnimatedMessageBar ---
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDigitInputField(String label, TextEditingController controller) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey[300]!),
//       ),
//       child: TextField(
//         cursorColor: Colors.orange,
//         controller: controller,
//         keyboardType: TextInputType.number,
//         inputFormatters: [
//           LengthLimitingTextInputFormatter(1),
//           FilteringTextInputFormatter.digitsOnly,
//         ],
//         onTap: _clearMessage, // Clear message on tap
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: TextStyle(color: Colors.grey[600]),
//           border: InputBorder.none,
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 12,
//           ),
//           suffixIcon: Container(
//             margin: const EdgeInsets.all(8),
//             decoration: const BoxDecoration(
//               color: Colors.orange,
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(
//               Icons.arrow_forward,
//               color: Colors.white,
//               size: 16,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPointsInputField(TextEditingController controller) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey[300]!),
//       ),
//       child: TextField(
//         cursorColor: Colors.orange,
//         controller: controller,
//         keyboardType: TextInputType.number,
//         inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//         onTap: _clearMessage, // Clear message on tap
//         decoration: InputDecoration(
//           hintText: 'Enter Points',
//           border: InputBorder.none,
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 12,
//           ),
//           suffixIcon: Container(
//             margin: const EdgeInsets.all(8),
//             decoration: const BoxDecoration(
//               color: Colors.orange,
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(
//               Icons.arrow_forward,
//               color: Colors.white,
//               size: 16,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEntryItem(String jodi, String points, int index) {
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
//       elevation: 1,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
//         child: Row(
//           children: [
//             Expanded(
//               flex: 2,
//               child: Text(
//                 jodi,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//             Expanded(
//               flex: 3,
//               child: Text(
//                 points,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//             IconButton(
//               icon: const Icon(Icons.delete, color: Colors.red),
//               onPressed: () => _deleteEntry(index),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildBottomBar() {
//     int totalBids = _getTotalBidsCount();
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
//                 style: TextStyle(fontSize: 14, color: Colors.grey[700]),
//               ),
//               Text(
//                 '$totalBids',
//                 style: const TextStyle(
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
//                 style: TextStyle(fontSize: 14, color: Colors.grey[700]),
//               ),
//               Text(
//                 '$totalPoints',
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           ElevatedButton(
//             onPressed: () {
//               if (_entries.isEmpty) {
//                 _showMessage(
//                   'Please add some bids before submitting.',
//                   isError: true,
//                 );
//                 return;
//               }
//               if (totalPoints > _walletBalance) {
//                 _showMessage(
//                   'Insufficient wallet balance to submit all bids.',
//                   isError: true,
//                 );
//                 return;
//               }
//               // Call the confirmation dialog here
//               _showBidConfirmationDialog(
//                 gameTitle: widget.title,
//                 gameDate: DateFormat(
//                   'dd MMM yyyy, hh:mm a',
//                 ).format(DateTime.now()),
//                 gameId: widget.gameId,
//                 gameType: widget.gameType,
//                 bids: _entries
//                     .map(
//                       (e) => {
//                         'digit': e['jodi']!, // Map 'jodi' to 'digit'
//                         'points': e['points']!,
//                         'type': widget.gameType, // Use actual game type
//                       },
//                     )
//                     .toList(),
//                 totalBids: totalBids,
//                 totalBidsAmount: totalPoints,
//                 walletBalanceBeforeDeduction: _walletBalance.toString(),
//                 walletBalanceAfterDeduction: (_walletBalance - totalPoints)
//                     .toString(),
//               );
//             },
//             child: const Text(
//               'SUBMIT',
//               style: TextStyle(color: Colors.white, fontSize: 16),
//             ),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.orange,
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               elevation: 3,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
