import 'dart:async'; // For Timer

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
import 'package:intl/intl.dart';

import '../../BidService.dart'; // Assuming BidService.dart is in the parent directory
import '../../components/AnimatedMessageBar.dart'; // Assuming this component is separate
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';

class SingleDigitsBulkScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameName;
  final String gameType; // This should be like "singleDigits"
  final bool selectionStatus;

  const SingleDigitsBulkScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameType,
    required this.selectionStatus,
  }) : super(key: key);

  @override
  State<SingleDigitsBulkScreen> createState() => _SingleDigitsBulkScreenState();
}

class _SingleDigitsBulkScreenState extends State<SingleDigitsBulkScreen> {
  late String selectedGameType =
      'Open'; // This refers to sessionType (Open/Close)
  final List<String> gameTypes = ['Open', 'Close'];

  final TextEditingController pointsController = TextEditingController();

  Color dropdownBorderColor = Colors.black;
  Color textFieldBorderColor = Colors.black;

  // bidAmounts maps digit (e.g., "7") to amount (e.g., "100")
  Map<String, String> bidAmounts = {};
  late GetStorage storage;
  late BidService _bidService; // Declare BidService

  late String _accessToken; // Renamed to private to match common convention
  late String _registerId; // Renamed to private
  bool _accountStatus = false; // Renamed to private
  int _walletBalance = 0; // Renamed to private, directly storing int

