import 'dart:async'; // For Timer
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get_storage/get_storage.dart'; // Required for wallet balance and tokens
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
// import 'package:http/http.dart' as http; // No longer directly needed for API calls
import 'package:intl/intl.dart'; // For date formatting in dialog
import 'package:marquee/marquee.dart'; // For Marquee widget
import 'package:new_sara/BidsServicesBulk.dart';

import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart'; // Added for potential API failure
import '../../components/BidSuccessDialog.dart'; // Added for potential API success

class ChoiceSpDpTpBoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId; // Added to constructor as required
  final String
  gameType; // Added to constructor as required (e.g., 'single patti', 'double patti')
  final String
  gameName; // New: Add gameName to determine API endpoint in BidService (e.g., 'Kalyan Morning')

  const ChoiceSpDpTpBoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId, // Game ID is now required
    required this.gameType, // Game Type is now required
    required this.gameName, // Game Name is required for BidService
  }) : super(key: key);

  @override
  State<ChoiceSpDpTpBoardScreen> createState() =>
      _ChoiceSpDpTpBoardScreenState();
}

class _ChoiceSpDpTpBoardScreenState extends State<ChoiceSpDpTpBoardScreen> {
  final TextEditingController _leftDigitController = TextEditingController();
  final TextEditingController _middleDigitController = TextEditingController();
  final TextEditingController _rightDigitController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  bool _isSPSelected = false;
  bool _isDPSelected = false;
  bool _isTPSelected = false;

  String? _selectedGameTypeOption; // OPEN or CLOSE

  List<Map<String, String>> _bids = []; // List to store the added bids

  // Wallet and user data from GetStorage
  String _walletBalance = '0'; // Changed to private for consistency
  final GetStorage _storage = GetStorage();
  late BidServiceBulk _bidService; // Declare BidService
  String _accessToken = ''; // Made private
  String _registerId = ''; // Made private
  bool _accountStatus = false; // Made private

  final String _deviceId = 'qwert'; // Consistent placeholder
  final String _deviceName = 'sm2233'; // Consistent placeholder

  // State management for AnimatedMessageBar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey(); // Key to force rebuild/re-animation
  Timer? _messageDismissTimer; // Timer for auto-dismiss

  // State variable to track API call status
  bool _isApiCalling = false; // Added to disable UI during API call

  @override
  void initState() {
    super.initState();
    _selectedGameTypeOption = 'OPEN'; // Default to OPEN

    _bidService = BidServiceBulk(_storage); // Initialize BidService

    // Initialize wallet balance and other user data from GetStorage
    _loadInitialData();
    _setupStorageListeners();
  }

  Future<void> _loadInitialData() async {
    _accessToken = _storage.read('accessToken') ?? '';
    _registerId = _storage.read('registerId') ?? '';
    _accountStatus = _storage.read('accountStatus') ?? false;

    final dynamic storedWalletBalance = _storage.read('walletBalance');
    if (storedWalletBalance is int) {
      _walletBalance = storedWalletBalance.toString();
    } else if (storedWalletBalance is String) {
      _walletBalance = storedWalletBalance;
    } else {
      _walletBalance = '0'; // Default if not found or unexpected type
    }
    setState(() {}); // Update UI with loaded balance
  }

