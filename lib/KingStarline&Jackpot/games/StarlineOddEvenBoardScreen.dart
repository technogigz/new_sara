import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../StarlineBidService.dart';

enum GameType { odd, even }

enum LataDayType { open, close }

class StarlineOddEvenBoardScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType;
  final String gameName;
  final bool selectionStatus;

  const StarlineOddEvenBoardScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
    this.gameName = "",
    required this.selectionStatus,
  }) : super(key: key);

  @override
  _StarlineOddEvenBoardScreenState createState() =>
      _StarlineOddEvenBoardScreenState();
}

class _StarlineOddEvenBoardScreenState
    extends State<StarlineOddEvenBoardScreen> {
  GameType? _selectedGameType = GameType.odd;
  late LataDayType _selectedLataDayType;

  final TextEditingController _pointsController = TextEditingController();

  List<Map<String, String>> _entries = [];

  late final GetStorage storage = GetStorage();
  late String _accessToken;
  late String _registerId;
  late bool _accountStatus;
  late int _walletBalance;

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  final UserController userController = Get.put(UserController());

  late final StarlineBidService _bidService;

  @override
  void initState() {
    super.initState();
    _bidService = StarlineBidService(storage);

    _accessToken = storage.read('accessToken') ?? '';
    _registerId = storage.read('registerId') ?? '';
    _accountStatus = userController.accountStatus.value;

    double walletBalanceDouble = double.parse(
      userController.walletBalance.value,
    );
    _walletBalance = walletBalanceDouble.toInt();

    _selectedLataDayType = widget.selectionStatus
        ? LataDayType.open
        : LataDayType.close;

    // Listen for changes in GetStorage keys and update UI
    storage.listenKey('accessToken', (value) {
      _accessToken = value ?? '';
    });
    storage.listenKey('registerId', (value) {
      _registerId = value ?? '';
    });
    storage.listenKey('accountStatus', (value) {
      _accountStatus = value ?? false;
    });
    storage.listenKey('walletBalance', (value) {
      setState(() {
        _walletBalance = int.tryParse(value ?? '0') ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
  }

  void _clearMessage() {
    if (mounted && _messageToShow != null) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  void _addEntry() {
    _clearMessage();

    String points = _pointsController.text.trim();
    String type = _selectedLataDayType == LataDayType.close ? 'CLOSE' : 'OPEN';
    String bidType = _selectedGameType == GameType.odd ? "Odd" : "Even";

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    setState(() {
      _entries.removeWhere(
        (entry) => entry['type'] == type && entry['bidType'] == bidType,
      );

      _entries.add({'points': points, 'type': type, 'bidType': bidType});

      _pointsController.clear();
      _showMessage(
        '$bidType bid for $type added successfully!',
        isError: false,
      );
    });
  }

  void _deleteEntry(int index) {
    _clearMessage();
    setState(() {
      _entries.removeAt(index);
      _showMessage('Entry deleted.', isError: false);
    });
  }

  int _getTotalPoints() {
    return _entries.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  void _showConfirmationDialog() {
    _clearMessage();

    if (_entries.isEmpty) {
      _showMessage('Please add at least one entry.', isError: true);
      return;
    }

    final int totalPoints = _getTotalPoints();
    if (_walletBalance < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid. You need $totalPoints points.',
        isError: true,
      );
      return;
    }

    List<Map<String, String>> bidsForDialog = [];
    for (var entry in _entries) {
      final String bidType = entry['bidType']!;
      final String type = entry['type']!;
      final String points = entry['points']!;

      final List<String> digits = (bidType == 'Odd')
          ? ['1', '3', '5', '7', '9']
          : ['0', '2', '4', '6', '8'];

      for (String digit in digits) {
        bidsForDialog.add({
          "digit": digit,
          "pana": "",
          "points": points,
          "type": type,
          "bidType": bidType,
        });
      }
    }

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.title,
          gameDate: formattedDate,
          bids: bidsForDialog,
          totalBids: _entries.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: _walletBalance,
          walletBalanceAfterDeduction: (_walletBalance - totalPoints)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                _entries.clear();
              });
            }
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    Map<String, String> bidAmounts = {};
    String selectedGameSessionType = 'OPEN';

    for (var entry in _entries) {
      final String bidType = entry['bidType']!;
      final String points = entry['points']!;
      final String type = entry['type']!;

      if (type == 'CLOSE' && widget.selectionStatus) {
        selectedGameSessionType = 'CLOSE';
      }

      List<String> digitsToAdd = (bidType == 'Odd')
          ? ['1', '3', '5', '7', '9']
          : ['0', '2', '4', '6', '8'];

      for (String digit in digitsToAdd) {
        bidAmounts[digit] = points;
      }
    }

    const String deviceId = 'your_device_id_odd_even';
    const String deviceName = 'OddEvenBoardApp';

    final response = await _bidService.placeFinalBids(
      gameName: widget.gameName,
      accessToken: _accessToken,
      registerId: _registerId,
      deviceId: deviceId,
      deviceName: deviceName,
      accountStatus: _accountStatus,
      bidAmounts: bidAmounts,
      selectedGameType: selectedGameSessionType,
      gameId: widget.gameId,
      gameType: widget.gameType,
      totalBidAmount: _getTotalPoints(),
    );

    if (mounted) {
      if (response['status'] == true) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return const BidSuccessDialog();
          },
        );
        return true;
      } else {
        String errorMessage = response['msg'] ?? "Unknown error occurred.";
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return BidFailureDialog(errorMessage: errorMessage);
          },
        );
        return false;
      }
    }
    return false;
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
          onPressed: () => Navigator.pop(context),
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
                  "assets/images/ic_wallet.png",
                  width: 22,
                  height: 22,
                  color: Colors.black,
                ),
                const SizedBox(width: 4),
                Text(
                  userController.walletBalance.value,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<GameType>(
                              title: const Text('Odd'),
                              value: GameType.odd,
                              groupValue: _selectedGameType,
                              onChanged: (GameType? value) {
                                setState(() => _selectedGameType = value);
                              },
                              activeColor: Colors.orange,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<GameType>(
                              title: const Text('Even'),
                              value: GameType.even,
                              groupValue: _selectedGameType,
                              onChanged: (GameType? value) {
                                setState(() => _selectedGameType = value);
                              },
                              activeColor: Colors.orange,
                              contentPadding: EdgeInsets.zero,
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
                          Expanded(
                            child: _buildPointsInputField(_pointsController),
                          ),
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
                                backgroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 3,
                              ),
                              child: const Text(
                                'ADD',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
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
                            'Type',
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
                            'Session',
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
                if (_entries.isNotEmpty)
                  Divider(height: 1, color: Colors.grey[400]),
                Expanded(
                  child: _entries.isEmpty
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
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            return _buildEntryItem(
                              entry['bidType']!,
                              entry['points']!,
                              entry['type']!,
                              index,
                            );
                          },
                        ),
                ),
                if (_entries.isNotEmpty) _buildBottomBar(),
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
        cursorColor: Colors.orange,
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onTap: _clearMessage,
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
              color: Colors.orange,
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

  Widget _buildEntryItem(
    String bidType,
    String points,
    String type,
    int index,
  ) {
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
                bidType,
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
    int totalBids = _entries.length;
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
            onPressed: _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
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

// import 'dart:async';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:intl/intl.dart';
// import 'package:marquee/marquee.dart';
// import 'package:new_sara/KingStarline&Jackpot/StarlineBidService.dart';
//
// import '../../components/AnimatedMessageBar.dart';
// import '../../components/BidConfirmationDialog.dart';
// import '../../components/BidFailureDialog.dart';
// import '../../components/BidSuccessDialog.dart';
//
// enum GameType { odd, even }
//
// enum LataDayType { open, close }
//
// class StarlineOddEvenBoardScreen extends StatefulWidget {
//   final String title;
//   final int gameId;
//   final String
//   gameType; // This will likely be something like "single" or "odd_even"
//   final String gameName;
//   final bool selectionStatus;
//
//   const StarlineOddEvenBoardScreen({
//     Key? key,
//     required this.title,
//     required this.gameId,
//     required this.gameType,
//     this.gameName = "",
//     required this.selectionStatus, // Ensure gameName is passed, especially for API URL logic in BidService
//   }) : super(key: key);
//
//   @override
//   _StarlineOddEvenBoardScreenState createState() =>
//       _StarlineOddEvenBoardScreenState();
// }
//
// class _StarlineOddEvenBoardScreenState
//     extends State<StarlineOddEvenBoardScreen> {
//   GameType? _selectedGameType = GameType.odd;
//   LataDayType?
//   _selectedLataDayType; // Will be initialized based on selectionStatus
//
//   final TextEditingController _pointsController = TextEditingController();
//
//   List<Map<String, String>> _entries =
//       []; // Stores individual digit bids for display
//
//   late GetStorage storage = GetStorage();
//   late String _accessToken;
//   late String _registerId;
//   late String _preferredLanguage;
//   bool _accountStatus = false;
//   late int _walletBalance;
//
//   String? _messageToShow;
//   bool _isErrorForMessage = false;
//   Key _messageBarKey = UniqueKey();
//
//   late final StarlineBidService _bidService; // Instantiate BidService here
//
//   @override
//   void initState() {
//     super.initState();
//     _bidService = StarlineBidService(
//       storage,
//     ); // Initialize BidService with the storage instance
//
//     _accessToken = storage.read('accessToken') ?? '';
//     _registerId = storage.read('registerId') ?? '';
//     _accountStatus = storage.read('accountStatus') ?? false;
//     _preferredLanguage = storage.read('selectedLanguage') ?? 'en';
//
//     final dynamic storedWalletBalance = storage.read('walletBalance');
//     if (storedWalletBalance is String) {
//       _walletBalance = int.tryParse(storedWalletBalance) ?? 0;
//     } else if (storedWalletBalance is int) {
//       _walletBalance = storedWalletBalance;
//     } else {
//       _walletBalance = 0;
//     }
//
//     // Initialize _selectedLataDayType based on widget.selectionStatus
//     if (widget.selectionStatus) {
//       _selectedLataDayType = LataDayType.open;
//     } else {
//       _selectedLataDayType = LataDayType.close;
//     }
//
//     // Listen for changes in GetStorage keys and update UI
//     storage.listenKey('accessToken', (value) {
//       _accessToken = value ?? '';
//     });
//
//     storage.listenKey('registerId', (value) {
//       _registerId = value ?? '';
//     });
//
//     storage.listenKey('accountStatus', (value) {
//       _accountStatus = value ?? false;
//     });
//
//     storage.listenKey('selectedLanguage', (value) {
//       _preferredLanguage = value ?? 'en';
//     });
//
//     storage.listenKey('walletBalance', (value) {
//       if (value is String) {
//         _walletBalance = int.tryParse(value) ?? 0;
//       } else if (value is int) {
//         _walletBalance = value;
//       } else {
//         _walletBalance = 0;
//       }
//     });
//
//     setState(() {});
//   }
//
//   @override
//   void dispose() {
//     _pointsController.dispose();
//     super.dispose();
//   }
//
//   // --- Message Bar Logic ---
//   void _showMessage(String message, {bool isError = false}) {
//     if (!mounted) return;
//     setState(() {
//       _messageToShow = message;
//       _isErrorForMessage = isError;
//       _messageBarKey = UniqueKey(); // Force rebuild of AnimatedMessageBar
//     });
//   }
//
//   void _clearMessage() {
//     if (mounted && _messageToShow != null) {
//       setState(() {
//         _messageToShow = null;
//       });
//     }
//   }
//
//   // --- Bid Entry Management ---
//   void _addEntry() {
//     _clearMessage();
//
//     String points = _pointsController.text.trim();
//     String type = _selectedLataDayType == LataDayType.close ? 'CLOSE' : 'OPEN';
//
//     if (points.isEmpty ||
//         int.tryParse(points) == null ||
//         int.parse(points) < 10 ||
//         int.parse(points) > 1000) {
//       _showMessage('Points must be between 10 and 1000.', isError: true);
//       return;
//     }
//
//     if (_selectedGameType != null) {
//       List<String> digitsToAdd;
//       String bidType; // "Odd" or "Even"
//
//       if (_selectedGameType == GameType.odd) {
//         digitsToAdd = ['1', '3', '5', '7', '9'];
//         bidType = "Odd";
//       } else {
//         // GameType.even
//         digitsToAdd = ['0', '2', '4', '6', '8'];
//         bidType = "Even";
//       }
//
//       setState(() {
//         // Remove existing Odd/Even entries for the selected type (OPEN/CLOSE)
//         // to prevent duplicates and ensure only one Odd/Even type bid per sessionType.
//         _entries.removeWhere(
//           (entry) =>
//               entry['type'] == type &&
//               (entry['bidType'] == "Odd" || entry['bidType'] == "Even"),
//         );
//
//         // Add new entries for each digit
//         for (String digit in digitsToAdd) {
//           _entries.add({
//             'digit': digit,
//             'points': points,
//             'type': type, // OPEN or CLOSE
//             'bidType': bidType, // Odd or Even
//           });
//         }
//         _pointsController.clear();
//         _showMessage('Entry added successfully!', isError: false);
//       });
//     } else {
//       _showMessage(
//         'Please select game type (Odd/Even) and enter points.',
//         isError: true,
//       );
//     }
//   }
//
//   void _deleteEntry(int index) {
//     _clearMessage();
//     setState(() {
//       _entries.removeAt(index);
//       _showMessage('Entry deleted.', isError: false);
//     });
//   }
//
//   int _getTotalPoints() {
//     return _entries.fold(
//       0,
//       (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
//     );
//   }
//
//   // --- Confirmation Dialog and Bid Submission ---
//   void _showConfirmationDialog() {
//     _clearMessage();
//
//     if (_entries.isEmpty) {
//       _showMessage('Please add at least one entry.', isError: true);
//       return;
//     }
//
//     final int totalPoints = _getTotalPoints();
//
//     if (_walletBalance < totalPoints) {
//       _showMessage(
//         'Insufficient wallet balance to place this bid. You need $totalPoints points.',
//         isError: true,
//       );
//       return;
//     }
//
//     // Prepare bids for display in the confirmation dialog
//     List<Map<String, String>> bidsForDialog = _entries.map((entry) {
//       return {
//         "digit": entry['digit']!,
//         "pana": "", // Pana is empty for Odd/Even in dialog
//         "points": entry['points']!,
//         "type": entry['type']!, // OPEN or CLOSE
//         "bidType": entry['bidType']!, // Odd or Even
//       };
//     }).toList();
//
//     final String formattedDate = DateFormat(
//       'dd MMM yyyy, hh:mm a',
//     ).format(DateTime.now());
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return BidConfirmationDialog(
//           gameTitle: widget.title,
//           gameDate: formattedDate,
//           bids: bidsForDialog,
//           totalBids: bidsForDialog.length,
//           totalBidsAmount: totalPoints,
//           walletBalanceBeforeDeduction: _walletBalance,
//           walletBalanceAfterDeduction: (_walletBalance - totalPoints)
//               .toString(),
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameType, // Pass original gameType for confirmation
//           onConfirm: () async {
//             // Navigator.pop(dialogContext); // Dismiss confirmation dialog first
//             bool success = await _placeFinalBids();
//             if (success) {
//               setState(() {
//                 _entries.clear(); // Clear entries only on successful bid
//               });
//             }
//           },
//         );
//       },
//     );
//   }
//
//   Future<bool> _placeFinalBids() async {
//     // Prepare bid amounts in the required format for BidService
//     // This map will contain individual digits as keys and their points as values.
//     Map<String, String> bidAmounts = {};
//     String selectedGameSessionType = 'OPEN';
//
//     // Populate bidAmounts with data from _entries
//     // _entries already holds the individual digits (1,3,5,7,9 or 0,2,4,6,8)
//     // with their respective points for the selected session type.
//     for (var entry in _entries) {
//       if (entry['type'] == selectedGameSessionType) {
//         bidAmounts[entry['digit']!] = entry['points']!;
//       }
//     }
//
//     // Placeholder device information (replace with actual device data in production)
//     // In a real app, you'd get these from a device info package.
//     const String deviceId =
//         'your_device_id_odd_even'; // Use a unique ID for odd-even
//     const String deviceName = 'OddEvenBoardApp';
//
//     final response = await _bidService.placeFinalBids(
//       gameName: widget.gameName,
//       accessToken: _accessToken,
//       registerId: _registerId,
//       deviceId: deviceId,
//       deviceName: deviceName,
//       accountStatus: _accountStatus,
//       bidAmounts: bidAmounts, // This is the map of 'digit' to 'points'
//       selectedGameType: selectedGameSessionType, // 'OPEN' or 'CLOSE'
//       gameId: widget.gameId,
//       gameType: widget
//           .gameType, // Original gameType from widget, e.g., 'single', 'odd_even'
//       totalBidAmount: _getTotalPoints(),
//     );
//
//     if (mounted) {
//       // Use if/else as requested for showing dialogs
//       if (response['status'] == true) {
//         int newWalletBalance = _walletBalance - _getTotalPoints();
//         await _bidService.updateWalletBalance(newWalletBalance);
//         setState(() {
//           _walletBalance = newWalletBalance;
//         });
//
//         await showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (BuildContext dialogContext) {
//             return const BidSuccessDialog();
//           },
//         );
//         return true; // Indicate success
//       } else {
//         String errorMessage = response['msg'] ?? "Unknown error occurred.";
//         await showDialog(
//           context: context,
//           barrierDismissible:
//               false, // Make it non-dismissible for critical errors
//           builder: (BuildContext dialogContext) {
//             return BidFailureDialog(errorMessage: errorMessage);
//           },
//         );
//         return false; // Indicate failure
//       }
//     }
//     return false; // Should not be reached if mounted, but for safety
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Dynamically build the list of dropdown items based on widget.selectionStatus
//     List<DropdownMenuItem<LataDayType>> dropdownItems = [];
//     if (widget.selectionStatus) {
//       dropdownItems.add(
//         DropdownMenuItem<LataDayType>(
//           value: LataDayType.open,
//           child: SizedBox(
//             width: 150,
//             height: 20,
//             child: Marquee(
//               text: '${widget.title} OPEN',
//               style: const TextStyle(fontSize: 16),
//               scrollAxis: Axis.horizontal,
//               blankSpace: 40.0,
//               velocity: 30.0,
//               pauseAfterRound: const Duration(seconds: 1),
//               startPadding: 10.0,
//               accelerationDuration: const Duration(seconds: 1),
//               accelerationCurve: Curves.linear,
//               decelerationDuration: const Duration(milliseconds: 500),
//               decelerationCurve: Curves.easeOut,
//             ),
//           ),
//         ),
//       );
//     }
//     // "Close" is always an option
//     dropdownItems.add(
//       DropdownMenuItem<LataDayType>(
//         value: LataDayType.close,
//         child: SizedBox(
//           width: 150,
//           height: 20,
//           child: Marquee(
//             text: '${widget.title} CLOSE',
//             style: const TextStyle(fontSize: 16),
//             scrollAxis: Axis.horizontal,
//             blankSpace: 40.0,
//             velocity: 30.0,
//             pauseAfterRound: const Duration(seconds: 1),
//             startPadding: 10.0,
//             accelerationDuration: const Duration(seconds: 1),
//             accelerationCurve: Curves.linear,
//             decelerationDuration: const Duration(milliseconds: 500),
//             decelerationCurve: Curves.easeOut,
//           ),
//         ),
//       ),
//     );
//
//     return Scaffold(
//       backgroundColor: Colors.grey[200],
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//         title: Text(
//           widget.title,
//           style: const TextStyle(
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
//                 Image.asset(
//                   "assets/images/ic_wallet.png",
//                   width: 22,
//                   height: 22,
//                   color: Colors.black,
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   _walletBalance.toString(),
//                   style: const TextStyle(color: Colors.black, fontSize: 16),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Expanded(
//                           child: RadioListTile<GameType>(
//                             title: const Text('Odd'),
//                             value: GameType.odd,
//                             groupValue: _selectedGameType,
//                             onChanged: (GameType? value) {
//                               setState(() {
//                                 _selectedGameType = value;
//                               });
//                             },
//                             activeColor: Colors.orange,
//                             contentPadding: EdgeInsets.zero,
//                           ),
//                         ),
//                         Expanded(
//                           child: RadioListTile<GameType>(
//                             title: const Text('Even'),
//                             value: GameType.even,
//                             groupValue: _selectedGameType,
//                             onChanged: (GameType? value) {
//                               setState(() {
//                                 _selectedGameType = value;
//                               });
//                             },
//                             activeColor: Colors.orange,
//                             contentPadding: EdgeInsets.zero,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         const Expanded(
//                           child: Text(
//                             'Enter Points :',
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: _buildPointsInputField(_pointsController),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.end,
//                       children: [
//                         SizedBox(
//                           width: 150,
//                           child: ElevatedButton(
//                             onPressed: _addEntry,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.orange,
//                               padding: const EdgeInsets.symmetric(vertical: 12),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               elevation: 3,
//                             ),
//                             child: const Text(
//                               'ADD',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 16,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               Divider(height: 1, color: Colors.grey[400]),
//               if (_entries.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16.0,
//                     vertical: 8.0,
//                   ),
//                   child: Row(
//                     children: [
//                       const Expanded(
//                         flex: 2,
//                         child: Text(
//                           'Digit',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                       const Expanded(
//                         flex: 3,
//                         child: Text(
//                           'Points',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                       const Expanded(
//                         flex: 2,
//                         child: Text(
//                           'Type',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 48), // Space for delete icon
//                     ],
//                   ),
//                 ),
//               if (_entries.isNotEmpty)
//                 Divider(height: 1, color: Colors.grey[400]),
//               Expanded(
//                 child: _entries.isEmpty
//                     ? Center(
//                         child: Text(
//                           'No entries yet. Add some data!',
//                           style: TextStyle(
//                             fontSize: 16,
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                       )
//                     : ListView.builder(
//                         itemCount: _entries.length,
//                         itemBuilder: (context, index) {
//                           final entry = _entries[index];
//                           return _buildEntryItem(
//                             entry['digit']!,
//                             entry['points']!,
//                             entry['type']!,
//                             index,
//                           );
//                         },
//                       ),
//               ),
//               if (_entries.isNotEmpty) _buildBottomBar(),
//             ],
//           ),
//           // Animated Message Bar at the top
//           if (_messageToShow != null)
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               child: AnimatedMessageBar(
//                 key:
//                     _messageBarKey, // Key to trigger animation on message change
//                 message: _messageToShow!,
//                 isError: _isErrorForMessage,
//                 onDismissed: _clearMessage,
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   // --- Helper Widgets ---
//   Widget _buildPointsInputField(TextEditingController controller) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey[300]!),
//       ),
//       child: TextField(
//         cursorColor: Colors.orange,
//         controller: controller,
//         keyboardType: TextInputType.number,
//         inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//         onTap: _clearMessage, // Clear messages when user starts typing
//         decoration: InputDecoration(
//           hintText: 'Enter Points',
//           border: InputBorder.none,
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 12,
//           ),
//           suffixIcon: Container(
//             margin: const EdgeInsets.all(8),
//             decoration: const BoxDecoration(
//               color: Colors.orange,
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(
//               Icons.arrow_forward,
//               color: Colors.white,
//               size: 16,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEntryItem(String digit, String points, String type, int index) {
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//             Expanded(
//               flex: 3,
//               child: Text(
//                 points,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
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
//               ),
//             ),
//             IconButton(
//               icon: const Icon(Icons.delete, color: Colors.red),
//               onPressed: () => _deleteEntry(index),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildBottomBar() {
//     int totalBids = _entries.length;
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
//             offset: const Offset(0, -3), // Shadow at the top
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
//                 style: TextStyle(fontSize: 14, color: Colors.grey[700]),
//               ),
//               Text(
//                 '$totalBids',
//                 style: const TextStyle(
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
//                 style: TextStyle(fontSize: 14, color: Colors.grey[700]),
//               ),
//               Text(
//                 '$totalPoints',
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           ElevatedButton(
//             onPressed: _showConfirmationDialog,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.orange,
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               elevation: 3,
//             ),
//             child: const Text(
//               'SUBMIT',
//               style: TextStyle(color: Colors.white, fontSize: 16),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
