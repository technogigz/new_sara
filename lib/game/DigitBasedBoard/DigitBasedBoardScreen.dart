import 'dart:convert'; // For json encoding/decoding

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get_storage/get_storage.dart'; // For GetStorage
import 'package:http/http.dart' as http; // For making HTTP requests
import 'package:intl/intl.dart'; // For date formatting

// Assuming you have this file created from previous instructions
import '../../components/BidConfirmationDialog.dart';

class DigitBasedBoardScreen extends StatefulWidget {
  final String title;
  final String gameType;
  final String gameId;

  const DigitBasedBoardScreen({
    Key? key,
    required this.title,
    required this.gameType,
    required this.gameId,
  }) : super(key: key);

  @override
  _DigitBasedBoardScreenState createState() => _DigitBasedBoardScreenState();
}

class _DigitBasedBoardScreenState extends State<DigitBasedBoardScreen> {
  final TextEditingController _leftDigitController = TextEditingController();
  final TextEditingController _rightDigitController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  List<Map<String, String>> _entries = [];
  int _walletBalance = 0; // State variable for wallet balance

  @override
  void initState() {
    super.initState();
    _loadWalletBalance(); // Load wallet balance when the screen initializes
  }

  @override
  void dispose() {
    _leftDigitController.dispose();
    _rightDigitController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  void _loadWalletBalance() {
    final box = GetStorage();
    final dynamic storedValue = box.read('walletBalance');

    if (storedValue != null) {
      if (storedValue is int) {
        _walletBalance = storedValue;
      } else if (storedValue is String) {
        _walletBalance = int.tryParse(storedValue) ?? 0;
      } else {
        _walletBalance = 0; // Fallback for unexpected types
      }
    } else {
      _walletBalance = 1000; // Default balance if nothing is stored
      box.write('walletBalance', _walletBalance); // Save default if not present
    }
    setState(() {}); // Update UI to show loaded balance
  }

  void _updateWalletBalance(int spentAmount) {
    setState(() {
      _walletBalance -= spentAmount;
      GetStorage().write(
        'walletBalance',
        _walletBalance,
      ); // Save updated balance
    });
  }

  Future<void> _addEntry() async {
    final String leftDigit = _leftDigitController.text.trim();
    final String rightDigit = _rightDigitController.text.trim();
    final String points = _pointsController.text.trim();

    // Client-side validation
    if (leftDigit.isEmpty && rightDigit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one digit.')),
      );
      return;
    }

    if (points.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter points.')));
      return;
    }

    final int intPoints = int.tryParse(points) ?? 0;
    if (intPoints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Points must be a positive number.')),
      );
      return;
    }

