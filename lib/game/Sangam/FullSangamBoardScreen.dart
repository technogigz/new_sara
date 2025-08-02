import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../BidService.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';

class FullSangamBoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;
  final String gameType;

  const FullSangamBoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameType,
    required this.gameId,
  }) : super(key: key);

  @override
  State<FullSangamBoardScreen> createState() => _FullSangamBoardScreenState();
}

class _FullSangamBoardScreenState extends State<FullSangamBoardScreen> {
  final TextEditingController _openPannaController = TextEditingController();
  final TextEditingController _closePannaController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  List<Map<String, String>> _bids = [];
  late GetStorage storage = GetStorage();
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance;

  bool _isApiCalling = false;

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  late BidService _bidService;

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupStorageListeners();
    _bidService = BidService(storage);
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = storage.read('accountStatus') ?? false;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is String) {
      walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else if (storedWalletBalance is int) {
      walletBalance = storedWalletBalance;
    } else {
      walletBalance = 0;
    }
  }

  void _setupStorageListeners() {
    storage.listenKey('accessToken', (value) {
      if (mounted) setState(() => accessToken = value ?? '');
    });

    storage.listenKey('registerId', (value) {
      if (mounted) setState(() => registerId = value ?? '');
    });

    storage.listenKey('accountStatus', (value) {
      if (mounted) setState(() => accountStatus = value ?? false);
    });

    storage.listenKey('selectedLanguage', (value) {
      if (mounted) setState(() => preferredLanguage = value ?? 'en');
    });

    storage.listenKey('walletBalance', (value) {
      if (mounted) {
        setState(() {
          if (value is String) {
            walletBalance = int.tryParse(value) ?? 0;
          } else if (value is int) {
            walletBalance = value;
          } else {
            walletBalance = 0;
          }
        });
      }
    });
  }

  static final List<String> _allPannas = List.generate(
    900,
    (index) => (index + 100).toString(),
  );

  @override
  void dispose() {
    _openPannaController.dispose();
    _closePannaController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted)
      return; // Add this check to prevent setState on unmounted widget
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
  }

  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  void _addBid() {
    if (_isApiCalling) return;
    _clearMessage();
    final openPanna = _openPannaController.text.trim();
    final closePanna = _closePannaController.text.trim();
    final points = _pointsController.text.trim();

    if (openPanna.isEmpty ||
        openPanna.length != 3 ||
        int.tryParse(openPanna) == null) {
      _showMessage(
        'Please enter a 3-digit number for Open Panna.',
        isError: true,
      );
      return;
    }
    int? parsedOpenPanna = int.tryParse(openPanna);
    if (parsedOpenPanna == null ||
        parsedOpenPanna < 100 ||
        parsedOpenPanna > 999) {
      _showMessage('Open Panna must be between 100 and 999.', isError: true);
      return;
    }

    if (closePanna.isEmpty ||
        closePanna.length != 3 ||
        int.tryParse(closePanna) == null) {
      _showMessage(
        'Please enter a 3-digit number for Close Panna.',
        isError: true,
      );
      return;
    }
    int? parsedClosePanna = int.tryParse(closePanna);
    if (parsedClosePanna == null ||
        parsedClosePanna < 100 ||
        parsedClosePanna > 999) {
      _showMessage('Close Panna must be between 100 and 999.', isError: true);
      return;
    }

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    final sangam = '$openPanna-$closePanna';

    setState(() {
      int existingIndex = _bids.indexWhere((bid) => bid['sangam'] == sangam);

      if (existingIndex != -1) {
        _bids[existingIndex]['points'] =
            (int.parse(_bids[existingIndex]['points']!) + parsedPoints)
                .toString();
        _showMessage('Updated points for $sangam.');
      } else {
        _bids.add({
          "sangam": sangam,
          "points": points,
          "openPanna": openPanna,
          "closePanna": closePanna,
          "type": "FullSangam",
        });
        _showMessage('Added bid: $sangam with $points points.');
      }

      _openPannaController.clear();
      _closePannaController.clear();
      _pointsController.clear();
    });
  }

  void _removeBid(int index) {
    if (_isApiCalling) return;
    _clearMessage();
    // The key is to wrap the removal in setState() to trigger a UI rebuild.
    setState(() {
      final removedSangam = _bids[index]['sangam'];
      _bids.removeAt(index);
      _showMessage('Bid for $removedSangam removed from list.');
    });
  }

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    if (_bids.isEmpty) {
      _showMessage('Please add at least one bid.', isError: true);
      return;
    }

    final int totalPoints = _getTotalPoints();

    if (walletBalance < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
      return;
    }

    List<Map<String, String>> bidsForDialog = _bids.map((bid) {
      return {
        "pana": bid['openPanna']!,
        "digit": bid['closePanna']!,
        "points": bid['points']!,
        "type": bid['type']!,
        "sangam": bid['sangam']!,
        "jodi": "",
      };
    }).toList();

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
          bids: bidsForDialog,
          totalBids: bidsForDialog.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            // Navigator.pop(dialogContext); // Dismiss confirmation dialog first
            setState(() {
              _isApiCalling = true;
            });
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                _bids.clear(); // Clear bids on successful submission
              });
            }
            if (mounted) {
              setState(() {
                _isApiCalling = false;
              });
            }
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    if (accessToken.isEmpty || registerId.isEmpty) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            // Use a different context for the dialog
            return const BidFailureDialog(
              errorMessage: 'Authentication error. Please log in again.',
            );
          },
        );
      }
      return false;
    }

    Map<String, String> bidAmountsForService = {};
    for (var bid in _bids) {
      bidAmountsForService[bid['sangam']!] = bid['points']!;
    }

    final response = await _bidService.placeFinalBids(
      gameName: widget.screenTitle,
      accessToken: accessToken,
      registerId: registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: accountStatus,
      bidAmounts: bidAmountsForService,
      selectedGameType: "FULLSANGAM",
      gameId: widget.gameId,
      gameType: widget.gameType,
      totalBidAmount: _getTotalPoints(),
    );

    if (response['status'] == true) {
      int currentWallet = walletBalance;
      int deductedAmount = _getTotalPoints();
      int newWalletBalance = currentWallet - deductedAmount;
      await _bidService.updateWalletBalance(newWalletBalance);

      if (mounted) {
        setState(() {
          walletBalance = newWalletBalance;
        });
        // Ensure this dialog is shown after the current context allows it.
        // It's already handled by the BidConfirmationDialog's onConfirm,
        // which dismisses itself and then calls _placeFinalBids().
        // So, this showDialog will correctly appear.
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            // Use a different context for the dialog
            return const BidSuccessDialog();
          },
        );
        _clearMessage();
      }
      return true;
    } else {
      String errorMessage = response['msg'] ?? "Unknown error occurred.";
      if (mounted) {
        // Ensure this dialog is shown after the current context allows it.
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            // Use a different context for the dialog
            return BidFailureDialog(errorMessage: errorMessage);
          },
        );
      }
      return false;
    }
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
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Image.asset(
            "assets/images/ic_wallet.png",
            width: 22,
            height: 22,
            color: Colors.black,
          ),
          const SizedBox(width: 6),
          Center(
            child: Text(
              walletBalance.toString(),
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
                    _buildPannaInputRow(
                      'Enter Open Panna :',
                      _openPannaController,
                      hintText: 'e.g., 123',
                      maxLength: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildPannaInputRow(
                      'Enter Close Panna :',
                      _closePannaController,
                      hintText: 'e.g., 456',
                      maxLength: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildInputRow(
                      'Enter Points :',
                      _pointsController,
                      hintText: 'e.g., 100',
                      maxLength: 4,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: _addBid,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
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
                          'Sangam',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Points',
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
                                      bid['sangam']!,
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
            cursorColor: Colors.orange,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              if (maxLength != null)
                LengthLimitingTextInputFormatter(maxLength),
            ],
            onTap: _clearMessage,
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
                borderSide: BorderSide(color: Colors.orange, width: 2),
              ),
              suffixIcon: const Icon(
                Icons.arrow_forward,
                color: Colors.orange,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPannaInputRow(
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
                  controller.text = textEditingController.text;
                  controller.selection = textEditingController.selection;

                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      if (maxLength != null)
                        LengthLimitingTextInputFormatter(maxLength),
                    ],
                    onTap: _clearMessage,
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
                        borderSide: BorderSide(color: Colors.orange, width: 2),
                      ),
                      suffixIcon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    onSubmitted: (value) => onFieldSubmitted(),
                  );
                },
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return _allPannas.where((String option) {
                return option.startsWith(textEditingValue.text);
              });
            },
            onSelected: (String selection) {
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
                            : options.length * 48.0,
                        width: 150,
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

// import 'dart:async'; // For Timer
// import 'dart:convert'; // For jsonEncode, json.decode
// import 'dart:developer'; // For log
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // For TextInputFormatter
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
// import 'package:http/http.dart' as http; // For API calls
// import 'package:intl/intl.dart'; // Import for date formatting
//
// import '../../components/AnimatedMessageBar.dart';
// import '../../components/BidConfirmationDialog.dart'; // Import the BidConfirmationDialog
// // Assuming these are also in your components folder
// import '../../components/BidFailureDialog.dart'; // Make sure you have this file
// import '../../components/BidSuccessDialog.dart'; // Make sure you have this file
// import '../../ulits/Constents.dart'; // Import the Constants file for API endpoint
//
// class FullSangamBoardScreen extends StatefulWidget {
//   final String screenTitle;
//   final int gameId;
//   final String gameType; // e.g., "FullSangam"
//
//   const FullSangamBoardScreen({
//     Key? key,
//     required this.screenTitle,
//     required this.gameType,
//     required this.gameId,
//   }) : super(key: key);
//
//   @override
//   State<FullSangamBoardScreen> createState() => _FullSangamBoardScreenState();
// }
//
// class _FullSangamBoardScreenState extends State<FullSangamBoardScreen> {
//   final TextEditingController _openPannaController = TextEditingController();
//   final TextEditingController _closePannaController = TextEditingController();
//   final TextEditingController _pointsController = TextEditingController();
//
//   List<Map<String, String>> _bids = [];
//   late GetStorage storage = GetStorage();
//   late String accessToken;
//   late String registerId;
//   late String preferredLanguage;
//   bool accountStatus = false;
//   late int walletBalance;
//
//   // State to manage API call in progress
//   bool _isApiCalling = false;
//
//   // Placeholder for device info. In a real app, these would be dynamic.
//   final String _deviceId = 'test_device_id_flutter';
//   final String _deviceName = 'test_device_name_flutter';
//
//   // State management for AnimatedMessageBar
//   String? _messageToShow;
//   bool _isErrorForMessage = false;
//   Key _messageBarKey = UniqueKey(); // Key to force rebuild/re-animation
//
//   @override
//   void initState() {
//     super.initState();
//     _loadInitialData();
//     _setupStorageListeners();
//   }
//
//   // Load initial data from GetStorage
//   Future<void> _loadInitialData() async {
//     accessToken = storage.read('accessToken') ?? '';
//     registerId = storage.read('registerId') ?? '';
//     accountStatus = storage.read('accountStatus') ?? false;
//     preferredLanguage = storage.read('selectedLanguage') ?? 'en';
//
//     final dynamic storedWalletBalance = storage.read('walletBalance');
//     if (storedWalletBalance is String) {
//       walletBalance = int.tryParse(storedWalletBalance) ?? 0;
//     } else if (storedWalletBalance is int) {
//       walletBalance = storedWalletBalance;
//     } else {
//       walletBalance = 0;
//     }
//   }
//
//   // Set up listeners for GetStorage keys
//   void _setupStorageListeners() {
//     storage.listenKey('accessToken', (value) {
//       if (mounted) setState(() => accessToken = value ?? '');
//     });
//
//     storage.listenKey('registerId', (value) {
//       if (mounted) setState(() => registerId = value ?? '');
//     });
//
//     storage.listenKey('accountStatus', (value) {
//       if (mounted) setState(() => accountStatus = value ?? false);
//     });
//
//     storage.listenKey('selectedLanguage', (value) {
//       if (mounted) setState(() => preferredLanguage = value ?? 'en');
//     });
//
//     storage.listenKey('walletBalance', (value) {
//       if (mounted) {
//         setState(() {
//           if (value is String) {
//             walletBalance = int.tryParse(value) ?? 0;
//           } else if (value is int) {
//             walletBalance = value;
//           } else {
//             walletBalance = 0;
//           }
//         });
//       }
//     });
//   }
//
//   // List of all possible 3-digit pannas for suggestions (100-999)
//   static final List<String> _allPannas = List.generate(
//     900,
//     (index) => (index + 100).toString(),
//   );
//
//   @override
//   void dispose() {
//     _openPannaController.dispose();
//     _closePannaController.dispose();
//     _pointsController.dispose();
//     super.dispose();
//   }
//
//   // Helper method to show messages using AnimatedMessageBar
//   void _showMessage(String message, {bool isError = false}) {
//     setState(() {
//       _messageToShow = message;
//       _isErrorForMessage = isError;
//       _messageBarKey = UniqueKey(); // Update key to trigger animation
//     });
//   }
//
//   // Helper method to clear the message bar
//   void _clearMessage() {
//     if (mounted) {
//       setState(() {
//         _messageToShow = null;
//       });
//     }
//   }
//
//   void _addBid() {
//     if (_isApiCalling) return; // Prevent adding bids while API is in progress
//     _clearMessage(); // Clear any previous messages
//     final openPanna = _openPannaController.text.trim();
//     final closePanna = _closePannaController.text.trim();
//     final points = _pointsController.text.trim();
//
//     // 1. Validate Open Panna (3 digits, 100-999)
//     if (openPanna.isEmpty ||
//         openPanna.length != 3 ||
//         int.tryParse(openPanna) == null) {
//       _showMessage(
//         'Please enter a 3-digit number for Open Panna.',
//         isError: true,
//       );
//       return;
//     }
//     int? parsedOpenPanna = int.tryParse(openPanna);
//     if (parsedOpenPanna == null ||
//         parsedOpenPanna < 100 ||
//         parsedOpenPanna > 999) {
//       _showMessage('Open Panna must be between 100 and 999.', isError: true);
//       return;
//     }
//
//     // 2. Validate Close Panna (3 digits, 100-999)
//     if (closePanna.isEmpty ||
//         closePanna.length != 3 ||
//         int.tryParse(closePanna) == null) {
//       _showMessage(
//         'Please enter a 3-digit number for Close Panna.',
//         isError: true,
//       );
//       return;
//     }
//     int? parsedClosePanna = int.tryParse(closePanna);
//     if (parsedClosePanna == null ||
//         parsedClosePanna < 100 ||
//         parsedClosePanna > 999) {
//       _showMessage('Close Panna must be between 100 and 999.', isError: true);
//       return;
//     }
//
//     // 3. Validate Points (10 to 1000)
//     int? parsedPoints = int.tryParse(points);
//     if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
//       _showMessage('Points must be between 10 and 1000.', isError: true);
//       return;
//     }
//
//     // Construct the Sangam string (Open Panna - Close Panna for Full Sangam)
//     final sangam = '$openPanna-$closePanna';
//
//     setState(() {
//       // Check if an existing bid with the same Sangam already exists
//       int existingIndex = _bids.indexWhere((bid) => bid['sangam'] == sangam);
//
//       if (existingIndex != -1) {
//         // If it exists, update the points of the existing bid
//         _bids[existingIndex]['points'] =
//             (int.parse(_bids[existingIndex]['points']!) + parsedPoints)
//                 .toString();
//         _showMessage('Updated points for $sangam.');
//       } else {
//         // Otherwise, add a new bid
//         _bids.add({
//           "sangam": sangam,
//           "points": points,
//           "openPanna": openPanna,
//           "closePanna": closePanna,
//           "type": "FullSangam", // Indicate game type for API payload
//         });
//         _showMessage('Added bid: $sangam with $points points.');
//       }
//
//       // Clear controllers after adding/updating
//       _openPannaController.clear();
//       _closePannaController.clear();
//       _pointsController.clear();
//     });
//   }
//
//   void _removeBid(int index) {
//     if (_isApiCalling) return; // Prevent removing bids while API is in progress
//     _clearMessage();
//     setState(() {
//       final removedSangam = _bids[index]['sangam'];
//       _bids.removeAt(index);
//       _showMessage('Bid for $removedSangam removed from list.');
//     });
//   }
//
//   int _getTotalPoints() {
//     return _bids.fold(
//       0,
//       (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
//     );
//   }
//
//   void _showConfirmationDialog() {
//     _clearMessage();
//     if (_isApiCalling) return; // Prevent showing dialog if API is in progress
//
//     if (_bids.isEmpty) {
//       _showMessage('Please add at least one bid.', isError: true);
//       return;
//     }
//
//     final int totalPoints = _getTotalPoints();
//
//     if (walletBalance < totalPoints) {
//       _showMessage(
//         'Insufficient wallet balance to place this bid.',
//         isError: true,
//       );
//       return;
//     }
//
//     // Prepare bids list for the dialog
//     List<Map<String, String>> bidsForDialog = _bids.map((bid) {
//       return {
//         "pana": bid['openPanna']!, // Open Panna
//         "digit": bid['closePanna']!, // Close Panna
//         "points": bid['points']!,
//         "type": bid['type']!, // "FullSangam"
//         "sangam": bid['sangam']!, // For display in dialog
//         "jodi": "", // Not applicable for Sangam, but common in bid payloads
//       };
//     }).toList();
//
//     final String formattedDate = DateFormat(
//       'dd MMM yyyy, hh:mm a',
//     ).format(DateTime.now());
//
//     showDialog(
//       context: context,
//       barrierDismissible: false, // User must interact with the dialog
//       builder: (BuildContext dialogContext) {
//         return BidConfirmationDialog(
//           gameTitle: widget.screenTitle,
//           gameDate: formattedDate,
//           bids: bidsForDialog,
//           totalBids: bidsForDialog.length,
//           totalBidsAmount: totalPoints,
//           walletBalanceBeforeDeduction: walletBalance,
//           walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameType, // Pass the gameType (e.g., "FullSangam")
//           onConfirm: () async {
//             Navigator.pop(dialogContext); // Dismiss the confirmation dialog
//             setState(() {
//               _isApiCalling = true; // Set API calling state to true
//             });
//             bool success = await _placeFinalBids();
//             if (success) {
//               setState(() {
//                 _bids.clear(); // Clear bids on successful submission
//               });
//               // No need to show success message here as BidSuccessDialog does it
//             }
//             if (mounted) {
//               setState(() {
//                 _isApiCalling = false; // Reset API calling state
//               });
//             }
//           },
//         );
//       },
//     );
//   }
//
//   // Place final bids via API
//   Future<bool> _placeFinalBids() async {
//     String url;
//     // For Sangam, typically it's 'place-bid' but with specific gameType/sessionType
//     // Ensure that widget.gameType matches the API's expectation for Sangam.
//     // Assuming 'place-bid' is the general endpoint for non-jackpot/starline.
//     if (widget.gameType.toLowerCase().contains('jackpot')) {
//       url = '${Constant.apiEndpoint}place-jackpot-bid';
//     } else if (widget.gameType.toLowerCase().contains('starline')) {
//       url = '${Constant.apiEndpoint}place-starline-bid';
//     } else {
//       url = '${Constant.apiEndpoint}place-bid'; // General bid placement
//     }
//
//     if (accessToken.isEmpty || registerId.isEmpty) {
//       if (mounted) {
//         await showDialog(
//           // Await dialog
//           context: context,
//           barrierDismissible: false,
//           builder: (BuildContext context) {
//             return const BidFailureDialog(
//               errorMessage: 'Authentication error. Please log in again.',
//             );
//           },
//         );
//       }
//       return false;
//     }
//
//     final headers = {
//       'deviceId': _deviceId,
//       'deviceName': _deviceName,
//       'accessStatus': accountStatus ? '1' : '0', // Convert bool to '1' or '0'
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $accessToken',
//     };
//
//     final List<Map<String, dynamic>> bidPayload = _bids.map((bid) {
//       return {
//         // For Full Sangam, typically you send both openPana and closePana
//         "sessionType": bid['type']!.toUpperCase(), // "FULLSANGAM"
//         "digit":
//             bid['closePanna']!, // Often the close panna is sent as 'digit' in some APIs
//         "pana": bid['openPanna']!, // Open panna
//         "bidAmount": int.tryParse(bid['points'] ?? '0') ?? 0,
//         // You might need to adjust 'digit' and 'pana' keys based on your specific API schema
//       };
//     }).toList();
//
//     final body = jsonEncode({
//       "registerId": registerId,
//       "gameId": widget.gameId,
//       "bidAmount": _getTotalPoints(),
//       "gameType":
//           widget.gameType, // Use the gameType from the widget's properties
//       "bid": bidPayload,
//     });
//
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
//       log('API Response for Final Bid Submission: ${responseBody}');
//
//       if (response.statusCode == 200 &&
//           (responseBody['status'] == true ||
//               responseBody['status'] == 'true')) {
//         // Update wallet balance in GetStorage and local state on successful bid
//         int currentWallet = walletBalance;
//         int deductedAmount = _getTotalPoints();
//         int newWalletBalance = currentWallet - deductedAmount;
//         await storage.write(
//           'walletBalance',
//           newWalletBalance, // Storing as int if possible, or string based on preference.
//           // Your storage listenKey handles both.
//         );
//         if (mounted) {
//           setState(() {
//             walletBalance = newWalletBalance; // Update local state
//           });
//           await showDialog(
//             // Await success dialog
//             context: context,
//             barrierDismissible: false,
//             builder: (BuildContext context) {
//               return const BidSuccessDialog();
//             },
//           );
//           _clearMessage(); // Clear message after success dialog dismissal
//         }
//         return true; // Indicate success
//       } else {
//         String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
//         if (mounted) {
//           await showDialog(
//             // Await failure dialog
//             context: context,
//             barrierDismissible: false,
//             builder: (BuildContext context) {
//               return BidFailureDialog(errorMessage: errorMessage);
//             },
//           );
//         }
//         return false; // Indicate failure
//       }
//     } catch (e) {
//       log('Network error during bid submission: $e');
//       if (mounted) {
//         await showDialog(
//           // Await failure dialog
//           context: context,
//           barrierDismissible: false,
//           builder: (BuildContext context) {
//             return const BidFailureDialog(
//               errorMessage:
//                   'Network error. Please check your internet connection.',
//             );
//           },
//         );
//       }
//       return false; // Indicate failure
//     }
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
//           Center(
//             child: Text(
//               walletBalance.toString(), // Display actual wallet balance
//               style: GoogleFonts.poppins(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//         ],
//       ),
//       body: Stack(
//         // Use Stack to overlay the message bar
//         children: [
//           Column(
//             children: [
//               Padding(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16.0,
//                   vertical: 12.0,
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildPannaInputRow(
//                       'Enter Open Panna :',
//                       _openPannaController,
//                       hintText: 'e.g., 123',
//                       maxLength: 3,
//                     ),
//                     const SizedBox(height: 16),
//                     _buildPannaInputRow(
//                       'Enter Close Panna :',
//                       _closePannaController,
//                       hintText: 'e.g., 456',
//                       maxLength: 3,
//                     ),
//                     const SizedBox(height: 16),
//                     _buildInputRow(
//                       'Enter Points :',
//                       _pointsController,
//                       hintText: 'e.g., 100',
//                       maxLength: 4,
//                     ),
//                     const SizedBox(height: 20),
//                     SizedBox(
//                       width: double.infinity,
//                       height: 45,
//                       child: ElevatedButton(
//                         onPressed: _addBid,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.orange,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                         ),
//                         child: Text(
//                           "ADD",
//                           style: GoogleFonts.poppins(
//                             color: Colors.white,
//                             fontWeight: FontWeight.w600,
//                             letterSpacing: 0.5,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const Divider(thickness: 1),
//
//               // Table Headers
//               if (_bids.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16.0,
//                     vertical: 8.0,
//                   ),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           'Sangam',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         child: Text(
//                           'Points',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 48), // Space for delete icon
//                     ],
//                   ),
//                 ),
//               if (_bids.isNotEmpty) const Divider(thickness: 1),
//
//               // Dynamic List of Bids
//               Expanded(
//                 child: _bids.isEmpty
//                     ? Center(
//                         child: Text(
//                           'No Bids Placed',
//                           style: GoogleFonts.poppins(color: Colors.grey),
//                         ),
//                       )
//                     : ListView.builder(
//                         itemCount: _bids.length,
//                         itemBuilder: (context, index) {
//                           final bid = _bids[index];
//                           return Container(
//                             margin: const EdgeInsets.symmetric(
//                               horizontal: 10,
//                               vertical: 4,
//                             ),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(8),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.grey.withOpacity(0.2),
//                                   spreadRadius: 1,
//                                   blurRadius: 3,
//                                   offset: const Offset(0, 1),
//                                 ),
//                               ],
//                             ),
//                             child: Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 16.0,
//                                 vertical: 8.0,
//                               ),
//                               child: Row(
//                                 children: [
//                                   Expanded(
//                                     child: Text(
//                                       bid['sangam']!,
//                                       style: GoogleFonts.poppins(),
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: Text(
//                                       bid['points']!,
//                                       style: GoogleFonts.poppins(),
//                                     ),
//                                   ),
//                                   IconButton(
//                                     icon: const Icon(
//                                       Icons.delete,
//                                       color: Colors.red,
//                                     ),
//                                     onPressed: () => _removeBid(index),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//               ),
//               // Bottom Bar (conditionally rendered)
//               if (_bids.isNotEmpty) _buildBottomBar(),
//             ],
//           ),
//           // AnimatedMessageBar positioned at the top
//           if (_messageToShow != null)
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               child: AnimatedMessageBar(
//                 key: _messageBarKey, // Use the unique key
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
//   // Helper widget for standard input rows
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
//             cursorColor: Colors.orange,
//             controller: controller,
//             keyboardType: TextInputType.number,
//             inputFormatters: [
//               FilteringTextInputFormatter.digitsOnly,
//               if (maxLength != null)
//                 LengthLimitingTextInputFormatter(maxLength),
//             ],
//             onTap: _clearMessage, // Clear message on tap
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
//                 borderSide: BorderSide(color: Colors.orange, width: 2),
//               ),
//               suffixIcon: const Icon(
//                 Icons.arrow_forward,
//                 color: Colors.orange,
//                 size: 20,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   // Helper widget for Panna input with Autocomplete suggestions
//   Widget _buildPannaInputRow(
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
//                   controller.selection = textEditingController.selection;
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
//                     onTap: _clearMessage, // Clear message on tap
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
//                         borderSide: BorderSide(color: Colors.orange, width: 2),
//                       ),
//                       suffixIcon: const Icon(
//                         Icons.arrow_forward,
//                         color: Colors.orange,
//                         size: 20,
//                       ),
//                     ),
//                     onSubmitted: (value) => onFieldSubmitted(),
//                   );
//                 },
//             optionsBuilder: (TextEditingValue textEditingValue) {
//               if (textEditingValue.text.isEmpty) {
//                 return const Iterable<String>.empty();
//               }
//               return _allPannas.where((String option) {
//                 return option.startsWith(textEditingValue.text);
//               });
//             },
//             onSelected: (String selection) {
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
//                             : options.length * 48.0,
//                         width: 150,
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
//             onPressed: _showConfirmationDialog, // Call the confirmation dialog
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.orange[700],
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             child: Text(
//               'SUBMIT',
//               style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
