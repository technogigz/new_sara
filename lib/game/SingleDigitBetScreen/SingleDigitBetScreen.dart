import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Import for date formatting

import '../../components/BidConfirmationDialog.dart';

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

  @override
  void initState() {
    super.initState();
    // Initial read for GetStorage values
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = storage.read('accountStatus') ?? false;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    // Safely parse walletBalance to int
    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is int) {
      walletBalance = storedWalletBalance;
    } else if (storedWalletBalance is String) {
      walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else {
      walletBalance = 0; // Default to 0 if it's not an int or a valid string
    }

    // --- FIX APPLIED HERE ---
    // Initialize selectedGameBetType to a valid option from gameTypesOptions.
    // This resolves the DropdownButton assertion error.
    selectedGameBetType = gameTypesOptions[0]; // Set default to "Open"

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

    // Also listen for wallet balance changes
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

  void _addEntry() {
    final digit = digitController.text.trim();
    final points = pointsController.text.trim();

    if (digit.isNotEmpty && points.isNotEmpty) {
      if (digit.length == 1 && int.tryParse(digit) != null) {
        setState(() {
          addedEntries.add({
            "digit": digit,
            "points": points,
            "type":
                selectedGameBetType, // Use the state's selected game type (Open/Close)
          });
          digitController.clear();
          pointsController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a single digit for Bid Digits.'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both Digit and Amount.')),
      );
    }
  }

  void _removeEntry(int index) {
    setState(() {
      addedEntries.removeAt(index);
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
    final int totalPoints = _getTotalPoints();

    // Check if wallet balance is sufficient
    if (walletBalance < totalPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient wallet balance to place this bid.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BidConfirmationDialog(
          gameTitle: widget.gameName,
          gameDate: formattedDate, // Use a formatted current date
          bids: addedEntries,
          totalBids: addedEntries.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId
              .toString(), // Convert to String if gameId is int
          gameType: widget
              .gameCategoryType, // Pass the general game type (e.g., "singleDigits")
        );
      },
    );
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Digit",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "Amount",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "Game Type",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
                              icon: const Icon(Icons.delete, color: Colors.red),
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
            value:
                selectedGameBetType, // Use the state variable for the dropdown's value
            icon: const Icon(Icons.keyboard_arrow_down),
            onChanged: (String? newValue) {
              setState(() {
                selectedGameBetType = newValue!;
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