    // Validate left digit
    if (leftDigit.isNotEmpty &&
        (leftDigit.length != 1 || int.tryParse(leftDigit) == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Left digit must be a single number (0-9).'),
        ),
      );
      return;
    }

    // Validate right digit
    if (rightDigit.isNotEmpty &&
        (rightDigit.length != 1 || int.tryParse(rightDigit) == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Right digit must be a single number (0-9).'),
        ),
      );
      return;
    }

    // Determine the total amount to be deducted initially for validation
    // Based on previous understanding, if rightDigit is empty, 10 Jodis are implied.
    int totalAmountForRequest = intPoints; // For a single Jodi/Pana
    if (leftDigit.isNotEmpty && rightDigit.isEmpty) {
      totalAmountForRequest = intPoints * 10; // 10 Jodis (0-9)
    }

    if (totalAmountForRequest > _walletBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient wallet balance for all bids.'),
        ),
      );
      return;
    }

    // Prepare the body for the API call
    final Map<String, dynamic> requestBody;
    if (leftDigit.isNotEmpty && rightDigit.isEmpty) {
      // If only left digit is provided, send it and the amount. Backend is expected to generate "panas" (jodis)
      requestBody = {
        "leftDigit": int.parse(leftDigit),
        "amount": intPoints,
        // The API response indicates a single 'amount' for multiple panas,
        // so we send the per-pana amount here.
      };
    } else if (leftDigit.isNotEmpty && rightDigit.isNotEmpty) {
      // If both digits are provided, send a single jodi
      requestBody = {
        "leftDigit": int.parse(leftDigit),
        "rightDigit": int.parse(rightDigit),
        "amount": intPoints,
      };
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid digit combination.')),
      );
      return;
    }

    final url = Uri.parse(
      'https://sara777.win/api/v1/digit-based-jodi',
    ); // Assuming this API supports the response structure
    final box = GetStorage();
    String bearerToken = box.read("accessToken") ?? '';

    final headers = {
      'deviceId': 'qwert',
      'deviceName': 'sm2233',
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $bearerToken',
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == true) {
          final List<dynamic> info = responseData['info'] ?? [];
          List<Map<String, String>> bidsFromApi = [];
          int totalAmountDeducted = 0;

          for (var item in info) {
            final String pana = item['pana'].toString();
            final String amount = item['amount'].toString();
            bidsFromApi.add({
              'pana': pana,
              'points': amount,
              'type': 'Digit Board',
            });
            totalAmountDeducted += int.tryParse(amount) ?? 0;
          }

          if (bidsFromApi.isNotEmpty) {
            setState(() {
              _entries.addAll(
                bidsFromApi.map(
                  (e) => {'jodi': e['pana']!, 'points': e['points']!},
                ),
              ); // Add to local list
              _leftDigitController.clear();
              _rightDigitController.clear();
              _pointsController.clear();
            });

            _updateWalletBalance(
              totalAmountDeducted,
            ); // Deduct total amount from wallet

            // Prepare data for the confirmation dialog
            _showBidConfirmationDialog(
              gameTitle: widget
                  .title, // You might get a game title from API if available
              gameType: 'Digit Board',
              gameId: widget.gameId,
              gameDate: DateFormat(
                'dd MMM yyyy, hh:mm a',
              ).format(DateTime.now()), // Or from API
              bids: bidsFromApi
                  .map(
                    (bid) => {
                      'digit':
                          bid['pana']!, // Use 'pana' as 'digit' for the dialog
                      'points': bid['points']!,
                      'type': bid['type']!,
                    },
                  )
                  .toList(),
              totalBids: bidsFromApi.length,
              totalBidsAmount: totalAmountDeducted,
              walletBalanceBeforeDeduction:
                  (_walletBalance + totalAmountDeducted)
                      .toString(), // Calculate before deduction
              walletBalanceAfterDeduction: _walletBalance.toString(),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'API response was successful but no bids were returned.',
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'API Error: ${responseData['msg'] ?? 'Unknown error'}',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Server Error: ${response.statusCode} - ${response.reasonPhrase}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Network Error: $e')));
    }
  }

  void _deleteEntry(int index) {
    setState(() {
      _entries.removeAt(index);
    });
    // In a real app, you might want to call an API to cancel the bid here.
  }

  int _getTotalBidsCount() {
    return _entries.length;
  }

  int _getTotalPoints() {
    return _entries.fold(
      0,
      (sum, item) => sum + int.tryParse(item['points'] ?? '0')!,
    );
  }

  void _showBidConfirmationDialog({
    required String gameTitle,
    required String gameDate,
    required String gameId,
    required String gameType,
    required List<Map<String, String>> bids,
    required int totalBids,
    required int totalBidsAmount,
    required String walletBalanceBeforeDeduction,
    String? walletBalanceAfterDeduction,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BidConfirmationDialog(
          gameTitle: gameTitle,
          gameDate: gameDate,
          gameId: gameId,
          gameType: gameType,
          bids: bids,
          totalBids: totalBids,
          totalBidsAmount: totalBidsAmount,
          walletBalanceBeforeDeduction:
              int.tryParse(walletBalanceBeforeDeduction) ?? 0,
          walletBalanceAfterDeduction: walletBalanceAfterDeduction,
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
                Image.asset(
                  "assets/images/wallet_icon.png",
                  height: 24,
                  color: Colors.black,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_walletBalance', // Display dynamic wallet balance
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
                const SizedBox(height: 8),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: _addEntry,
                        child: const Text(
                          'ADD',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 3,
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
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Jodi', // Changed from 'Pana' to 'Jodi' for consistency with UI field
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
                  const SizedBox(width: 48),
                ],
              ),
            ),
          if (_entries.isNotEmpty) Divider(height: 1, color: Colors.grey[400]),
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
                      // Use 'jodi' key for display as per your UI layout
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
        cursorColor: Colors.amber,
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
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
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteEntry(index),
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Submit button pressed!')),
              );
            },
            child: const Text(
              'SUBMIT',
              style: TextStyle(color: Colors.white, fontSize: 16),
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

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // For TextInputFormatter
//
// class DigitBasedBoardScreen extends StatefulWidget {
//   // Add a final field to store the title
//   final String title;
//
//   // Constructor now requires the title
//   const DigitBasedBoardScreen({Key? key, required this.title})
//     : super(key: key);
//
//   @override
//   _DigitBasedBoardScreenState createState() => _DigitBasedBoardScreenState();
// }
//
// class _DigitBasedBoardScreenState extends State<DigitBasedBoardScreen> {
//   // Controllers for the text input fields
//   final TextEditingController _leftDigitController = TextEditingController();
//   final TextEditingController _rightDigitController = TextEditingController();
//   final TextEditingController _pointsController = TextEditingController();
//
//   // List to store the added entries (Jodi and Points)
//   List<Map<String, String>> _entries = [];
//
//   // Dispose controllers to free up resources when the widget is removed from the widget tree
//   @override
//   void dispose() {
//     _leftDigitController.dispose();
//     _rightDigitController.dispose();
//     _pointsController.dispose();
//     super.dispose();
//   }
//
//   // Function to add a new entry to the list
//   void _addEntry() {
//     setState(() {
//       String left = _leftDigitController.text.trim();
//       String points = _pointsController.text.trim();
//
//       if (left.isNotEmpty && points.isNotEmpty) {
//         // Ensure left is a single digit
//         if (left.length != 1 || int.tryParse(left) == null) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Left digit must be a single number (0-9).'),
//             ),
//           );
//           return;
//         }
//
//         for (int i = 0; i <= 9; i++) {
//           String jodi = '$left$i';
//
//           // Optional: Skip duplicate entries
//           bool alreadyExists = _entries.any((entry) => entry['jodi'] == jodi);
//           if (!alreadyExists) {
//             _entries.add({'jodi': jodi, 'points': points});
//           }
//         }
//
//         // Clear input fields
//         _leftDigitController.clear();
//         _pointsController.clear();
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Please enter left digit and points.')),
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
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[200], // Light grey background as per image
//       appBar: AppBar(
//         backgroundColor: Colors.white, // White app bar background
//         elevation: 0, // No shadow for the app bar
//         leading: IconButton(
//           icon: Icon(
//             Icons.arrow_back_ios,
//             color: Colors.black,
//           ), // Back arrow icon
//           onPressed: () {
//             // TODO: Implement back button functionality
//             Navigator.pop(context); // Example: Pop current screen
//           },
//         ),
//         // Use widget.title to display the title passed to the screen
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
//                 // Using a placeholder icon as Image.asset requires asset declaration
//                 Image.asset(
//                   "assets/images/wallet_icon.png",
//                   height: 24,
//                   color: Colors.black,
//                 ), // Wallet icon
//                 SizedBox(width: 4),
//                 Text(
//                   '5',
//                   style: TextStyle(color: Colors.black, fontSize: 16),
//                 ), // Wallet balance
//               ],
//             ),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Input Section
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: _buildDigitInputField(
//                         'Left Digit',
//                         _leftDigitController,
//                       ),
//                     ),
//                     SizedBox(width: 16), // Space between input fields
//                     Expanded(
//                       child: _buildDigitInputField(
//                         'Right Digit',
//                         _rightDigitController,
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
//                     SizedBox(width: 10), // Space between input fields
//                     Expanded(child: _buildPointsInputField(_pointsController)),
//                   ],
//                 ),
//                 SizedBox(height: 8),
//                 SizedBox(height: 16),
//                 // Aligning the ADD button to the right
//                 Row(
//                   mainAxisAlignment:
//                       MainAxisAlignment.end, // Align to the right
//                   children: [
//                     SizedBox(
//                       width: 150, // Set fixed width for the button
//                       child: ElevatedButton(
//                         onPressed:
//                             _addEntry, // Call _addEntry function on press
//                         child: Text(
//                           'ADD',
//                           style: TextStyle(color: Colors.white, fontSize: 16),
//                         ),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor:
//                               Colors.amber, // Orange background for button
//                           padding: EdgeInsets.symmetric(vertical: 12),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(
//                               8,
//                             ), // Rounded corners
//                           ),
//                           elevation: 3, // Subtle shadow for button
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           Divider(
//             height: 1,
//             color: Colors.grey[400],
//           ), // Divider below input section
//           // Conditionally render List Header and List of Entries
//           if (_entries.isNotEmpty) // Only show if there is data
//             Padding(
//               padding: const EdgeInsets.symmetric(
//                 horizontal: 16.0,
//                 vertical: 8.0,
//               ),
//               child: Row(
//                 children: [
//                   Expanded(
//                     flex:
//                         2, // Allocate space for 'Jodi' to align with list items
//                     child: Text(
//                       'Jodi',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                   Expanded(
//                     flex:
//                         3, // Allocate space for 'Points' to align with list items
//                     child: Text(
//                       'Points',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                   SizedBox(
//                     width: 48,
//                   ), // Space to align with the delete icon in list items
//                 ],
//               ),
//             ),
//           if (_entries.isNotEmpty) // Only show if there is data
//             Divider(
//               height: 1,
//               color: Colors.grey[400],
//             ), // Divider below list header
//           Expanded(
//             child: _entries.isEmpty
//                 ? Center(
//                     child: Text(
//                       'No entries yet. Add some data!',
//                       style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//                     ),
//                   )
//                 : ListView.builder(
//                     itemCount: _entries.length, // Number of items in the list
//                     itemBuilder: (context, index) {
//                       final entry = _entries[index];
//                       return _buildEntryItem(
//                         entry['jodi']!,
//                         entry['points']!,
//                         index,
//                       );
//                     },
//                   ),
//           ),
//           // Conditionally render Bottom Bar (Bids, Points, Submit Button)
//           if (_entries.isNotEmpty) _buildBottomBar(),
//         ],
//       ),
//     );
//   }
//
//   // Helper widget for Left/Right Digit input fields
//   Widget _buildDigitInputField(String label, TextEditingController controller) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white, // White background for input field
//         borderRadius: BorderRadius.circular(8), // Rounded corners
//         border: Border.all(color: Colors.grey[300]!), // Light grey border
//       ),
//       child: TextField(
//         cursorColor: Colors.amber,
//         controller: controller,
//         keyboardType: TextInputType.number, // Numeric keyboard
//         inputFormatters: [
//           LengthLimitingTextInputFormatter(1), // Limit to 1 digit
//           FilteringTextInputFormatter.digitsOnly, // Allow only digits
//         ],
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: TextStyle(color: Colors.grey[600]),
//           border: InputBorder.none, // Remove default border
//           contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//           suffixIcon: Container(
//             margin: EdgeInsets.all(8), // Margin around the circular icon
//             decoration: BoxDecoration(
//               color: Colors.amber, // Orange circular background
//               shape: BoxShape.circle,
//             ),
//             child: Icon(
//               Icons.arrow_forward,
//               color: Colors.white,
//               size: 16,
//             ), // White arrow icon
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Helper widget for Enter Points input field
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
//         inputFormatters: [
//           FilteringTextInputFormatter.digitsOnly, // Allow only digits
//         ],
//         decoration: InputDecoration(
//           hintText: 'Enter Points', // Added hint text here
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
//   Widget _buildEntryItem(String jodi, String points, int index) {
//     return Card(
//       margin: EdgeInsets.symmetric(
//         horizontal: 5,
//         vertical: 4,
//       ), // Margin around each card
//       elevation: 1, // Subtle shadow for cards
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(8), // Rounded corners for cards
//       ),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
//         child: Row(
//           children: [
//             Expanded(
//               flex: 2, // Flex distribution for Jodi text
//               child: Text(
//                 jodi,
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//               ),
//             ),
//             Expanded(
//               flex: 3, // Flex distribution for Points text
//               child: Text(
//                 points,
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//               ),
//             ),
//             IconButton(
//               icon: Icon(Icons.delete, color: Colors.red), // Delete icon
//               onPressed: () => _deleteEntry(index), // Call delete function
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Helper widget for the bottom bar
//   Widget _buildBottomBar() {
//     // Calculate total bids and points dynamically from the _entries list
//     int totalBids = _entries.length;
//     int totalPoints = _entries.fold(
//       0,
//       (sum, item) => sum + int.tryParse(item['points'] ?? '0')!,
//     );
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
//               // TODO: Implement submit functionality
//               ScaffoldMessenger.of(
//                 context,
//               ).showSnackBar(SnackBar(content: Text('Submit button pressed!')));
//             },
//             child: Text(
//               'SUBMIT',
//               style: TextStyle(color: Colors.white, fontSize: 16),
//             ),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.amber,
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
//
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart'; // For TextInputFormatter
// //
// // class DigitBasedBoardScreen extends StatefulWidget {
// //   // Add a final field to store the title
// //   final String title;
// //
// //   // Constructor now requires the title
// //   const DigitBasedBoardScreen({Key? key, required this.title})
// //     : super(key: key);
// //
// //   @override
// //   _DigitBasedBoardScreenState createState() => _DigitBasedBoardScreenState();
// // }
// //
// // class _DigitBasedBoardScreenState extends State<DigitBasedBoardScreen> {
// //   // Controllers for the text input fields
// //   final TextEditingController _leftDigitController = TextEditingController();
// //   final TextEditingController _rightDigitController = TextEditingController();
// //   final TextEditingController _pointsController = TextEditingController();
// //
// //   // List to store the added entries (Jodi and Points)
// //   List<Map<String, String>> _entries = [];
// //
// //   // Dispose controllers to free up resources when the widget is removed from the widget tree
// //   @override
// //   void dispose() {
// //     _leftDigitController.dispose();
// //     _rightDigitController.dispose();
// //     _pointsController.dispose();
// //     super.dispose();
// //   }
// //
// //   // Function to add a new entry to the list
// //   void _addEntry() {
// //     setState(() {
// //       String left = _leftDigitController.text.trim();
// //       String right = _rightDigitController.text.trim();
// //       String points = _pointsController.text.trim();
// //
// //       // Only add if all fields are non-empty
// //       if (left.isNotEmpty && right.isNotEmpty && points.isNotEmpty) {
// //         _entries.add({
// //           'jodi': '$left$right', // Combine left and right digit for Jodi
// //           'points': points,
// //         });
// //         // Clear the text fields after adding
// //         _leftDigitController.clear();
// //         _rightDigitController.clear();
// //         _pointsController.clear();
// //       } else {
// //         // Optionally show a snackbar or dialog if fields are empty
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(content: Text('Please enter values for all fields.')),
// //         );
// //       }
// //     });
// //   }
// //
// //   // Function to delete an entry from the list
// //   void _deleteEntry(int index) {
// //     setState(() {
// //       _entries.removeAt(index);
// //     });
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: Colors.grey[200], // Light grey background as per image
// //       appBar: AppBar(
// //         backgroundColor: Colors.white, // White app bar background
// //         elevation: 0, // No shadow for the app bar
// //         leading: IconButton(
// //           icon: Icon(
// //             Icons.arrow_back_ios,
// //             color: Colors.black,
// //           ), // Back arrow icon
// //           onPressed: () {
// //             // TODO: Implement back button functionality
// //             Navigator.pop(context); // Example: Pop current screen
// //           },
// //         ),
// //         // Use widget.title to display the title passed to the screen
// //         title: Text(
// //           widget.title,
// //           style: TextStyle(
// //             color: Colors.black,
// //             fontSize: 18,
// //             fontWeight: FontWeight.bold,
// //           ),
// //         ),
// //         actions: [
// //           Padding(
// //             padding: const EdgeInsets.only(right: 16.0),
// //             child: Row(
// //               children: [
// //                 Image.asset(
// //                   "assets/images/wallet_icon.png",
// //                   height: 24,
// //                   color: Colors.black,
// //                 ), // Wallet icon
// //                 SizedBox(width: 4),
// //                 Text(
// //                   '5',
// //                   style: TextStyle(color: Colors.black, fontSize: 16),
// //                 ), // Wallet balance
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //       body: Column(
// //         children: [
// //           // Input Section
// //           Padding(
// //             padding: const EdgeInsets.all(16.0),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 Row(
// //                   children: [
// //                     Expanded(
// //                       child: _buildDigitInputField(
// //                         'Left Digit',
// //                         _leftDigitController,
// //                       ),
// //                     ),
// //                     SizedBox(width: 16), // Space between input fields
// //                     Expanded(
// //                       child: _buildDigitInputField(
// //                         'Right Digit',
// //                         _rightDigitController,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //                 SizedBox(height: 16),
// //                 // Reverted the "Enter Points" section to its correct layout
// //                 Row(
// //                   children: [
// //                     Expanded(
// //                       child: Text(
// //                         'Enter Points :',
// //                         style: TextStyle(
// //                           fontSize: 16,
// //                           fontWeight: FontWeight.bold,
// //                         ),
// //                       ),
// //                     ),
// //                     // Space between input fields
// //                     SizedBox(width: 10),
// //                     Expanded(child: _buildPointsInputField(_pointsController)),
// //                   ],
// //                 ),
// //
// //                 SizedBox(height: 8),
// //                 SizedBox(height: 16),
// //                 // Aligning the ADD button to the right
// //                 Row(
// //                   mainAxisAlignment:
// //                       MainAxisAlignment.end, // Align to the right
// //                   children: [
// //                     SizedBox(
// //                       width: 150, // Set fixed width for the button
// //                       child: ElevatedButton(
// //                         onPressed:
// //                             _addEntry, // Call _addEntry function on press
// //                         child: Text(
// //                           'ADD',
// //                           style: TextStyle(color: Colors.white, fontSize: 16),
// //                         ),
// //                         style: ElevatedButton.styleFrom(
// //                           backgroundColor:
// //                               Colors.amber, // Orange background for button
// //                           padding: EdgeInsets.symmetric(vertical: 12),
// //                           shape: RoundedRectangleBorder(
// //                             borderRadius: BorderRadius.circular(
// //                               8,
// //                             ), // Rounded corners
// //                           ),
// //                           elevation: 3, // Subtle shadow for button
// //                         ),
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ],
// //             ),
// //           ),
// //           Divider(
// //             height: 1,
// //             color: Colors.grey[400],
// //           ), // Divider below input section
// //           // List Header (Jodi and Points)
// //           Padding(
// //             padding: const EdgeInsets.symmetric(
// //               horizontal: 16.0,
// //               vertical: 8.0,
// //             ),
// //             child: Row(
// //               children: [
// //                 Expanded(
// //                   flex: 2, // Allocate space for 'Jodi' to align with list items
// //                   child: Text(
// //                     'Jodi',
// //                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
// //                   ),
// //                 ),
// //                 Expanded(
// //                   flex:
// //                       3, // Allocate space for 'Points' to align with list items
// //                   child: Text(
// //                     'Points',
// //                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
// //                   ),
// //                 ),
// //                 SizedBox(
// //                   width: 48,
// //                 ), // Space to align with the delete icon in list items
// //               ],
// //             ),
// //           ),
// //           Divider(
// //             height: 1,
// //             color: Colors.grey[400],
// //           ), // Divider below list header
// //           // List of Entries (scrollable)
// //           Expanded(
// //             child: ListView.builder(
// //               itemCount: _entries.length, // Number of items in the list
// //               itemBuilder: (context, index) {
// //                 final entry = _entries[index];
// //                 return _buildEntryItem(entry['jodi']!, entry['points']!, index);
// //               },
// //             ),
// //           ),
// //           // Bottom Bar (Bids, Points, Submit Button)
// //           _buildBottomBar(),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   // Helper widget for Left/Right Digit input fields
// //   Widget _buildDigitInputField(String label, TextEditingController controller) {
// //     return Container(
// //       decoration: BoxDecoration(
// //         color: Colors.white, // White background for input field
// //         borderRadius: BorderRadius.circular(8), // Rounded corners
// //         border: Border.all(color: Colors.grey[300]!), // Light grey border
// //       ),
// //       child: TextField(
// //         cursorColor: Colors.amber,
// //         controller: controller,
// //         keyboardType: TextInputType.number, // Numeric keyboard
// //         inputFormatters: [
// //           LengthLimitingTextInputFormatter(1), // Limit to 1 digit
// //           FilteringTextInputFormatter.digitsOnly, // Allow only digits
// //         ],
// //         decoration: InputDecoration(
// //           labelText: label,
// //           labelStyle: TextStyle(color: Colors.grey[600]),
// //           border: InputBorder.none, // Remove default border
// //           contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //           suffixIcon: Container(
// //             margin: EdgeInsets.all(8), // Margin around the circular icon
// //             decoration: BoxDecoration(
// //               color: Colors.amber, // Orange circular background
// //               shape: BoxShape.circle,
// //             ),
// //             child: Icon(
// //               Icons.arrow_forward,
// //               color: Colors.white,
// //               size: 16,
// //             ), // White arrow icon
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // Helper widget for Enter Points input field
// //   Widget _buildPointsInputField(TextEditingController controller) {
// //     return Container(
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(8),
// //         border: Border.all(color: Colors.grey[300]!),
// //       ),
// //       child: TextField(
// //         cursorColor: Colors.amber,
// //         controller: controller,
// //         keyboardType: TextInputType.number,
// //         inputFormatters: [
// //           FilteringTextInputFormatter.digitsOnly, // Allow only digits
// //         ],
// //         decoration: InputDecoration(
// //           hintText: 'Enter Points', // Added hint text here
// //           border: InputBorder.none,
// //           contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //           suffixIcon: Container(
// //             margin: EdgeInsets.all(8),
// //             decoration: BoxDecoration(
// //               color: Colors.amber,
// //               shape: BoxShape.circle,
// //             ),
// //
// //             child: Icon(Icons.arrow_forward, color: Colors.white, size: 16),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // Helper widget to build each entry item in the list
// //   Widget _buildEntryItem(String jodi, String points, int index) {
// //     return Card(
// //       margin: EdgeInsets.symmetric(
// //         horizontal: 16,
// //         vertical: 4,
// //       ), // Margin around each card
// //       elevation: 1, // Subtle shadow for cards
// //       shape: RoundedRectangleBorder(
// //         borderRadius: BorderRadius.circular(8), // Rounded corners for cards
// //       ),
// //       child: Padding(
// //         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
// //         child: Row(
// //           children: [
// //             Expanded(
// //               flex: 2, // Flex distribution for Jodi text
// //               child: Text(
// //                 jodi,
// //                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
// //               ),
// //             ),
// //             Expanded(
// //               flex: 3, // Flex distribution for Points text
// //               child: Text(
// //                 points,
// //                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
// //               ),
// //             ),
// //             IconButton(
// //               icon: Icon(Icons.delete, color: Colors.red), // Delete icon
// //               onPressed: () => _deleteEntry(index), // Call delete function
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // Helper widget for the bottom bar
// //   Widget _buildBottomBar() {
// //     // Calculate total bids and points dynamically from the _entries list
// //     int totalBids = _entries.length;
// //     int totalPoints = _entries.fold(
// //       0,
// //       (sum, item) => sum + int.tryParse(item['points'] ?? '0')!,
// //     );
// //
// //     return Container(
// //       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //       decoration: BoxDecoration(
// //         color: Colors.white, // White background for bottom bar
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.grey.withOpacity(0.3),
// //             spreadRadius: 2,
// //             blurRadius: 5,
// //             offset: Offset(0, -3), // Shadow at the top of the bar
// //           ),
// //         ],
// //       ),
// //       child: Row(
// //         mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out elements
// //         children: [
// //           Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Text(
// //                 'Bids',
// //                 style: TextStyle(fontSize: 14, color: Colors.grey[700]),
// //               ),
// //               Text(
// //                 '$totalBids',
// //                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
// //               ),
// //             ],
// //           ),
// //           Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Text(
// //                 'Points',
// //                 style: TextStyle(fontSize: 14, color: Colors.grey[700]),
// //               ),
// //               Text(
// //                 '$totalPoints',
// //                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
// //               ),
// //             ],
// //           ),
// //           ElevatedButton(
// //             onPressed: () {
// //               // TODO: Implement submit functionality
// //               ScaffoldMessenger.of(
// //                 context,
// //               ).showSnackBar(SnackBar(content: Text('Submit button pressed!')));
// //             },
// //             child: Text(
// //               'SUBMIT',
// //               style: TextStyle(color: Colors.white, fontSize: 16),
// //             ),
// //             style: ElevatedButton.styleFrom(
// //               backgroundColor: Colors.amber,
// //               padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
// //               shape: RoundedRectangleBorder(
// //                 borderRadius: BorderRadius.circular(8),
// //               ),
// //               elevation: 3,
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
