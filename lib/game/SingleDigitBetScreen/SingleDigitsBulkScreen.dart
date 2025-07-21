import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
import 'package:intl/intl.dart';

import '../../components/BidConfirmationDialog.dart'; // For date formatting

class SingleDigitsBulkScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameName;
  final String
  selectedGameType; // This is the game type from KingStarline (e.g., "singleDigitsBulk")
  final String
  gameType; // This seems redundant if selectedGameType holds the main type

  const SingleDigitsBulkScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.selectedGameType, // Using this as the primary game type identifier
    required this.gameType, // Keeping it for now, but consider if redundant
  }) : super(key: key);

  @override
  State<SingleDigitsBulkScreen> createState() => _SingleDigitsBulkScreenState();
}

class _SingleDigitsBulkScreenState extends State<SingleDigitsBulkScreen> {
  // These are the actual options for the dropdown (Open/Close)
  String selectedGameType = 'Open'; // Default for the dropdown
  final List<String> gameTypes = ['Open', 'Close']; // Options for the dropdown

  final TextEditingController pointsController = TextEditingController();

  Color dropdownBorderColor = Colors.black;
  Color textFieldBorderColor = Colors.black;

  Map<String, String> bidAmounts = {};
  late GetStorage storage =
      GetStorage(); // Use the late keyword for direct initialization

  late String mobile = '';
  late String name = '';
  late bool accountActiveStatus;
  late String walletBallence;

