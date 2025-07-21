import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
import 'package:marquee/marquee.dart'; // For Marquee widget

class ChoiceSpDpTpBoardScreen extends StatefulWidget {
  final String screenTitle;

  const ChoiceSpDpTpBoardScreen({
    Key? key,
    required this.screenTitle,
    required int gameId,
    required String gameType,
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

  // Defaulting to 'OPEN' as per typical use-case, adjust if 'MORNING OPEN' is strictly needed from start
  // The Dropdown will populate based on widget.screenTitle anyway.
  String? _selectedGameTypeOption;

  List<Map<String, String>> _bids = []; // List to store the added bids

  @override
  void initState() {
    super.initState();
    // Initialize _selectedGameTypeOption based on the first part of screenTitle
    // Assuming screenTitle is like "MARKET NAME - XXX"
    // And you want dropdown items like "MARKET NAME OPEN" and "MARKET NAME CLOSE"
    // The initial value for the dropdown should be one of these.
    // Let's default to "OPEN" for the value, the display text will be formatted in the DropdownMenuItem
    _selectedGameTypeOption = 'OPEN';
  }

  @override
  void dispose() {
    _leftDigitController.dispose();
    _middleDigitController.dispose();
    _rightDigitController.dispose();
    _pointsController.dispose();
    super.dispose();
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
    // Check if there are exactly two unique digits and one of them appears twice.
    return freq.length == 2 && freq.values.any((count) => count == 2);
  }

  bool _isValidTpPanna(String panna) {
    if (panna.length != 3) return false;
    return panna[0] == panna[1] && panna[1] == panna[2];
  }

  void _addBid() {
    print("ADD button pressed - entering _addBid"); // Debug print
    final leftDigit = _leftDigitController.text.trim();
    final middleDigit = _middleDigitController.text.trim();
    final rightDigit = _rightDigitController.text.trim();
    final points = _pointsController.text.trim();

    // 1. Validate individual digits
    if (leftDigit.isEmpty || middleDigit.isEmpty || rightDigit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all three digits.')),
      );
      return;
    }
    if (leftDigit.length != 1 ||
        middleDigit.length != 1 ||
        rightDigit.length != 1 ||
        int.tryParse(leftDigit) == null ||
        int.tryParse(middleDigit) == null ||
        int.tryParse(rightDigit) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter single digits for Left, Middle, and Right.',
          ),
        ),
      );
      return;
    }

    final pannaInput = '$leftDigit$middleDigit$rightDigit';

    // 2. Validate points range (10 to 10000)
    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Points must be between 10 and 10000.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select SP, DP, or TP.')),
      );
      return;
    }
    if (selectedCount > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select only one of SP, DP, or TP.'),
        ),
      );
      return;
    }

    // 4. Validate panna input based on selected game category
    bool isValidPanna = false;
    if (gameCategory == 'SP') {
      isValidPanna = _isValidSpPanna(pannaInput);
      if (!isValidPanna) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SP Panna must have 3 unique digits.')),
        );
        return;
      }
    } else if (gameCategory == 'DP') {
      isValidPanna = _isValidDpPanna(pannaInput);
      if (!isValidPanna) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'DP Panna must have two same digits and one different.',
            ),
          ),
        );
        return;
      }
    } else if (gameCategory == 'TP') {
      isValidPanna = _isValidTpPanna(pannaInput);
      if (!isValidPanna) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TP Panna must have 3 identical digits.'),
          ),
        );
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
          print(
            // Debug print
            "Adding single bid: Digit-$pannaInput, Points-$points, Type-$_selectedGameTypeOption, GameType-$gameCategory",
          );
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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Panna $pannaInput already added for $gameCategory ($_selectedGameTypeOption).',
              ),
            ),
          );
        }
      });
    }
  }

  void _removeBid(int index) {
    setState(() {
      _bids.removeAt(index);
    });
  }

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
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
            // Ensure the '5' is vertically centered
            child: Text(
              '5', // This should likely be dynamic (e.g., user's balance)
              style: GoogleFonts.poppins(
                // Using GoogleFonts for consistency
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
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
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedGameTypeOption = newValue;
                              });
                            },
                            items: <String>['OPEN', 'CLOSE']
                                .map<DropdownMenuItem<String>>((String value) {
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
                                        showFadingOnlyWhenScrolling: true,
                                        fadingEdgeStartFraction: 0.1,
                                        fadingEdgeEndFraction: 0.1,
                                        startPadding: 10.0,
                                        accelerationDuration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        accelerationCurve: Curves.linear,
                                        decelerationDuration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        decelerationCurve: Curves.easeOut,
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _isSPSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                _isSPSelected = value ?? false;
                                if (_isSPSelected) {
                                  _isDPSelected = false;
                                  _isTPSelected = false;
                                }
                              });
                            },
                            activeColor: Colors.amber,
                            checkColor: Colors.white,
                          ),
                          Text('SP', style: GoogleFonts.poppins(fontSize: 16)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _isDPSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                _isDPSelected = value ?? false;
                                if (_isDPSelected) {
                                  _isSPSelected = false;
                                  _isTPSelected = false;
                                }
                              });
                            },
                            activeColor: Colors.amber,
                            checkColor: Colors.white,
                          ),
                          Text('DP', style: GoogleFonts.poppins(fontSize: 16)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _isTPSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                _isTPSelected = value ?? false;
                                if (_isTPSelected) {
                                  _isSPSelected = false;
                                  _isDPSelected = false;
                                }
                              });
                            },
                            activeColor: Colors.amber,
                            checkColor: Colors.white,
                          ),
                          Text('TP', style: GoogleFonts.poppins(fontSize: 16)),
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
                          // Apply consistent styling
                          hintText: 'Amount', // Simpler hint
                          hintStyle: GoogleFonts.poppins(fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ), // Adjust padding
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
                const SizedBox(height: 20), // Increased spacing
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 150,
                    height: 45,
                    child: ElevatedButton(
                      onPressed:
                          _addBid, // Correctly calls the single bid function
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            8,
                          ), // Slightly rounded corners
                        ),
                        elevation: 2,
                      ),
                      child: Text(
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
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2, // Amount
                    child: Text(
                      'Amount',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 3, // Game Type (SP/DP/TP) + (OPEN/CLOSE)
                    child: Text(
                      'Type',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
                                  color:
                                      Colors.blueGrey[700], // More subtle color
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
                              padding: EdgeInsets.zero, // Remove extra padding
                              constraints:
                                  const BoxConstraints(), // Remove extra constraints
                              onPressed: () => _removeBid(index),
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
            onPressed: () {
              if (_bids.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please add at least one bid to submit.'),
                  ),
                );
                return;
              }
              // TODO: Implement actual submission logic here
              // For example, sending _bids data to a server
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Submitting ${_bids.length} bids with total $totalPoints points!',
                  ),
                ),
              );
              // Optionally clear bids after submission or navigate away
              // setState(() {
              //   _bids.clear();
              // });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber, // Changed to green for submit
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: Text(
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
