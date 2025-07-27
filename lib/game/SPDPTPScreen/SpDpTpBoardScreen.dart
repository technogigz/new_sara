import 'dart:math'; // For Random number generation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
import 'package:marquee/marquee.dart';

import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';

class SpDpTpBoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;
  final String gameType; // Added gameType to constructor

  const SpDpTpBoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId, // Game ID is now required
    required this.gameType, // Game Type is now required
  }) : super(key: key);

  @override
  State<SpDpTpBoardScreen> createState() => _SpDpTpBoardScreenState();
}

class _SpDpTpBoardScreenState extends State<SpDpTpBoardScreen> {
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _pannaController =
      TextEditingController(); // Renamed for clarity - still for single digit input

  bool _isSPSelected = false;
  bool _isDPSelected = false;
  bool _isTPSelected = false;

  String? _selectedGameTypeOption = 'OPEN'; // Changed to OPEN/CLOSE options

  // List to store the added bids. Using 'amount' key for consistency.
  List<Map<String, String>> _bids = [];
  final Random _random = Random(); // Random instance for generating pannas

  late String walletBallence;
  String accessToken = '';
  String registerId = '';
  String preferredLanguage = 'en';
  bool accountStatus = false;
  final storage = GetStorage();

  // State management for AnimatedMessageBar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey(); // Key to force rebuild/re-animation

