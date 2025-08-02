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

class RedBracketBoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;
  final String gameType;

  const RedBracketBoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId,
    required this.gameType,
  }) : super(key: key);

  @override
  State<RedBracketBoardScreen> createState() => _RedBracketBoardScreenState();
}

class _RedBracketBoardScreenState extends State<RedBracketBoardScreen> {
  final TextEditingController _redBracketController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  List<Map<String, String>> _bids = [];

  late GetStorage storage = GetStorage();
  late String _accessToken;
  late String _registerId;
  late String _preferredLanguage;
  bool _accountStatus = false;
  late int _walletBalance;
  bool _isApiCalling = false; // Added to manage API call state

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  late BidService _bidService; // Declare BidService instance

  static final List<String> _allJodis = List.generate(
    100,
    (index) => index.toString().padLeft(2, '0'),
  );

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupStorageListeners();
    _bidService = BidService(storage); // Initialize BidService
  }

  Future<void> _loadInitialData() async {
    _accessToken = storage.read('accessToken') ?? '';
    _registerId = storage.read('registerId') ?? '';
    _accountStatus = storage.read('accountStatus') ?? false;
    _preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is String) {
      _walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else if (storedWalletBalance is int) {
      _walletBalance = storedWalletBalance;
    } else {
      _walletBalance = 0;
    }
  }

  void _setupStorageListeners() {
    storage.listenKey('accessToken', (value) {
      if (mounted) {
        setState(() {
          _accessToken = value ?? '';
        });
      }
    });

    storage.listenKey('registerId', (value) {
      if (mounted) {
        setState(() {
          _registerId = value ?? '';
        });
      }
    });

    storage.listenKey('accountStatus', (value) {
      if (mounted) {
        setState(() {
          _accountStatus = value ?? false;
        });
      }
    });

    storage.listenKey('selectedLanguage', (value) {
      if (mounted) {
        setState(() {
          _preferredLanguage = value ?? 'en';
        });
      }
    });

    storage.listenKey('walletBalance', (value) {
      if (mounted) {
        setState(() {
          if (value is String) {
            _walletBalance = int.tryParse(value) ?? 0;
          } else if (value is int) {
            _walletBalance = value;
          } else {
            _walletBalance = 0;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _redBracketController.dispose();
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
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  void _addBid() {
    if (_isApiCalling) return; // Prevent adding bids while API is in progress
    _clearMessage();
    final redBracket = _redBracketController.text.trim();
    final points = _pointsController.text.trim();

    if (redBracket.isEmpty ||
        redBracket.length != 2 ||
        int.tryParse(redBracket) == null) {
      _showMessage(
        'Please enter a 2-digit number for Red Bracket (00-99).',
        isError: true,
      );
      return;
    }
    int? parsedRedBracket = int.tryParse(redBracket);
    if (parsedRedBracket == null ||
        parsedRedBracket < 0 ||
        parsedRedBracket > 99) {
      _showMessage('Red Bracket must be between 00 and 99.', isError: true);
      return;
    }

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    setState(() {
      int existingIndex = _bids.indexWhere((bid) => bid['jodi'] == redBracket);

      if (existingIndex != -1) {
        _bids[existingIndex]['points'] =
            (int.parse(_bids[existingIndex]['points']!) + parsedPoints)
                .toString();
        _showMessage('Updated points for Jodi $redBracket.');
      } else {
        _bids.add({"jodi": redBracket, "points": points, "type": "Jodi"});
        _showMessage('Added bid: Jodi $redBracket with $points points.');
      }

      _redBracketController.clear();
      _pointsController.clear();
    });
  }

  void _removeBid(int index) {
    if (_isApiCalling) return; // Prevent removing bids while API is in progress
    _clearMessage();
    setState(() {
      final removedJodi = _bids[index]['jodi'];
      _bids.removeAt(index);
      _showMessage('Bid for Jodi $removedJodi removed from list.');
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
    if (_isApiCalling) return; // Prevent showing dialog if API is in progress

    if (_bids.isEmpty) {
      _showMessage('Please add at least one bid.', isError: true);
      return;
    }

    final int totalPoints = _getTotalPoints();

    if (_walletBalance < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
      return;
    }

    List<Map<String, String>> bidsForDialog = _bids.map((bid) {
      return {
        "digit": bid['jodi']!,
        "pana": "",
        "points": bid['points']!,
        "type": bid['type']!,
        "jodi": bid['jodi']!,
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
          walletBalanceBeforeDeduction: _walletBalance,
          walletBalanceAfterDeduction: (_walletBalance - totalPoints)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            // Navigator.pop(dialogContext);
            setState(() {
              _isApiCalling = true; // Set API calling state to true
            });
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                _bids.clear();
              });
            }
            if (mounted) {
              setState(() {
                _isApiCalling = false; // Reset API calling state
              });
            }
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    if (_accessToken.isEmpty || _registerId.isEmpty) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return const BidFailureDialog(
              errorMessage: 'Authentication error. Please log in again.',
            );
          },
        );
      }
      return false;
    }

    // Prepare bidAmounts map for BidService
    Map<String, String> bidAmountsForService = {};
    for (var bid in _bids) {
      bidAmountsForService[bid['jodi']!] = bid['points']!;
    }

    final response = await _bidService.placeFinalBids(
      gameName: widget.screenTitle,
      accessToken: _accessToken,
      registerId: _registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: _accountStatus,
      bidAmounts: bidAmountsForService,
      selectedGameType:
          "JODI", // Assuming "Jodi" is the session type for Red Bracket
      gameId: widget.gameId,
      gameType: widget.gameType,
      totalBidAmount: _getTotalPoints(),
    );

    if (response['status'] == true) {
      int currentWallet = _walletBalance;
      int deductedAmount = _getTotalPoints();
      int newWalletBalance = currentWallet - deductedAmount;
      await _bidService.updateWalletBalance(
        newWalletBalance,
      ); // Use BidService to update balance

      if (mounted) {
        setState(() {
          _walletBalance = newWalletBalance;
        });
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return const BidSuccessDialog();
          },
        );
      }
      return true;
    } else {
      String errorMessage = response['msg'] ?? "Unknown error occurred.";
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
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
              _walletBalance.toString(),
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
                    _buildJodiInputRow(
                      'Enter Red Bracket',
                      _redBracketController,
                      hintText: 'e.g., 25',
                      maxLength: 2,
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
                          'Jodi',
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
              return _allJodis.where((String option) {
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

// import 'dart:async';
// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
//
// import '../../components/BidConfirmationDialog.dart';
// import '../../components/BidFailureDialog.dart'; // Make sure you have this file
// import '../../components/BidSuccessDialog.dart'; // Make sure you have this file
// import '../../ulits/Constents.dart';
//
// class AnimatedMessageBar extends StatefulWidget {
//   final String message;
//   final bool isError;
//   final VoidCallback? onDismissed;
//
//   const AnimatedMessageBar({
//     Key? key,
//     required this.message,
//     this.isError = false,
//     this.onDismissed,
//   }) : super(key: key);
//
//   @override
//   _AnimatedMessageBarState createState() => _AnimatedMessageBarState();
// }
//
// class _AnimatedMessageBarState extends State<AnimatedMessageBar> {
//   double _height = 0.0;
//   Timer? _visibilityTimer;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _showBar();
//     });
//   }
//
//   void _showBar() {
//     if (!mounted) return;
//     setState(() {
//       _height = 48.0;
//     });
//
//     _visibilityTimer = Timer(const Duration(seconds: 2), () {
//       if (!mounted) return;
//       setState(() {
//         _height = 0.0;
//       });
//       Timer(const Duration(milliseconds: 300), () {
//         if (mounted && widget.onDismissed != null) {
//           widget.onDismissed!();
//         }
//       });
//     });
//   }
//
//   @override
//   void dispose() {
//     _visibilityTimer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedContainer(
//       height: _height,
//       duration: const Duration(milliseconds: 300),
//       curve: Curves.easeInOut,
//       color: widget.isError ? Colors.red : Colors.green,
//       alignment: Alignment.center,
//       child: _height > 0.0
//           ? Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16.0),
//               child: Row(
//                 children: [
//                   Icon(
//                     widget.isError
//                         ? Icons.error_outline
//                         : Icons.check_circle_outline,
//                     color: Colors.white,
//                     size: 20,
//                   ),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       widget.message,
//                       style: GoogleFonts.poppins(
//                         color: Colors.white,
//                         fontSize: 13,
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           : const SizedBox.shrink(),
//     );
//   }
// }
//
// class RedBracketBoardScreen extends StatefulWidget {
//   final String screenTitle;
//   final int gameId;
//   final String gameType;
//
//   const RedBracketBoardScreen({
//     Key? key,
//     required this.screenTitle,
//     required this.gameId,
//     required this.gameType,
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
//   List<Map<String, String>> _bids = [];
//
//   late GetStorage storage = GetStorage();
//   late String _accessToken; // Renamed for consistency
//   late String _registerId; // Renamed for consistency
//   late String _preferredLanguage; // Renamed for consistency
//   bool _accountStatus = false; // Renamed for consistency
//   late int _walletBalance; // Renamed for consistency
//
//   final String _deviceId = 'test_device_id_flutter';
//   final String _deviceName = 'test_device_name_flutter';
//
//   static final List<String> _allJodis = List.generate(
//     100,
//     (index) => index.toString().padLeft(2, '0'),
//   );
//
//   String? _messageToShow;
//   bool _isErrorForMessage = false;
//   Key _messageBarKey = UniqueKey();
//
//   @override
//   void initState() {
//     super.initState();
//     _loadInitialData();
//     _setupStorageListeners();
//   }
//
//   Future<void> _loadInitialData() async {
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
//   }
//
//   void _setupStorageListeners() {
//     storage.listenKey('accessToken', (value) {
//       setState(() {
//         _accessToken = value ?? '';
//       });
//     });
//
//     storage.listenKey('registerId', (value) {
//       setState(() {
//         _registerId = value ?? '';
//       });
//     });
//
//     storage.listenKey('accountStatus', (value) {
//       setState(() {
//         _accountStatus = value ?? false;
//       });
//     });
//
//     storage.listenKey('selectedLanguage', (value) {
//       setState(() {
//         _preferredLanguage = value ?? 'en';
//       });
//     });
//
//     storage.listenKey('walletBalance', (value) {
//       setState(() {
//         if (value is String) {
//           _walletBalance = int.tryParse(value) ?? 0;
//         } else if (value is int) {
//           _walletBalance = value;
//         } else {
//           _walletBalance = 0;
//         }
//       });
//     });
//   }
//
//   @override
//   void dispose() {
//     _redBracketController.dispose();
//     _pointsController.dispose();
//     super.dispose();
//   }
//
//   void _showMessage(String message, {bool isError = false}) {
//     if (!mounted) return;
//     setState(() {
//       _messageToShow = message;
//       _isErrorForMessage = isError;
//       _messageBarKey = UniqueKey();
//     });
//   }
//
//   void _clearMessage() {
//     if (mounted) {
//       setState(() {
//         _messageToShow = null;
//       });
//     }
//   }
//
//   void _addBid() {
//     _clearMessage();
//     final redBracket = _redBracketController.text.trim();
//     final points = _pointsController.text.trim();
//
//     if (redBracket.isEmpty ||
//         redBracket.length != 2 ||
//         int.tryParse(redBracket) == null) {
//       _showMessage(
//         'Please enter a 2-digit number for Red Bracket (00-99).',
//         isError: true,
//       );
//       return;
//     }
//     int? parsedRedBracket = int.tryParse(redBracket);
//     if (parsedRedBracket == null ||
//         parsedRedBracket < 0 ||
//         parsedRedBracket > 99) {
//       _showMessage('Red Bracket must be between 00 and 99.', isError: true);
//       return;
//     }
//
//     int? parsedPoints = int.tryParse(points);
//     if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
//       _showMessage('Points must be between 10 and 1000.', isError: true);
//       return;
//     }
//
//     setState(() {
//       int existingIndex = _bids.indexWhere((bid) => bid['jodi'] == redBracket);
//
//       if (existingIndex != -1) {
//         _bids[existingIndex]['points'] =
//             (int.parse(_bids[existingIndex]['points']!) + parsedPoints)
//                 .toString();
//         _showMessage('Updated points for Jodi $redBracket.');
//       } else {
//         _bids.add({"jodi": redBracket, "points": points, "type": "Jodi"});
//         _showMessage('Added bid: Jodi $redBracket with $points points.');
//       }
//
//       _redBracketController.clear();
//       _pointsController.clear();
//     });
//   }
//
//   void _removeBid(int index) {
//     _clearMessage();
//     setState(() {
//       final removedJodi = _bids[index]['jodi'];
//       _bids.removeAt(index);
//       _showMessage('Bid for Jodi $removedJodi removed from list.');
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
//   void _showConfirmationDialog() {
//     _clearMessage(); // Clear any transient message before showing a dialog
//
//     if (_bids.isEmpty) {
//       _showMessage('Please add at least one bid.', isError: true);
//       return;
//     }
//
//     final int totalPoints = _getTotalPoints();
//
//     if (_walletBalance < totalPoints) {
//       _showMessage(
//         'Insufficient wallet balance to place this bid.',
//         isError: true,
//       );
//       return;
//     }
//
//     List<Map<String, String>> bidsForDialog = _bids.map((bid) {
//       return {
//         "digit": bid['jodi']!,
//         "pana": "",
//         "points": bid['points']!,
//         "type": bid['type']!,
//         "jodi": bid['jodi']!,
//       };
//     }).toList();
//
//     final String formattedDate = DateFormat(
//       'dd MMM yyyy, hh:mm a',
//     ).format(DateTime.now());
//
//     // Await the confirmation dialog to ensure it completes before proceeding
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return BidConfirmationDialog(
//           gameTitle: widget.screenTitle,
//           gameDate: formattedDate,
//           bids: bidsForDialog,
//           totalBids: bidsForDialog.length,
//           totalBidsAmount: totalPoints,
//           walletBalanceBeforeDeduction: _walletBalance,
//           walletBalanceAfterDeduction: (_walletBalance - totalPoints)
//               .toString(),
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameType,
//           onConfirm: () async {
//             Navigator.pop(dialogContext); // Dismiss confirmation dialog
//             bool success = await _placeFinalBids();
//             if (success) {
//               setState(() {
//                 _bids.clear(); // Clear bids only on successful submission
//               });
//               // Success dialog is now handled inside _placeFinalBids
//             }
//           },
//         );
//       },
//     );
//   }
//
//   Future<bool> _placeFinalBids() async {
//     String apiUrl; // Changed `url` to `apiUrl` for consistency
//     if (widget.screenTitle.toLowerCase().contains('jackpot')) {
//       apiUrl = '${Constant.apiEndpoint}place-jackpot-bid';
//     } else if (widget.screenTitle.toLowerCase().contains('starline')) {
//       apiUrl = '${Constant.apiEndpoint}place-starline-bid';
//     } else {
//       apiUrl = '${Constant.apiEndpoint}place-bid';
//     }
//
//     if (_accessToken.isEmpty || _registerId.isEmpty) {
//       if (mounted) {
//         await showDialog(
//           // Use a dialog for critical errors
//           context: context,
//           builder: (BuildContext dialogContext) {
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
//       'accessStatus': _accountStatus ? '1' : '0',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $_accessToken',
//     };
//
//     final List<Map<String, dynamic>> bidPayload = _bids.map((bid) {
//       return {
//         "sessionType": bid['type']!.toUpperCase(),
//         "digit": bid['jodi']!,
//         "pana": "",
//         "bidAmount": int.tryParse(bid['points'] ?? '0') ?? 0,
//       };
//     }).toList();
//
//     final body = jsonEncode({
//       "registerId": _registerId,
//       "gameId": widget.gameId,
//       "bidAmount": _getTotalPoints(),
//       "gameType": widget.gameType,
//       "bid": bidPayload,
//     });
//
//     // Log the cURL and headers here
//     String curlCommand = 'curl -X POST \\';
//     curlCommand += '\n  $apiUrl \\';
//     headers.forEach((key, value) {
//       curlCommand += '\n  -H "$key: $value" \\';
//     });
//     curlCommand += '\n  -d \'$body\'';
//
//     log('CURL Command for Final Bid Submission:\n$curlCommand', name: 'BidAPI');
//     log('Request Headers for Final Bid Submission: $headers', name: 'BidAPI');
//     log('Request Body for Final Bid Submission: $body', name: 'BidAPI');
//
//     log('Placing final bids to URL: $apiUrl'); // Use apiUrl here
//     log('Request Body: $body');
//
//     try {
//       final response = await http.post(
//         Uri.parse(apiUrl),
//         headers: headers,
//         body: body,
//       );
//
//       log('Response Status Code: ${response.statusCode}', name: 'BidAPI');
//       log('Response Body: ${response.body}', name: 'BidAPI');
//
//       final Map<String, dynamic> responseBody = json.decode(response.body);
//
//       if (mounted) {
//         // Ensure widget is still mounted before showing dialog
//         if (response.statusCode == 200 && responseBody['status'] == true) {
//           int newWalletBalance = _walletBalance - _getTotalPoints();
//           await storage.write(
//             'walletBalance',
//             newWalletBalance.toString(),
//           ); // Await storage write
//           setState(() {
//             _walletBalance = newWalletBalance;
//           });
//
//           // Show success dialog
//           await showDialog(
//             context: context,
//             barrierDismissible: false,
//             builder: (BuildContext dialogContext) {
//               return const BidSuccessDialog();
//             },
//           );
//           return true;
//         } else {
//           String errorMessage =
//               responseBody['msg'] ?? "Unknown error occurred.";
//           // Show failure dialog
//           await showDialog(
//             context: context,
//             builder: (BuildContext dialogContext) {
//               return BidFailureDialog(errorMessage: errorMessage);
//             },
//           );
//           return false;
//         }
//       }
//       return false; // Fallback if not mounted
//     } catch (e) {
//       log('Network error during bid submission: $e', name: 'BidAPIError');
//       if (mounted) {
//         // Show network error dialog
//         await showDialog(
//           context: context,
//           builder: (BuildContext dialogContext) {
//             return const BidFailureDialog(
//               errorMessage:
//                   'Network error. Please check your internet connection.',
//             );
//           },
//         );
//       }
//       return false;
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F5F5),
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
//               _walletBalance.toString(), // Use _walletBalance
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
//                     _buildJodiInputRow(
//                       'Enter Red Bracket',
//                       _redBracketController,
//                       hintText: 'e.g., 25',
//                       maxLength: 2,
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
//                           'Jodi',
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
//                       const SizedBox(width: 48),
//                     ],
//                   ),
//                 ),
//               if (_bids.isNotEmpty) const Divider(thickness: 1),
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
//                                       bid['jodi']!,
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
//               if (_bids.isNotEmpty) _buildBottomBar(),
//             ],
//           ),
//           if (_messageToShow != null)
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               child: AnimatedMessageBar(
//                 key: _messageBarKey,
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
//             onTap: _clearMessage,
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
//                     onTap: _clearMessage,
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
//               return _allJodis.where((String option) {
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
//             onPressed: _showConfirmationDialog,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.orange[700],
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               elevation: 3,
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
