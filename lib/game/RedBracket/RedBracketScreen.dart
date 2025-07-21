import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get_storage/get_storage.dart'; // Import GetStorage
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
import 'package:intl/intl.dart'; // Import for date formatting

import '../../components/BidConfirmationDialog.dart'; // Import the BidConfirmationDialog

class RedBracketBoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId; // Add gameId to the constructor
  final String gameType; // Add gameType to the constructor

  const RedBracketBoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId, // Make it required
    required this.gameType, // Make it required
  }) : super(key: key);

  @override
  State<RedBracketBoardScreen> createState() => _RedBracketBoardScreenState();
}

class _RedBracketBoardScreenState extends State<RedBracketBoardScreen> {
  final TextEditingController _redBracketController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  List<Map<String, String>> _bids = []; // List to store the added bids

  late GetStorage storage = GetStorage(); // Initialize GetStorage
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance; // This will hold the wallet balance

  // List of all possible 2-digit numbers (00-99) for suggestions
  static final List<String> _allJodis = List.generate(
    100,
    (index) => index.toString().padLeft(2, '0'),
  );

  @override
  void initState() {
    super.initState();
    // Initial read for all storage keys
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = storage.read('accountStatus') ?? false;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    // Directly initialize walletBalance from GetStorage, safely parsing it.
    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is String) {
      walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else if (storedWalletBalance is int) {
      walletBalance = storedWalletBalance;
    } else {
      walletBalance = 0; // Default if null or unexpected type
    }

    // Listen for changes to all relevant storage keys
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

    // Listen specifically for changes to 'walletBalance'
    storage.listenKey('walletBalance', (value) {
      setState(() {
        if (value is String) {
          walletBalance = int.tryParse(value) ?? 0;
        } else if (value is int) {
          walletBalance = value;
        } else {
          walletBalance = 0; // Default if null or unexpected type
        }
      });
    });
  }