  void _setupStorageListeners() {
    _storage.listenKey('accessToken', (value) {
      if (mounted) setState(() => _accessToken = value ?? '');
    });
    _storage.listenKey('registerId', (value) {
      if (mounted) setState(() => _registerId = value ?? '');
    });
    _storage.listenKey('accountStatus', (value) {
      if (mounted) setState(() => _accountStatus = value ?? false);
    });
    _storage.listenKey('walletBalance', (value) {
      if (mounted) {
        setState(() {
          if (value is int) {
            _walletBalance = value.toString();
          } else if (value is String) {
            _walletBalance = value;
          } else {
            _walletBalance = '0';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _leftDigitController.dispose();
    _middleDigitController.dispose();
    _rightDigitController.dispose();
    _pointsController.dispose();
    _messageDismissTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  // Helper method to show messages using AnimatedMessageBar
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

  // Helper method to clear the message bar
  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  // Helper function to validate Panna types
  bool _isValidSpPanna(String panna) {
    if (panna.length != 3) return false;
    Set<String> uniqueDigits = panna.split('').toSet();
    return uniqueDigits.length == 3;
  }

  bool _isValidDpPanna(String panna) {
    if (panna.length != 3) return false;
    List<String> digits = panna.split('');
    digits.sort();
    return (digits[0] == digits[1] && digits[1] != digits[2]) ||
        (digits[0] != digits[1] && digits[1] == digits[2]);
  }

  bool _isValidTpPanna(String panna) {
    if (panna.length != 3) return false;
    return panna[0] == panna[1] && panna[1] == panna[2];
  }

  void _addBid() {
    _clearMessage(); // Clear any previous messages
    if (_isApiCalling) return; // Prevent adding bids while API is busy

    final leftDigit = _leftDigitController.text.trim();
    final middleDigit = _middleDigitController.text.trim();
    final rightDigit = _rightDigitController.text.trim();
    final points = _pointsController.text.trim();

    // 1. Validate individual digits
    if (leftDigit.isEmpty || middleDigit.isEmpty || rightDigit.isEmpty) {
      _showMessage('Please enter all three digits.', isError: true);
      return;
    }
    if (leftDigit.length != 1 ||
        middleDigit.length != 1 ||
        rightDigit.length != 1 ||
        int.tryParse(leftDigit) == null ||
        int.tryParse(middleDigit) == null ||
        int.tryParse(rightDigit) == null) {
      _showMessage(
        'Please enter single digits (0-9) for Left, Middle, and Right.',
        isError: true,
      );
      return;
    }

    final pannaInput = '$leftDigit$middleDigit$rightDigit';

    // 2. Validate points range (10 to 10000)
    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 10000) {
      _showMessage('Points must be between 10 and 10000.', isError: true);
      return;
    }

    // 3. Determine selected game category (SP/DP/TP)
    String gameCategory = '';
    int selectedCount = 0;
    if (_isSPSelected) {
      gameCategory = 'SP';
      selectedCount++;
    }
    if (_isDPSelected) {
      gameCategory = 'DP';
      selectedCount++;
    }
    if (_isTPSelected) {
      gameCategory = 'TP';
      selectedCount++;
    }

    if (selectedCount == 0) {
      _showMessage('Please select SP, DP, or TP.', isError: true);
      return;
    }
    if (selectedCount > 1) {
      _showMessage('Please select only one of SP, DP, or TP.', isError: true);
      return;
    }

    // 4. Validate panna input based on selected game category
    bool isValidPanna = false;
    if (gameCategory == 'SP') {
      isValidPanna = _isValidSpPanna(pannaInput);
      if (!isValidPanna) {
        _showMessage('SP Panna must have 3 unique digits.', isError: true);
        return;
      }
    } else if (gameCategory == 'DP') {
      isValidPanna = _isValidDpPanna(pannaInput);
      if (!isValidPanna) {
        _showMessage(
          'DP Panna must have two same digits and one different.',
          isError: true,
        );
        return;
      }
    } else if (gameCategory == 'TP') {
      isValidPanna = _isValidTpPanna(pannaInput);
      if (!isValidPanna) {
        _showMessage('TP Panna must have 3 identical digits.', isError: true);
        return;
      }
    }

    // 5. Add bid if all validations pass
    if (isValidPanna) {
      setState(() {
        bool alreadyExists = _bids.any(
          (entry) =>
              entry['digit'] == pannaInput &&
              entry['gameType'] == gameCategory &&
              entry['type'] ==
                  _selectedGameTypeOption, // Also check type (OPEN/CLOSE)
        );

        if (!alreadyExists) {
          _bids.add({
            "digit": pannaInput,
            "points": points,
            "type": _selectedGameTypeOption!,
            "gameType": gameCategory,
          });
          _leftDigitController.clear();
          _middleDigitController.clear();
          _rightDigitController.clear();
          _pointsController.clear();
          // Reset checkboxes after successful add to prevent accidental multiple adds with wrong type
          _isSPSelected = false;
          _isDPSelected = false;
          _isTPSelected = false;
          _showMessage(
            'Bid added successfully for $gameCategory: $pannaInput.',
          );
        } else {
          _showMessage(
            'Panna $pannaInput already added for $gameCategory ($_selectedGameTypeOption).',
            isError: true,
          );
        }
      });
    }
  }

  void _removeBid(int index) {
    _clearMessage(); // Clear any previous messages
    if (_isApiCalling) return; // Prevent removing bids while API is busy

    setState(() {
      final removedBid = _bids.removeAt(index);
      _showMessage(
        'Removed bid: ${removedBid['gameType']} ${removedBid['digit']}.',
      );
    });
  }

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  void _showBidConfirmationDialog() {
    _clearMessage(); // Clear any previous messages
    if (_isApiCalling) return; // Prevent showing dialog if API is busy

    if (_bids.isEmpty) {
      _showMessage('Please add bids before submitting.', isError: true);
      return;
    }

    final int currentTotalPoints = _getTotalPoints();
    final int currentWalletBalance = int.tryParse(_walletBalance) ?? 0;

    if (currentWalletBalance < currentTotalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
      return;
    }

    // Filter and map bids to the format expected by BidConfirmationDialog
    final List<Map<String, String>> bidsForDialog = _bids.map((bid) {
      return {
        'digit': bid['digit']!,
        'points': bid['points']!,
        'type': '${bid['gameType']} (${bid['type']})', // Combine for display
      };
    }).toList();

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.screenTitle,
          gameDate: formattedDate,
          bids: bidsForDialog,
          totalBids: bidsForDialog.length,
          totalBidsAmount: currentTotalPoints,
          walletBalanceBeforeDeduction: currentWalletBalance,
          walletBalanceAfterDeduction:
              (currentWalletBalance - currentTotalPoints).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            log('Bids Confirmed for API submission: $bidsForDialog');
            Navigator.pop(dialogContext); // Dismiss the confirmation dialog

            setState(() {
              _isApiCalling = true; // Set API calling state
            });

            final result =
                await _placeFinalBids(); // Call the actual API method

            if (result['status'] == true) {
              setState(() {
                _bids.clear(); // Clear bids only on successful submission
              });
              _showMessage(result['msg'], isError: false);
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
              _showMessage(
                result['msg'] ?? "Bid submission failed. Please try again.",
                isError: true,
              );
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
            // Ensure API calling state is reset regardless of outcome
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

  // Refactored to use BidService
  Future<Map<String, dynamic>> _placeFinalBids() async {
    // Prepare bids for the BidService.placeFinalBids method
    // The BidService expects 'digit', 'points', 'type' in its bids list.
    // For SP/DP/TP, the 'digit' is the 'pannaInput' and 'type' is the 'sessionType' (OPEN/CLOSE)
    // plus a 'gameTypeCategory' (SP/DP/TP)
    final List<Map<String, String>> bidsForService = _bids.map((entry) {
      return {
        "digit": entry['digit']!, // The actual panna (e.g., "123")
        "points": entry['points']!,
        "type": entry['type']!, // This is 'OPEN' or 'CLOSE'
        "gameTypeCategory": entry['gameType']!, // This is 'SP', 'DP', 'TP'
      };
    }).toList();

    final result = await _bidService.placeFinalBids(
      gameName: widget
          .gameName, // Pass gameName to BidService for endpoint determination
      accessToken: _accessToken,
      registerId: _registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: _accountStatus,
      bids: bidsForService, // Pass the formatted bids
      gameType: widget
          .gameType, // The specific game type like "single patti", "double patti", "triple patti"
      gameId: widget.gameId,
      totalBidAmount: _getTotalPoints(),
      selectedSessionType:
          _selectedGameTypeOption ?? 'OPEN', // Pass the chosen session type
    );

    return result; // Return the result map directly
  }

  @override
  Widget build(BuildContext context) {
    String marketName = widget.screenTitle.contains(" - ")
        ? widget.screenTitle.split(' - ')[0]
        : widget.screenTitle;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.screenTitle,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
              '₹$_walletBalance', // Display wallet balance
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
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
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Game Type',
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                        SizedBox(
                          width: 180, // Increased width for longer text
                          height: 40,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black54),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedGameTypeOption,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.amber,
                                ),
                                onChanged:
                                    _isApiCalling // Disable if API is calling
                                    ? null
                                    : (String? newValue) {
                                        setState(() {
                                          _selectedGameTypeOption = newValue;
                                          _clearMessage(); // Clear message on dropdown change
                                        });
                                      },
                                items:
                                    const <String>[
                                          'OPEN',
                                          'CLOSE',
                                        ] // Added const
                                        .map<DropdownMenuItem<String>>((
                                          String value,
                                        ) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: SizedBox(
                                              width: 150,
                                              height: 20,
                                              child: Marquee(
                                                text: '$marketName $value',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                                scrollAxis: Axis.horizontal,
                                                blankSpace: 40.0,
                                                velocity: 30.0,
                                                pauseAfterRound: const Duration(
                                                  seconds: 2,
                                                ),
                                                showFadingOnlyWhenScrolling:
                                                    true,
                                                fadingEdgeStartFraction: 0.1,
                                                fadingEdgeEndFraction: 0.1,
                                                startPadding: 10.0,
                                                accelerationDuration:
                                                    const Duration(
                                                      milliseconds: 500,
                                                    ),
                                                accelerationCurve:
                                                    Curves.linear,
                                                decelerationDuration:
                                                    const Duration(
                                                      milliseconds: 500,
                                                    ),
                                                decelerationCurve:
                                                    Curves.easeOut,
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _isSPSelected,
                                onChanged:
                                    _isApiCalling // Disable if API is calling
                                    ? null
                                    : (bool? value) {
                                        setState(() {
                                          _isSPSelected = value ?? false;
                                          if (_isSPSelected) {
                                            _isDPSelected = false;
                                            _isTPSelected = false;
                                          }
                                          _clearMessage(); // Clear message on checkbox change
                                        });
                                      },
                                activeColor: Colors.amber,
                                checkColor: Colors.white,
                              ),
                              Text(
                                'SP',
                                style: GoogleFonts.poppins(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _isDPSelected,
                                onChanged:
                                    _isApiCalling // Disable if API is calling
                                    ? null
                                    : (bool? value) {
                                        setState(() {
                                          _isDPSelected = value ?? false;
                                          if (_isDPSelected) {
                                            _isSPSelected = false;
                                            _isTPSelected = false;
                                          }
                                          _clearMessage(); // Clear message on checkbox change
                                        });
                                      },
                                activeColor: Colors.amber,
                                checkColor: Colors.white,
                              ),
                              Text(
                                'DP',
                                style: GoogleFonts.poppins(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _isTPSelected,
                                onChanged:
                                    _isApiCalling // Disable if API is calling
                                    ? null
                                    : (bool? value) {
                                        setState(() {
                                          _isTPSelected = value ?? false;
                                          if (_isTPSelected) {
                                            _isSPSelected = false;
                                            _isDPSelected = false;
                                          }
                                          _clearMessage(); // Clear message on checkbox change
                                        });
                                      },
                                activeColor: Colors.amber,
                                checkColor: Colors.white,
                              ),
                              Text(
                                'TP',
                                style: GoogleFonts.poppins(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildDigitInputField(
                            'Digit 1', // Changed hint for clarity
                            _leftDigitController,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDigitInputField(
                            'Digit 2', // Changed hint for clarity
                            _middleDigitController,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDigitInputField(
                            'Digit 3', // Changed hint for clarity
                            _rightDigitController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment:
                          CrossAxisAlignment.center, // Align items vertically
                      children: [
                        Text(
                          'Enter Points:',
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                        SizedBox(
                          width: 150, // Keep width consistent
                          height: 40, // Keep height consistent
                          child: TextField(
                            cursorColor: Colors.amber,
                            controller: _pointsController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(
                                5,
                              ), // Max 5 digits for up to 10000
                            ],
                            decoration: InputDecoration(
                              hintText: 'Amount', // Simpler hint
                              hintStyle: GoogleFonts.poppins(fontSize: 14),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 8.0,
                              ), // Adjust padding
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Colors.black54,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Colors.black54,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Colors.amber,
                                  width: 2,
                                ),
                              ),
                            ),
                            onTap:
                                _clearMessage, // Clear message on text field tap
                            enabled:
                                !_isApiCalling, // Disable if API is calling
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20), // Increased spacing
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 150,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _isApiCalling
                              ? null
                              : _addBid, // Disable if API is calling
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                8,
                              ), // Slightly rounded corners
                            ),
                            elevation: 2,
                          ),
                          child: _isApiCalling
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                              : Text(
                                  "ADD", // More descriptive text
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10), // Spacing before divider
                  ],
                ),
              ),
              const Divider(thickness: 1, height: 1),
              if (_bids.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16.0,
                    8.0,
                    16.0,
                    0,
                  ), // Adjust padding
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2, // Give more space to digit
                        child: Text(
                          'Panna',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2, // Amount
                        child: Text(
                          'Amount',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3, // Game Type (SP/DP/TP) + (OPEN/CLOSE)
                        child: Text(
                          'Type',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Space for delete icon
                    ],
                  ),
                ),
              if (_bids.isNotEmpty)
                const Divider(
                  thickness: 0.5,
                  indent: 16,
                  endIndent: 16,
                  height: 10,
                ),
              Expanded(
                child: _bids.isEmpty
                    ? Center(
                        child: Text(
                          'No Bids Added Yet',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                          top: 0,
                          bottom: 8.0,
                        ), // Adjust padding
                        itemCount: _bids.length,
                        itemBuilder: (context, index) {
                          final bid = _bids[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.15),
                                  spreadRadius: 1,
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    bid['digit']!,
                                    style: GoogleFonts.poppins(fontSize: 15),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    bid['points']!,
                                    style: GoogleFonts.poppins(fontSize: 15),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '${bid['gameType']} (${bid['type']})',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors
                                          .blueGrey[700], // More subtle color
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  iconSize: 22,
                                  splashRadius: 20,
                                  padding:
                                      EdgeInsets.zero, // Remove extra padding
                                  constraints:
                                      const BoxConstraints(), // Remove extra constraints
                                  onPressed: _isApiCalling
                                      ? null
                                      : () => _removeBid(
                                          index,
                                        ), // Disable if API is calling
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (_bids.isNotEmpty) _buildBottomBar(),
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

  Widget _buildDigitInputField(String hint, TextEditingController controller) {
    return SizedBox(
      height: 40,
      child: TextField(
        cursorColor: Colors.amber,
        controller: controller,
        textAlign: TextAlign.center, // Center the input digit
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
        keyboardType: TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8.0,
          ), // Adjusted padding
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Colors.black54),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Colors.black54),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Colors.amber, width: 2),
          ),
        ),
        onTap: _clearMessage, // Clear message on text field tap
        enabled: !_isApiCalling, // Disable if API is calling
      ),
    );
  }

  Widget _buildBottomBar() {
    int totalBids = _bids.length;
    int totalPoints = _getTotalPoints();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 12,
      ), // Adjusted padding
      decoration: BoxDecoration(
        color: Colors.white, // Changed to white for better contrast with shadow
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // Softer shadow
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ), // Subtle top border
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Bids',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.blueGrey[700],
                ),
              ),
              Text(
                '$totalBids',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Points',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.blueGrey[700],
                ),
              ),
              Text(
                '$totalPoints',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: (_isApiCalling || _bids.isEmpty)
                ? null
                : _showBidConfirmationDialog, // Disable if API is calling or no bids
            style: ElevatedButton.styleFrom(
              backgroundColor: _isApiCalling
                  ? Colors.grey
                  : Colors.amber, // Dim if disabled
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
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
                      fontWeight: FontWeight.w600,
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
// import 'package:flutter/services.dart'; // For TextInputFormatter
// import 'package:get_storage/get_storage.dart'; // Required for wallet balance and tokens
// import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
// import 'package:http/http.dart' as http; // Import for making HTTP requests
// import 'package:intl/intl.dart'; // For date formatting in dialog
// import 'package:marquee/marquee.dart'; // For Marquee widget
//
// // Assuming these paths are correct for your components
// import '../../components/AnimatedMessageBar.dart';
// import '../../components/BidConfirmationDialog.dart';
// import '../../components/BidFailureDialog.dart'; // Added for potential API failure
// import '../../components/BidSuccessDialog.dart'; // Added for potential API success
// import '../../ulits/Constents.dart'; // Assuming this provides Constant.apiEndpoint
//
// class ChoiceSpDpTpBoardScreen extends StatefulWidget {
//   final String screenTitle;
//   final int gameId; // Added to constructor as required
//   final String gameType; // Added to constructor as required
//
//   const ChoiceSpDpTpBoardScreen({
//     Key? key,
//     required this.screenTitle,
//     required this.gameId, // Game ID is now required
//     required this.gameType, // Game Type is now required
//   }) : super(key: key);
//
//   @override
//   State<ChoiceSpDpTpBoardScreen> createState() =>
//       _ChoiceSpDpTpBoardScreenState();
// }
//
// class _ChoiceSpDpTpBoardScreenState extends State<ChoiceSpDpTpBoardScreen> {
//   final TextEditingController _leftDigitController = TextEditingController();
//   final TextEditingController _middleDigitController = TextEditingController();
//   final TextEditingController _rightDigitController = TextEditingController();
//   final TextEditingController _pointsController = TextEditingController();
//
//   bool _isSPSelected = false;
//   bool _isDPSelected = false;
//   bool _isTPSelected = false;
//
//   String? _selectedGameTypeOption;
//
//   List<Map<String, String>> _bids = []; // List to store the added bids
//
//   // Wallet and user data from GetStorage
//   late String walletBalance;
//   final GetStorage _storage = GetStorage();
//   late String accessToken; // For API calls
//   late String registerId; // For API calls
//   bool accountStatus = false; // For API calls
//   late String
//   preferredLanguage; // For API calls, though not used in API body directly
//
//   final String _deviceId = 'test_device_id_flutter'; // Example device ID
//   final String _deviceName = 'test_device_name_flutter'; // Example device Name
//
//   // State management for AnimatedMessageBar
//   String? _messageToShow;
//   bool _isErrorForMessage = false;
//   Key _messageBarKey = UniqueKey(); // Key to force rebuild/re-animation
//
//   // State variable to track API call status
//   bool _isApiCalling = false; // Added to disable UI during API call
//
//   @override
//   void initState() {
//     super.initState();
//     _selectedGameTypeOption = 'OPEN'; // Default to OPEN
//
//     // Initialize wallet balance and other user data from GetStorage
//     _loadInitialData();
//     _setupStorageListeners();
//   }
//
//   Future<void> _loadInitialData() async {
//     accessToken = _storage.read('accessToken') ?? '';
//     registerId = _storage.read('registerId') ?? '';
//     accountStatus = _storage.read('accountStatus') ?? false;
//     preferredLanguage = _storage.read('selectedLanguage') ?? 'en';
//
//     final dynamic storedWalletBalance = _storage.read('walletBalance');
//     if (storedWalletBalance is int) {
//       walletBalance = storedWalletBalance.toString();
//     } else if (storedWalletBalance is String) {
//       walletBalance = storedWalletBalance;
//     } else {
//       walletBalance = '0'; // Default if not found or unexpected type
//     }
//   }
//
//   void _setupStorageListeners() {
//     _storage.listenKey('accessToken', (value) {
//       if (mounted) setState(() => accessToken = value ?? '');
//     });
//     _storage.listenKey('registerId', (value) {
//       if (mounted) setState(() => registerId = value ?? '');
//     });
//     _storage.listenKey('accountStatus', (value) {
//       if (mounted) setState(() => accountStatus = value ?? false);
//     });
//     _storage.listenKey('selectedLanguage', (value) {
//       if (mounted) setState(() => preferredLanguage = value ?? 'en');
//     });
//     _storage.listenKey('walletBalance', (value) {
//       if (mounted) {
//         setState(() {
//           if (value is int) {
//             walletBalance = value.toString();
//           } else if (value is String) {
//             walletBalance = value;
//           } else {
//             walletBalance = '0';
//           }
//         });
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _leftDigitController.dispose();
//     _middleDigitController.dispose();
//     _rightDigitController.dispose();
//     _pointsController.dispose();
//     super.dispose();
//   }
//
//   // Helper method to show messages using AnimatedMessageBar
//   void _showMessage(String message, {bool isError = false}) {
//     setState(() {
//       _messageToShow = message;
//       _isErrorForMessage = isError;
//       _messageBarKey = UniqueKey(); // Update key to trigger animation
//     });
//   }
//
//   // Helper method to clear the message bar
//   void _clearMessage() {
//     if (mounted) {
//       setState(() {
//         _messageToShow = null;
//       });
//     }
//   }
//
//   // Helper function to validate Panna types
//   bool _isValidSpPanna(String panna) {
//     if (panna.length != 3) return false;
//     Set<String> uniqueDigits = panna.split('').toSet();
//     return uniqueDigits.length == 3;
//   }
//
//   // Corrected DP Panna validation
//   bool _isValidDpPanna(String panna) {
//     if (panna.length != 3) return false;
//     List<String> digits = panna.split('');
//     digits.sort(); // Sort to easily check for two same digits
//     // DP can be XYY or XXY or YXX. This logic covers that.
//     return (digits[0] == digits[1] && digits[1] != digits[2]) ||
//         (digits[0] != digits[1] && digits[1] == digits[2]);
//   }
//
//   bool _isValidTpPanna(String panna) {
//     if (panna.length != 3) return false;
//     return panna[0] == panna[1] && panna[1] == panna[2];
//   }
//
//   void _addBid() {
//     _clearMessage(); // Clear any previous messages
//     if (_isApiCalling) return; // Prevent adding bids while API is busy
//
//     log("ADD button pressed - entering _addBid"); // Debug print
//     final leftDigit = _leftDigitController.text.trim();
//     final middleDigit = _middleDigitController.text.trim();
//     final rightDigit = _rightDigitController.text.trim();
//     final points = _pointsController.text.trim();
//
//     // 1. Validate individual digits
//     if (leftDigit.isEmpty || middleDigit.isEmpty || rightDigit.isEmpty) {
//       _showMessage('Please enter all three digits.', isError: true);
//       return;
//     }
//     if (leftDigit.length != 1 ||
//         middleDigit.length != 1 ||
//         rightDigit.length != 1 ||
//         int.tryParse(leftDigit) == null ||
//         int.tryParse(middleDigit) == null ||
//         int.tryParse(rightDigit) == null) {
//       _showMessage(
//         'Please enter single digits for Left, Middle, and Right.',
//         isError: true,
//       );
//       return;
//     }
//
//     final pannaInput = '$leftDigit$middleDigit$rightDigit';
//
//     // 2. Validate points range (10 to 10000)
//     int? parsedPoints = int.tryParse(points);
//     if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 10000) {
//       _showMessage('Points must be between 10 and 10000.', isError: true);
//       return;
//     }
//
//     // 3. Determine selected game category (SP/DP/TP)
//     String gameCategory = '';
//     int selectedCount = 0;
//     if (_isSPSelected) {
//       gameCategory = 'SP';
//       selectedCount++;
//     }
//     if (_isDPSelected) {
//       gameCategory = 'DP';
//       selectedCount++;
//     }
//     if (_isTPSelected) {
//       gameCategory = 'TP';
//       selectedCount++;
//     }
//
//     if (selectedCount == 0) {
//       _showMessage('Please select SP, DP, or TP.', isError: true);
//       return;
//     }
//     if (selectedCount > 1) {
//       _showMessage('Please select only one of SP, DP, or TP.', isError: true);
//       return;
//     }
//
//     // 4. Validate panna input based on selected game category
//     bool isValidPanna = false;
//     if (gameCategory == 'SP') {
//       isValidPanna = _isValidSpPanna(pannaInput);
//       if (!isValidPanna) {
//         _showMessage('SP Panna must have 3 unique digits.', isError: true);
//         return;
//       }
//     } else if (gameCategory == 'DP') {
//       isValidPanna = _isValidDpPanna(pannaInput);
//       if (!isValidPanna) {
//         _showMessage(
//           'DP Panna must have two same digits and one different.',
//           isError: true,
//         );
//         return;
//       }
//     } else if (gameCategory == 'TP') {
//       isValidPanna = _isValidTpPanna(pannaInput);
//       if (!isValidPanna) {
//         _showMessage('TP Panna must have 3 identical digits.', isError: true);
//         return;
//       }
//     }
//
//     // 5. Add bid if all validations pass
//     if (isValidPanna) {
//       setState(() {
//         bool alreadyExists = _bids.any(
//           (entry) =>
//               entry['digit'] == pannaInput &&
//               entry['gameType'] == gameCategory &&
//               entry['type'] ==
//                   _selectedGameTypeOption, // Also check type (OPEN/CLOSE)
//         );
//
//         if (!alreadyExists) {
//           log(
//             // Debug print
//             "Adding single bid: Digit-$pannaInput, Points-$points, Type-$_selectedGameTypeOption, GameType-$gameCategory",
//           );
//           _bids.add({
//             "digit": pannaInput,
//             "points": points,
//             "type": _selectedGameTypeOption!,
//             "gameType": gameCategory,
//           });
//           _leftDigitController.clear();
//           _middleDigitController.clear();
//           _rightDigitController.clear();
//           _pointsController.clear();
//           // Reset checkboxes after successful add to prevent accidental multiple adds with wrong type
//           _isSPSelected = false;
//           _isDPSelected = false;
//           _isTPSelected = false;
//           _showMessage(
//             'Bid added successfully for $gameCategory: $pannaInput.',
//           );
//         } else {
//           _showMessage(
//             'Panna $pannaInput already added for $gameCategory ($_selectedGameTypeOption).',
//             isError: true,
//           );
//         }
//       });
//     }
//   }
//
//   void _removeBid(int index) {
//     _clearMessage(); // Clear any previous messages
//     if (_isApiCalling) return; // Prevent removing bids while API is busy
//
//     setState(() {
//       final removedBid = _bids.removeAt(index);
//       _showMessage(
//         'Removed bid: ${removedBid['gameType']} ${removedBid['digit']}.',
//       );
//     });
//   }
//
//   int _getTotalPoints() {
//     return _bids.fold(
//       0,
//       (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
//     );
//   }
//
//   void _showBidConfirmationDialog() {
//     _clearMessage(); // Clear any previous messages
//     if (_isApiCalling) return; // Prevent showing dialog if API is busy
//
//     if (_bids.isEmpty) {
//       _showMessage('Please add bids before submitting.', isError: true);
//       return;
//     }
//
//     final int currentTotalPoints = _getTotalPoints();
//     final int currentWalletBalance = int.tryParse(walletBalance) ?? 0;
//
//     if (currentWalletBalance < currentTotalPoints) {
//       _showMessage(
//         'Insufficient wallet balance to place this bid.',
//         isError: true,
//       );
//       return;
//     }
//
//     // Filter and map bids to the format expected by BidConfirmationDialog
//     final List<Map<String, String>> bidsForDialog = _bids.map((bid) {
//       return {
//         'digit': bid['digit']!,
//         'points': bid['points']!,
//         'type': '${bid['gameType']} (${bid['type']})', // Combine for display
//       };
//     }).toList();
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
//           gameTitle: widget.screenTitle,
//           gameDate: formattedDate,
//           bids: bidsForDialog,
//           totalBids: bidsForDialog.length,
//           totalBidsAmount: currentTotalPoints,
//           walletBalanceBeforeDeduction: currentWalletBalance,
//           walletBalanceAfterDeduction:
//               (currentWalletBalance - currentTotalPoints).toString(),
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameType,
//           onConfirm: () async {
//             log('Bids Confirmed for API submission: $bidsForDialog');
//             Navigator.pop(dialogContext); // Dismiss the confirmation dialog
//
//             setState(() {
//               _isApiCalling = true; // Set API calling state
//             });
//
//             bool success =
//                 await _placeFinalBids(); // Call the actual API method
//
//             if (success) {
//               setState(() {
//                 _bids.clear(); // Clear bids only on successful submission
//               });
//             }
//             // Ensure API calling state is reset regardless of outcome
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
//     final gameCategory = widget.gameType.toLowerCase();
//
//     // Determine the correct API endpoint based on gameType
//     if (gameCategory.contains('jackpot')) {
//       url = '${Constant.apiEndpoint}place-jackpot-bid';
//     } else if (gameCategory.contains('starline')) {
//       url = '${Constant.apiEndpoint}place-starline-bid';
//     } else {
//       // Assuming 'place-bid' for regular games like SP/DP/TP
//       url = '${Constant.apiEndpoint}place-bid';
//     }
//
//     // --- Authentication Check ---
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
//       'accessStatus': accountStatus ? '1' : '0', // Convert bool to '1' or '0'
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $accessToken',
//     };
//
//     final List<Map<String, dynamic>> bidPayload = _bids.map((entry) {
//       final String bidDigit = entry['digit'] ?? '';
//       final int bidAmount = int.tryParse(entry['points'] ?? '0') ?? 0;
//       final String gameTypeCategory = entry['gameType'] ?? ''; // SP/DP/TP
//
//       return {
//         "sessionType": entry['type']?.toUpperCase() ?? '', // OPEN/CLOSE
//         "digit": bidDigit,
//         "pana": bidDigit, // For SP/DP/TP, the panna is the digit itself
//         "jodi":
//             "", // Assuming jodi is not applicable or an empty string for this game
//         "gameTypeCategory": gameTypeCategory, // SP, DP, TP
//         "bidAmount": bidAmount,
//       };
//     }).toList();
//
//     final body = jsonEncode({
//       "registerId": registerId,
//       "gameId": widget.gameId,
//       "bidAmount": _getTotalPoints(),
//       "gameType": widget.gameType, // Pass the original gameType from widget
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
//         int newWalletBalance =
//             (int.tryParse(walletBalance) ?? 0) - _getTotalPoints();
//         await _storage.write('walletBalance', newWalletBalance); // Store as int
//
//         if (mounted) {
//           setState(() {
//             walletBalance = newWalletBalance.toString(); // Update local state
//           });
//           // Show success dialog
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
//     String marketName = widget.screenTitle.contains(" - ")
//         ? widget.screenTitle.split(' - ')[0]
//         : widget.screenTitle;
//
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F5F5),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 1,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           widget.screenTitle,
//           style: GoogleFonts.poppins(
//             color: Colors.black,
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         actions: [
//           const Icon(
//             Icons.account_balance_wallet_outlined,
//             color: Colors.black,
//           ),
//           const SizedBox(width: 6),
//           Center(
//             // Ensure the '5' is vertically centered
//             child: Text(
//               walletBalance, // Display wallet balance
//               style: GoogleFonts.poppins(
//                 // Using GoogleFonts for consistency
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
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
//                   horizontal: 16.0,
//                   vertical: 12.0,
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Select Game Type',
//                           style: GoogleFonts.poppins(fontSize: 16),
//                         ),
//                         SizedBox(
//                           width: 180, // Increased width for longer text
//                           height: 40,
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 12),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               border: Border.all(color: Colors.black54),
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                             child: DropdownButtonHideUnderline(
//                               child: DropdownButton<String>(
//                                 isExpanded: true,
//                                 value: _selectedGameTypeOption,
//                                 icon: const Icon(
//                                   Icons.keyboard_arrow_down,
//                                   color: Colors.amber,
//                                 ),
//                                 onChanged:
//                                     _isApiCalling // Disable if API is calling
//                                     ? null
//                                     : (String? newValue) {
//                                         setState(() {
//                                           _selectedGameTypeOption = newValue;
//                                           _clearMessage(); // Clear message on dropdown change
//                                         });
//                                       },
//                                 items:
//                                     const <String>[
//                                           'OPEN',
//                                           'CLOSE',
//                                         ] // Added const
//                                         .map<DropdownMenuItem<String>>((
//                                           String value,
//                                         ) {
//                                           return DropdownMenuItem<String>(
//                                             value: value,
//                                             child: SizedBox(
//                                               width: 150,
//                                               height: 20,
//                                               child: Marquee(
//                                                 text: '$marketName $value',
//                                                 style: GoogleFonts.poppins(
//                                                   fontSize: 14,
//                                                   color: Colors.black87,
//                                                 ),
//                                                 scrollAxis: Axis.horizontal,
//                                                 blankSpace: 40.0,
//                                                 velocity: 30.0,
//                                                 pauseAfterRound: const Duration(
//                                                   seconds: 2,
//                                                 ),
//                                                 showFadingOnlyWhenScrolling:
//                                                     true,
//                                                 fadingEdgeStartFraction: 0.1,
//                                                 fadingEdgeEndFraction: 0.1,
//                                                 startPadding: 10.0,
//                                                 accelerationDuration:
//                                                     const Duration(
//                                                       milliseconds: 500,
//                                                     ),
//                                                 accelerationCurve:
//                                                     Curves.linear,
//                                                 decelerationDuration:
//                                                     const Duration(
//                                                       milliseconds: 500,
//                                                     ),
//                                                 decelerationCurve:
//                                                     Curves.easeOut,
//                                               ),
//                                             ),
//                                           );
//                                         })
//                                         .toList(),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Checkbox(
//                                 value: _isSPSelected,
//                                 onChanged:
//                                     _isApiCalling // Disable if API is calling
//                                     ? null
//                                     : (bool? value) {
//                                         setState(() {
//                                           _isSPSelected = value ?? false;
//                                           if (_isSPSelected) {
//                                             _isDPSelected = false;
//                                             _isTPSelected = false;
//                                           }
//                                           _clearMessage(); // Clear message on checkbox change
//                                         });
//                                       },
//                                 activeColor: Colors.amber,
//                                 checkColor: Colors.white,
//                               ),
//                               Text(
//                                 'SP',
//                                 style: GoogleFonts.poppins(fontSize: 16),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Expanded(
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Checkbox(
//                                 value: _isDPSelected,
//                                 onChanged:
//                                     _isApiCalling // Disable if API is calling
//                                     ? null
//                                     : (bool? value) {
//                                         setState(() {
//                                           _isDPSelected = value ?? false;
//                                           if (_isDPSelected) {
//                                             _isSPSelected = false;
//                                             _isTPSelected = false;
//                                           }
//                                           _clearMessage(); // Clear message on checkbox change
//                                         });
//                                       },
//                                 activeColor: Colors.amber,
//                                 checkColor: Colors.white,
//                               ),
//                               Text(
//                                 'DP',
//                                 style: GoogleFonts.poppins(fontSize: 16),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Expanded(
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Checkbox(
//                                 value: _isTPSelected,
//                                 onChanged:
//                                     _isApiCalling // Disable if API is calling
//                                     ? null
//                                     : (bool? value) {
//                                         setState(() {
//                                           _isTPSelected = value ?? false;
//                                           if (_isTPSelected) {
//                                             _isSPSelected = false;
//                                             _isDPSelected = false;
//                                           }
//                                           _clearMessage(); // Clear message on checkbox change
//                                         });
//                                       },
//                                 activeColor: Colors.amber,
//                                 checkColor: Colors.white,
//                               ),
//                               Text(
//                                 'TP',
//                                 style: GoogleFonts.poppins(fontSize: 16),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Expanded(
//                           child: _buildDigitInputField(
//                             'Digit 1', // Changed hint for clarity
//                             _leftDigitController,
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: _buildDigitInputField(
//                             'Digit 2', // Changed hint for clarity
//                             _middleDigitController,
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: _buildDigitInputField(
//                             'Digit 3', // Changed hint for clarity
//                             _rightDigitController,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       crossAxisAlignment:
//                           CrossAxisAlignment.center, // Align items vertically
//                       children: [
//                         Text(
//                           'Enter Points:',
//                           style: GoogleFonts.poppins(fontSize: 16),
//                         ),
//                         SizedBox(
//                           width: 150, // Keep width consistent
//                           height: 40, // Keep height consistent
//                           child: TextField(
//                             cursorColor: Colors.amber,
//                             controller: _pointsController,
//                             keyboardType: TextInputType.number,
//                             inputFormatters: [
//                               FilteringTextInputFormatter.digitsOnly,
//                               LengthLimitingTextInputFormatter(
//                                 5,
//                               ), // Max 5 digits for up to 10000
//                             ],
//                             decoration: InputDecoration(
//                               // Apply consistent styling
//                               hintText: 'Amount', // Simpler hint
//                               hintStyle: GoogleFonts.poppins(fontSize: 14),
//                               contentPadding: const EdgeInsets.symmetric(
//                                 horizontal: 12.0,
//                                 vertical: 8.0,
//                               ), // Adjust padding
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(20),
//                                 borderSide: const BorderSide(
//                                   color: Colors.black54,
//                                 ),
//                               ),
//                               enabledBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(20),
//                                 borderSide: const BorderSide(
//                                   color: Colors.black54,
//                                 ),
//                               ),
//                               focusedBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(20),
//                                 borderSide: const BorderSide(
//                                   color: Colors.amber,
//                                   width: 2,
//                                 ),
//                               ),
//                             ),
//                             onTap:
//                                 _clearMessage, // Clear message on text field tap
//                             enabled:
//                                 !_isApiCalling, // Disable if API is calling
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 20), // Increased spacing
//                     Align(
//                       alignment: Alignment.centerRight,
//                       child: SizedBox(
//                         width: 150,
//                         height: 45,
//                         child: ElevatedButton(
//                           onPressed: _isApiCalling
//                               ? null
//                               : _addBid, // Disable if API is calling
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.amber,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(
//                                 8,
//                               ), // Slightly rounded corners
//                             ),
//                             elevation: 2,
//                           ),
//                           child: _isApiCalling
//                               ? const CircularProgressIndicator(
//                                   color: Colors.white,
//                                   strokeWidth: 2,
//                                 )
//                               : Text(
//                                   "ADD", // More descriptive text
//                                   textAlign: TextAlign.center,
//                                   style: GoogleFonts.poppins(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.w600,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 10), // Spacing before divider
//                   ],
//                 ),
//               ),
//               const Divider(thickness: 1, height: 1),
//               if (_bids.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(
//                     16.0,
//                     8.0,
//                     16.0,
//                     0,
//                   ), // Adjust padding
//                   child: Row(
//                     children: [
//                       Expanded(
//                         flex: 2, // Give more space to digit
//                         child: Text(
//                           'Panna',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         flex: 2, // Amount
//                         child: Text(
//                           'Amount',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         flex: 3, // Game Type (SP/DP/TP) + (OPEN/CLOSE)
//                         child: Text(
//                           'Type',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 48), // Space for delete icon
//                     ],
//                   ),
//                 ),
//               if (_bids.isNotEmpty)
//                 const Divider(
//                   thickness: 0.5,
//                   indent: 16,
//                   endIndent: 16,
//                   height: 10,
//                 ),
//
//               Expanded(
//                 child: _bids.isEmpty
//                     ? Center(
//                         child: Text(
//                           'No Bids Added Yet',
//                           style: GoogleFonts.poppins(
//                             fontSize: 16,
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                       )
//                     : ListView.builder(
//                         padding: const EdgeInsets.only(
//                           top: 0,
//                           bottom: 8.0,
//                         ), // Adjust padding
//                         itemCount: _bids.length,
//                         itemBuilder: (context, index) {
//                           final bid = _bids[index];
//                           return Container(
//                             margin: const EdgeInsets.symmetric(
//                               horizontal: 16,
//                               vertical: 4,
//                             ),
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 12.0,
//                               vertical: 8.0,
//                             ),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(8),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.grey.withOpacity(0.15),
//                                   spreadRadius: 1,
//                                   blurRadius: 2,
//                                   offset: const Offset(0, 1),
//                                 ),
//                               ],
//                             ),
//                             child: Row(
//                               children: [
//                                 Expanded(
//                                   flex: 2,
//                                   child: Text(
//                                     bid['digit']!,
//                                     style: GoogleFonts.poppins(fontSize: 15),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   flex: 2,
//                                   child: Text(
//                                     bid['points']!,
//                                     style: GoogleFonts.poppins(fontSize: 15),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   flex: 3,
//                                   child: Text(
//                                     '${bid['gameType']} (${bid['type']})',
//                                     style: GoogleFonts.poppins(
//                                       fontSize: 14,
//                                       color: Colors
//                                           .blueGrey[700], // More subtle color
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ),
//                                 IconButton(
//                                   icon: const Icon(
//                                     Icons.delete_outline,
//                                     color: Colors.redAccent,
//                                   ),
//                                   iconSize: 22,
//                                   splashRadius: 20,
//                                   padding:
//                                       EdgeInsets.zero, // Remove extra padding
//                                   constraints:
//                                       const BoxConstraints(), // Remove extra constraints
//                                   onPressed: _isApiCalling
//                                       ? null
//                                       : () => _removeBid(
//                                           index,
//                                         ), // Disable if API is calling
//                                 ),
//                               ],
//                             ),
//                           );
//                         },
//                       ),
//               ),
//               if (_bids.isNotEmpty) _buildBottomBar(),
//             ],
//           ),
//           // AnimatedMessageBar positioned at the top
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
//   Widget _buildDigitInputField(String hint, TextEditingController controller) {
//     return SizedBox(
//       height: 40,
//       child: TextField(
//         cursorColor: Colors.amber,
//         controller: controller,
//         textAlign: TextAlign.center, // Center the input digit
//         style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
//         keyboardType: TextInputType.number,
//         inputFormatters: [
//           LengthLimitingTextInputFormatter(1),
//           FilteringTextInputFormatter.digitsOnly,
//         ],
//         decoration: InputDecoration(
//           hintText: hint,
//           hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
//           contentPadding: const EdgeInsets.symmetric(
//             vertical: 8.0,
//           ), // Adjusted padding
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(20),
//             borderSide: const BorderSide(color: Colors.black54),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(20),
//             borderSide: const BorderSide(color: Colors.black54),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(20),
//             borderSide: const BorderSide(color: Colors.amber, width: 2),
//           ),
//         ),
//         onTap: _clearMessage, // Clear message on text field tap
//         enabled: !_isApiCalling, // Disable if API is calling
//       ),
//     );
//   }
//
//   Widget _buildBottomBar() {
//     int totalBids = _bids.length;
//     int totalPoints = _getTotalPoints();
//
//     return Container(
//       padding: const EdgeInsets.symmetric(
//         horizontal: 20,
//         vertical: 12,
//       ), // Adjusted padding
//       decoration: BoxDecoration(
//         color: Colors.white, // Changed to white for better contrast with shadow
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1), // Softer shadow
//             spreadRadius: 0,
//             blurRadius: 10,
//             offset: const Offset(0, -2),
//           ),
//         ],
//         border: Border(
//           top: BorderSide(color: Colors.grey[300]!, width: 0.5),
//         ), // Subtle top border
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 'Total Bids',
//                 style: GoogleFonts.poppins(
//                   fontSize: 13,
//                   color: Colors.blueGrey[700],
//                 ),
//               ),
//               Text(
//                 '$totalBids',
//                 style: GoogleFonts.poppins(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 'Total Points',
//                 style: GoogleFonts.poppins(
//                   fontSize: 13,
//                   color: Colors.blueGrey[700],
//                 ),
//               ),
//               Text(
//                 '$totalPoints',
//                 style: GoogleFonts.poppins(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//           ElevatedButton(
//             onPressed: _isApiCalling
//                 ? null
//                 : _showBidConfirmationDialog, // Disable if API is calling
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _isApiCalling
//                   ? Colors.grey
//                   : Colors.amber, // Dim if disabled
//               padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               elevation: 2,
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
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }
