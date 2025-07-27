// lib/screens/half_sangam_b_board_screen.dart
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

class HalfSangamBBoardScreen extends StatefulWidget {
  final String screenTitle; // e.g., "SRIDEVI NIGHT, HALF SANGAM"
  final String gameType; // This will be "halfSangamB"
  final int gameId;
  final String gameName; // e.g., "SRIDEVI NIGHT"

  const HalfSangamBBoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameType,
    required this.gameId,
    required this.gameName,
  }) : super(key: key);

  @override
  State<HalfSangamBBoardScreen> createState() => _HalfSangamBBoardScreenState();
}

class _HalfSangamBBoardScreenState extends State<HalfSangamBBoardScreen> {
  final TextEditingController _ankController = TextEditingController();
  final TextEditingController _pannaController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  // Each map will contain: {'ank': '9', 'panna': '119', 'points': '125'}
  List<Map<String, String>> _bids = [];
  late GetStorage storage = GetStorage();
  late BidService _bidService;
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance;

  bool _isApiCalling = false;

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  static final List<String> _allPannas = [
    "100",
    "110",
    "112",
    "113",
    "114",
    "115",
    "116",
    "117",
    "118",
    "119",
    "122",
    "133",
    "144",
    "155",
    "166",
    "177",
    "188",
    "199",
    "200",
    "220",
    "223",
    "224",
    "225",
    "226",
    "227",
    "228",
    "229",
    "233",
    "244",
    "255",
    "266",
    "277",
    "288",
    "299",
    "300",
    "330",
    "334",
    "335",
    "336",
    "337",
    "338",
    "339",
    "344",
    "355",
    "366",
    "377",
    "388",
    "399",
    "400",
    "440",
    "445",
    "446",
    "447",
    "448",
    "449",
    "455",
    "466",
    "477",
    "488",
    "499",
    "500",
    "550",
    "556",
    "557",
    "558",
    "559",
    "566",
    "577",
    "588",
    "599",
    "600",
    "660",
    "667",
    "668",
    "669",
    "677",
    "688",
    "699",
    "700",
    "770",
    "778",
    "779",
    "788",
    "799",
    "800",
    "880",
    "889",
    "899",
    "900",
    "990",
  ];

  @override
  void initState() {
    super.initState();
    _bidService = BidService(storage);
    _loadInitialData();
    _setupStorageListeners();
  }

