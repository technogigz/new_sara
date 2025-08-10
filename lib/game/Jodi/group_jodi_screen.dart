import 'dart:async'; // Import for Timer

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:new_sara/components/BidFailureDialog.dart';

import '../../BidService.dart';
import '../../Helper/UserController.dart';
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

  final UserController userController = Get.put(UserController());

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
    double walletBalance = double.parse(userController.walletBalance.value);
    _walletBalance = walletBalance.toInt();
  }

  void _initializeStorageValues() {
    _mobile = userController.mobileNo.value;
    _name = userController.fullName.value;
    _accountActiveStatus = userController.accountStatus.value;
    _accessToken =
        _storage.read('accessToken') ?? ''; // Initialize access token
    _registerId = _storage.read('registerId') ?? ''; // Initialize register ID
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_outlined,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        actions: [
          Row(
            children: [
              Image.asset(
                "assets/images/ic_wallet.png",
                width: 22,
                height: 22,
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
      body: SafeArea(
        child: Stack(
          // Use Stack to overlay the message bar
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildInputRow(
                        "Enter Jodi",
                        jodiController,
                        isJodi: true,
                      ),
                      const SizedBox(height: 10),
                      _buildInputRow("Enter Points", pointsController),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: addBid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 3,
                          ),
                          child: const Text(
                            "ADD BID",
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
                            backgroundColor: Colors.orange,
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
      ),
    );
  }

  void _showConfirmationDialog() {
    if (bids.isEmpty) {
      _showMessageBar('Please add bids before submitting.', isError: true);
      return;
    }

    int currentTotalPoints = totalPoints;

    // Create a list of maps with consistent keys for the dialog
    final List<Map<String, String>> bidsForDialog = bids.map((bid) {
      return {
        'digit': bid['jodi']!, // Use 'jodi' as the digit
        'points': bid['points']!, // Use 'points' as the amount
        'type': 'Group Jodi', // Hardcoded type for the dialog
        'pana': '', // Not applicable for Group Jodi, so leave empty
      };
    }).toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BidConfirmationDialog(
          gameTitle: widget.title,
          bids: bidsForDialog, // Pass the corrected list
          totalBids: bids.length,
          totalBidsAmount: currentTotalPoints,
          walletBalanceBeforeDeduction: _walletBalance,
          walletBalanceAfterDeduction: (_walletBalance - currentTotalPoints)
              .toString(),
          gameDate: DateTime.now().toLocal().toString().split(' ')[0],
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            // Navigator.pop(context);
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
          ),
        ),
      ],
    );
  }
}
