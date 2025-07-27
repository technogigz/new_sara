import 'dart:async'; // Import for Timer

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:new_sara/components/BidFailureDialog.dart';

import '../../BidService.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidSuccessDialog.dart';

class GroupJodiScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType; // e.g., 'groupjodi'

  const GroupJodiScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
  }) : super(key: key);

  @override
  State<GroupJodiScreen> createState() => _GroupJodiScreenState();
}

class _GroupJodiScreenState extends State<GroupJodiScreen> {
  final TextEditingController jodiController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  List<Map<String, String>> bids = [];

  final GetStorage _storage = GetStorage(); // Use private instance
  late String _mobile;
  late String _name;
  late bool _accountActiveStatus;
  late int _walletBalance; // Changed to int for consistency

  // Device info (typically from a utility or initial fetch)
  String _deviceId = "flutter_device"; // Placeholder, get actual value
  String _deviceName = "Flutter_App"; // Placeholder, get actual value

  // Access token and register ID
  late String _accessToken;
  late String _registerId;

  // --- Message Bar State ---
  String _messageBarMessage = '';
  bool _isMessageBarError = false;
  bool _isMessageBarVisible = false;
  // --- End Message Bar State ---

  @override
  void initState() {
    super.initState();
    _initializeStorageValues();
    _listenToStorageChanges();
  }

  void _initializeStorageValues() {
    _mobile = _storage.read('mobileNoEnc') ?? '';
    _name = _storage.read('fullName') ?? '';
    _accountActiveStatus = _storage.read('accountStatus') ?? false;
    _accessToken =
        _storage.read('accessToken') ?? ''; // Initialize access token
    _registerId = _storage.read('registerId') ?? ''; // Initialize register ID

    final storedWallet = _storage.read('walletBalance');
    if (storedWallet is int) {
      _walletBalance = storedWallet;
    } else if (storedWallet is String) {
      _walletBalance = int.tryParse(storedWallet) ?? 0;
    } else {
      _walletBalance = 0;
    }
  }

  void _listenToStorageChanges() {
    _storage.listenKey('mobileNoEnc', (value) {
      if (mounted) setState(() => _mobile = value ?? '');
    });

    _storage.listenKey('fullName', (value) {
      if (mounted) setState(() => _name = value ?? '');
    });

    _storage.listenKey('accountStatus', (value) {
      if (mounted) setState(() => _accountActiveStatus = value ?? false);
    });

    _storage.listenKey('walletBalance', (value) {
      if (mounted) {
        setState(() {
          if (value is int) {
            _walletBalance = value;
          } else if (value is String) {
            _walletBalance = int.tryParse(value) ?? 0;
          } else {
            _walletBalance = 0;
          }
        });
      }
    });

    _storage.listenKey('accessToken', (value) {
      if (mounted) setState(() => _accessToken = value ?? '');
    });
    _storage.listenKey('registerId', (value) {
      if (mounted) setState(() => _registerId = value ?? '');
    });
  }

  @override
  void dispose() {
    jodiController.dispose();
    pointsController.dispose();
    super.dispose();
  }

  String _getCutDigit(String digit) {
    int d = int.parse(digit);
    return ((d + 5) % 10).toString();
  }

  void addBid() {
    String jodiInput = jodiController.text.trim();
    String points = pointsController.text.trim();

    if (jodiInput.length != 2 || int.tryParse(jodiInput) == null) {
      _showMessageBar('Please enter a valid 2-digit Jodi.', isError: true);
      return;
    }

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints <= 0) {
      _showMessageBar('Please enter a valid amount for Points.', isError: true);
      return;
    }

    String digit1 = jodiInput[0];
    String digit2 = jodiInput[1];

    String cutDigit1 = _getCutDigit(digit1);
    String cutDigit2 = _getCutDigit(digit2);

    Set<String> uniqueGeneratedJodis = {};
    uniqueGeneratedJodis.add('$digit1$digit2');
    uniqueGeneratedJodis.add('$digit1$cutDigit2');
    uniqueGeneratedJodis.add('$cutDigit1$digit2');
    uniqueGeneratedJodis.add('$cutDigit1$cutDigit2');
    uniqueGeneratedJodis.add('$digit2$digit1');
    uniqueGeneratedJodis.add('$digit2$cutDigit1');
    uniqueGeneratedJodis.add('$cutDigit2$digit1');
    uniqueGeneratedJodis.add('$cutDigit2$cutDigit1');

