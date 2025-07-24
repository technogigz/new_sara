import 'dart:async'; // For Timer
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
import 'package:intl/intl.dart';

import '../../components/BidConfirmationDialog.dart'; // For BidConfirmationDialog

// AnimatedMessageBar component
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
  final String gameType;

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
  String selectedGameType = 'Open';
  final List<String> gameTypes = ['Open', 'Close'];

  final TextEditingController pointsController = TextEditingController();

  Color dropdownBorderColor = Colors.black;
  Color textFieldBorderColor = Colors.black;

  Map<String, String> bidAmounts = {};
  late GetStorage storage = GetStorage();

  late String mobile = '';
  late String name = '';
  late bool accountActiveStatus;
  late String walletBallenceString;
  late int walletBalanceInt = 0;

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupStorageListeners();
  }

  void _loadInitialData() {
    mobile = storage.read('mobileNoEnc') ?? '';
    name = storage.read('fullName') ?? '';
    accountActiveStatus = storage.read('accountStatus') ?? false;
    walletBallenceString = storage.read('walletBalance') ?? '0';
    walletBalanceInt = int.tryParse(walletBallenceString) ?? 0;
  }

  void _setupStorageListeners() {
    storage.listenKey('mobileNoEnc', (value) {
      setState(() {
        mobile = value ?? '';
      });
    });

    storage.listenKey('fullName', (value) {
      setState(() {
        name = value ?? '';
      });
    });

    storage.listenKey('accountStatus', (value) {
      setState(() {
        accountActiveStatus = value ?? false;
      });
    });

    storage.listenKey('walletBalance', (value) {
      setState(() {
        walletBallenceString = value ?? '0';
        walletBalanceInt = int.tryParse(walletBallenceString) ?? 0;
      });
    });
  }

  @override
  void dispose() {
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

  void onNumberPressed(String number) {
    _clearMessage();
    final amount = pointsController.text.trim();
    if (amount.isNotEmpty) {
      if (int.tryParse(amount) != null && int.parse(amount) > 0) {
        setState(() {
          bidAmounts[number] = amount;
          _showMessage('Added bid for Digit: $number, Amount: $amount');
        });
      } else {
        _showMessage('Please enter a valid positive amount.', isError: true);
      }
    } else {
      _showMessage('Please enter an amount first.', isError: true);
    }
  }

  int _getTotalPoints() {
    return bidAmounts.values
        .map((e) => int.tryParse(e) ?? 0)
        .fold(0, (a, b) => a + b);
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (bidAmounts.isEmpty) {
      _showMessage('Please add at least one bid.', isError: true);
      return;
    }

    final int totalPoints = _getTotalPoints();

    if (walletBalanceInt < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
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
        "pana": digit,
      });
    });

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BidConfirmationDialog(
          gameTitle: widget.gameName,
          gameDate: formattedDate,
          bids: bidsForDialog,
          totalBids: bidsForDialog.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalanceInt,
          walletBalanceAfterDeduction: (walletBalanceInt - totalPoints)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () {
            log('Bids Confirmed for API submission: $bidsForDialog');
            _showMessage('Bids submitted successfully!');
            Navigator.pop(context);
            setState(() {
              bidAmounts.clear();
            });
          },
        );
      },
    );
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
              onChanged: (String? newValue) {
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
          onTap: () => onNumberPressed(number),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(8),
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
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bidAmounts[number]!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white,
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
      backgroundColor: Colors.grey.shade200, // Changed to shade200
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
                if (accountActiveStatus)
                  GestureDetector(
                    onTap: () {},
                    child: SizedBox(
                      height: 42,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Image.asset(
                            'assets/images/wallet_icon.png',
                            width: 24,
                            height: 24,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "₹${walletBallenceString}",
                            style: const TextStyle(
                              // Removed GoogleFonts for consistency with previous use
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w200,
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
            // Added Padding to the main body content
            padding: const EdgeInsets.all(16.0), // Adjust padding as needed
            child: Column(
              children: [
                _inputRow("Select Game Type:", _buildDropdown()),
                _inputRow("Enter Points:", _buildTextField()),
                const SizedBox(height: 30),
                _buildNumberPad(),
                const SizedBox(height: 20),
                if (bidAmounts.isNotEmpty) // Only show headers if bids exist
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0.0,
                    ), // No horizontal padding here, handled by Card's margin
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
                // The bottom bar is positioned, so no need for SizedBox here
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
          if (bidAmounts.isNotEmpty) // Condition moved here
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Text(
                          "Bid",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${bidAmounts.length}",
                          style: GoogleFonts.poppins(),
                        ),
                      ],
                    ),
                    const SizedBox(width: 30),
                    Column(
                      children: [
                        Text(
                          "Total",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text("$totalAmount", style: GoogleFonts.poppins()),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _showConfirmationDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        "Submit",
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
      margin: const EdgeInsets.symmetric(
        horizontal: 0,
        vertical: 4,
      ), // Changed horizontal to 0
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
                type,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
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