  @override
  void initState() {
    super.initState();

    final storage = GetStorage();

    // Initial reads
    mobile = storage.read('mobileNoEnc') ?? '';
    name = storage.read('fullName') ?? '';
    accountActiveStatus = storage.read('accountStatus') ?? false;
    walletBallence = storage.read('walletBalance') ?? '';

    // Listen to updates
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
        walletBallence = value ?? '0';
      });
    });
  }

  @override
  void dispose() {
    pointsController.dispose();
    super.dispose();
  }

  void onNumberPressed(String number) {
    setState(() {
      final amount = pointsController.text.trim();
      if (amount.isNotEmpty) {
        if (int.tryParse(amount) != null && int.parse(amount) > 0) {
          bidAmounts[number] = amount;
          // You can call _fetchWalletBalanceFromApi here if you want to refresh wallet after each bid add
          // _fetchWalletBalanceFromApi();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid positive amount.'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter an amount first.')),
        );
      }
    });
  }

  int _getTotalPoints() {
    return bidAmounts.values
        .map((e) => int.tryParse(e) ?? 0)
        .fold(0, (a, b) => a + b);
  }

  void _showConfirmationDialog() {
    if (bidAmounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one bid.')),
      );
      return;
    }

    final int totalPoints = _getTotalPoints();

    if (walletBallence as int < totalPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient wallet balance to place this bid.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    List<Map<String, String>> bidsForDialog = [];
    bidAmounts.forEach((digit, points) {
      bidsForDialog.add({
        "digit": digit,
        "points": points,
        "type": selectedGameType,
        "pana":
            digit, // Assuming 'pana' is the same as 'digit' for single digits
      });
    });

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BidConfirmationDialog(
          gameTitle: widget.gameName,
          gameDate: formattedDate,
          bids: bidsForDialog,
          totalBids: bidsForDialog.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBallence as int,
          walletBalanceAfterDeduction: ((walletBallence as int) - totalPoints)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
        );
      },
    ).then((_) {});
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
      backgroundColor: Colors.grey.shade100,
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
                // Display loading indicator or balance
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
                            "₹${walletBallence}",
                            style: TextStyle(
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _inputRow("Select Game Type:", _buildDropdown()),
                _inputRow("Enter Points:", _buildTextField()),
                const SizedBox(height: 30),
                _buildNumberPad(),
                // Add a flexible space to push the bottom bar down
                const Spacer(),
                // The list of bids is now below the number pad
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
                              selectedGameType, // Use the selected game type from dropdown
                            );
                          },
                        ),
                ),
                const SizedBox(height: 60), // Space for the bottom bar
              ],
            ),
          ),
          if (bidAmounts.isNotEmpty)
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

  // Renamed from _buildBidEntryItem to make it more generic for single digits
  Widget _buildBidEntryItem(String digit, String points, String type) {
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
                digit, // Display the digit
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
              onPressed: () => setState(() {
                bidAmounts.remove(digit);
                // Call _fetchWalletBalanceFromApi if you want to refresh wallet after removing a bid
                // _fetchWalletBalanceFromApi();
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// import 'dart:convert'; // Import for JSON encoding/decoding
// import 'dart:developer'; // For log
//
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
// import 'package:http/http.dart' as http; // Import for HTTP requests
// import 'package:intl/intl.dart';
// import 'package:new_sara/ulits/Constents.dart'; // Ensure this path is correct
//
// import '../../components/BidConfirmationDialog.dart'; // For date formatting
//
// class SingleDigitsBulkScreen extends StatefulWidget {
//   final String title;
//   final int gameId;
//   final String gameName;
//   final String
//   selectedGameType; // This is the game type from KingStarline (e.g., "singleDigitsBulk")
//   final String
//   gameType; // This seems redundant if selectedGameType holds the main type
//
//   const SingleDigitsBulkScreen({
//     Key? key,
//     required this.title,
//     required this.gameId,
//     required this.gameName,
//     required this.selectedGameType, // Using this as the primary game type identifier
//     required this.gameType, // Keeping it for now, but consider if redundant
//   }) : super(key: key);
//
//   @override
//   State<SingleDigitsBulkScreen> createState() => _SingleDigitsBulkScreenState();
// }
//
// class _SingleDigitsBulkScreenState extends State<SingleDigitsBulkScreen> {
//   // These are the actual options for the dropdown (Open/Close)
//   String selectedGameType = 'Open'; // Default for the dropdown
//   final List<String> gameTypes = ['Open', 'Close']; // Options for the dropdown
//
//   final TextEditingController pointsController = TextEditingController();
//
//   Color dropdownBorderColor = Colors.black;
//   Color textFieldBorderColor = Colors.black;
//
//   Map<String, String> bidAmounts = {};
//   late GetStorage storage = GetStorage();
//
//   late String accessToken;
//   late String registerId;
//   late String preferredLanguage;
//   bool accountStatus = false;
//   late int walletBalance; // Corrected spelling to walletBalance
//
//   bool _isWalletLoading = true; // New state to indicate wallet loading
//
//   // Placeholder for device info. In a real app, these would be dynamic.
//   final String _deviceId = 'test_device_id_flutter';
//   final String _deviceName = 'test_device_name_flutter';
//
//   @override
//   void initState() {
//     super.initState();
//     _loadInitialData(); // Load initial data from storage
//     _setupStorageListeners(); // Set up listeners for storage changes
//     _fetchWalletBalance(); // Fetch wallet balance from API
//     selectedGameType = gameTypes[0]; // Initialize dropdown to "Open"
//   }
//
//   Future<void> _loadInitialData() async {
//     accessToken = storage.read('accessToken') ?? '';
//     registerId = storage.read('registerId') ?? '';
//     accountStatus = storage.read('accountStatus') ?? false;
//     preferredLanguage = storage.read('selectedLanguage') ?? 'en';
//
//     // Initial read of walletBalance from storage (will be overwritten by API call)
//     final dynamic storedWalletBalance = storage.read('walletBalance');
//     if (storedWalletBalance is String) {
//       walletBalance = int.tryParse(storedWalletBalance) ?? 0;
//     } else if (storedWalletBalance is int) {
//       walletBalance = storedWalletBalance;
//     } else {
//       walletBalance = 0;
//     }
//     // No setState here, as _fetchWalletBalance will handle the update
//   }
//
//   void _setupStorageListeners() {
//     storage.listenKey('accessToken', (value) {
//       setState(() {
//         accessToken = value ?? '';
//       });
//     });
//
//     storage.listenKey('registerId', (value) {
//       setState(() {
//         registerId = value ?? '';
//       });
//     });
//
//     storage.listenKey('accountStatus', (value) {
//       setState(() {
//         accountStatus = value ?? false;
//       });
//     });
//
//     storage.listenKey('selectedLanguage', (value) {
//       setState(() {
//         preferredLanguage = value ?? 'en';
//       });
//     });
//
//     // Listener for walletBalance changes in GetStorage
//     storage.listenKey('walletBalance', (value) {
//       setState(() {
//         if (value is String) {
//           walletBalance = int.tryParse(value) ?? 0;
//         } else if (value is int) {
//           walletBalance = value;
//         } else {
//           walletBalance = 0;
//         }
//       });
//     });
//   }
//
//   @override
//   void dispose() {
//     pointsController.dispose();
//     super.dispose();
//   }
//
//   // Function to fetch account balance (copied from SinglePannaBulkBoardScreen)
//   Future<void> _fetchWalletBalance() async {
//     setState(() {
//       _isWalletLoading = true; // Set loading state for wallet
//     });
//     try {
//       int balance = await getAccount(accountStatus);
//       setState(() {
//         walletBalance = balance;
//         _isWalletLoading = false;
//         storage.write(
//           'walletBalance',
//           balance,
//         ); // Update storage with fresh balance
//       });
//     } catch (e) {
//       log("Error fetching wallet balance: $e");
//       setState(() {
//         _isWalletLoading = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to load wallet balance: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   // The getAccount function (copied from SinglePannaBulkBoardScreen)
//   Future<int> getAccount(bool currentAccountStatus) async {
//     String? token = storage.read('accessToken');
//     if (token == null || token.isEmpty) {
//       log('getAccount: Access token is missing or empty.');
//       throw Exception('Authentication required.');
//     }
//
//     // ⭐⭐⭐ IMPORTANT: VERIFY THIS ENDPOINT ⭐⭐⭐
//     // Replace 'user-account-details' with your actual API endpoint for account info.
//     // Also, ensure Constant.apiEndpoint is correct (e.g., 'https://sara777.win/api/').
//     final url = Uri.parse('${Constant.apiEndpoint}user-account-details');
//     log(
//       'Attempting to fetch account details from URL: $url',
//     ); // Log the full URL
//
//     final headers = {
//       'deviceId': _deviceId,
//       'deviceName': _deviceName,
//       'accessStatus': currentAccountStatus ? '1' : '0',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $token',
//     };
//
//     try {
//       final response = await http.get(url, headers: headers);
//       log('getAccount API Response Status: ${response.statusCode}');
//       log(
//         'getAccount API Response Body: ${response.body}',
//       ); // Log the full response body
//
//       if (response.statusCode == 200) {
//         final responseData = json.decode(response.body);
//         if (responseData['status'] == true) {
//           if (responseData['info'] != null &&
//               responseData['info']['walletBalance'] != null) {
//             dynamic balance = responseData['info']['walletBalance'];
//             if (balance is int) {
//               return balance;
//             } else if (balance is String) {
//               return int.tryParse(balance) ?? 0; // Safely parse string to int
//             } else {
//               throw Exception(
//                 'Wallet balance received in unexpected format: $balance',
//               );
//             }
//           } else {
//             throw Exception('Wallet balance not found in API response info.');
//           }
//         } else {
//           throw Exception(
//             'Failed to fetch account details: ${responseData['msg'] ?? 'API status is false'}',
//           );
//         }
//       } else {
//         throw Exception(
//           'Failed to fetch account details: HTTP ${response.statusCode}, Body: ${response.body}',
//         );
//       }
//     } catch (e) {
//       log("getAccount Exception: $e");
//       rethrow; // Re-throw the exception to be caught by _fetchWalletBalance
//     }
//   }
//
//   void onNumberPressed(String number) {
//     setState(() {
//       final amount = pointsController.text.trim();
//       if (amount.isNotEmpty) {
//         if (int.tryParse(amount) != null && int.parse(amount) > 0) {
//           bidAmounts[number] = amount;
//           _fetchWalletBalance(); // Refresh wallet balance after adding a bid
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Please enter a valid positive amount.'),
//             ),
//           );
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Please enter an amount first.')),
//         );
//       }
//     });
//   }
//
//   int _getTotalPoints() {
//     return bidAmounts.values
//         .map((e) => int.tryParse(e) ?? 0)
//         .fold(0, (a, b) => a + b);
//   }
//
//   void _showConfirmationDialog() {
//     if (bidAmounts.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please add at least one bid.')),
//       );
//       return;
//     }
//
//     final int totalPoints = _getTotalPoints();
//
//     if (walletBalance < totalPoints) {
//       // Corrected spelling here
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Insufficient wallet balance to place this bid.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }
//
//     List<Map<String, String>> bidsForDialog = [];
//     bidAmounts.forEach((digit, points) {
//       bidsForDialog.add({
//         "digit": digit,
//         "points": points,
//         "type": selectedGameType,
//         "pana":
//             digit, // Assuming 'pana' is the same as 'digit' for single digits
//       });
//     });
//
//     final String formattedDate = DateFormat(
//       'dd MMM yyyy, hh:mm a',
//     ).format(DateTime.now());
//
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return BidConfirmationDialog(
//           gameTitle: widget.gameName,
//           gameDate: formattedDate,
//           bids: bidsForDialog,
//           totalBids: bidsForDialog.length,
//           totalBidsAmount: totalPoints,
//           walletBalanceBeforeDeduction:
//               walletBalance, // Corrected spelling here
//           walletBalanceAfterDeduction: (walletBalance - totalPoints)
//               .toString(), // Corrected spelling here
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameType,
//         );
//       },
//     ).then((_) {
//       _fetchWalletBalance(); // Refresh wallet balance after dialog closes (assuming bid submission happens via dialog)
//     });
//   }
//
//   Widget _buildDropdown() {
//     return SizedBox(
//       height: 35,
//       width: 150,
//       child: DecoratedBox(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           border: Border.all(color: dropdownBorderColor),
//           borderRadius: BorderRadius.circular(30),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 12.0),
//           child: DropdownButtonHideUnderline(
//             child: DropdownButton<String>(
//               value: selectedGameType,
//               icon: const Icon(Icons.keyboard_arrow_down),
//               onChanged: (String? newValue) {
//                 setState(() {
//                   selectedGameType = newValue!;
//                   dropdownBorderColor = Colors.amber;
//                 });
//               },
//               items: gameTypes.map((String value) {
//                 return DropdownMenuItem<String>(
//                   value: value,
//                   child: Text(value, style: GoogleFonts.poppins(fontSize: 14)),
//                 );
//               }).toList(),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTextField() {
//     return SizedBox(
//       height: 35,
//       width: 150,
//       child: TextFormField(
//         controller: pointsController,
//         cursorColor: Colors.amber,
//         keyboardType: TextInputType.number,
//         style: GoogleFonts.poppins(fontSize: 14),
//         decoration: InputDecoration(
//           hintText: 'Enter Amount',
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 0,
//           ),
//           filled: true,
//           fillColor: Colors.white,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.black),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.black),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.amber, width: 2),
//           ),
//         ),
//         onTap: () {
//           setState(() {
//             textFieldBorderColor = Colors.amber;
//           });
//         },
//       ),
//     );
//   }
//
//   Widget _inputRow(String label, Widget field) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: GoogleFonts.poppins(
//               fontSize: 13,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           field,
//         ],
//       ),
//     );
//   }
//
//   Widget _buildNumberPad() {
//     final numbers = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
//
//     return Wrap(
//       spacing: 10,
//       runSpacing: 10,
//       alignment: WrapAlignment.center,
//       children: numbers.map((number) {
//         return GestureDetector(
//           onTap: () => onNumberPressed(number),
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               Container(
//                 width: 70,
//                 height: 70,
//                 alignment: Alignment.center,
//                 decoration: BoxDecoration(
//                   color: Colors.amber,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   number,
//                   style: GoogleFonts.poppins(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//               if (bidAmounts[number] != null)
//                 Positioned(
//                   top: 4,
//                   right: 6,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 4,
//                       vertical: 2,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.transparent,
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: Text(
//                       bidAmounts[number]!,
//                       style: GoogleFonts.poppins(
//                         fontSize: 13,
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         );
//       }).toList(),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     int totalAmount = _getTotalPoints();
//
//     return Scaffold(
//       backgroundColor: Colors.grey.shade100,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
//         ),
//         title: Text(
//           widget.title,
//           style: GoogleFonts.poppins(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//             color: Colors.black,
//           ),
//         ),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 16),
//             child: Row(
//               children: [
//                 Image.asset(
//                   'assets/images/wallet_icon.png',
//                   width: 24,
//                   height: 24,
//                 ),
//                 const SizedBox(width: 4),
//                 // Display loading indicator or balance
//                 Text(
//                   walletBalance.toString(), // Corrected spelling here
//                   style: GoogleFonts.poppins(color: Colors.black),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             child: Column(
//               children: [
//                 _inputRow("Select Game Type:", _buildDropdown()),
//                 _inputRow("Enter Points:", _buildTextField()),
//                 const SizedBox(height: 30),
//                 _buildNumberPad(),
//                 const SizedBox(height: 60),
//               ],
//             ),
//           ),
//           if (bidAmounts.isNotEmpty)
//             Positioned(
//               bottom: 0,
//               left: 0,
//               right: 0,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 12,
//                 ),
//                 color: Colors.white,
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Column(
//                       children: [
//                         Text(
//                           "Bid",
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         Text(
//                           "${bidAmounts.length}",
//                           style: GoogleFonts.poppins(),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(width: 30),
//                     Column(
//                       children: [
//                         Text(
//                           "Total",
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         Text("$totalAmount", style: GoogleFonts.poppins()),
//                       ],
//                     ),
//                     const Spacer(),
//                     ElevatedButton(
//                       onPressed: _showConfirmationDialog,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.amber,
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 20,
//                           vertical: 10,
//                         ),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(6),
//                         ),
//                       ),
//                       child: Text(
//                         "Submit",
//                         style: GoogleFonts.poppins(
//                           color: Colors.white,
//                           fontSize: 16,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
//
// // import 'package:flutter/material.dart';
// // import 'package:get_storage/get_storage.dart';
// // import 'package:google_fonts/google_fonts.dart';
// // import 'package:intl/intl.dart';
// //
// // import '../../components/BidConfirmationDialog.dart';
// //
// // class SingleDigitsBulkScreen extends StatefulWidget {
// //   final String title;
// //   final int gameId;
// //   final String gameName;
// //   final String selectedGameType;
// //   final String gameType;
// //
// //   const SingleDigitsBulkScreen({
// //     Key? key,
// //     required this.title,
// //     required this.gameId,
// //     required this.gameName,
// //     required this.selectedGameType,
// //     required this.gameType,
// //   }) : super(key: key);
// //
// //   @override
// //   State<SingleDigitsBulkScreen> createState() => _SingleDigitsBulkScreenState();
// // }
// //
// // class _SingleDigitsBulkScreenState extends State<SingleDigitsBulkScreen> {
// //   String selectedGameType = 'Open';
// //   final List<String> gameTypes = ['Open', 'Close'];
// //   final TextEditingController pointsController = TextEditingController();
// //
// //   Color dropdownBorderColor = Colors.black;
// //   Color textFieldBorderColor = Colors.black;
// //
// //   Map<String, String> bidAmounts = {};
// //   late GetStorage storage = GetStorage();
// //   late String accessToken;
// //   late String registerId;
// //   late String preferredLanguage;
// //   bool accountStatus = false;
// //   late int walletBallence;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     // Initial read
// //     accessToken = storage.read('accessToken') ?? '';
// //     registerId = storage.read('registerId') ?? '';
// //     accountStatus = storage.read('accountStatus') ?? false;
// //     preferredLanguage = storage.read('selectedLanguage') ?? 'en';
// //
// //     // FIX HERE: Safely parse the walletBallence to an int
// //     final dynamic storedwalletBallence = storage.read('walletBallence');
// //     if (storedwalletBallence is String) {
// //       walletBallence = int.tryParse(storedwalletBallence) ?? 0;
// //     } else if (storedwalletBallence is int) {
// //       walletBallence = storedwalletBallence;
// //     } else {
// //       walletBallence = 0; // Default if neither string nor int, or null
// //     }
// //
// //     // Auto-update on key change
// //     storage.listenKey('accessToken', (value) {
// //       setState(() {
// //         accessToken = value ?? '';
// //       });
// //     });
// //
// //     storage.listenKey('registerId', (value) {
// //       setState(() {
// //         registerId = value ?? '';
// //       });
// //     });
// //
// //     storage.listenKey('accountStatus', (value) {
// //       setState(() {
// //         accountStatus = value ?? false;
// //       });
// //     });
// //
// //     storage.listenKey('selectedLanguage', (value) {
// //       setState(() {
// //         preferredLanguage = value ?? 'en';
// //       });
// //     });
// //
// //     storage.listenKey('walletBallence', (value) {
// //       setState(() {
// //         // Handle potential String or int from GetStorage
// //         if (value is String) {
// //           walletBallence = int.tryParse(value) ?? 0;
// //         } else if (value is int) {
// //           walletBallence = value;
// //         } else {
// //           walletBallence = 0;
// //         }
// //       });
// //     });
// //
// //     selectedGameType = gameTypes[0];
// //   }
// //
// //   @override
// //   void dispose() {
// //     pointsController.dispose();
// //     super.dispose();
// //   }
// //
// //   void onNumberPressed(String number) {
// //     setState(() {
// //       final amount = pointsController.text.trim();
// //       if (amount.isNotEmpty) {
// //         // Ensure points are valid before adding, e.g., not zero or negative
// //         if (int.tryParse(amount) != null && int.parse(amount) > 0) {
// //           bidAmounts[number] = amount;
// //         } else {
// //           ScaffoldMessenger.of(context).showSnackBar(
// //             const SnackBar(
// //               content: Text('Please enter a valid positive amount.'),
// //             ),
// //           );
// //         }
// //       } else {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text('Please enter an amount first.')),
// //         );
// //       }
// //     });
// //   }
// //
// //   int _getTotalPoints() {
// //     return bidAmounts.values
// //         .map((e) => int.tryParse(e) ?? 0)
// //         .fold(0, (a, b) => a + b);
// //   }
// //
// //   void _showConfirmationDialog() {
// //     if (bidAmounts.isEmpty) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text('Please add at least one bid.')),
// //       );
// //       return;
// //     }
// //
// //     final int totalPoints = _getTotalPoints();
// //
// //     if (walletBallence < totalPoints) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(
// //           content: Text('Insufficient wallet balance to place this bid.'),
// //           backgroundColor: Colors.red,
// //         ),
// //       );
// //       return;
// //     }
// //
// //     List<Map<String, String>> bidsForDialog = [];
// //     bidAmounts.forEach((digit, points) {
// //       bidsForDialog.add({
// //         "digit": digit,
// //         "points": points,
// //         "type": selectedGameType,
// //         "pana": digit,
// //       });
// //     });
// //
// //     final String formattedDate = DateFormat(
// //       'dd MMM yyyy, hh:mm a',
// //     ).format(DateTime.now());
// //
// //     showDialog(
// //       context: context,
// //       builder: (BuildContext context) {
// //         return BidConfirmationDialog(
// //           gameTitle: widget.gameName,
// //           gameDate: formattedDate,
// //           bids: bidsForDialog,
// //           totalBids: bidsForDialog.length,
// //           totalBidsAmount: totalPoints,
// //           walletBallenceBeforeDeduction: walletBallence,
// //           walletBallenceAfterDeduction: (walletBallence - totalPoints).toString(),
// //           gameId: widget.gameId.toString(),
// //           gameType: widget.gameType,
// //         );
// //       },
// //     );
// //   }
// //
// //   Widget _buildDropdown() {
// //     return SizedBox(
// //       height: 35,
// //       width: 150,
// //       child: DecoratedBox(
// //         decoration: BoxDecoration(
// //           color: Colors.white,
// //           border: Border.all(color: dropdownBorderColor),
// //           borderRadius: BorderRadius.circular(30),
// //         ),
// //         child: Padding(
// //           padding: const EdgeInsets.symmetric(horizontal: 12.0),
// //           child: DropdownButtonHideUnderline(
// //             child: DropdownButton<String>(
// //               value: selectedGameType,
// //               icon: const Icon(Icons.keyboard_arrow_down),
// //               onChanged: (String? newValue) {
// //                 setState(() {
// //                   selectedGameType = newValue!;
// //                   dropdownBorderColor = Colors.amber;
// //                 });
// //               },
// //               items: gameTypes.map((String value) {
// //                 return DropdownMenuItem<String>(
// //                   value: value,
// //                   child: Text(value, style: GoogleFonts.poppins(fontSize: 14)),
// //                 );
// //               }).toList(),
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildTextField() {
// //     return SizedBox(
// //       height: 35,
// //       width: 150,
// //       child: TextFormField(
// //         controller: pointsController,
// //         cursorColor: Colors.amber,
// //         keyboardType: TextInputType.number,
// //         style: GoogleFonts.poppins(fontSize: 14),
// //         decoration: InputDecoration(
// //           hintText: 'Enter Amount',
// //           contentPadding: const EdgeInsets.symmetric(
// //             horizontal: 16,
// //             vertical: 0,
// //           ),
// //           filled: true,
// //           fillColor: Colors.white,
// //           border: OutlineInputBorder(
// //             borderRadius: BorderRadius.circular(30),
// //             borderSide: const BorderSide(color: Colors.black),
// //           ),
// //           enabledBorder: OutlineInputBorder(
// //             borderRadius: BorderRadius.circular(30),
// //             borderSide: const BorderSide(color: Colors.black),
// //           ),
// //           focusedBorder: OutlineInputBorder(
// //             borderRadius: BorderRadius.circular(30),
// //             borderSide: const BorderSide(color: Colors.amber, width: 2),
// //           ),
// //         ),
// //         onTap: () {
// //           setState(() {
// //             textFieldBorderColor = Colors.amber;
// //           });
// //         },
// //       ),
// //     );
// //   }
// //
// //   Widget _inputRow(String label, Widget field) {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(vertical: 6),
// //       child: Row(
// //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //         children: [
// //           Text(
// //             label,
// //             style: GoogleFonts.poppins(
// //               fontSize: 13,
// //               fontWeight: FontWeight.w500,
// //             ),
// //           ),
// //           field,
// //         ],
// //       ),
// //     );
// //   }
// //
// //   Widget _buildNumberPad() {
// //     final numbers = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
// //
// //     return Wrap(
// //       spacing: 10,
// //       runSpacing: 10,
// //       alignment: WrapAlignment.center,
// //       children: numbers.map((number) {
// //         return GestureDetector(
// //           onTap: () => onNumberPressed(number),
// //           child: Stack(
// //             alignment: Alignment.center,
// //             children: [
// //               Container(
// //                 width: 70,
// //                 height: 70,
// //                 alignment: Alignment.center,
// //                 decoration: BoxDecoration(
// //                   color: Colors.amber,
// //                   borderRadius: BorderRadius.circular(8),
// //                 ),
// //                 child: Text(
// //                   number,
// //                   style: GoogleFonts.poppins(
// //                     fontSize: 22,
// //                     fontWeight: FontWeight.bold,
// //                     color: Colors.white,
// //                   ),
// //                 ),
// //               ),
// //               if (bidAmounts[number] != null)
// //                 Positioned(
// //                   top: 4,
// //                   right: 6,
// //                   child: Container(
// //                     padding: const EdgeInsets.symmetric(
// //                       horizontal: 4,
// //                       vertical: 2,
// //                     ),
// //                     decoration: BoxDecoration(
// //                       color: Colors.transparent,
// //                       borderRadius: BorderRadius.circular(4),
// //                     ),
// //                     child: Text(
// //                       bidAmounts[number]!,
// //                       style: GoogleFonts.poppins(
// //                         fontSize: 13,
// //                         color: Colors.white,
// //                         fontWeight: FontWeight.bold,
// //                       ),
// //                     ),
// //                   ),
// //                 ),
// //             ],
// //           ),
// //         );
// //       }).toList(),
// //     );
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     int totalAmount = _getTotalPoints();
// //
// //     return Scaffold(
// //       backgroundColor: Colors.grey.shade100,
// //       appBar: AppBar(
// //         backgroundColor: Colors.white,
// //         elevation: 0,
// //         leading: IconButton(
// //           onPressed: () => Navigator.pop(context),
// //           icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
// //         ),
// //         title: Text(
// //           widget.title,
// //           style: GoogleFonts.poppins(
// //             fontWeight: FontWeight.bold,
// //             fontSize: 16,
// //             color: Colors.black,
// //           ),
// //         ),
// //         actions: [
// //           Padding(
// //             padding: const EdgeInsets.only(right: 16),
// //             child: Row(
// //               children: [
// //                 Image.asset(
// //                   'assets/images/wallet_icon.png',
// //                   width: 24,
// //                   height: 24,
// //                 ),
// //                 const SizedBox(width: 4),
// //                 Text(
// //                   walletBallence.toString(),
// //                   style: GoogleFonts.poppins(color: Colors.black),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //       body: Stack(
// //         children: [
// //           Padding(
// //             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //             child: Column(
// //               children: [
// //                 _inputRow("Select Game Type:", _buildDropdown()),
// //                 _inputRow("Enter Points:", _buildTextField()),
// //                 const SizedBox(height: 30),
// //                 _buildNumberPad(),
// //                 const SizedBox(height: 60),
// //               ],
// //             ),
// //           ),
// //           if (bidAmounts.isNotEmpty)
// //             Positioned(
// //               bottom: 0,
// //               left: 0,
// //               right: 0,
// //               child: Container(
// //                 padding: const EdgeInsets.symmetric(
// //                   horizontal: 16,
// //                   vertical: 12,
// //                 ),
// //                 color: Colors.white,
// //                 child: Row(
// //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                   children: [
// //                     Column(
// //                       children: [
// //                         Text(
// //                           "Bid",
// //                           style: GoogleFonts.poppins(
// //                             fontWeight: FontWeight.bold,
// //                           ),
// //                         ),
// //                         Text(
// //                           "${bidAmounts.length}",
// //                           style: GoogleFonts.poppins(),
// //                         ),
// //                       ],
// //                     ),
// //                     const SizedBox(width: 30),
// //                     Column(
// //                       children: [
// //                         Text(
// //                           "Total",
// //                           style: GoogleFonts.poppins(
// //                             fontWeight: FontWeight.bold,
// //                           ),
// //                         ),
// //                         Text("$totalAmount", style: GoogleFonts.poppins()),
// //                       ],
// //                     ),
// //                     const Spacer(),
// //                     ElevatedButton(
// //                       onPressed: _showConfirmationDialog,
// //                       style: ElevatedButton.styleFrom(
// //                         backgroundColor: Colors.amber,
// //                         padding: const EdgeInsets.symmetric(
// //                           horizontal: 20,
// //                           vertical: 10,
// //                         ),
// //                         shape: RoundedRectangleBorder(
// //                           borderRadius: BorderRadius.circular(6),
// //                         ),
// //                       ),
// //                       child: Text(
// //                         "Submit",
// //                         style: GoogleFonts.poppins(
// //                           color: Colors.white,
// //                           fontSize: 16,
// //                         ),
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ),
// //         ],
// //       ),
// //     );
// //   }
// // }
