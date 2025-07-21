import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart'; // Import GetStorage
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:marquee/marquee.dart';

import '../../components/BidConfirmationDialog.dart'; // Import the BidConfirmationDialog

enum GameType { odd, even }

enum LataDayType { open, close }

class OddEvenBoardScreen extends StatefulWidget {
  final String title;
  final int gameId; // Add gameId to the constructor
  final String gameType; // Add gameType to the constructor

  const OddEvenBoardScreen({
    Key? key,
    required this.title,
    required this.gameId, // Make it required
    required this.gameType, // Make it required
  }) : super(key: key);

  @override
  _OddEvenBoardScreenState createState() => _OddEvenBoardScreenState();
}

class _OddEvenBoardScreenState extends State<OddEvenBoardScreen> {
  GameType? _selectedGameType = GameType.odd; // Default to Odd
  LataDayType? _selectedLataDayType = LataDayType.close; // Default to Close

  final TextEditingController _pointsController = TextEditingController();

  List<Map<String, String>> _entries =
      []; // This list is used for the display logic

  late GetStorage storage = GetStorage(); // Initialize GetStorage
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance; // This will hold the wallet balance

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
    _pointsController.dispose();
    super.dispose();
  }

  // Function to add a new entry to the list
  void _addEntry() {
    setState(() {
      String points = _pointsController.text.trim();
      String type = _selectedLataDayType == LataDayType.close
          ? 'CLOSE'
          : 'OPEN';

      if (points.isEmpty ||
          int.tryParse(points) == null ||
          int.parse(points) < 10 ||
          int.parse(points) > 1000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Points must be between 10 and 1000.')),
        );
        return;
      }

      if (_selectedGameType != null) {
        List<String> digitsToAdd;
        String bidType;
        if (_selectedGameType == GameType.odd) {
          digitsToAdd = ['1', '3', '5', '7', '9'];
          bidType = "Odd"; // Corresponding bid type for API
        } else {
          digitsToAdd = ['0', '2', '4', '6', '8'];
          bidType = "Even"; // Corresponding bid type for API
        }

        // Clear existing entries of the same type (OPEN/CLOSE and ODD/EVEN)
        _entries.removeWhere(
          (entry) =>
              entry['type'] == type &&
              (entry['bidType'] == "Odd" || entry['bidType'] == "Even"),
        );

        for (String digit in digitsToAdd) {
          _entries.add({
            'digit': digit,
            'points': points,
            'type': type, // "OPEN" or "CLOSE"
            'bidType': bidType, // "Odd" or "Even"
          });
        }
        _pointsController.clear(); // Clear points after adding
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select game type and enter points.'),
          ),
        );
      }
    });
  }

  // Function to delete an entry from the list
  void _deleteEntry(int index) {
    setState(() {
      _entries.removeAt(index);
    });
  }

  // Function to get total points (adapted for _entries list)
  int getTotalPoints() {
    return _entries.fold(
      0,
      (sum, item) => sum + int.tryParse(item['points'] ?? '0')!,
    );
  }

  // --- Start of _showConfirmationDialog method ---
  void _showConfirmationDialog() {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one entry.')),
      );
      return;
    }

    final int totalPoints = getTotalPoints();

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
    // For Odd/Even, 'digit' is the selected digits (0,2,4,6,8 or 1,3,5,7,9)
    // 'type' is "OPEN" or "CLOSE"
    // 'bidType' will be "Odd" or "Even"
    List<Map<String, String>> bidsForDialog = _entries.map((entry) {
      return {
        "digit": entry['digit']!,
        "pana": "", // Not applicable for Odd/Even, keep empty
        "points": entry['points']!,
        "type": entry['type']!, // "OPEN" or "CLOSE"
        "bidType": entry['bidType']!, // "Odd" or "Even" for display/API
      };
    }).toList();

    // The current date and time
    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BidConfirmationDialog(
          gameTitle: widget.title, // Use screenTitle for gameTitle
          gameDate: formattedDate,
          bids: bidsForDialog,
          totalBids: bidsForDialog.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(), // Ensure gameId is String
          gameType:
              widget.gameType, // Pass the correct gameType (e.g., "OddEven")
        );
      },
    );
  }
  // --- End of _showConfirmationDialog method ---

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
          style: const TextStyle(
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
                const Icon(Icons.account_balance_wallet, color: Colors.black),
                const SizedBox(width: 4),
                Text(
                  walletBalance.toString(), // Display actual wallet balance
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Game Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Dropdown for LATA DAY CLOSE/OPEN
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<LataDayType>(
                          value: _selectedLataDayType,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.amber,
                          ),
                          onChanged: (LataDayType? newValue) {
                            setState(() {
                              _selectedLataDayType = newValue;
                            });
                          },
                          items:
                              <LataDayType>[
                                LataDayType.close,
                                LataDayType.open,
                              ].map<DropdownMenuItem<LataDayType>>((
                                LataDayType value,
                              ) {
                                return DropdownMenuItem<LataDayType>(
                                  value: value,
                                  child: SizedBox(
                                    width: 150, // constrain width
                                    height: 20,
                                    child: Marquee(
                                      text: value == LataDayType.close
                                          ? '${widget.title} CLOSE'
                                          : '${widget.title} OPEN',
                                      style: const TextStyle(fontSize: 16),
                                      scrollAxis: Axis.horizontal,
                                      blankSpace: 40.0,
                                      velocity: 30.0,
                                      pauseAfterRound: const Duration(
                                        seconds: 1,
                                      ),
                                      startPadding: 10.0,
                                      accelerationDuration: const Duration(
                                        seconds: 1,
                                      ),
                                      accelerationCurve: Curves.linear,
                                      decelerationDuration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      decelerationCurve: Curves.easeOut,
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<GameType>(
                        title: const Text('Odd'),
                        value: GameType.odd,
                        groupValue: _selectedGameType,
                        onChanged: (GameType? value) {
                          setState(() {
                            _selectedGameType = value;
                          });
                        },
                        activeColor:
                            Colors.amber, // Color of the selected radio button
                        contentPadding:
                            EdgeInsets.zero, // Remove default padding
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<GameType>(
                        title: const Text('Even'),
                        value: GameType.even,
                        groupValue: _selectedGameType,
                        onChanged: (GameType? value) {
                          setState(() {
                            _selectedGameType = value;
                          });
                        },
                        activeColor:
                            Colors.amber, // Color of the selected radio button
                        contentPadding:
                            EdgeInsets.zero, // Remove default padding
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Enter Points :',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _buildPointsInputField(_pointsController)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: _addEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          'ADD',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[400]),
          if (_entries.isNotEmpty) // Use _entries for conditional rendering
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Digit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Points',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Type',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Space for the delete icon
                ],
              ),
            ),
          if (_entries.isNotEmpty) // Use _entries for conditional rendering
            Divider(height: 1, color: Colors.grey[400]),
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Text(
                      'No entries yet. Add some data!',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return _buildEntryItem(
                        entry['digit']!,
                        entry['points']!,
                        entry['type']!,
                        index,
                      );
                    },
                  ),
          ),
          if (_entries.isNotEmpty)
            _buildBottomBar(), // Use _entries for conditional rendering
        ],
      ),
    );
  }

  // Helper widget for Enter Points input field (reused from previous)
  Widget _buildPointsInputField(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        cursorColor: Colors.amber,
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          hintText: 'Enter Points',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.amber,
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

  // Helper widget to build each entry item in the list
  Widget _buildEntryItem(String digit, String points, String type, int index) {
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
                digit,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                points,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                type,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ), // Green for 'CLOSE'
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteEntry(index),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for the bottom bar (reused from previous DigitBasedBoardScreen)
  Widget _buildBottomBar() {
    // Calculate total bids and points dynamically from the _entries list
    int totalBids = _entries.length; // Use _entries here
    int totalPoints = getTotalPoints(); // Use getTotalPoints() here

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, // White background for bottom bar
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, -3), // Shadow at the top of the bar
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out elements
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bids',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              Text(
                '$totalBids',
                style: const TextStyle(
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
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              Text(
                '$totalPoints',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _showConfirmationDialog, // Call the confirmation dialog
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber, // Use Colors.amber for consistency
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: const Text(
              'SUBMIT',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:marquee/marquee.dart';
//
// enum GameType { odd, even }
//
// enum LataDayType { open, close } // Assuming two types based on image
//
// class OddEvenBoardScreen extends StatefulWidget {
//   final String title;
//
//   const OddEvenBoardScreen({
//     Key? key,
//     required this.title,
//     required gameId,
//     required gameType,
//   }) : super(key: key);
//
//   @override
//   _OddEvenBoardScreenState createState() => _OddEvenBoardScreenState();
// }
//
// class _OddEvenBoardScreenState extends State<OddEvenBoardScreen> {
//   GameType? _selectedGameType = GameType.odd; // Default to Odd
//   LataDayType? _selectedLataDayType = LataDayType.close; // Default to Close
//
//   final TextEditingController _pointsController = TextEditingController();
//
//   List<Map<String, String>> _entries =
//       []; // This list is used for the display logic
//
//   @override
//   void dispose() {
//     _pointsController.dispose();
//     super.dispose();
//   }
//
//   // Function to add a new entry to the list
//   void _addEntry() {
//     setState(() {
//       String points = _pointsController.text.trim();
//       String type = _selectedLataDayType == LataDayType.close
//           ? 'CLOSE'
//           : 'OPEN';
//
//       if (points.isNotEmpty && _selectedGameType != null) {
//         List<String> digitsToAdd;
//         if (_selectedGameType == GameType.odd) {
//           digitsToAdd = ['1', '3', '5', '7', '9'];
//         } else {
//           digitsToAdd = ['0', '2', '4', '6', '8'];
//         }
//
//         for (String digit in digitsToAdd) {
//           _entries.add({'digit': digit, 'points': points, 'type': type});
//         }
//         _pointsController.clear(); // Clear points after adding
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Please select game type and enter points.')),
//         );
//       }
//     });
//   }
//
//   // Function to delete an entry from the list
//   void _deleteEntry(int index) {
//     setState(() {
//       _entries.removeAt(index);
//     });
//   }
//
//   // Function to get total points (adapted for _entries list)
//   int getTotalPoints() {
//     return _entries.fold(
//       0,
//       (sum, item) => sum + int.tryParse(item['points'] ?? '0')!,
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
//           icon: Icon(Icons.arrow_back_ios, color: Colors.black),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//         title: Text(
//           widget.title,
//           style: TextStyle(
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
//                 Icon(Icons.account_balance_wallet, color: Colors.black),
//                 SizedBox(width: 4),
//                 Text('5', style: TextStyle(color: Colors.black, fontSize: 16)),
//               ],
//             ),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Select Game Type',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     // Dropdown for LATA DAY CLOSE/OPEN
//                     Container(
//                       padding: EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 4,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(color: Colors.grey[300]!),
//                       ),
//                       child: DropdownButtonHideUnderline(
//                         child: DropdownButton<LataDayType>(
//                           value: _selectedLataDayType,
//                           icon: Icon(
//                             Icons.keyboard_arrow_down,
//                             color: Colors.amber,
//                           ),
//                           onChanged: (LataDayType? newValue) {
//                             setState(() {
//                               _selectedLataDayType = newValue;
//                             });
//                           },
//                           items:
//                               <LataDayType>[
//                                 LataDayType.close,
//                                 LataDayType.open,
//                               ].map<DropdownMenuItem<LataDayType>>((
//                                 LataDayType value,
//                               ) {
//                                 return DropdownMenuItem<LataDayType>(
//                                   value: value,
//                                   child: SizedBox(
//                                     width: 150, // constrain width
//                                     height: 20,
//                                     child: Marquee(
//                                       text: value == LataDayType.close
//                                           ? '${widget.title} CLOSE'
//                                           : '${widget.title} OPEN',
//                                       style: const TextStyle(fontSize: 16),
//                                       scrollAxis: Axis.horizontal,
//                                       blankSpace: 40.0,
//                                       velocity: 30.0,
//                                       pauseAfterRound: Duration(seconds: 1),
//                                       startPadding: 10.0,
//                                       accelerationDuration: Duration(
//                                         seconds: 1,
//                                       ),
//                                       accelerationCurve: Curves.linear,
//                                       decelerationDuration: Duration(
//                                         milliseconds: 500,
//                                       ),
//                                       decelerationCurve: Curves.easeOut,
//                                     ),
//                                   ),
//                                 );
//                               }).toList(),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: RadioListTile<GameType>(
//                         title: const Text('Odd'),
//                         value: GameType.odd,
//                         groupValue: _selectedGameType,
//                         onChanged: (GameType? value) {
//                           setState(() {
//                             _selectedGameType = value;
//                           });
//                         },
//                         activeColor:
//                             Colors.amber, // Color of the selected radio button
//                         contentPadding:
//                             EdgeInsets.zero, // Remove default padding
//                       ),
//                     ),
//                     Expanded(
//                       child: RadioListTile<GameType>(
//                         title: const Text('Even'),
//                         value: GameType.even,
//                         groupValue: _selectedGameType,
//                         onChanged: (GameType? value) {
//                           setState(() {
//                             _selectedGameType = value;
//                           });
//                         },
//                         activeColor:
//                             Colors.amber, // Color of the selected radio button
//                         contentPadding:
//                             EdgeInsets.zero, // Remove default padding
//                       ),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 16),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         'Enter Points :',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     SizedBox(width: 10),
//                     Expanded(child: _buildPointsInputField(_pointsController)),
//                   ],
//                 ),
//                 SizedBox(height: 16),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.end,
//                   children: [
//                     SizedBox(
//                       width: 150,
//                       child: ElevatedButton(
//                         onPressed: _addEntry,
//                         child: Text(
//                           'ADD',
//                           style: TextStyle(color: Colors.white, fontSize: 16),
//                         ),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.amber,
//                           padding: EdgeInsets.symmetric(vertical: 12),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           elevation: 3,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           Divider(height: 1, color: Colors.grey[400]),
//           if (_entries.isNotEmpty) // Use _entries for conditional rendering
//             Padding(
//               padding: const EdgeInsets.symmetric(
//                 horizontal: 16.0,
//                 vertical: 8.0,
//               ),
//               child: Row(
//                 children: [
//                   Expanded(
//                     flex: 2,
//                     child: Text(
//                       'Digit',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                   Expanded(
//                     flex: 3,
//                     child: Text(
//                       'Points',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                   Expanded(
//                     flex: 2,
//                     child: Text(
//                       'Type',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                   SizedBox(width: 48), // Space for the delete icon
//                 ],
//               ),
//             ),
//           if (_entries.isNotEmpty) // Use _entries for conditional rendering
//             Divider(height: 1, color: Colors.grey[400]),
//           Expanded(
//             child: _entries.isEmpty
//                 ? Center(
//                     child: Text(
//                       'No entries yet. Add some data!',
//                       style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//                     ),
//                   )
//                 : ListView.builder(
//                     itemCount: _entries.length,
//                     itemBuilder: (context, index) {
//                       final entry = _entries[index];
//                       return _buildEntryItem(
//                         entry['digit']!,
//                         entry['points']!,
//                         entry['type']!,
//                         index,
//                       );
//                     },
//                   ),
//           ),
//           if (_entries.isNotEmpty)
//             _buildBottomBar(), // Use _entries for conditional rendering
//         ],
//       ),
//     );
//   }
//
//   // Helper widget for Enter Points input field (reused from previous)
//   Widget _buildPointsInputField(TextEditingController controller) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey[300]!),
//       ),
//       child: TextField(
//         cursorColor: Colors.amber,
//         controller: controller,
//         keyboardType: TextInputType.number,
//         inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//         decoration: InputDecoration(
//           hintText: 'Enter Points',
//           border: InputBorder.none,
//           contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//           suffixIcon: Container(
//             margin: EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: Colors.amber,
//               shape: BoxShape.circle,
//             ),
//             child: Icon(Icons.arrow_forward, color: Colors.white, size: 16),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Helper widget to build each entry item in the list
//   Widget _buildEntryItem(String digit, String points, String type, int index) {
//     return Card(
//       margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//       elevation: 1,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
//         child: Row(
//           children: [
//             Expanded(
//               flex: 2,
//               child: Text(
//                 digit,
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//               ),
//             ),
//             Expanded(
//               flex: 3,
//               child: Text(
//                 points,
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//               ),
//             ),
//             Expanded(
//               flex: 2,
//               child: Text(
//                 type,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                   color: Colors.green[700],
//                 ),
//               ), // Green for 'CLOSE'
//             ),
//             IconButton(
//               icon: Icon(Icons.delete, color: Colors.red),
//               onPressed: () => _deleteEntry(index),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Helper widget for the bottom bar (reused from previous DigitBasedBoardScreen)
//   Widget _buildBottomBar() {
//     // Calculate total bids and points dynamically from the _entries list
//     int totalBids = _entries.length; // Use _entries here
//     int totalPoints = getTotalPoints(); // Use getTotalPoints() here
//
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: Colors.white, // White background for bottom bar
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.3),
//             spreadRadius: 2,
//             blurRadius: 5,
//             offset: Offset(0, -3), // Shadow at the top of the bar
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out elements
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
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//           ElevatedButton(
//             onPressed: () {
//               ScaffoldMessenger.of(
//                 context,
//               ).showSnackBar(SnackBar(content: Text('Submit button pressed!')));
//             },
//             child: Text(
//               'SUBMIT',
//               style: TextStyle(color: Colors.white, fontSize: 16),
//             ),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.amber, // Use Colors.amber for consistency
//               padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