  @override
  void dispose() {
    _redBracketController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  void _addBid() {
    final redBracket = _redBracketController.text.trim();
    final points = _pointsController.text.trim();

    // 1. Validate Red Bracket (2 digits, 00-99)
    if (redBracket.isEmpty ||
        redBracket.length != 2 ||
        int.tryParse(redBracket) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a 2-digit number for Red Bracket (00-99).',
          ),
        ),
      );
      return;
    }
    int? parsedRedBracket = int.tryParse(redBracket);
    if (parsedRedBracket == null ||
        parsedRedBracket < 0 ||
        parsedRedBracket > 99) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Red Bracket must be between 00 and 99.')),
      );
      return;
    }

    // 2. Validate Points (10 to 1000)
    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Points must be between 10 and 1000.')),
      );
      return;
    }

    setState(() {
      // Check if an existing bid with the same Red Bracket already exists
      int existingIndex = _bids.indexWhere((bid) => bid['jodi'] == redBracket);

      if (existingIndex != -1) {
        // If it exists, update the points of the existing bid
        _bids[existingIndex]['points'] =
            (int.parse(_bids[existingIndex]['points']!) + parsedPoints)
                .toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated points for Jodi $redBracket.')),
        );
      } else {
        // Otherwise, add a new bid
        _bids.add({
          "jodi": redBracket,
          "points": points,
          "type":
              "Jodi", // Indicate game type for API, assuming "Jodi" for Red Bracket
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added bid: Jodi $redBracket with $points points.'),
          ),
        );
      }

      // Clear controllers after adding/updating
      _redBracketController.clear();
      _pointsController.clear();
    });
  }

  void _removeBid(int index) {
    setState(() {
      _bids.removeAt(index);
    });
  }

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + int.tryParse(item['points'] ?? '0')!,
    );
  }

  // --- Start of _showConfirmationDialog method ---
  void _showConfirmationDialog() {
    if (_bids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one bid.')),
      );
      return;
    }

    final int totalPoints = _getTotalPoints();

    if (walletBalance < totalPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient wallet balance to place this bid.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prepare bids list for the dialog
    List<Map<String, String>> bidsForDialog = _bids.map((bid) {
      // For Red Bracket/Jodi, 'digit' might be the jodi itself, or split into two digits if API requires.
      // Assuming 'digit' for the whole jodi for simplicity in dialog,
      // but ensure your API can handle it correctly.
      return {
        "digit": bid['jodi']!, // For Red Bracket/Jodi, use 'jodi' as 'digit'
        "pana": "", // Not applicable for Jodi, keep empty
        "points": bid['points']!,
        "type": bid['type']!, // This will be "Jodi"
        "jodi": bid['jodi']!, // Keep jodi for display purposes in dialog
      };
    }).toList();

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BidConfirmationDialog(
          gameTitle: widget.screenTitle, // Use screenTitle for gameTitle
          gameDate: formattedDate,
          bids: bidsForDialog,
          totalBids: bidsForDialog.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(), // Ensure gameId is String
          gameType: widget.gameType, // Pass the correct gameType (e.g., "Jodi")
        );
      },
    );
  }
  // --- End of _showConfirmationDialog method ---

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
              walletBalance.toString(), // Display actual wallet balance
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
                _buildJodiInputRow(
                  // First input is now Red Bracket with Autocomplete
                  'Enter Red Bracket',
                  _redBracketController,
                  hintText: 'e.g., 25', // Added hint text
                  maxLength: 2,
                ),
                const SizedBox(height: 16),
                _buildInputRow(
                  // This is for points
                  'Enter Points :',
                  _pointsController,
                  hintText: 'e.g., 100', // Added hint text
                  maxLength: 4,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: _addBid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      "ADD",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(thickness: 1),

          // Table Headers
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
                      'Jodi',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Points',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
                                  bid['jodi']!,
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  bid['points']!,
                                  style: GoogleFonts.poppins(),
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
    );
  }

  // Helper widget for input rows (standard TextField)
  Widget _buildInputRow(
    String label,
    TextEditingController controller, {
    String hintText = '',
    int? maxLength,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 16)),
        SizedBox(
          width: 150,
          height: 40,
          child: TextField(
            cursorColor: Colors.amber,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              if (maxLength != null)
                LengthLimitingTextInputFormatter(maxLength),
            ],
            decoration: InputDecoration(
              hintText: hintText,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(color: Colors.black),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(color: Colors.black),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(color: Colors.amber, width: 2),
              ),
              suffixIcon: const Icon(
                Icons.arrow_forward,
                color: Colors.amber,
                size: 20,
              ), // Arrow icon
            ),
          ),
        ),
      ],
    );
  }

  // Helper widget for Jodi input with Autocomplete suggestions
  Widget _buildJodiInputRow(
    String label,
    TextEditingController controller, {
    String hintText = '',
    int? maxLength,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 16)),
        SizedBox(
          width: 150,
          height: 40,
          child: Autocomplete<String>(
            fieldViewBuilder:
                (
                  BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  // Keep our controller in sync with Autocomplete's internal controller
                  controller.text = textEditingController.text;
                  controller.selection = textEditingController
                      .selection; // Maintain cursor position

                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      if (maxLength != null)
                        LengthLimitingTextInputFormatter(maxLength),
                    ],
                    decoration: InputDecoration(
                      hintText: hintText,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide(color: Colors.amber, width: 2),
                      ),
                      suffixIcon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.amber,
                        size: 20,
                      ), // Arrow icon
                    ),
                    onSubmitted: (value) => onFieldSubmitted(),
                  );
                },
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              // Filter jodis that start with the entered text
              return _allJodis.where((String option) {
                return option.startsWith(textEditingValue.text);
              });
            },
            onSelected: (String selection) {
              // When a suggestion is selected, update the controller
              controller.text = selection;
            },
            optionsViewBuilder:
                (
                  BuildContext context,
                  AutocompleteOnSelected<String> onSelected,
                  Iterable<String> options,
                ) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: SizedBox(
                        height: options.length > 5
                            ? 200.0
                            : options.length *
                                  48.0, // Dynamic height up to 5 items, then fixed
                        width: 150, // Match the width of the input field
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return GestureDetector(
                              onTap: () {
                                onSelected(option);
                              },
                              child: ListTile(
                                title: Text(
                                  option,
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
          ),
        ),
      ],
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
            onPressed: _showConfirmationDialog, // Call the confirmation dialog
            child: Text(
              'SUBMIT',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
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

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // For TextInputFormatter
// import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
//
// class RedBracketBoardScreen extends StatefulWidget {
//   final String screenTitle;
//
//   const RedBracketBoardScreen({
//     Key? key,
//     required this.screenTitle,
//     required gameId,
//     required gameType,
//   }) : super(key: key);
//
//   @override
//   State<RedBracketBoardScreen> createState() => _RedBracketBoardScreenState();
// }
//
// class _RedBracketBoardScreenState extends State<RedBracketBoardScreen> {
//   final TextEditingController _redBracketController = TextEditingController();
//   final TextEditingController _pointsController = TextEditingController();
//
//   List<Map<String, String>> _bids = []; // List to store the added bids
//
//   // List of all possible 2-digit numbers (00-99) for suggestions
//   static final List<String> _allJodis = List.generate(
//     100,
//     (index) => index.toString().padLeft(2, '0'),
//   );
//
//   @override
//   void dispose() {
//     _redBracketController.dispose();
//     _pointsController.dispose();
//     super.dispose();
//   }
//
//   void _addBid() {
//     final redBracket = _redBracketController.text.trim();
//     final points = _pointsController.text.trim();
//
//     // 1. Validate Red Bracket (2 digits, 00-99)
//     if (redBracket.isEmpty ||
//         redBracket.length != 2 ||
//         int.tryParse(redBracket) == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text(
//             'Please enter a 2-digit number for Red Bracket (00-99).',
//           ),
//         ),
//       );
//       return;
//     }
//     int? parsedRedBracket = int.tryParse(redBracket);
//     if (parsedRedBracket == null ||
//         parsedRedBracket < 0 ||
//         parsedRedBracket > 99) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Red Bracket must be between 00 and 99.')),
//       );
//       return;
//     }
//
//     // 2. Validate Points (10 to 1000)
//     int? parsedPoints = int.tryParse(points);
//     if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Points must be between 10 and 1000.')),
//       );
//       return;
//     }
//
//     setState(() {
//       // Check if an existing bid with the same Red Bracket already exists
//       int existingIndex = _bids.indexWhere((bid) => bid['jodi'] == redBracket);
//
//       if (existingIndex != -1) {
//         // If it exists, update the points of the existing bid
//         _bids[existingIndex]['points'] =
//             (int.parse(_bids[existingIndex]['points']!) + parsedPoints)
//                 .toString();
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Updated points for Jodi $redBracket.')),
//         );
//       } else {
//         // Otherwise, add a new bid
//         _bids.add({"jodi": redBracket, "points": points});
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Added bid: Jodi $redBracket with $points points.'),
//           ),
//         );
//       }
//
//       // Clear controllers after adding/updating
//       _redBracketController.clear();
//       _pointsController.clear();
//     });
//   }
//
//   void _removeBid(int index) {
//     setState(() {
//       _bids.removeAt(index);
//     });
//   }
//
//   int _getTotalPoints() {
//     return _bids.fold(
//       0,
//       (sum, item) => sum + int.tryParse(item['points'] ?? '0')!,
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F5F5), // Light gray background
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
//           const Center(
//             child: Text(
//               '5',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//         ],
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.symmetric(
//               horizontal: 16.0,
//               vertical: 12.0,
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _buildJodiInputRow(
//                   // First input is now Red Bracket with Autocomplete
//                   'Enter Red Bracket',
//                   _redBracketController,
//                   hintText: '', // No hint text in the image
//                   maxLength: 2,
//                 ),
//                 const SizedBox(height: 16),
//                 _buildInputRow(
//                   // This is for points
//                   'Enter Points :',
//                   _pointsController,
//                   hintText: '', // No hint text in the image
//                   maxLength: 4,
//                 ),
//                 const SizedBox(height: 20),
//                 SizedBox(
//                   width: double.infinity,
//                   height: 45,
//                   child: ElevatedButton(
//                     onPressed: _addBid,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.amber,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(6),
//                       ),
//                     ),
//                     child: Text(
//                       "ADD",
//                       style: GoogleFonts.poppins(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w600,
//                         letterSpacing: 0.5,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const Divider(thickness: 1),
//
//           // Table Headers
//           if (_bids.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.symmetric(
//                 horizontal: 16.0,
//                 vertical: 8.0,
//               ),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       'Jodi',
//                       style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                   Expanded(
//                     child: Text(
//                       'Points',
//                       style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                   const SizedBox(width: 48), // Space for delete icon
//                 ],
//               ),
//             ),
//           if (_bids.isNotEmpty) const Divider(thickness: 1),
//
//           // Dynamic List of Bids
//           Expanded(
//             child: _bids.isEmpty
//                 ? Center(
//                     child: Text(
//                       'No Bids Placed',
//                       style: GoogleFonts.poppins(color: Colors.grey),
//                     ),
//                   )
//                 : ListView.builder(
//                     itemCount: _bids.length,
//                     itemBuilder: (context, index) {
//                       final bid = _bids[index];
//                       return Container(
//                         margin: const EdgeInsets.symmetric(
//                           horizontal: 10,
//                           vertical: 4,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(8),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.grey.withOpacity(0.2),
//                               spreadRadius: 1,
//                               blurRadius: 3,
//                               offset: const Offset(0, 1),
//                             ),
//                           ],
//                         ),
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 16.0,
//                             vertical: 8.0,
//                           ),
//                           child: Row(
//                             children: [
//                               Expanded(
//                                 child: Text(
//                                   bid['jodi']!,
//                                   style: GoogleFonts.poppins(),
//                                 ),
//                               ),
//                               Expanded(
//                                 child: Text(
//                                   bid['points']!,
//                                   style: GoogleFonts.poppins(),
//                                 ),
//                               ),
//                               IconButton(
//                                 icon: const Icon(
//                                   Icons.delete,
//                                   color: Colors.red,
//                                 ),
//                                 onPressed: () => _removeBid(index),
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//           ),
//           // Bottom Bar (conditionally rendered)
//           if (_bids.isNotEmpty) _buildBottomBar(),
//         ],
//       ),
//     );
//   }
//
//   // Helper widget for input rows (standard TextField)
//   Widget _buildInputRow(
//     String label,
//     TextEditingController controller, {
//     String hintText = '',
//     int? maxLength,
//   }) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(label, style: GoogleFonts.poppins(fontSize: 16)),
//         SizedBox(
//           width: 150,
//           height: 40,
//           child: TextField(
//             cursorColor: Colors.amber,
//             controller: controller,
//             keyboardType: TextInputType.number,
//             inputFormatters: [
//               FilteringTextInputFormatter.digitsOnly,
//               if (maxLength != null)
//                 LengthLimitingTextInputFormatter(maxLength),
//             ],
//             decoration: InputDecoration(
//               hintText: hintText,
//               contentPadding: const EdgeInsets.symmetric(horizontal: 12),
//               border: const OutlineInputBorder(
//                 borderRadius: BorderRadius.all(Radius.circular(20)),
//                 borderSide: BorderSide(color: Colors.black),
//               ),
//               enabledBorder: const OutlineInputBorder(
//                 borderRadius: BorderRadius.all(Radius.circular(20)),
//                 borderSide: BorderSide(color: Colors.black),
//               ),
//               focusedBorder: const OutlineInputBorder(
//                 borderRadius: BorderRadius.all(Radius.circular(20)),
//                 borderSide: BorderSide(color: Colors.amber, width: 2),
//               ),
//               suffixIcon: const Icon(
//                 Icons.arrow_forward,
//                 color: Colors.amber,
//                 size: 20,
//               ), // Arrow icon
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   // Helper widget for Jodi input with Autocomplete suggestions
//   Widget _buildJodiInputRow(
//     String label,
//     TextEditingController controller, {
//     String hintText = '',
//     int? maxLength,
//   }) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(label, style: GoogleFonts.poppins(fontSize: 16)),
//         SizedBox(
//           width: 150,
//           height: 40,
//           child: Autocomplete<String>(
//             fieldViewBuilder:
//                 (
//                   BuildContext context,
//                   TextEditingController textEditingController,
//                   FocusNode focusNode,
//                   VoidCallback onFieldSubmitted,
//                 ) {
//                   // Keep our controller in sync with Autocomplete's internal controller
//                   controller.text = textEditingController.text;
//                   controller.selection = textEditingController
//                       .selection; // Maintain cursor position
//
//                   return TextField(
//                     controller: textEditingController,
//                     focusNode: focusNode,
//                     keyboardType: TextInputType.number,
//                     inputFormatters: [
//                       FilteringTextInputFormatter.digitsOnly,
//                       if (maxLength != null)
//                         LengthLimitingTextInputFormatter(maxLength),
//                     ],
//                     decoration: InputDecoration(
//                       hintText: hintText,
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                       ),
//                       border: const OutlineInputBorder(
//                         borderRadius: BorderRadius.all(Radius.circular(20)),
//                         borderSide: BorderSide(color: Colors.black),
//                       ),
//                       enabledBorder: const OutlineInputBorder(
//                         borderRadius: BorderRadius.all(Radius.circular(20)),
//                         borderSide: BorderSide(color: Colors.black),
//                       ),
//                       focusedBorder: const OutlineInputBorder(
//                         borderRadius: BorderRadius.all(Radius.circular(20)),
//                         borderSide: BorderSide(color: Colors.amber, width: 2),
//                       ),
//                       suffixIcon: const Icon(
//                         Icons.arrow_forward,
//                         color: Colors.amber,
//                         size: 20,
//                       ), // Arrow icon
//                     ),
//                     onSubmitted: (value) => onFieldSubmitted(),
//                   );
//                 },
//             optionsBuilder: (TextEditingValue textEditingValue) {
//               if (textEditingValue.text.isEmpty) {
//                 return const Iterable<String>.empty();
//               }
//               // Filter jodis that start with the entered text
//               return _allJodis.where((String option) {
//                 return option.startsWith(textEditingValue.text);
//               });
//             },
//             onSelected: (String selection) {
//               // When a suggestion is selected, update the controller
//               controller.text = selection;
//             },
//             optionsViewBuilder:
//                 (
//                   BuildContext context,
//                   AutocompleteOnSelected<String> onSelected,
//                   Iterable<String> options,
//                 ) {
//                   return Align(
//                     alignment: Alignment.topLeft,
//                     child: Material(
//                       elevation: 4.0,
//                       child: SizedBox(
//                         height: options.length > 5
//                             ? 200.0
//                             : options.length *
//                                   48.0, // Dynamic height up to 5 items, then fixed
//                         width: 150, // Match the width of the input field
//                         child: ListView.builder(
//                           padding: EdgeInsets.zero,
//                           itemCount: options.length,
//                           itemBuilder: (BuildContext context, int index) {
//                             final String option = options.elementAt(index);
//                             return GestureDetector(
//                               onTap: () {
//                                 onSelected(option);
//                               },
//                               child: ListTile(
//                                 title: Text(
//                                   option,
//                                   style: GoogleFonts.poppins(fontSize: 14),
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//           ),
//         ),
//       ],
//     );
//   }
//
//   // Helper for bottom bar
//   Widget _buildBottomBar() {
//     int totalBids = _bids.length;
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
//                 style: GoogleFonts.poppins(
//                   fontSize: 14,
//                   color: Colors.grey[700],
//                 ),
//               ),
//               Text(
//                 '$totalBids',
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
//                 'Points',
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
//             onPressed: () {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Submit button pressed!')),
//               );
//             },
//             child: Text(
//               'SUBMIT',
//               style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
//             ),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.orange[700],
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