  @override
  void initState() {
    super.initState();
    final storedWallet = storage.read('walletBalance');

    // Initial read
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = storage.read('accountStatus') ?? false;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    // Corrected type conversion for initial read
    if (storedWallet is int) {
      walletBallence = storedWallet.toString();
    } else if (storedWallet is String) {
      walletBallence = storedWallet;
    } else {
      walletBallence = '0'; // Default to '0' if null or unexpected type
    }

    // Auto-update on key change
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
          walletBallence = value.toString();
        } else if (value is String) {
          walletBallence = value;
        } else {
          walletBallence = '0'; // Default to '0' if null or unexpected type
        }
      });
    });
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _pannaController.dispose();
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

  // Calculates the total points from the bids list
  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
    );
  }

  void _showConfirmationDialog() {
    _clearMessage(); // Clear any previous messages
    if (_bids.isEmpty) {
      _showMessage('Please add bids before submitting.', isError: true);
      return;
    }

    int currentTotalPoints = _getTotalPoints();
    int currentWalletBalance = int.tryParse(walletBallence) ?? 0;

    if (currentWalletBalance < currentTotalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
      return;
    }

    // Filter out bids with null or empty 'digit', 'amount', or 'gameType'
    final List<Map<String, String>> validBids = _bids
        .where((bid) {
          return bid['digit'] != null &&
              bid['digit']!.isNotEmpty &&
              bid['amount'] != null &&
              bid['amount']!.isNotEmpty &&
              bid['gameType'] != null &&
              bid['gameType']!.isNotEmpty;
        })
        .map((bid) {
          // Create a new map with the correct keys for the dialog
          return {
            'digit': bid['digit']!,
            'points':
                bid['amount']!, // 'amount' from _bids maps to 'points' in dialog
            'type':
                bid['gameType']!, // 'gameType' from _bids maps to 'type' in dialog
          };
        })
        .toList();

    if (validBids.isEmpty) {
      _showMessage('No valid bids to submit.', isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.screenTitle, // Corrected to screenTitle
          bids: validBids, // Pass the filtered and correctly mapped bids
          totalBids: validBids.length, // Update total bids count
          totalBidsAmount: currentTotalPoints,
          walletBalanceBeforeDeduction: currentWalletBalance,
          walletBalanceAfterDeduction:
              (currentWalletBalance - currentTotalPoints).toString(),

          gameDate: DateTime.now().toLocal().toString().split(' ')[0],
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () {
            // This is where your API call to submit bids would go
            _showMessage(
              'Bids submitted successfully (API integration needed)!',
              isError: false,
            );
            Navigator.pop(dialogContext); // Dismiss the confirmation dialog
            setState(() {
              _bids.clear(); // Clear bids after successful submission
            });
          },
        );
      },
    );
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
    Map<String, int> freq = {};
    for (var d in digits) {
      freq[d] = (freq[d] ?? 0) + 1;
    }
    return freq.length == 2 && freq.values.contains(2);
  }

  bool _isValidTpPanna(String panna) {
    if (panna.length != 3) return false;
    return panna[0] == panna[1] && panna[1] == panna[2];
  }

  // Function to add 10 random bids (triggered by the single "ADD" button)
  void _addTenRandomBids() {
    _clearMessage(); // Clear any previous messages
    final points = _pointsController.text.trim();

    // Validate points range (10 to 1000)
    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage(
        'Points must be between 10 and 1000 for random bids.',
        isError: true,
      );
      return;
    }

    // Determine selected game category (SP/DP/TP)
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
      _showMessage(
        'Please select SP, DP, or TP for random bids.',
        isError: true,
      );
      return;
    }
    if (selectedCount > 1) {
      _showMessage(
        'Please select only one of SP, DP, or TP for random bids.',
        isError: true,
      );
      return;
    }

    setState(() {
      int bidsAdded = 0;
      int maxAttemptsPerBid =
          200; // Increased attempts for more robust generation

      while (bidsAdded < 10) {
        String generatedPanna = '';
        bool isValid = false;
        int attempts = 0;

        while (!isValid && attempts < maxAttemptsPerBid) {
          attempts++;
          // Generate a random 3-digit number between 000 and 999. Need to format with leading zeros.
          String candidatePanna = _random
              .nextInt(1000)
              .toString()
              .padLeft(3, '0');

          if (gameCategory == 'SP') {
            isValid = _isValidSpPanna(candidatePanna);
          } else if (gameCategory == 'DP') {
            isValid = _isValidDpPanna(candidatePanna);
          } else if (gameCategory == 'TP') {
            isValid = _isValidTpPanna(candidatePanna);
          }

          // Check for duplicates in the current _bids list AND if it's valid
          if (isValid &&
              _bids.any(
                (bid) =>
                    bid['digit'] == candidatePanna &&
                    bid['gameType'] == gameCategory,
              )) {
            isValid = false; // It's a duplicate, try again
          }

          if (isValid) {
            generatedPanna =
                candidatePanna; // Assign only if valid and not duplicate
          }
        }

        if (isValid) {
          _bids.add({
            "digit": generatedPanna,
            "amount": points, // Changed to 'amount' for consistency
            "gameType": gameCategory,
          });
          bidsAdded++;
        } else if (attempts >= maxAttemptsPerBid) {
          // Could not find a valid unique panna after many attempts, stop trying for this bid
          _showMessage(
            'Could not generate 10 unique $gameCategory bids. Added $bidsAdded bids.',
            isError: true,
          );
          break; // Exit the while loop if unable to generate
        }
      }
      if (bidsAdded > 0) {
        _showMessage('Added $bidsAdded random bids of type $gameCategory.');
      }

      _pannaController.clear();
      _pointsController.clear();
    });
  }

  void _removeBid(int index) {
    _clearMessage(); // Clear any previous messages
    setState(() {
      final removedBid = _bids.removeAt(index);
      _showMessage(
        'Removed bid: ${removedBid['gameType']} ${removedBid['digit']}.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light gray background
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
              '$walletBallence', // Display wallet balance
              style: const TextStyle(
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
                          width: 150,
                          height: 40,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(
                                20,
                              ), // Adjusted border radius
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedGameTypeOption,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.amber,
                                ),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedGameTypeOption = newValue;
                                    _clearMessage(); // Clear message on dropdown change
                                  });
                                },
                                items:
                                    <String>[
                                          'OPEN',
                                          'CLOSE',
                                        ] // Options are now OPEN/CLOSE
                                        .map<DropdownMenuItem<String>>((
                                          String value,
                                        ) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: SizedBox(
                                              width:
                                                  150, // Constrain width for marquee
                                              height: 20, // Explicit height
                                              child: Marquee(
                                                text: value == 'OPEN'
                                                    ? '${widget.screenTitle.split(' - ')[0]} OPEN'
                                                    : '${widget.screenTitle.split(' - ')[0]} CLOSE',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                ),
                                                scrollAxis: Axis.horizontal,
                                                blankSpace: 40.0,
                                                velocity: 30.0,
                                                pauseAfterRound: const Duration(
                                                  seconds: 1,
                                                ),
                                                startPadding: 10.0,
                                                accelerationDuration:
                                                    const Duration(seconds: 1),
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
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Checkbox(
                                value: _isSPSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _isSPSelected = value!;
                                    if (value!) {
                                      _isDPSelected = false;
                                      _isTPSelected = false;
                                    }
                                    _clearMessage(); // Clear message on checkbox change
                                  });
                                },
                                activeColor: Colors.amber,
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
                            children: [
                              Checkbox(
                                value: _isDPSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _isDPSelected = value!;
                                    if (value!) {
                                      _isSPSelected = false;
                                      _isTPSelected = false;
                                    }
                                    _clearMessage(); // Clear message on checkbox change
                                  });
                                },
                                activeColor: Colors.amber,
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
                            children: [
                              Checkbox(
                                value: _isTPSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _isTPSelected = value!;
                                    if (value!) {
                                      _isSPSelected = false;
                                      _isDPSelected = false;
                                    }
                                    _clearMessage(); // Clear message on checkbox change
                                  });
                                },
                                activeColor: Colors.amber,
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
                        const Text(
                          'Enter Single Digits:',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(
                          width: 150,
                          height: 40,
                          child: TextField(
                            cursorColor: Colors.amber,
                            controller: _pannaController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(
                                1,
                              ), // Limit to 1 digit
                              FilteringTextInputFormatter
                                  .digitsOnly, // Only digits
                            ],
                            decoration: const InputDecoration(
                              hintText: 'Bid Digits',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(color: Colors.black),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(color: Colors.black),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.amber,
                                  width: 2,
                                ),
                              ),
                            ),
                            onTap:
                                _clearMessage, // Clear message on text field tap
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Enter Points:',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(
                          width: 150,
                          height: 40,
                          child: TextField(
                            cursorColor: Colors.amber,
                            controller: _pointsController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(
                                4,
                              ), // Allow up to 4 digits for 1000
                            ],
                            decoration: const InputDecoration(
                              hintText: 'Enter Amount',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(color: Colors.black),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(color: Colors.black),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.amber,
                                  width: 2,
                                ),
                              ),
                            ),
                            onTap:
                                _clearMessage, // Clear message on text field tap
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // Single "ADD" button for adding 10 random bids
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 150, // Set fixed width as requested
                        height: 45,
                        child: ElevatedButton(
                          onPressed:
                              _addTenRandomBids, // This button now triggers 10 random bids
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber, // Changed to amber
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            "ADD", // Changed text to "ADD"
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              fontSize: 16, // Adjusted font size
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(thickness: 1), // Divider after input section
              // Table Headers (conditionally rendered)
              if (_bids.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Digit',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Amount', // Changed to Amount
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Game Type',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Space for delete icon
                    ],
                  ),
                ),
              if (_bids.isNotEmpty) const Divider(thickness: 1),

              // Dynamic List of Bids
              Expanded(
                child: _bids.isEmpty
                    ? Center(
                        child: Text(
                          'No Bids Placed',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _bids.length,
                        itemBuilder: (context, index) {
                          final bid = _bids[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      bid['digit']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      bid['amount']!, // Changed to 'amount'
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      bid['gameType']!,
                                      style: GoogleFonts.poppins(
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeBid(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Bottom Bar (conditionally rendered)
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

  // Helper for bottom bar
  Widget _buildBottomBar() {
    int totalBids = _bids.length;
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
                _showConfirmationDialog, // Linked to the confirmation dialog
            child: Text(
              'SUBMIT',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
          ),
        ],
      ),
    );
  }
}