  @override
  void dispose() {
    _ankController.dispose();
    _pannaController.dispose();
    _pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = storage.read('accountStatus') ?? false;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is int) {
      walletBalance = storedWalletBalance;
    } else if (storedWalletBalance is String) {
      walletBalance = int.tryParse(storedWalletBalance) ?? 0;
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

    storage.listenKey('walletBalance', (value) {
      if (mounted) {
        setState(() {
          if (value is int) {
            walletBalance = value;
          } else if (value is String) {
            walletBalance = int.tryParse(value) ?? 0;
          } else {
            walletBalance = 0;
          }
        });
      }
    });

    storage.listenKey('selectedLanguage', (value) {
      if (mounted) setState(() => preferredLanguage = value ?? 'en');
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    _messageDismissTimer?.cancel();

    if (!mounted) return;

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

  void _addBid() {
    if (_isApiCalling) return;

    _clearMessage();
    final ank = _ankController.text.trim();
    final panna = _pannaController.text.trim();
    final points = _pointsController.text.trim();

    if (ank.isEmpty ||
        ank.length != 1 ||
        int.tryParse(ank) == null ||
        int.parse(ank) < 0 ||
        int.parse(ank) > 9) {
      _showMessage('Please enter a single digit for Ank (0-9).', isError: true);
      return;
    }

    if (panna.isEmpty || panna.length != 3 || !_allPannas.contains(panna)) {
      _showMessage('Please enter a valid 3-digit Panna.', isError: true);
      return;
    }

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    setState(() {
      // For Half Sangam B, the unique combination is Ank and Panna
      int existingIndex = _bids.indexWhere(
        (bid) => bid['ank'] == ank && bid['panna'] == panna,
      );

      if (existingIndex != -1) {
        _bids[existingIndex]['points'] =
            (int.parse(_bids[existingIndex]['points']!) + parsedPoints)
                .toString();
        _showMessage('Updated points for $ank-$panna.');
      } else {
        _bids.add({
          "ank": ank,
          "panna": panna,
          "points": points,
          // 'gameTypeCategory' is not directly used in the _bids list for THIS BidService,
          // but we'll use it to construct the unique key for the map sent to BidService.
          // For consistency with previous comprehensive service, keeping it internal is fine.
        });
        _showMessage('Added bid: $ank-$panna with $points points.');
      }

      _ankController.clear();
      _pannaController.clear();
      _pointsController.clear();
    });
  }

  void _removeBid(int index) {
    if (_isApiCalling) return;

    _clearMessage();
    setState(() {
      final removedSangam = '${_bids[index]['ank']}-${_bids[index]['panna']}';
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
        "digit": bid['ank']!, // Ank for display
        "pana": bid['panna']!, // Panna for display
        "points": bid['points']!,
        "type": widget.screenTitle, // Use screen title as Game Type for dialog
        "sangam":
            '${bid['ank']}-${bid['panna']}', // Combined for display in dialog
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
          gameTitle: widget.gameName,
          gameDate: formattedDate,
          bids: bidsForDialog,
          totalBids: _bids.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            Navigator.pop(dialogContext);
            if (mounted) {
              setState(() {
                _isApiCalling = true;
              });
            }
            final Map<String, dynamic> result = await _placeFinalBids();
            if (result['status'] == true) {
              if (mounted) {
                setState(() {
                  _bids.clear();
                });
                // Update wallet balance in storage after successful bid
                final int newBalance =
                    (result['data']?['wallet_balance'] as num?)?.toInt() ??
                    (walletBalance - totalPoints);
                await _bidService.updateWalletBalance(newBalance);

                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const BidSuccessDialog();
                  },
                );
              }
            } else {
              if (mounted) {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return BidFailureDialog(
                      errorMessage:
                          result['msg'] ??
                          "Bid submission failed. Please try again.",
                    );
                  },
                );
              }
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

  // Place final bids using BidService, adapting data to its expected format
  Future<Map<String, dynamic>> _placeFinalBids() async {
    // Transform _bids list into Map<String, String> bidAmounts
    // For Half Sangam, the 'digit' key in bidAmounts will be "Ank-Pana"
    Map<String, String> bidAmountsMap = {};
    for (var bid in _bids) {
      final String digitKey = '${bid['ank']}-${bid['panna']}'; // e.g., "9-119"
      bidAmountsMap[digitKey] = bid['points']!;
    }

    // Determine selectedGameType for the BidService. This is usually "OPEN" for Half Sangam B
    final String selectedSessionType = "OPEN";

    final Map<String, dynamic> result = await _bidService.placeFinalBids(
      gameName: widget.gameName,
      accessToken: accessToken,
      registerId: registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: accountStatus,
      bidAmounts: bidAmountsMap, // Pass the transformed map
      selectedGameType: selectedSessionType, // Pass the determined session type
      gameId: widget.gameId,
      gameType: widget.gameType, // Pass the gameType (e.g., "halfSangamB")
      totalBidAmount: _getTotalPoints(),
    );

    return result;
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
          const Icon(
            Icons.account_balance_wallet_outlined,
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
                    _buildInputRow(
                      'Ank',
                      _ankController,
                      hintText: 'e.g., 9',
                      maxLength: 1,
                    ),
                    const SizedBox(height: 16),
                    _buildPannaInputRow(
                      'Pana',
                      _pannaController,
                      hintText: 'e.g., 119',
                      maxLength: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildInputRow(
                      'Enter Points :',
                      _pointsController,
                      hintText: 'Enter Amount',
                      maxLength: 4,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: _isApiCalling ? null : _addBid,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: _isApiCalling
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2,
                              )
                            : Text(
                                "ADD BID",
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
                        flex: 2,
                        child: Text(
                          'Digit',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Amount',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
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
                          'No bids added yet',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _bids.length,
                        itemBuilder: (context, index) {
                          final bid = _bids[index];
                          final String displayDigit = bid['ank']!;
                          final String displayPana = bid['panna']!;
                          final String displaySangam =
                              '$displayDigit - $displayPana';

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
                                      displaySangam,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      bid['points']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      widget.screenTitle,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: _isApiCalling
                                        ? null
                                        : () => _removeBid(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              _buildBottomBar(),
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
            cursorColor: Colors.amber,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              if (maxLength != null)
                LengthLimitingTextInputFormatter(maxLength),
            ],
            onTap: _clearMessage,
            enabled: !_isApiCalling,
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
                    enabled: !_isApiCalling,
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
                'Bid',
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
                'Total',
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
            onPressed: (_isApiCalling || _bids.isEmpty)
                ? null
                : _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: (_isApiCalling || _bids.isEmpty)
                  ? Colors.grey
                  : Colors.amber,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: _isApiCalling
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  )
                : Text(
                    'SUBMIT',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