    setState(() {
      for (String jodi in uniqueGeneratedJodis) {
        if (!bids.any(
          (bid) => bid['jodi'] == jodi && bid['points'] == points,
        )) {
          bids.add({'jodi': jodi, 'points': points});
        }
      }
      jodiController.clear();
      pointsController.clear();
    });
    _showMessageBar('Jodis added successfully!');
  }

  void removeBid(int index) {
    setState(() {
      bids.removeAt(index);
    });
    _showMessageBar('Bid removed.');
  }

  int get totalPoints =>
      bids.fold(0, (sum, item) => sum + (int.tryParse(item['points']!) ?? 0));

  // --- Helper to show AnimatedMessageBar ---
  void _showMessageBar(String message, {bool isError = false}) {
    if (mounted) {
      setState(() {
        _messageBarMessage = message;
        _isMessageBarError = isError;
        _isMessageBarVisible = true; // Trigger visibility
      });
      // The AnimatedMessageBar itself handles its timer and dismissal
    }
  }

  // Future<void> _placeFinalBids() async {
  //   String url;
  //   if (widget.gameType.toLowerCase().contains('jackpot')) {
  //     url = '${Constant.apiEndpoint}place-jackpot-bid';
  //   } else if (widget.gameType.toLowerCase().contains('starline')) {
  //     url = '${Constant.apiEndpoint}place-starline-bid';
  //   } else {
  //     url = '${Constant.apiEndpoint}place-bid';
  //   }
  //
  //   if (_accessToken.isEmpty || _registerId.isEmpty) {
  //     _showMessageBar(
  //       'Authentication error. Please log in again.',
  //       isError: true,
  //     );
  //     return;
  //   }
  //
  //   final headers = {
  //     'deviceId': _deviceId,
  //     'deviceName': _deviceName,
  //     'accessStatus': _accountActiveStatus ? '1' : '0',
  //     'Content-Type': 'application/json',
  //     'Authorization': 'Bearer $_accessToken',
  //   };
  //
  //   final List<Map<String, dynamic>> bidPayload = bids.map((entry) {
  //     return {
  //       "sessionType": "OPEN",
  //       "digit": entry['jodi']!,
  //       "bidAmount": int.tryParse(entry['points'] ?? '0') ?? 0,
  //     };
  //   }).toList();
  //
  //   final body = jsonEncode({
  //     "registerId": _registerId,
  //     "gameId": widget.gameId,
  //     "bidAmount": totalPoints,
  //     "gameType": widget.gameType,
  //     "bid": bidPayload,
  //   });
  //
  //   String curlCommand = 'curl -X POST \\';
  //   curlCommand += '\n  ${Uri.parse(url).toString()} \\';
  //   headers.forEach((key, value) {
  //     curlCommand += '\n  -H "$key: $value" \\';
  //   });
  //   curlCommand += '\n  -d \'${jsonEncode(json.decode(body))}\'';
  //
  //   log('CURL Command for Final Bid Submission:\n$curlCommand');
  //   log('Request Headers for Final Bid Submission: $headers');
  //   log('Request Body for Final Bid Submission: $body');
  //
  //   try {
  //     final response = await http.post(
  //       Uri.parse(url),
  //       headers: headers,
  //       body: body,
  //     );
  //
  //     final Map<String, dynamic> responseBody = json.decode(response.body);
  //
  //     log('API Response for Final Bid Submission: $responseBody');
  //
  //     if (response.statusCode == 200 && responseBody['status'] == true) {
  //       log('Bid submission successful. ${responseBody['msg']}');
  //       int deductedAmount = totalPoints;
  //       int newWalletBalance = _walletBalance - deductedAmount;
  //       _storage.write('walletBalance', newWalletBalance.toString());
  //
  //       if (mounted) {
  //         setState(() {
  //           _walletBalance = newWalletBalance;
  //           bids.clear();
  //         });
  //
  //         // ✅ Show success dialog
  //         showDialog(
  //           context: context,
  //           builder: (context) => AlertDialog(
  //             title: const Text("Success"),
  //             content: Text(responseBody['msg'] ?? 'Bid placed successfully!'),
  //             actions: [
  //               TextButton(
  //                 child: const Text("OK"),
  //                 onPressed: () => Navigator.of(context).pop(),
  //               ),
  //             ],
  //           ),
  //         );
  //       }
  //     } else {
  //       String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
  //       log('Bid submission failed: $errorMessage');
  //       if (mounted) {
  //         // ❌ Show failure dialog
  //         showDialog(
  //           context: context,
  //           builder: (context) => AlertDialog(
  //             title: const Text("Bid Failed"),
  //             content: Text(errorMessage),
  //             actions: [
  //               TextButton(
  //                 child: const Text("OK"),
  //                 onPressed: () => Navigator.of(context).pop(),
  //               ),
  //             ],
  //           ),
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     log('Network error during bid submission: $e');
  //     if (mounted) {
  //       _showMessageBar(
  //         'Network error during bid submission: ${e.toString()}',
  //         isError: true,
  //       );
  //     }
  //   }
  // }

  // Future<void> _placeFinalBids() async {
  //   final bidService = BidService(_storage);
  //
  //   if (_accessToken.isEmpty || _registerId.isEmpty) {
  //     _showMessageBar(
  //       'Authentication error. Please log in again.',
  //       isError: true,
  //     );
  //     return;
  //   }
  //
  //   final Map<String, String> bidAmounts = {
  //     for (var entry in bids) entry['jodi']!: entry['points'] ?? '0',
  //   };
  //
  //   final result = await bidService.placeFinalBids(
  //     gameName: widget.title,
  //     accessToken: _accessToken,
  //     registerId: _registerId,
  //     deviceId: _deviceId,
  //     deviceName: _deviceName,
  //     accountStatus: _accountActiveStatus,
  //     bidAmounts: bidAmounts,
  //     selectedGameType: "OPEN", // or dynamically set
  //     gameId: widget.gameId,
  //     gameType: widget.gameType,
  //     totalBidAmount: totalPoints,
  //   );
  //
  //   if (!mounted) return;
  //
  //   if (result['status'] == true) {
  //     final newBalance = _walletBalance - totalPoints;
  //     await bidService.updateWalletBalance(newBalance);
  //
  //     if (mounted) {
  //       setState(() {
  //         _walletBalance = newBalance;
  //         bids.clear();
  //       });
  //
  //       // ✅ Show Success Dialog
  //       await showDialog(context: context, builder: (_) => BidSuccessDialog());
  //     }
  //   } else {
  //     final errorMsg = result['msg'] ?? 'Failed to place bid.';
  //
  //     // ❌ Show Failure Dialog
  //     if (mounted) {
  //       await showDialog(
  //         context: context,
  //         builder: (_) => BidFailureDialog(errorMessage: errorMsg),
  //       );
  //     }
  //   }
  // }

  Future<bool> _placeFinalBids() async {
    final _bidService = BidService(_storage);
    final Map<String, String> bidAmounts = {
      for (var entry in bids) entry['jodi']!: entry['points'] ?? '0',
    };

    if (_accessToken.isEmpty || _registerId.isEmpty) {
      if (!mounted) return false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Authentication error. Please log in again.',
        ),
      );
      return false;
    }

    try {
      final result = await _bidService.placeFinalBids(
        gameName: widget.title,
        accessToken: _accessToken,
        registerId: _registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: _accountActiveStatus,
        bidAmounts: bidAmounts,
        selectedGameType: "OPEN",
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: totalPoints,
      );

      if (!mounted) return false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => result['status']
            ? const BidSuccessDialog()
            : BidFailureDialog(
                errorMessage: result['msg'] ?? 'Something went wrong',
              ),
      );

      if (result['status'] == true) {
        final newWalletBalance = _walletBalance - totalPoints;
        setState(() {
          _walletBalance = newWalletBalance;
        });
        await _bidService.updateWalletBalance(newWalletBalance);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      if (!mounted) return false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'An unexpected error occurred.',
        ),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Colors.black),
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        actions: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.black,
              ), // Wallet icon
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  '$_walletBalance', // Display walletBalance dynamically
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ],
      ),
      body: Stack(
        // Use Stack to overlay the message bar
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildInputRow("Enter Jodi", jodiController, isJodi: true),
                    const SizedBox(height: 10),
                    _buildInputRow("Enter Points", pointsController),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: addBid,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5B544),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          "ADD",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (bids.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Jodi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Points',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SizedBox(width: 48),
                    ],
                  ),
                ),
              Expanded(
                child: bids.isEmpty
                    ? Center(
                        child: Text(
                          'No entries yet. Add some data!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: bids.length,
                        itemBuilder: (context, index) {
                          final bid = bids[index];
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
                                    flex: 2,
                                    child: Text(
                                      bid['jodi']!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      bid['points']!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => removeBid(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (bids.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                            "Bids",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            "${bids.length}",
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
                            "Points",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            "$totalPoints",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _showConfirmationDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5B544),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          "SUBMIT",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // --- AnimatedMessageBar at the top ---
          if (_isMessageBarVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedMessageBar(
                message: _messageBarMessage,
                isError: _isMessageBarError,
                onDismissed: () {
                  // Optional: if you need to do something after the bar dismisses
                  if (mounted) {
                    setState(() {
                      _isMessageBarVisible = false; // Hide after dismissal
                    });
                  }
                },
              ),
            ),
          // --- End AnimatedMessageBar ---
        ],
      ),
    );
  }

  void _showConfirmationDialog() {
    if (bids.isEmpty) {
      _showMessageBar('Please add bids before submitting.', isError: true);
      return;
    }

    int currentTotalPoints = totalPoints;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BidConfirmationDialog(
          gameTitle: widget.title,
          bids: bids,
          totalBids: bids.length,
          totalBidsAmount: currentTotalPoints,
          walletBalanceBeforeDeduction: _walletBalance,
          walletBalanceAfterDeduction: (_walletBalance - currentTotalPoints)
              .toString(),
          gameDate: DateTime.now().toLocal().toString().split(' ')[0],
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            Navigator.pop(context);
            await _placeFinalBids();
          },
        );
      },
    );
  }

  Widget _buildInputRow(
    String label,
    TextEditingController controller, {
    bool isJodi = false,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                if (isJodi) LengthLimitingTextInputFormatter(2),
              ],
              decoration: InputDecoration(
                hintText: isJodi ? 'Enter 2-digit Jodi' : 'Enter Points',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5B544),
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
          ),
        ),
      ],
    );
  }
}

// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:http/http.dart' as http;
//
// import '../../components/BidConfirmationDialog.dart';
// import '../../components/BidFailureDialog.dart'; // Adjust path as needed
// // Import your custom dialogs here
// import '../../components/BidSuccessDialog.dart'; // Adjust path as needed
// import '../../ulits/Constents.dart'; // Make sure this path is correct
//
// class GroupJodiScreen extends StatefulWidget {
//   final String title;
//   final int gameId;
//   final String gameType; // e.g., 'groupjodi'
//
//   const GroupJodiScreen({
//     Key? key,
//     required this.title,
//     required this.gameId,
//     required this.gameType,
//   }) : super(key: key);
//
//   @override
//   State<GroupJodiScreen> createState() => _GroupJodiScreenState();
// }
//
// class _GroupJodiScreenState extends State<GroupJodiScreen> {
//   final TextEditingController jodiController = TextEditingController();
//   final TextEditingController pointsController = TextEditingController();
//
//   List<Map<String, String>> bids = [];
//
//   final GetStorage _storage = GetStorage(); // Use private instance
//   late String _mobile;
//   late String _name;
//   late bool _accountActiveStatus;
//   late int _walletBalance; // Changed to int for consistency
//
//   // Device info (typically from a utility or initial fetch)
//   String _deviceId = "flutter_device"; // Placeholder, get actual value
//   String _deviceName = "Flutter_App"; // Placeholder, get actual value
//
//   // Access token and register ID
//   late String _accessToken;
//   late String _registerId;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeStorageValues();
//     _listenToStorageChanges();
//   }
//
//   void _initializeStorageValues() {
//     _mobile = _storage.read('mobileNoEnc') ?? '';
//     _name = _storage.read('fullName') ?? '';
//     _accountActiveStatus = _storage.read('accountStatus') ?? false;
//     _accessToken =
//         _storage.read('accessToken') ?? ''; // Initialize access token
//     _registerId = _storage.read('registerId') ?? ''; // Initialize register ID
//
//     // Safely parse walletBalance to int
//     final storedWallet = _storage.read('walletBalance');
//     if (storedWallet is int) {
//       _walletBalance = storedWallet;
//     } else if (storedWallet is String) {
//       _walletBalance = int.tryParse(storedWallet) ?? 0;
//     } else {
//       _walletBalance = 0;
//     }
//   }
//
//   void _listenToStorageChanges() {
//     _storage.listenKey('mobileNoEnc', (value) {
//       if (mounted) setState(() => _mobile = value ?? '');
//     });
//
//     _storage.listenKey('fullName', (value) {
//       if (mounted) setState(() => _name = value ?? '');
//     });
//
//     _storage.listenKey('accountStatus', (value) {
//       if (mounted) setState(() => _accountActiveStatus = value ?? false);
//     });
//
//     _storage.listenKey('walletBalance', (value) {
//       if (mounted) {
//         setState(() {
//           if (value is int) {
//             _walletBalance = value;
//           } else if (value is String) {
//             _walletBalance = int.tryParse(value) ?? 0;
//           } else {
//             _walletBalance = 0;
//           }
//         });
//       }
//     });
//
//     // Listen to token/ID changes if they can change during app lifecycle
//     _storage.listenKey('accessToken', (value) {
//       if (mounted) setState(() => _accessToken = value ?? '');
//     });
//     _storage.listenKey('registerId', (value) {
//       if (mounted) setState(() => _registerId = value ?? '');
//     });
//   }
//
//   @override
//   void dispose() {
//     jodiController.dispose();
//     pointsController.dispose();
//     super.dispose();
//   }
//
//   String _getCutDigit(String digit) {
//     int d = int.parse(digit);
//     return ((d + 5) % 10).toString();
//   }
//
//   void addBid() {
//     String jodiInput = jodiController.text.trim();
//     String points = pointsController.text.trim();
//
//     if (jodiInput.length != 2 || int.tryParse(jodiInput) == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please enter a valid 2-digit Jodi.')),
//       );
//       return;
//     }
//
//     int? parsedPoints = int.tryParse(points);
//     if (parsedPoints == null || parsedPoints <= 0) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please enter a valid amount for Points.'),
//         ),
//       );
//       return;
//     }
//
//     String digit1 = jodiInput[0];
//     String digit2 = jodiInput[1];
//
//     String cutDigit1 = _getCutDigit(digit1);
//     String cutDigit2 = _getCutDigit(digit2);
//
//     Set<String> uniqueGeneratedJodis = {};
//     uniqueGeneratedJodis.add('$digit1$digit2');
//     uniqueGeneratedJodis.add('$digit1$cutDigit2');
//     uniqueGeneratedJodis.add('$cutDigit1$digit2');
//     uniqueGeneratedJodis.add('$cutDigit1$cutDigit2');
//     uniqueGeneratedJodis.add('$digit2$digit1');
//     uniqueGeneratedJodis.add('$digit2$cutDigit1');
//     uniqueGeneratedJodis.add('$cutDigit2$digit1');
//     uniqueGeneratedJodis.add('$cutDigit2$cutDigit1');
//
//     setState(() {
//       for (String jodi in uniqueGeneratedJodis) {
//         // Only add if this specific jodi with this exact point value is not already in the list
//         if (!bids.any(
//           (bid) => bid['jodi'] == jodi && bid['points'] == points,
//         )) {
//           bids.add({'jodi': jodi, 'points': points});
//         }
//       }
//       jodiController.clear();
//       pointsController.clear();
//     });
//   }
//
//   void removeBid(int index) {
//     setState(() {
//       bids.removeAt(index);
//     });
//   }
//
//   int get totalPoints =>
//       bids.fold(0, (sum, item) => sum + (int.tryParse(item['points']!) ?? 0));
//
//   // --- Start of Integrated _placeFinalBids Logic ---
//   Future<void> _placeFinalBids() async {
//     String url;
//     if (widget.gameType.toLowerCase().contains('jackpot')) {
//       url = '${Constant.apiEndpoint}place-jackpot-bid';
//     } else if (widget.gameType.toLowerCase().contains('starline')) {
//       url = '${Constant.apiEndpoint}place-starline-bid';
//     } else {
//       url = '${Constant.apiEndpoint}place-bid'; // General bid placement
//     }
//
//     if (_accessToken.isEmpty || _registerId.isEmpty) {
//       if (mounted) {
//         showDialog(
//           context: context,
//           builder: (BuildContext context) {
//             return const BidFailureDialog(
//               errorMessage: 'Authentication error. Please log in again.',
//             );
//           },
//         );
//       }
//       return; // Return void as this is not a Future<bool>
//     }
//
//     final headers = {
//       'deviceId': _deviceId,
//       'deviceName': _deviceName,
//       'accessStatus': _accountActiveStatus
//           ? '1'
//           : '0', // Convert bool to '1' or '0'
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $_accessToken',
//     };
//
//     final List<Map<String, dynamic>> bidPayload = bids.map((entry) {
//       return {
//         // Group Jodi typically only has 'OPEN' session type, confirm with API docs
//         // If your API expects 'OPEN' or 'CLOSE' for GroupJodi, adjust logic if needed
//         "sessionType": "OPEN", // GroupJodi usually implies OPEN session
//         "digit": entry['jodi']!, // For Jodi, 'digit' is the 2-digit jodi
//         "bidAmount": int.tryParse(entry['points'] ?? '0') ?? 0,
//       };
//     }).toList();
//
//     final body = jsonEncode({
//       "registerId": _registerId,
//       "gameId": widget.gameId,
//       "bidAmount": totalPoints, // Use the getter here
//       "gameType": widget.gameType, // e.g., "groupjodi"
//       "bid": bidPayload,
//     });
//     // Log the cURL and headers here
//     String curlCommand = 'curl -X POST \\';
//     curlCommand += '\n  ${Uri.parse(url)} \\';
//     headers.forEach((key, value) {
//       curlCommand += '\n  -H "$key: $value" \\';
//     });
//     curlCommand += '\n  -d \'$body\'';
//
//     log('CURL Command for Final Bid Submission:\n$curlCommand');
//
//     log('Request Headers for Final Bid Submission: $headers');
//     log('Request Body for Final Bid Submission: $body');
//
//     log('Placing final bids to URL: $url');
//     log('Request Headers: $headers');
//     log('Request Body: $body');
//
//     try {
//       final response = await http.post(
//         Uri.parse(url),
//         headers: headers,
//         body: body,
//       );
//
//       final Map<String, dynamic> responseBody = json.decode(response.body);
//
//       log('API Response for Final Bid Submission: $responseBody');
//
//       if (response.statusCode == 200 && responseBody['status'] == true) {
//         log('Bid submission successful. ${responseBody['msg']}');
//         int deductedAmount = totalPoints;
//         int newWalletBalance = _walletBalance - deductedAmount;
//         _storage.write(
//           'walletBalance',
//           newWalletBalance.toString(),
//         ); // Update storage
//
//         if (mounted) {
//           setState(() {
//             _walletBalance = newWalletBalance; // Update local state
//             bids.clear(); // Clear bids on successful submission
//           });
//           showDialog(
//             context: context,
//             builder: (BuildContext context) {
//               return const BidSuccessDialog();
//             },
//           );
//         }
//       } else {
//         String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
//         log('Bid submission failed: $errorMessage');
//         if (mounted) {
//           showDialog(
//             context: context,
//             builder: (BuildContext context) {
//               return BidFailureDialog(errorMessage: errorMessage);
//             },
//           );
//         }
//       }
//     } catch (e) {
//       log('Network error during bid submission: $e');
//       if (mounted) {
//         showDialog(
//           context: context,
//           builder: (BuildContext context) {
//             return BidFailureDialog(
//               errorMessage:
//                   'Network error during bid submission: ${e.toString()}',
//             );
//           },
//         );
//       }
//     }
//   }
//   // --- End of Integrated _placeFinalBids Logic ---
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFEEEEEE),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0.5,
//         leading: const BackButton(color: Colors.black),
//         title: Text(
//           widget.title.toUpperCase(),
//           style: const TextStyle(color: Colors.black, fontSize: 16),
//         ),
//         actions: [
//           Row(
//             children: [
//               const Icon(
//                 Icons.account_balance_wallet_outlined,
//                 color: Colors.black,
//               ), // Wallet icon
//               const SizedBox(width: 4),
//               Padding(
//                 padding: const EdgeInsets.only(top: 2.0),
//                 child: Text(
//                   '$_walletBalance', // Display walletBalance dynamically
//                   style: const TextStyle(color: Colors.black, fontSize: 16),
//                 ),
//               ),
//               const SizedBox(width: 10),
//             ],
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               children: [
//                 _buildInputRow("Enter Jodi", jodiController, isJodi: true),
//                 const SizedBox(height: 10),
//                 _buildInputRow("Enter Points", pointsController),
//                 const SizedBox(height: 10),
//                 SizedBox(
//                   width: double.infinity,
//                   height: 45,
//                   child: ElevatedButton(
//                     onPressed: addBid,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color(0xFFF5B544),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       elevation: 3,
//                     ),
//                     child: const Text(
//                       "ADD",
//                       style: TextStyle(fontSize: 16, color: Colors.white),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const Divider(height: 1),
//           if (bids.isNotEmpty)
//             const Padding(
//               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//               child: Row(
//                 children: [
//                   Expanded(
//                     flex: 2,
//                     child: Text(
//                       'Jodi',
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
//                   SizedBox(width: 48),
//                 ],
//               ),
//             ),
//           Expanded(
//             child: bids.isEmpty
//                 ? Center(
//                     child: Text(
//                       'No entries yet. Add some data!',
//                       style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//                     ),
//                   )
//                 : ListView.builder(
//                     itemCount: bids.length,
//                     itemBuilder: (context, index) {
//                       final bid = bids[index];
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
//                                 flex: 2,
//                                 child: Text(
//                                   bid['jodi']!,
//                                   style: const TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ),
//                               Expanded(
//                                 flex: 3,
//                                 child: Text(
//                                   bid['points']!,
//                                   style: const TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ),
//                               IconButton(
//                                 icon: const Icon(
//                                   Icons.delete,
//                                   color: Colors.red,
//                                 ),
//                                 onPressed: () => removeBid(index),
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//           ),
//           if (bids.isNotEmpty)
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.3),
//                     spreadRadius: 2,
//                     blurRadius: 5,
//                     offset: const Offset(0, -3),
//                   ),
//                 ],
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         "Bids",
//                         style: TextStyle(fontSize: 14, color: Colors.grey[700]),
//                       ),
//                       Text(
//                         "${bids.length}",
//                         style: const TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         "Points",
//                         style: TextStyle(fontSize: 14, color: Colors.grey[700]),
//                       ),
//                       Text(
//                         "$totalPoints",
//                         style: const TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       _showConfirmationDialog();
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color(0xFFF5B544),
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 24,
//                         vertical: 12,
//                       ),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       elevation: 3,
//                     ),
//                     child: const Text(
//                       "SUBMIT",
//                       style: TextStyle(color: Colors.white, fontSize: 16),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   void _showConfirmationDialog() {
//     if (bids.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please add bids before submitting.')),
//       );
//       return;
//     }
//
//     int currentTotalPoints = totalPoints;
//
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return BidConfirmationDialog(
//           gameTitle: widget.title,
//           bids: bids,
//           totalBids: bids.length,
//           totalBidsAmount: currentTotalPoints,
//           walletBalanceBeforeDeduction: _walletBalance, // Pass as int
//           walletBalanceAfterDeduction: (_walletBalance - currentTotalPoints)
//               .toString(), // Calculate and pass
//           gameDate: DateTime.now().toLocal().toString().split(' ')[0],
//           gameId: widget.gameId.toString(), // Ensure gameId is String
//           gameType: widget.gameType,
//           onConfirm: () async {
//             Navigator.pop(context); // Dismiss the confirmation dialog first
//             await _placeFinalBids(); // Call the bid placement function
//           },
//         );
//       },
//     );
//   }
//
//   Widget _buildInputRow(
//     String label,
//     TextEditingController controller, {
//     bool isJodi = false,
//   }) {
//     return Row(
//       children: [
//         Expanded(
//           flex: 2,
//           child: Text(
//             label,
//             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//           ),
//         ),
//         const SizedBox(width: 10),
//         Expanded(
//           flex: 3,
//           child: Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: Colors.grey[300]!),
//             ),
//             child: TextField(
//               controller: controller,
//               keyboardType: TextInputType.number,
//               inputFormatters: [
//                 FilteringTextInputFormatter.digitsOnly,
//                 if (isJodi) LengthLimitingTextInputFormatter(2),
//               ],
//               decoration: InputDecoration(
//                 hintText: isJodi ? 'Enter 2-digit Jodi' : 'Enter Points',
//                 border: InputBorder.none,
//                 contentPadding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 12,
//                 ),
//                 suffixIcon: Container(
//                   margin: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFF5B544),
//                     shape: BoxShape.circle,
//                   ),
//                   child: const Icon(
//                     Icons.arrow_forward,
//                     color: Colors.white,
//                     size: 16,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// //
// // import '../../components/BidConfirmationDialog.dart'; // Import for TextInputFormatter
// //
// // class GroupJodiScreen extends StatefulWidget {
// //   final String title;
// //   const GroupJodiScreen({
// //     super.key,
// //     required this.title,
// //     required int gameId,
// //     required String gameType,
// //   });
// //
// //   @override
// //   State<GroupJodiScreen> createState() => _GroupJodiScreenState();
// // }
// //
// // class _GroupJodiScreenState extends State<GroupJodiScreen> {
// //   final TextEditingController jodiController = TextEditingController();
// //   final TextEditingController pointsController = TextEditingController();
// //
// //   List<Map<String, String>> bids = [];
// //
// //   @override
// //   void dispose() {
// //     jodiController.dispose();
// //     pointsController.dispose();
// //     super.dispose();
// //   }
// //
// //   // Helper function to calculate the "cut" of a digit
// //   String _getCutDigit(String digit) {
// //     int d = int.parse(digit);
// //     return ((d + 5) % 10).toString();
// //   }
// //
// //   void addBid() {
// //     String jodiInput = jodiController.text.trim();
// //     String points = pointsController.text.trim();
// //
// //     // Validate Jodi input: must be 2 digits and numeric
// //     if (jodiInput.length != 2 || int.tryParse(jodiInput) == null) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text('Please enter a valid 2-digit Jodi.')),
// //       );
// //       return;
// //     }
// //
// //     // Validate Points input: must not be empty
// //     if (points.isEmpty) {
// //       ScaffoldMessenger.of(
// //         context,
// //       ).showSnackBar(const SnackBar(content: Text('Please enter Points.')));
// //       return;
// //     }
// //
// //     // Parse the two digits from the Jodi input
// //     String digit1 = jodiInput[0];
// //     String digit2 = jodiInput[1];
// //
// //     // Calculate their "cut" digits
// //     String cutDigit1 = _getCutDigit(digit1);
// //     String cutDigit2 = _getCutDigit(digit2);
// //
// //     // Generate the 8 combinations
// //     List<String> generatedJodis = [
// //       '$digit1$digit2', // Original Jodi
// //       '$digit1$cutDigit2', // First digit and cut of second
// //       '$cutDigit1$digit2', // Cut of first digit and second
// //       '$cutDigit1$cutDigit2', // Cut of both digits
// //       '$digit2$digit1', // Reverse Jodi
// //       '$digit2$cutDigit1', // Second digit and cut of first
// //       '$cutDigit2$digit1', // Cut of second digit and first
// //       '$cutDigit2$cutDigit1', // Cut of second and cut of first
// //     ];
// //
// //     setState(() {
// //       // Add each generated Jodi with the entered points
// //       for (String jodi in generatedJodis) {
// //         // Ensure no duplicate Jodis are added if they somehow generate the same number
// //         // This simple check prevents exact string duplicates.
// //         if (!bids.any((bid) => bid['jodi'] == jodi)) {
// //           bids.add({'jodi': jodi, 'points': points});
// //         }
// //       }
// //       // Clear the text fields after adding
// //       jodiController.clear();
// //       pointsController.clear();
// //     });
// //   }
// //
// //   void removeBid(int index) {
// //     setState(() {
// //       bids.removeAt(index);
// //     });
// //   }
// //
// //   int get totalPoints =>
// //       bids.fold(0, (sum, item) => sum + int.parse(item['points']!));
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: const Color(0xFFEEEEEE),
// //       appBar: AppBar(
// //         backgroundColor: Colors.white,
// //         elevation: 0.5,
// //         leading: const BackButton(color: Colors.black),
// //         title: Text(
// //           widget.title.toUpperCase(),
// //           style: const TextStyle(color: Colors.black, fontSize: 16),
// //         ),
// //         actions: [
// //           Row(
// //             children: const [
// //               Icon(
// //                 Icons.account_balance_wallet_outlined,
// //                 color: Colors.black,
// //               ), // Wallet icon
// //               SizedBox(width: 4),
// //               Padding(
// //                 padding: EdgeInsets.only(top: 2.0),
// //                 child: Text(
// //                   '5',
// //                   style: TextStyle(color: Colors.black, fontSize: 16),
// //                 ),
// //               ),
// //               SizedBox(width: 10),
// //             ],
// //           ),
// //         ],
// //       ),
// //       body: Column(
// //         children: [
// //           Padding(
// //             padding: const EdgeInsets.all(12),
// //             child: Column(
// //               children: [
// //                 // Input row for "Enter Jodi"
// //                 _buildInputRow("Enter Jodi", jodiController, isJodi: true),
// //                 const SizedBox(height: 10),
// //                 // Input row for "Enter Points"
// //                 _buildInputRow("Enter Points", pointsController),
// //                 const SizedBox(height: 10),
// //                 SizedBox(
// //                   width: double.infinity,
// //                   height: 45,
// //                   child: ElevatedButton(
// //                     onPressed: addBid,
// //                     style: ElevatedButton.styleFrom(
// //                       backgroundColor: const Color(0xFFF5B544),
// //                       shape: RoundedRectangleBorder(
// //                         borderRadius: BorderRadius.circular(
// //                           8,
// //                         ), // Consistent rounded corners
// //                       ),
// //                       elevation: 3, // Subtle shadow
// //                     ),
// //                     child: const Text(
// //                       "ADD",
// //                       style: TextStyle(
// //                         fontSize: 16,
// //                         color: Colors.white,
// //                       ), // White text
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //           const Divider(height: 1),
// //           if (bids.isNotEmpty) // Conditionally render header
// //             const Padding(
// //               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
// //               child: Row(
// //                 children: [
// //                   Expanded(
// //                     flex: 2, // Adjusted flex for 'Jodi'
// //                     child: Text(
// //                       'Jodi',
// //                       style: TextStyle(
// //                         fontWeight: FontWeight.bold,
// //                         fontSize: 16,
// //                       ),
// //                     ),
// //                   ),
// //                   Expanded(
// //                     flex: 3, // Adjusted flex for 'Points'
// //                     child: Text(
// //                       'Points',
// //                       style: TextStyle(
// //                         fontWeight: FontWeight.bold,
// //                         fontSize: 16,
// //                       ),
// //                     ),
// //                   ),
// //                   SizedBox(width: 48), // Space for delete icon alignment
// //                 ],
// //               ),
// //             ),
// //           Expanded(
// //             child: bids.isEmpty
// //                 ? Center(
// //                     child: Text(
// //                       'No entries yet. Add some data!',
// //                       style: TextStyle(fontSize: 16, color: Colors.grey[600]),
// //                     ),
// //                   )
// //                 : ListView.builder(
// //                     itemCount: bids.length,
// //                     itemBuilder: (context, index) {
// //                       final bid = bids[index];
// //                       return Container(
// //                         margin: const EdgeInsets.symmetric(
// //                           horizontal: 10,
// //                           vertical: 4,
// //                         ),
// //                         decoration: BoxDecoration(
// //                           color: Colors.white,
// //                           borderRadius: BorderRadius.circular(
// //                             8,
// //                           ), // Consistent rounded corners
// //                           boxShadow: [
// //                             BoxShadow(
// //                               color: Colors.grey.withOpacity(0.2),
// //                               spreadRadius: 1,
// //                               blurRadius: 3,
// //                               offset: const Offset(0, 1), // Subtle shadow
// //                             ),
// //                           ],
// //                         ),
// //                         child: Padding(
// //                           padding: const EdgeInsets.symmetric(
// //                             horizontal: 16.0,
// //                             vertical: 8.0,
// //                           ),
// //                           child: Row(
// //                             children: [
// //                               Expanded(
// //                                 flex: 2,
// //                                 child: Text(
// //                                   bid['jodi']!,
// //                                   style: const TextStyle(
// //                                     fontSize: 16,
// //                                     fontWeight: FontWeight.w500,
// //                                   ),
// //                                 ), // Display 'jodi'
// //                               ),
// //                               Expanded(
// //                                 flex: 3,
// //                                 child: Text(
// //                                   bid['points']!,
// //                                   style: const TextStyle(
// //                                     fontSize: 16,
// //                                     fontWeight: FontWeight.w500,
// //                                   ),
// //                                 ),
// //                               ),
// //                               IconButton(
// //                                 icon: const Icon(
// //                                   Icons.delete,
// //                                   color: Colors.red,
// //                                 ),
// //                                 onPressed: () => removeBid(index),
// //                               ),
// //                             ],
// //                           ),
// //                         ),
// //                       );
// //                     },
// //                   ),
// //           ),
// //           if (bids.isNotEmpty) // Conditionally render footer
// //             Container(
// //               padding: const EdgeInsets.symmetric(
// //                 horizontal: 16,
// //                 vertical: 12,
// //               ), // Increased vertical padding
// //               decoration: BoxDecoration(
// //                 color: Colors.white,
// //                 boxShadow: [
// //                   BoxShadow(
// //                     color: Colors.grey.withOpacity(0.3),
// //                     spreadRadius: 2,
// //                     blurRadius: 5,
// //                     offset: const Offset(0, -3),
// //                   ),
// //                 ],
// //               ),
// //               child: Row(
// //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                 children: [
// //                   Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       Text(
// //                         "Bids",
// //                         style: TextStyle(fontSize: 14, color: Colors.grey[700]),
// //                       ),
// //                       Text(
// //                         "${bids.length}", // Use bids.length
// //                         style: const TextStyle(
// //                           fontSize: 18,
// //                           fontWeight: FontWeight.bold,
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                   Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       Text(
// //                         "Points",
// //                         style: TextStyle(fontSize: 14, color: Colors.grey[700]),
// //                       ),
// //                       Text(
// //                         "$totalPoints",
// //                         style: const TextStyle(
// //                           fontSize: 18,
// //                           fontWeight: FontWeight.bold,
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                   ElevatedButton(
// //                     onPressed: () {},
// //                     style: ElevatedButton.styleFrom(
// //                       backgroundColor: const Color(0xFFF5B544),
// //                       padding: const EdgeInsets.symmetric(
// //                         horizontal: 24,
// //                         vertical: 12,
// //                       ),
// //                       shape: RoundedRectangleBorder(
// //                         borderRadius: BorderRadius.circular(8),
// //                       ),
// //                       elevation: 3,
// //                     ),
// //                     child: const Text(
// //                       "SUBMIT",
// //                       style: TextStyle(color: Colors.white, fontSize: 16),
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   // The method to show the confirmation dialog
// //   void _showConfirmationDialog(int totalPoints) {
// //     showDialog(
// //       context: context,
// //       builder: (BuildContext context) {
// //         return BidConfirmationDialog(
// //           gameTitle: widget.title,
// //           bids: bids,
// //           totalBids: bids.length,
// //           totalBidsAmount: totalPoints,
// //           walletBalanceBeforeDeduction: walletBalance, // Pass as string
// //           walletBalanceAfterDeduction: (walletBalance - totalPoints)
// //               .toString(), // Pass as string
// //           gameDate: DateTime.now().toString(),
// //           gameId: widget.gameId as String,
// //           gameType: widget.gameType,
// //         );
// //       },
// //     );
// //   }
// //
// //   // Helper widget for input rows
// //   Widget _buildInputRow(
// //     String label,
// //     TextEditingController controller, {
// //     bool isJodi = false,
// //   }) {
// //     return Row(
// //       children: [
// //         Expanded(
// //           // Use Expanded for the label to align better
// //           flex: 2,
// //           child: Text(
// //             label,
// //             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
// //           ), // Bold and larger font for labels
// //         ),
// //         const SizedBox(width: 10),
// //         Expanded(
// //           flex: 3, // Give more space to the input field
// //           child: Container(
// //             decoration: BoxDecoration(
// //               color: Colors.white,
// //               borderRadius: BorderRadius.circular(8), // More rounded corners
// //               border: Border.all(color: Colors.grey[300]!),
// //             ),
// //             child: TextField(
// //               controller: controller,
// //               keyboardType: TextInputType.number,
// //               inputFormatters: [
// //                 FilteringTextInputFormatter.digitsOnly, // Allow only digits
// //                 if (isJodi)
// //                   LengthLimitingTextInputFormatter(
// //                     2,
// //                   ), // Limit to 2 digits for Jodi
// //               ],
// //               decoration: InputDecoration(
// //                 hintText: isJodi
// //                     ? 'Enter 2-digit Jodi'
// //                     : 'Enter Points', // Hint text
// //                 border: InputBorder.none, // Remove default border
// //                 contentPadding: const EdgeInsets.symmetric(
// //                   horizontal: 16,
// //                   vertical: 12, // Increased vertical padding
// //                 ),
// //                 suffixIcon: Container(
// //                   margin: const EdgeInsets.all(8),
// //                   decoration: BoxDecoration(
// //                     color: const Color(0xFFF5B544), // Orange background
// //                     shape: BoxShape.circle,
// //                   ),
// //                   child: const Icon(
// //                     Icons.arrow_forward,
// //                     color: Colors.white,
// //                     size: 16,
// //                   ), // Arrow icon
// //                 ),
// //               ),
// //             ),
// //           ),
// //         ),
// //       ],
// //     );
// //   }
// // }