  // --- AnimatedMessageBar State Management ---
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer; // Initialize Timer here
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
    _bidService = BidService(storage); // Initialize BidService with GetStorage
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
    _messageDismissTimer?.cancel(); // Cancel the timer on dispose
    super.dispose();
  }

  // --- AnimatedMessageBar Helper Methods ---
  void _showMessage(String message, {bool isError = false}) {
    _messageDismissTimer?.cancel(); // Cancel any existing timer
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey(); // Force rebuild of message bar
    });
    // Set a timer to dismiss the message after 3 seconds, consistent with Jodi
    _messageDismissTimer = Timer(const Duration(seconds: 3), _clearMessage);
  }

  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
    _messageDismissTimer
        ?.cancel(); // Ensure timer is cancelled when message is cleared manually
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

    // Calculate total points with the new bid to check against wallet balance
    int currentTotalPoints = _getTotalPoints();
    int pointsForThisBid = parsedAmount;

    // If the digit already exists, we'll replace its old points with new ones.
    // So, subtract the old points for this digit if it exists before adding new ones.
    if (bidAmounts.containsKey(number)) {
      currentTotalPoints -= (int.tryParse(bidAmounts[number]!) ?? 0);
    }

    int totalPointsWithNewBid = currentTotalPoints + pointsForThisBid;

    if (totalPointsWithNewBid > _walletBalance) {
      _showMessage(
        'Insufficient wallet balance to place these bids.',
        isError: true,
      );
      return;
    }

    // Check if bid for this digit already exists to update or add
    if (bidAmounts.containsKey(number)) {
      setState(() {
        bidAmounts[number] = amount; // Update existing bid
      });
      _showMessage(
        'Bid for Digit $number updated to $amount points.',
        isError: false,
      );
    } else {
      setState(() {
        bidAmounts[number] = amount; // Add new bid
      });
      _showMessage('Added bid for Digit: $number, Amount: $amount');
    }

    // DO NOT CLEAR pointsController here.
    // This allows the user to apply the same points to multiple digits.
    // pointsController.clear(); // This line is intentionally commented/removed
  }

  int _getTotalPoints() {
    return bidAmounts.values
        .map((e) => int.tryParse(e) ?? 0)
        .fold(0, (a, b) => a + b);
  }

  // --- Confirmation Dialog and Final Bid Submission (Modified) ---
  void _showConfirmationDialog() {
    _clearMessage();
    if (bidAmounts.isEmpty) {
      _showMessage(
        'Please add at least one bid before submitting.',
        isError: true,
      );
      return;
    }

    final int totalPoints = _getTotalPoints();
    final int currentWalletBalance =
        _walletBalance; // _walletBalance is already int

    if (currentWalletBalance < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place these bids.',
        isError: true,
      );
      return;
    }

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    // --- IMPORTANT: Transform bidAmounts Map into a List of Maps for the dialog ---
    List<Map<String, String>> bidsForDialog = bidAmounts.entries.map((entry) {
      return {
        "digit": entry.key,
        "points": entry.value,
        "type": selectedGameType, // Use the dynamically selected game type
        "pana": "", // pana should be empty for single digits
      };
    }).toList();
    // --- End Transformation ---

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: "${widget.gameName} - ${widget.gameType}",
          gameDate: formattedDate,
          bids: bidsForDialog, // Pass the transformed list
          totalBids: bidAmounts.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: currentWalletBalance,
          walletBalanceAfterDeduction: (currentWalletBalance - totalPoints)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () {
            // Dismiss the confirmation dialog before showing success/failure
            _placeFinalBids(); // Call the bid placement method
            // Navigator.pop(dialogContext);
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    setState(() {
      _isApiCalling = true; // Set loading state to true
    });

    // --- IMPORTANT: Transform bidAmounts Map into a List of Maps for the BidService ---
    List<Map<String, String>> formattedBidsForService = bidAmounts.entries.map((
      entry,
    ) {
      return {
        "digit": entry.key,
        "points": entry.value,
        "type": selectedGameType, // Use the dynamically selected game type
        "pana": "", // For single digits, pana should be empty
      };
    }).toList();
    // --- End Transformation ---
    final result = await _bidService.placeFinalBids(
      gameName: widget.gameName,
      accessToken: _accessToken,
      registerId: _registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: _accountStatus,
      bidAmounts: bidAmounts, // CORRECTED: Pass the correctly formatted list
      selectedGameType:
          selectedGameType, // Use the dynamically selected game type
      gameId: widget.gameId,
      gameType: widget.gameType,
      totalBidAmount: _getTotalPoints(),
    );

    if (!mounted) {
      // If the widget is disposed before the async operation completes,
      // ensure _isApiCalling is reset to prevent UI issues if the screen
      // is re-entered later.
      _isApiCalling = false;
      return false;
    }

    setState(() {
      _isApiCalling = false; // Set loading state to false after API call
    });

    // Ensure context is still valid before showing final dialog
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => result['status']
            ? const BidSuccessDialog()
            : BidFailureDialog(errorMessage: result['msg']),
      );

      if (result['status'] && context.mounted) {
        final int newBalance = _walletBalance - _getTotalPoints();
        setState(() {
          _walletBalance = newBalance;
          bidAmounts.clear(); // Clear bids on successful submission
          pointsController.clear(); // Clear points text field
        });
        await _bidService.updateWalletBalance(newBalance);
        _showMessage('Bids submitted successfully!'); // Show success message
      }
    });

    return result['status'] == true;
  }

  Widget _buildDropdown(bool selectionStatus) {
    final List<String> gameTypesOptions = ['OPEN', 'CLOSE'];

    final List<String> filteredOptions = selectionStatus
        ? gameTypesOptions
        : gameTypesOptions
              .where((opt) => opt.toLowerCase() == 'close')
              .toList();

    if (!filteredOptions.contains(selectedGameType.toUpperCase())) {
      selectedGameType = filteredOptions.first;
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
            value: selectedGameType.toUpperCase(),
            icon: const Icon(Icons.keyboard_arrow_down),
            onChanged:
                _isApiCalling // Disable dropdown when API is calling
                ? null
                : (String? newValue) {
                    setState(() {
                      selectedGameType = newValue!;
                      _clearMessage();
                    });
                  },
            items: filteredOptions.map((String value) {
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
                _inputRow(
                  "Select Game Type:",
                  _buildDropdown(widget.selectionStatus),
                ),
                _inputRow("Enter Points:", _buildTextField()),
                const SizedBox(height: 30),
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
          // Bottom total bar (always visible, disabled when no bids)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
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
                    onPressed: (_isApiCalling || bidAmounts.isEmpty)
                        ? null // Disable button while API is calling OR if no bids
                        : _showConfirmationDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_isApiCalling || bidAmounts.isEmpty)
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
