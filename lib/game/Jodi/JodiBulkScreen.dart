import 'dart:async';
import 'dart:convert'; // For jsonEncode and json.decode

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'package:intl/intl.dart';
import 'package:new_sara/components/BidConfirmationDialog.dart';

import '../../components/AnimatedMessageBar.dart';
import '../../ulits/Constents.dart'; // Ensure this path is correct for Constant.apiEndpoint

class JodiBulkScreen extends StatefulWidget {
  final String screenTitle;
  final String gameType;
  final int gameId;
  final String gameName;

  const JodiBulkScreen({
    Key? key,
    required this.screenTitle,
    required this.gameType,
    required this.gameId,
    required this.gameName,
  }) : super(key: key);

  @override
  State<JodiBulkScreen> createState() => _JodiBulkScreenState();
}

class _JodiBulkScreenState extends State<JodiBulkScreen> {
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _singleDigitController = TextEditingController();

  List<Map<String, String>> _bids = [];

  final GetStorage storage = GetStorage();

  String mobile = '';
  String name = '';
  bool accountActiveStatus = false;
  String walletBalance = '0';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupStorageListeners();
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _singleDigitController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  void _loadUserData() {
    mobile = storage.read('mobileNoEnc') ?? '';
    name = storage.read('fullName') ?? '';
    accountActiveStatus = storage.read('accountStatus') ?? false;
    walletBalance = storage.read('walletBalance')?.toString() ?? '0';
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
        walletBalance = value?.toString() ?? '0';
      });
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    _messageDismissTimer?.cancel();

    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });

    _messageDismissTimer = Timer(const Duration(seconds: 3), () {
      _clearMessage();
    });
  }

  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  void _addBidAutomatically() {
    _clearMessage();
    final digit = _singleDigitController.text.trim();
    final points = _pointsController.text.trim();

    if (digit.length != 2 || int.tryParse(digit) == null) {
      _showMessage(
        'Jodi digit must be exactly 2 numbers (00-99).',
        isError: true,
      );
      return;
    }

    if (points.isEmpty || int.tryParse(points) == null) {
      _showMessage('Please enter valid points.', isError: true);
      return;
    }

    final int parsedPoints = int.parse(points);

    if (parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    final int currentWalletBalance = int.tryParse(walletBalance) ?? 0;
    if (parsedPoints > currentWalletBalance) {
      _showMessage(
        'Insufficient wallet balance to add this bid.',
        isError: true,
      );
      return;
    }

    bool alreadyExists = _bids.any(
      (entry) =>
          entry['digit'] == digit && entry['gameType'] == widget.gameType,
    );

    if (!alreadyExists) {
      setState(() {
        _bids.add({
          "digit": digit,
          "points": points,
          "gameType": widget.gameType,
          "type": "Jodi",
        });
        _singleDigitController.clear();
        _pointsController.clear();
        _showMessage('Jodi $digit with $points points added.', isError: false);
      });
    } else {
      _showMessage(
        'Jodi $digit already added for this game type.',
        isError: true,
      );
    }
  }

  void _removeBid(int index) {
    setState(() {
      final Map<String, String> removedBid = _bids.removeAt(index);
      _showMessage('Jodi ${removedBid['digit']} removed.', isError: false);
    });
  }

  void _showConfirmationDialog() {
    _clearMessage();

    if (_bids.isEmpty) {
      _showMessage(
        'Please add at least one bid before submitting.',
        isError: true,
      );
      return;
    }

    final int totalPoints = _getTotalPoints();
    final int currentWalletBalance = int.tryParse(walletBalance) ?? 0;

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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.screenTitle,
          gameDate: formattedDate,
          bids: _bids
              .map(
                (bid) => {
                  "digit": bid['digit']!,
                  "points": bid['points']!,
                  "type": bid['type']!,
                  "gameType": bid['gameType']!,
                },
              )
              .toList(),
          totalBids: _bids.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: currentWalletBalance,
          walletBalanceAfterDeduction: (currentWalletBalance - totalPoints)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                _bids.clear();
              });
              _showMessage("All bids submitted successfully!", isError: false);
            } else {
              _showMessage(
                "Bid submission failed. Please try again.",
                isError: true,
              );
            }
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    String url;
    if (widget.gameName.toLowerCase().contains('jackpot')) {
      url = '${Constant.apiEndpoint}place-jackpot-bid';
    } else if (widget.gameName.toLowerCase().contains('starline')) {
      url = '${Constant.apiEndpoint}place-starline-bid';
    } else {
      url = '${Constant.apiEndpoint}place-bid';
    }

    if (mobile.isEmpty ||
        name.isEmpty ||
        storage.read('accessToken') == null ||
        storage.read('registerId') == null) {
      _showMessage("Authentication error. Please log in again.", isError: true);
      return false;
    }

    final headers = {
      'deviceId': 'qwert',
      'deviceName': 'sm2233',
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${storage.read('accessToken')}',
    };

    final List<Map<String, dynamic>> bidPayload = _bids.map((bid) {
      String sessionType = bid["type"] ?? "";
      String digit = bid["digit"] ?? "";
      int bidAmount = int.tryParse(bid["points"] ?? '0') ?? 0;

      if (bid["type"] != null && bid["type"]!.contains('(')) {
        final String fullType = bid["type"]!;
        final int startIndex = fullType.indexOf('(') + 1;
        final int endIndex = fullType.indexOf(')');
        if (startIndex > 0 && endIndex > startIndex) {
          sessionType = fullType.substring(startIndex, endIndex).toUpperCase();
        }
      }

      return {
        "sessionType": sessionType,
        "digit": digit,
        "pana": digit,
        "bidAmount": bidAmount,
      };
    }).toList();

    final body = {
      "registerId": storage.read('registerId'),
      "gameId": widget.gameId,
      "bidAmount": _getTotalPoints(),
      "gameType": widget.gameType,
      "bid": bidPayload,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      final Map<String, dynamic> responseBody = json.decode(response.body);

      if (response.statusCode == 200 && responseBody['status'] == true) {
        int currentWallet = int.tryParse(walletBalance) ?? 0;
        int deductedAmount = _getTotalPoints();
        int newWalletBalance = currentWallet - deductedAmount;
        storage.write('walletBalance', newWalletBalance.toString());
        setState(() {
          walletBalance = newWalletBalance.toString();
        });
        return true;
      } else {
        String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
        _showMessage('Bid submission failed: $errorMessage', isError: true);
        return false;
      }
    } catch (e) {
      _showMessage('Network error during bid submission: $e', isError: true);
      return false;
    }
  }

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          style: const TextStyle(
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
              walletBalance,
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
                          'Enter Points:',
                          style: GoogleFonts.poppins(fontSize: 16),
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
                            ],
                            onTap: _clearMessage,
                            decoration: InputDecoration(
                              hintText: 'Enter Amount',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Colors.black,
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
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Enter Jodi Digit:',
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                        SizedBox(
                          width: 150,
                          height: 40,
                          child: TextField(
                            cursorColor: Colors.amber,
                            controller: _singleDigitController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(2),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onTap: _clearMessage,
                            onChanged: (value) {
                              if (value.length == 2 &&
                                  _pointsController.text.isNotEmpty) {
                                _addBidAutomatically();
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Bid Digits',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Colors.black,
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
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
              const Divider(thickness: 1),
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
                          'Amount',
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
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              if (_bids.isNotEmpty) const Divider(thickness: 1),
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
                                      bid['digit'] ?? '',
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      bid['points'] ?? '',
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      bid['type'] ?? bid['gameType'] ?? '',
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
              if (_bids.isNotEmpty) _buildBottomBar(),
            ],
          ),
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
            onPressed: _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
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

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // For TextInputFormatter
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
//
// import '../../components/BidConfirmationDialog.dart'; // For GoogleFonts
//
// class JodiBulkScreen extends StatefulWidget {
//   final String screenTitle;
//
//   const JodiBulkScreen({
//     Key? key,
//     required this.screenTitle,
//     required String gameType,
//     required int gameId,
//   }) : super(key: key);
//
//   @override
//   State<JodiBulkScreen> createState() => _JodiBulkScreenState();
// }
//
// class _JodiBulkScreenState extends State<JodiBulkScreen> {
//   final TextEditingController _pointsController = TextEditingController();
//   final TextEditingController _singleDigitController = TextEditingController();
//
//   List<Map<String, String>> _bids = []; // List to store the added bids
//
//   late GetStorage storage =
//       GetStorage(); // Use the late keyword for direct initialization
//
//   late String mobile = '';
//   late String name = '';
//   late bool accountActiveStatus;
//   late String walletBallence;
//
//   @override
//   void initState() {
//     super.initState();
//
//     final storage = GetStorage();
//
//     // Initial reads
//     mobile = storage.read('mobileNoEnc') ?? '';
//     name = storage.read('fullName') ?? '';
//     accountActiveStatus = storage.read('accountStatus') ?? false;
//     walletBallence = storage.read('walletBalance') ?? '';
//
//     // Listen to updates
//     storage.listenKey('mobileNoEnc', (value) {
//       setState(() {
//         mobile = value ?? '';
//       });
//     });
//
//     storage.listenKey('fullName', (value) {
//       setState(() {
//         name = value ?? '';
//       });
//     });
//
//     storage.listenKey('accountStatus', (value) {
//       setState(() {
//         accountActiveStatus = value ?? false;
//       });
//     });
//
//     storage.listenKey('walletBalance', (value) {
//       setState(() {
//         walletBallence = value ?? '0';
//       });
//     });
//   }
//
//   @override
//   void dispose() {
//     _pointsController.dispose();
//     _singleDigitController.dispose();
//     super.dispose();
//   }
//
//   // Function to add a new bid automatically
//   void _addBidAutomatically() {
//     final digit = _singleDigitController.text.trim();
//     final points = _pointsController.text.trim();
//
//     // Only add if both fields have valid input
//     if (digit.length == 1 &&
//         int.tryParse(digit) != null &&
//         points.isNotEmpty &&
//         int.tryParse(points) != null) {
//       setState(() {
//         // Check if this digit already exists in the current game type (assuming 'Open' for now)
//         // This prevents adding the same single digit multiple times.
//         bool alreadyExists = _bids.any(
//           (entry) => entry['digit'] == digit && entry['gameType'] == 'Open',
//         );
//
//         if (!alreadyExists) {
//           _bids.add({
//             "digit": digit,
//             "points": points,
//             "gameType":
//                 "Open", // Assuming 'Open' as a default game type for single digit bids
//           });
//           _singleDigitController.clear(); // Clear digit after successful add
//           _pointsController.clear(); // Clear points after successful add
//         } else {
//           // Optionally provide feedback if the digit already exists
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Digit $digit already added for this game type.'),
//             ),
//           );
//         }
//       });
//     }
//   }
//
//   // Function to remove a bid from the list
//   void _removeBid(int index) {
//     setState(() {
//       _bids.removeAt(index);
//     });
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
//     if (walletBallence as int < totalPoints) {
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
//           walletBalanceBeforeDeduction: walletBallence as int,
//           walletBalanceAfterDeduction: ((walletBallence as int) - totalPoints)
//               .toString(),
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameType,
//         );
//       },
//     ).then((_) {});
//   }
//
//   // Calculate total points
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
//           style: const TextStyle(
//             color: Colors.black,
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         actions: [
//           const Icon(
//             Icons.account_balance_wallet_outlined,
//             color: Colors.black,
//           ), // Replaced Image.asset
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
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text('Enter Points:', style: TextStyle(fontSize: 16)),
//                     SizedBox(
//                       width: 150,
//                       height: 40,
//                       child: TextField(
//                         cursorColor: Colors.amber,
//                         controller: _pointsController,
//                         keyboardType: TextInputType.number,
//                         inputFormatters: [
//                           FilteringTextInputFormatter.digitsOnly,
//                         ], // Only digits
//                         onChanged: (value) =>
//                             _addBidAutomatically(), // Trigger add on change
//                         decoration: const InputDecoration(
//                           hintText: 'Enter Amount',
//                           contentPadding: EdgeInsets.symmetric(horizontal: 12),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(20)),
//                             borderSide: BorderSide(color: Colors.black),
//                           ),
//                           enabledBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(20)),
//                             borderSide: BorderSide(color: Colors.black),
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(20)),
//                             borderSide: BorderSide(
//                               color: Colors.amber,
//                               width: 2,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text(
//                       'Enter Single Digit:',
//                       style: TextStyle(fontSize: 16),
//                     ),
//                     SizedBox(
//                       width: 150,
//                       height: 40,
//                       child: TextField(
//                         cursorColor: Colors.amber,
//                         controller: _singleDigitController,
//                         keyboardType: TextInputType.number,
//                         inputFormatters: [
//                           LengthLimitingTextInputFormatter(
//                             1,
//                           ), // Limit to 1 digit
//                           FilteringTextInputFormatter.digitsOnly, // Only digits
//                         ],
//                         onChanged: (value) =>
//                             _addBidAutomatically(), // Trigger add on change
//                         decoration: const InputDecoration(
//                           hintText: 'Bid Digits',
//                           contentPadding: EdgeInsets.symmetric(horizontal: 12),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(20)),
//                             borderSide: BorderSide(color: Colors.black),
//                           ),
//                           enabledBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(20)),
//                             borderSide: BorderSide(color: Colors.black),
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(20)),
//                             borderSide: BorderSide(
//                               color: Colors.amber,
//                               width: 2,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 15),
//               ],
//             ),
//           ),
//           const Divider(thickness: 1), // Divider after input section
//           // Table Headers (conditionally rendered)
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
//                       'Digit',
//                       style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                   Expanded(
//                     child: Text(
//                       'Amount',
//                       style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                   Expanded(
//                     child: Text(
//                       'Game Type',
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
//                                   bid['digit']!,
//                                   style: GoogleFonts.poppins(),
//                                 ),
//                               ),
//                               Expanded(
//                                 child: Text(
//                                   bid['points']!,
//                                   style: GoogleFonts.poppins(),
//                                 ),
//                               ),
//                               Expanded(
//                                 child: Text(
//                                   bid['gameType']!,
//                                   style: GoogleFonts.poppins(
//                                     color: Colors.green[700],
//                                   ),
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
