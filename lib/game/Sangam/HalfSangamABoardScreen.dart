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

class HalfSangamABoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;
  final String gameType;
  final String gameName;

  const HalfSangamABoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId,
    required this.gameType,
    required this.gameName,
  }) : super(key: key);

  @override
  State<HalfSangamABoardScreen> createState() => _HalfSangamABoardScreenState();
}

class _HalfSangamABoardScreenState extends State<HalfSangamABoardScreen> {
  final TextEditingController _openDigitController = TextEditingController();
  final TextEditingController _closePannaController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  List<Map<String, String>> _bids = [];
  late GetStorage _storage = GetStorage();
  late BidService _bidService;
  String _accessToken = '';
  String _registerId = '';
  String _preferredLanguage = 'en';
  bool _accountStatus = false;
  int _walletBalance = 0;

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
    _bidService = BidService(_storage);
    _loadInitialData();
    _setupStorageListeners();
  }

  @override
  void dispose() {
    _openDigitController.dispose();
    _closePannaController.dispose();
    _pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _accessToken = _storage.read('accessToken') ?? '';
    _registerId = _storage.read('registerId') ?? '';
    _accountStatus = _storage.read('accountStatus') ?? false;
    _preferredLanguage = _storage.read('selectedLanguage') ?? 'en';

    final dynamic storedWalletBalance = _storage.read('walletBalance');
    if (storedWalletBalance is int) {
      _walletBalance = storedWalletBalance;
    } else if (storedWalletBalance is String) {
      _walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else {
      _walletBalance = 0;
    }
  }

  void _setupStorageListeners() {
    _storage.listenKey('accessToken', (value) {
      if (mounted) {
        setState(() => _accessToken = value ?? '');
      }
    });

    _storage.listenKey('registerId', (value) {
      if (mounted) {
        setState(() => _registerId = value ?? '');
      }
    });

    _storage.listenKey('accountStatus', (value) {
      if (mounted) {
        setState(() => _accountStatus = value ?? false);
      }
    });

    _storage.listenKey('selectedLanguage', (value) {
      if (mounted) {
        setState(() => _preferredLanguage = value ?? 'en');
      }
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
    _clearMessage();
    if (_isApiCalling) {
      return;
    }

    final openDigit = _openDigitController.text.trim();
    final closePanna = _closePannaController.text.trim();
    final points = _pointsController.text.trim();

    if (openDigit.isEmpty ||
        openDigit.length != 1 ||
        int.tryParse(openDigit) == null) {
      _showMessage(
        'Please enter a single digit for Open Digit (0-9).',
        isError: true,
      );
      return;
    }
    int? parsedOpenDigit = int.tryParse(openDigit);
    if (parsedOpenDigit == null || parsedOpenDigit < 0 || parsedOpenDigit > 9) {
      _showMessage(
        'Open Digit must be a single digit between 0 and 9.',
        isError: true,
      );
      return;
    }

    if (closePanna.isEmpty ||
        closePanna.length != 3 ||
        !_allPannas.contains(closePanna)) {
      _showMessage(
        'Please enter a valid 3-digit Panna (e.g., 123).',
        isError: true,
      );
      return;
    }

    int? parsedPoints = int.tryParse(points);
    final int minBid =
        int.tryParse(_storage.read('minBid')?.toString() ?? '10') ?? 10;
    if (parsedPoints == null || parsedPoints < minBid || parsedPoints > 1000) {
      _showMessage('Points must be between $minBid and 1000.', isError: true);
      return;
    }

    final sangam = '$openDigit-$closePanna';

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
          "openDigit": openDigit,
          "closePanna": closePanna,
          "type": widget.gameType,
        });
        _showMessage('Added bid: $sangam with $points points.');
      }

      _openDigitController.clear();
      _closePannaController.clear();
      _pointsController.clear();
    });
  }

  void _removeBid(int index) {
    _clearMessage();
    if (_isApiCalling) {
      return;
    }

    if (index >= 0 && index < _bids.length) {
      setState(() {
        final removedSangam = _bids[index]['sangam'];
        _bids.removeAt(index);
        _showMessage('Bid for $removedSangam removed from list.');
      });
    }
  }

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) {
      return;
    }

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
        "digit": bid['openDigit']!,
        "pana": bid['closePanna']!,
        "points": bid['points']!,
        "type": '--',
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
          gameTitle: widget.gameName,
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
            final Map<String, dynamic> result = await _placeFinalBids();
            if (!mounted) return;

            if (result['status'] == true) {
              setState(() {
                _bids.clear();
              });
              final int newBalance =
                  (result['data']?['wallet_balance'] as num?)?.toInt() ??
                  (_walletBalance - totalPoints);
              await _bidService.updateWalletBalance(newBalance);
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return const BidSuccessDialog();
                },
              );
            } else {
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
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _placeFinalBids() async {
    if (!mounted) return {'status': false, 'msg': 'Screen not mounted.'};
    setState(() {
      _isApiCalling = true;
    });

    try {
      if (_accessToken.isEmpty || _registerId.isEmpty) {
        return {
          'status': false,
          'msg': 'Authentication error. Please log in again.',
        };
      }

      Map<String, String> bidAmountsMap = {};
      for (var bid in _bids) {
        final String digitKey = '${bid['openDigit']!}-${bid['closePanna']!}';
        bidAmountsMap[digitKey] = bid['points']!;
      }

      int currentBatchTotalPoints = _getTotalPoints();

      if (bidAmountsMap.isEmpty) {
        return {'status': false, 'msg': 'No valid bids to submit.'};
      }

      final String selectedSessionType = "OPEN";

      final Map<String, dynamic> result = await _bidService.placeFinalBids(
        gameName: widget.gameName,
        accessToken: _accessToken,
        registerId: _registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: _accountStatus,
        bidAmounts: bidAmountsMap,
        selectedGameType: selectedSessionType,
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: currentBatchTotalPoints,
      );

      return result;
    } catch (e) {
      return {
        'status': false,
        'msg': 'An unexpected error occurred during bid submission: $e',
      };
    } finally {
      if (mounted) {
        setState(() {
          _isApiCalling = false;
        });
      }
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
          onPressed: () {
            Navigator.pop(context);
          },
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
              '₹${_walletBalance.toString()}',
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
      body: SafeArea(
        child: Stack(
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
                        'Enter Open Digit :',
                        _openDigitController,
                        hintText: 'e.g., 5',
                        maxLength: 1,
                        enabled: !_isApiCalling,
                      ),
                      const SizedBox(height: 16),
                      _buildPannaInputRow(
                        'Enter Close Panna :',
                        _closePannaController,
                        hintText: 'e.g., 123',
                        maxLength: 3,
                        enabled: !_isApiCalling,
                      ),
                      const SizedBox(height: 16),
                      _buildInputRow(
                        'Enter Points :',
                        _pointsController,
                        hintText: 'e.g., 100',
                        maxLength: 4,
                        enabled: !_isApiCalling,
                        onSubmitted: _addBid,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _isApiCalling ? null : _addBid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isApiCalling
                                ? Colors.grey
                                : Colors.orange,
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
                            final String displaySangam = bid['sangam']!;
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
                                        displaySangam,
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
      ),
    );
  }

  Widget _buildInputRow(
    String label,
    TextEditingController controller, {
    String hintText = '',
    int? maxLength,
    bool enabled = true,
    Function()? onSubmitted,
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
            enabled: enabled,
            onSubmitted: (value) => onSubmitted?.call(),
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
    bool enabled = true,
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
                  // This is the key fix: Keep your external controller in sync.
                  // Whenever your external controller changes, update the internal one.
                  controller.addListener(() {
                    if (textEditingController.text != controller.text) {
                      textEditingController.text = controller.text;
                    }
                  });

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
                    enabled: enabled,
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
                  : Colors.orange,
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

// import 'dart:async'; // For Timer
// import 'dart:developer'; // For log
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // For TextInputFormatter
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
// import 'package:intl/intl.dart';
//
// import '../../BidService.dart'; // Import BidService
// import '../../components/AnimatedMessageBar.dart';
// import '../../components/BidConfirmationDialog.dart';
// import '../../components/BidFailureDialog.dart';
// import '../../components/BidSuccessDialog.dart';
//
// class HalfSangamABoardScreen extends StatefulWidget {
//   final String screenTitle; // e.g., "SRIDEVI NIGHT, HALF SANGAM A"
//   final int gameId;
//   final String gameType; // e.g., "halfSangamA"
//   final String
//   gameName; // e.g., "SRIDEVI NIGHT" - Added this based on previous patterns
//
//   const HalfSangamABoardScreen({
//     Key? key,
//     required this.screenTitle,
//     required this.gameId,
//     required this.gameType,
//     required this.gameName, // Added this requirement
//   }) : super(key: key);
//
//   @override
//   State<HalfSangamABoardScreen> createState() => _HalfSangamABoardScreenState();
// }
//
// class _HalfSangamABoardScreenState extends State<HalfSangamABoardScreen> {
//   final TextEditingController _openDigitController = TextEditingController();
//   final TextEditingController _closePannaController = TextEditingController();
//   final TextEditingController _pointsController = TextEditingController();
//
//   List<Map<String, String>> _bids = [];
//   late GetStorage _storage = GetStorage(); // Renamed for consistency
//   late BidService _bidService; // Declare BidService
//   String _accessToken = ''; // Prefixed with _
//   String _registerId = ''; // Prefixed with _
//   String _preferredLanguage = 'en'; // Prefixed with _
//   bool _accountStatus = false; // Prefixed with _
//   int _walletBalance = 0; // Prefixed with _, keeping as int
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
//   Timer? _messageDismissTimer; // For dismissing message bar
//
//   // List of all possible 3-digit pannas for suggestions
//   // Refined this list to be more accurate (typically from 100 to 999)
//   static final List<String> _allPannas = [
//     "100",
//     "110",
//     "112",
//     "113",
//     "114",
//     "115",
//     "116",
//     "117",
//     "118",
//     "119",
//     "122",
//     "133",
//     "144",
//     "155",
//     "166",
//     "177",
//     "188",
//     "199",
//     "200",
//     "220",
//     "223",
//     "224",
//     "225",
//     "226",
//     "227",
//     "228",
//     "229",
//     "233",
//     "244",
//     "255",
//     "266",
//     "277",
//     "288",
//     "299",
//     "300",
//     "330",
//     "334",
//     "335",
//     "336",
//     "337",
//     "338",
//     "339",
//     "344",
//     "355",
//     "366",
//     "377",
//     "388",
//     "399",
//     "400",
//     "440",
//     "445",
//     "446",
//     "447",
//     "448",
//     "449",
//     "455",
//     "466",
//     "477",
//     "488",
//     "499",
//     "500",
//     "550",
//     "556",
//     "557",
//     "558",
//     "559",
//     "566",
//     "577",
//     "588",
//     "599",
//     "600",
//     "660",
//     "667",
//     "668",
//     "669",
//     "677",
//     "688",
//     "699",
//     "700",
//     "770",
//     "778",
//     "779",
//     "788",
//     "799",
//     "800",
//     "880",
//     "889",
//     "899",
//     "900",
//     "990",
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     log('HalfSangamABoardScreen: initState called.', name: 'HalfSangamAUI');
//     _bidService = BidService(_storage); // Initialize BidService
//     _loadInitialData();
//     _setupStorageListeners();
//   }
//
//   @override
//   void dispose() {
//     log('HalfSangamABoardScreen: dispose called.', name: 'HalfSangamAUI');
//     _openDigitController.dispose();
//     _closePannaController.dispose();
//     _pointsController.dispose();
//     _messageDismissTimer?.cancel(); // Cancel timer on dispose
//     super.dispose();
//   }
//
//   // Load initial data from GetStorage
//   Future<void> _loadInitialData() async {
//     log('HalfSangamAUI: _loadInitialData called.', name: 'HalfSangamAUI');
//     _accessToken = _storage.read('accessToken') ?? '';
//     _registerId = _storage.read('registerId') ?? '';
//     _accountStatus = _storage.read('accountStatus') ?? false;
//     _preferredLanguage = _storage.read('selectedLanguage') ?? 'en';
//
//     log(
//       'HalfSangamAUI: Loaded accessToken: ${_accessToken.isNotEmpty ? "YES" : "NO"}, registerId: ${_registerId.isNotEmpty ? "YES" : "NO"}, accountStatus: $_accountStatus, language: $_preferredLanguage',
//       name: 'HalfSangamAUI',
//     );
//
//     final dynamic storedWalletBalance = _storage.read('walletBalance');
//     if (storedWalletBalance is int) {
//       _walletBalance = storedWalletBalance;
//     } else if (storedWalletBalance is String) {
//       _walletBalance = int.tryParse(storedWalletBalance) ?? 0;
//     } else {
//       _walletBalance = 0;
//     }
//     log(
//       'HalfSangamAUI: Loaded walletBalance: $_walletBalance',
//       name: 'HalfSangamAUI',
//     );
//   }
//
//   // Set up listeners for GetStorage keys
//   void _setupStorageListeners() {
//     log('HalfSangamAUI: _setupStorageListeners called.', name: 'HalfSangamAUI');
//     _storage.listenKey('accessToken', (value) {
//       if (mounted) {
//         setState(() => _accessToken = value ?? '');
//         log(
//           'HalfSangamAUI: accessToken updated via listener.',
//           name: 'HalfSangamAUI',
//         );
//       }
//     });
//
//     _storage.listenKey('registerId', (value) {
//       if (mounted) {
//         setState(() => _registerId = value ?? '');
//         log(
//           'HalfSangamAUI: registerId updated via listener.',
//           name: 'HalfSangamAUI',
//         );
//       }
//     });
//
//     _storage.listenKey('accountStatus', (value) {
//       if (mounted) {
//         setState(() => _accountStatus = value ?? false);
//         log(
//           'HalfSangamAUI: accountStatus updated via listener.',
//           name: 'HalfSangamAUI',
//         );
//       }
//     });
//
//     _storage.listenKey('selectedLanguage', (value) {
//       if (mounted) {
//         setState(() => _preferredLanguage = value ?? 'en');
//         log(
//           'HalfSangamAUI: preferredLanguage updated via listener.',
//           name: 'HalfSangamAUI',
//         );
//       }
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
//         log(
//           'HalfSangamAUI: walletBalance updated via listener to: $_walletBalance',
//           name: 'HalfSangamAUI',
//         );
//       }
//     });
//   }
//
//   // Helper method to show messages using AnimatedMessageBar
//   void _showMessage(String message, {bool isError = false}) {
//     _messageDismissTimer?.cancel(); // Cancel any existing timer
//     log(
//       'HalfSangamAUI: _showMessage called: "$message" (isError: $isError)',
//       name: 'HalfSangamAUI',
//     );
//
//     if (!mounted) return;
//
//     setState(() {
//       _messageToShow = message;
//       _isErrorForMessage = isError;
//       _messageBarKey = UniqueKey(); // Update key to trigger animation
//     });
//
//     _messageDismissTimer = Timer(const Duration(seconds: 3), () {
//       _clearMessage();
//     });
//   }
//
//   // Helper method to clear the message bar
//   void _clearMessage() {
//     log('HalfSangamAUI: _clearMessage called.', name: 'HalfSangamAUI');
//     if (mounted) {
//       setState(() {
//         _messageToShow = null;
//       });
//     }
//   }
//
//   void _addBid() {
//     log('HalfSangamAUI: _addBid called.', name: 'HalfSangamAUI');
//     _clearMessage(); // Clear any previous messages
//     if (_isApiCalling) {
//       log(
//         'HalfSangamAUI: _addBid: API call in progress, returning.',
//         name: 'HalfSangamAUI',
//       );
//       return; // Prevent adding bids while API is in progress
//     }
//
//     final openDigit = _openDigitController.text.trim();
//     final closePanna = _closePannaController.text.trim();
//     final points = _pointsController.text.trim();
//
//     log(
//       'HalfSangamAUI: Input: OpenDigit:$openDigit, ClosePanna:$closePanna, Points:$points',
//       name: 'HalfSangamAUI',
//     );
//
//     // 1. Validate Open Digit (single digit, 0-9)
//     if (openDigit.isEmpty ||
//         openDigit.length != 1 ||
//         int.tryParse(openDigit) == null) {
//       _showMessage(
//         'Please enter a single digit for Open Digit (0-9).',
//         isError: true,
//       );
//       log(
//         'HalfSangamAUI: Validation: Invalid Open Digit.',
//         name: 'HalfSangamAUI',
//       );
//       return;
//     }
//     int? parsedOpenDigit = int.tryParse(openDigit);
//     if (parsedOpenDigit == null || parsedOpenDigit < 0 || parsedOpenDigit > 9) {
//       _showMessage(
//         'Open Digit must be a single digit between 0 and 9.',
//         isError: true,
//       );
//       log(
//         'HalfSangamAUI: Validation: Open Digit out of range.',
//         name: 'HalfSangamAUI',
//       );
//       return;
//     }
//
//     // 2. Validate Close Panna (3 digits, from _allPannas)
//     if (closePanna.isEmpty ||
//         closePanna.length != 3 ||
//         !_allPannas.contains(closePanna)) {
//       _showMessage(
//         'Please enter a valid 3-digit Panna (e.g., 123).',
//         isError: true,
//       );
//       log(
//         'HalfSangamAUI: Validation: Invalid Close Panna or not in list.',
//         name: 'HalfSangamAUI',
//       );
//       return;
//     }
//
//     // 3. Validate Points (10 to 1000)
//     int? parsedPoints = int.tryParse(points);
//     if (parsedPoints == null ||
//         parsedPoints < GetStorage().read('minBid') ||
//         parsedPoints > 1000) {
//       _showMessage(
//         'Points must be between ${GetStorage().read('minBid')} and 1000.',
//         isError: true,
//       );
//       log('HalfSangamAUI: Validation: Invalid points.', name: 'HalfSangamAUI');
//       return;
//     }
//
//     // Construct the Sangam string for display and unique key
//     final sangam = '$openDigit-$closePanna';
//
//     setState(() {
//       // Check if an existing bid with the same Sangam already exists
//       int existingIndex = _bids.indexWhere((bid) => bid['sangam'] == sangam);
//       log(
//         'HalfSangamAUI: Checking for existing bid, index: $existingIndex',
//         name: 'HalfSangamAUI',
//       );
//
//       if (existingIndex != -1) {
//         // If it exists, update the points of the existing bid
//         _bids[existingIndex]['points'] =
//             (int.parse(_bids[existingIndex]['points']!) + parsedPoints)
//                 .toString();
//         _showMessage('Updated points for $sangam.');
//         log(
//           'HalfSangamAUI: Updated existing bid: ${_bids[existingIndex]}',
//           name: 'HalfSangamAUI',
//         );
//       } else {
//         // Otherwise, add a new bid
//         _bids.add({
//           "sangam": sangam, // For display and unique ID
//           "points": points,
//           "openDigit": openDigit, // Store for API payload
//           "closePanna": closePanna, // Store for API payload
//           "type":
//               widget.gameType, // Store for API payload (e.g., "halfSangamA")
//         });
//         _showMessage('Added bid: $sangam with $points points.');
//         log(
//           'HalfSangamAUI: Added new bid: {"sangam": "$sangam", "points": "$points"}',
//           name: 'HalfSangamAUI',
//         );
//       }
//
//       // Clear controllers after adding/updating
//       _openDigitController.clear();
//       _closePannaController.clear();
//       _pointsController.clear();
//     });
//   }
//
//   void _removeBid(int index) {
//     log(
//       'HalfSangamAUI: _removeBid called for index: $index',
//       name: 'HalfSangamAUI',
//     );
//     _clearMessage();
//     if (_isApiCalling) {
//       log(
//         'HalfSangamAUI: _removeBid: API call in progress, returning.',
//         name: 'HalfSangamAUI',
//       );
//       return; // Prevent removing bids while API is in progress
//     }
//
//     if (index >= 0 && index < _bids.length) {
//       setState(() {
//         final removedSangam = _bids[index]['sangam'];
//         _bids.removeAt(index);
//         _showMessage('Bid for $removedSangam removed from list.');
//         log(
//           'HalfSangamAUI: Bid removed. Removed: $removedSangam. Current _bids: $_bids',
//           name: 'HalfSangamAUI',
//         );
//       });
//     } else {
//       log(
//         'HalfSangamAUI: _removeBid: Invalid index $index',
//         name: 'HalfSangamAUI',
//       );
//     }
//   }
//
//   int _getTotalPoints() {
//     int total = _bids.fold(
//       0,
//       (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
//     );
//     log('HalfSangamAUI: _getTotalPoints: $total', name: 'HalfSangamAUI');
//     return total;
//   }
//
//   void _showConfirmationDialog() {
//     log(
//       'HalfSangamAUI: _showConfirmationDialog called.',
//       name: 'HalfSangamAUI',
//     );
//     _clearMessage();
//     if (_isApiCalling) {
//       log(
//         'HalfSangamAUI: _showConfirmationDialog: API call in progress, returning.',
//         name: 'HalfSangamAUI',
//       );
//       return; // Prevent showing dialog if API is in progress
//     }
//
//     if (_bids.isEmpty) {
//       _showMessage('Please add at least one bid.', isError: true);
//       log(
//         'HalfSangamAUI: _showConfirmationDialog: No bids to submit.',
//         name: 'HalfSangamAUI',
//       );
//       return;
//     }
//
//     final int totalPoints = _getTotalPoints();
//
//     log(
//       'HalfSangamAUI: Confirmation Dialog: Total Points: $totalPoints, Wallet Balance: $_walletBalance',
//       name: 'HalfSangamAUI',
//     );
//
//     if (_walletBalance < totalPoints) {
//       _showMessage(
//         'Insufficient wallet balance to place this bid.',
//         isError: true,
//       );
//       log(
//         'HalfSangamAUI: Confirmation Dialog: Insufficient balance.',
//         name: 'HalfSangamAUI',
//       );
//       return;
//     }
//
//     // Prepare bids list for the dialog
//     List<Map<String, String>> bidsForDialog = _bids.map((bid) {
//       // For HalfSangamA, 'digit' is openDigit and 'pana' is closePanna for display.
//       return {
//         "digit": bid['openDigit']!, // Open Digit for display
//         "pana": bid['closePanna']!, // Close Panna for display
//         "points": bid['points']!,
//         "type": widget.screenTitle, // Use screenTitle for dialog display
//         "sangam": bid['sangam']!, // Combined for display in dialog
//         "jodi": "", // Not applicable for Sangam, but common in bid payloads
//       };
//     }).toList();
//     log(
//       'HalfSangamAUI: Bids prepared for dialog: $bidsForDialog',
//       name: 'HalfSangamAUI',
//     );
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
//           gameTitle: widget.gameName, // Use actual gameName from widget
//           gameDate: formattedDate,
//           bids: bidsForDialog,
//           totalBids: bidsForDialog.length,
//           totalBidsAmount: totalPoints,
//           walletBalanceBeforeDeduction: _walletBalance,
//           walletBalanceAfterDeduction: (_walletBalance - totalPoints)
//               .toString(),
//           gameId: widget.gameId.toString(), // Ensure gameId is String
//           gameType: widget
//               .gameType, // Pass the correct gameType (e.g., "halfSangamA")
//           onConfirm: () async {
//             log(
//               'HalfSangamAUI: Bid Confirmation Dialog: Confirmed by user.',
//               name: 'HalfSangamAUI',
//             );
//             // Navigator.pop(dialogContext); // Dismiss the confirmation dialog
//
//             // _placeFinalBids now manages _isApiCalling state internally.
//             final Map<String, dynamic> result = await _placeFinalBids();
//
//             if (!mounted) return; // Check mounted after async operation
//
//             if (result['status'] == true) {
//               log(
//                 'HalfSangamAUI: Handling successful bid result from _placeFinalBids.',
//                 name: 'HalfSangamAUI',
//               );
//               setState(() {
//                 _bids.clear(); // Clear bids on successful submission
//               });
//               // Update wallet balance from the successful API response if available,
//               // otherwise deduct locally. _bidService.updateWalletBalance is robust.
//               final int newBalance =
//                   (result['data']?['wallet_balance'] as num?)?.toInt() ??
//                   (_walletBalance - totalPoints);
//               await _bidService.updateWalletBalance(
//                 newBalance,
//               ); // Using BidService method to update storage
//               log(
//                 'HalfSangamAUI: Wallet balance updated in storage to $newBalance',
//                 name: 'HalfSangamAUI',
//               );
//
//               await showDialog(
//                 context: context,
//                 barrierDismissible: false,
//                 builder: (BuildContext context) {
//                   return const BidSuccessDialog();
//                 },
//               );
//             } else {
//               log(
//                 'HalfSangamAUI: Handling failed bid result from _placeFinalBids. Message: ${result['msg']}',
//                 name: 'HalfSangamAUI',
//               );
//               await showDialog(
//                 context: context,
//                 barrierDismissible: false,
//                 builder: (BuildContext context) {
//                   return BidFailureDialog(
//                     errorMessage:
//                         result['msg'] ??
//                         "Bid submission failed. Please try again.",
//                   );
//                 },
//               );
//             }
//             // _isApiCalling is reset in _placeFinalBids's finally block, so no need here.
//           },
//         );
//       },
//     );
//   }
//
//   // Place final bids via BidService
//   Future<Map<String, dynamic>> _placeFinalBids() async {
//     log('HalfSangamAUI: _placeFinalBids called.', name: 'HalfSangamAUI');
//     if (!mounted) return {'status': false, 'msg': 'Screen not mounted.'};
//
//     setState(() {
//       _isApiCalling = true;
//     });
//     log(
//       'HalfSangamAUI: _placeFinalBids: Setting _isApiCalling to true.',
//       name: 'HalfSangamAUI',
//     );
//
//     try {
//       if (_accessToken.isEmpty || _registerId.isEmpty) {
//         log(
//           'HalfSangamAUI: Authentication error: accessToken or registerId empty.',
//           name: 'HalfSangamAUI',
//         );
//         return {
//           'status': false,
//           'msg': 'Authentication error. Please log in again.',
//         };
//       }
//
//       // Transform _bids list into Map<String, String> bidAmounts for BidService
//       // Key: "openDigit-closePanna", Value: "points"
//       Map<String, String> bidAmountsMap = {};
//       for (var bid in _bids) {
//         final String digitKey =
//             '${bid['openDigit']!}-${bid['closePanna']!}'; // e.g., "5-123"
//         bidAmountsMap[digitKey] = bid['points']!;
//       }
//       log(
//         'HalfSangamAUI: bidAmountsMap generated for BidService: $bidAmountsMap',
//         name: 'HalfSangamAUI',
//       );
//
//       int currentBatchTotalPoints = _getTotalPoints();
//       log(
//         'HalfSangamAUI: currentBatchTotalPoints: $currentBatchTotalPoints',
//         name: 'HalfSangamAUI',
//       );
//
//       if (bidAmountsMap.isEmpty) {
//         log(
//           'HalfSangamAUI: No valid bids to submit (bidAmountsMap is empty).',
//           name: 'HalfSangamAUI',
//         );
//         return {'status': false, 'msg': 'No valid bids to submit.'};
//       }
//
//       // For Half Sangam A, the session type is implicitly "OPEN" as we're betting on the open digit's combination.
//       final String selectedSessionType = "OPEN";
//       log(
//         'HalfSangamAUI: Determined selectedSessionType: $selectedSessionType',
//         name: 'HalfSangamAUI',
//       );
//
//       log(
//         'HalfSangamAUI: Calling _bidService.placeFinalBids...',
//         name: 'HalfSangamAUI',
//       );
//       final Map<String, dynamic> result = await _bidService.placeFinalBids(
//         gameName: widget.gameName, // Using gameName from widget
//         accessToken: _accessToken,
//         registerId: _registerId,
//         deviceId: _deviceId,
//         deviceName: _deviceName,
//         accountStatus: _accountStatus,
//         bidAmounts: bidAmountsMap,
//         selectedGameType: selectedSessionType, // Session type for the backend
//         gameId: widget.gameId,
//         gameType:
//             widget.gameType, // Game type for the backend (e.g., "halfSangamA")
//         totalBidAmount: currentBatchTotalPoints,
//       );
//       log(
//         'HalfSangamAUI: _bidService.placeFinalBids returned: $result',
//         name: 'HalfSangamAUI',
//       );
//
//       return result; // Return the result from BidService directly
//     } catch (e) {
//       log(
//         'HalfSangamAUI: Caught unexpected error during bid placement: $e',
//         name: 'HalfSangamAUIError',
//       );
//       // Return a structured error message
//       return {
//         'status': false,
//         'msg': 'An unexpected error occurred during bid submission: $e',
//       };
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isApiCalling = false;
//         });
//         log(
//           'HalfSangamAUI: _placeFinalBids: Resetting _isApiCalling to false (finally block).',
//           name: 'HalfSangamAUI',
//         );
//       }
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
//           onPressed: () {
//             log('HalfSangamAUI: Back button pressed.', name: 'HalfSangamAUI');
//             Navigator.pop(context);
//           },
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
//           Image.asset(
//             "assets/images/ic_wallet.png",
//             width: 22,
//             height: 22,
//             color: Colors.black,
//           ),
//           const SizedBox(width: 6),
//           Center(
//             child: Text(
//               '₹${_walletBalance.toString()}', // Display actual wallet balance
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
//       body: SafeArea(
//         child: Stack(
//           children: [
//             Column(
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16.0,
//                     vertical: 12.0,
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _buildInputRow(
//                         'Enter Open Digit :',
//                         _openDigitController,
//                         hintText: 'e.g., 5',
//                         maxLength: 1,
//                         enabled: !_isApiCalling, // Disable when API is calling
//                       ),
//                       const SizedBox(height: 16),
//                       _buildPannaInputRow(
//                         'Enter Close Panna :',
//                         _closePannaController,
//                         hintText: 'e.g., 123',
//                         maxLength: 3,
//                         enabled: !_isApiCalling, // Disable when API is calling
//                       ),
//                       const SizedBox(height: 16),
//                       _buildInputRow(
//                         'Enter Points :',
//                         _pointsController,
//                         hintText: 'e.g., 100',
//                         maxLength: 4,
//                         enabled: !_isApiCalling, // Disable when API is calling
//                       ),
//                       const SizedBox(height: 20),
//                       SizedBox(
//                         width: double.infinity,
//                         height: 45,
//                         child: ElevatedButton(
//                           onPressed: _isApiCalling
//                               ? null
//                               : _addBid, // Disable when API is calling
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.orange, // Kept as amber
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(6),
//                             ),
//                           ),
//                           child: _isApiCalling
//                               ? const CircularProgressIndicator(
//                                   valueColor: AlwaysStoppedAnimation<Color>(
//                                     Colors.white,
//                                   ),
//                                   strokeWidth:
//                                       2, // Added strokeWidth for better visibility
//                                 )
//                               : Text(
//                                   "ADD",
//                                   style: GoogleFonts.poppins(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.w600,
//                                     letterSpacing: 0.5,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const Divider(thickness: 1),
//
//                 // Table Headers
//                 if (_bids.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 16.0,
//                       vertical: 8.0,
//                     ),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             'Sangam',
//                             style: GoogleFonts.poppins(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           child: Text(
//                             'Points',
//                             style: GoogleFonts.poppins(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 48), // Space for delete icon
//                       ],
//                     ),
//                   ),
//                 if (_bids.isNotEmpty) const Divider(thickness: 1),
//
//                 // Dynamic List of Bids
//                 Expanded(
//                   child: _bids.isEmpty
//                       ? Center(
//                           child: Text(
//                             'No Bids Placed',
//                             style: GoogleFonts.poppins(color: Colors.grey),
//                           ),
//                         )
//                       : ListView.builder(
//                           itemCount: _bids.length,
//                           itemBuilder: (context, index) {
//                             final bid = _bids[index];
//                             return Container(
//                               margin: const EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 4,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(8),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.grey.withOpacity(0.2),
//                                     spreadRadius: 1,
//                                     blurRadius: 3,
//                                     offset: const Offset(0, 1),
//                                   ),
//                                 ],
//                               ),
//                               child: Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 16.0,
//                                   vertical: 8.0,
//                                 ),
//                                 child: Row(
//                                   children: [
//                                     Expanded(
//                                       child: Text(
//                                         bid['sangam']!,
//                                         style: GoogleFonts.poppins(),
//                                       ),
//                                     ),
//                                     Expanded(
//                                       child: Text(
//                                         bid['points']!,
//                                         style: GoogleFonts.poppins(),
//                                       ),
//                                     ),
//                                     IconButton(
//                                       icon: const Icon(
//                                         Icons.delete,
//                                         color: Colors.red,
//                                       ),
//                                       onPressed: _isApiCalling
//                                           ? null
//                                           : () => _removeBid(
//                                               index,
//                                             ), // Disable when API is calling
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                 ),
//                 // Bottom Bar (conditionally rendered)
//                 _buildBottomBar(), // Removed if (_bids.isNotEmpty) for consistent bottom bar
//               ],
//             ),
//             // AnimatedMessageBar positioned at the top
//             if (_messageToShow != null)
//               Positioned(
//                 top: 0,
//                 left: 0,
//                 right: 0,
//                 child: AnimatedMessageBar(
//                   key: _messageBarKey,
//                   message: _messageToShow!,
//                   isError: _isErrorForMessage,
//                   onDismissed: _clearMessage,
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Helper widget for input rows (standard TextField)
//   Widget _buildInputRow(
//     String label,
//     TextEditingController controller, {
//     String hintText = '',
//     int? maxLength,
//     bool enabled = true, // Added enabled parameter
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
//             enabled: enabled, // Use the enabled parameter
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
//               ), // Arrow icon
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
//     bool enabled = true, // Added enabled parameter
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
//                     enabled: enabled, // Use the enabled parameter
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
//                       ), // Arrow icon
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
//             onPressed: (_isApiCalling || _bids.isEmpty)
//                 ? null
//                 : _showConfirmationDialog, // Disable when API is calling or no bids
//             style: ElevatedButton.styleFrom(
//               backgroundColor: (_isApiCalling || _bids.isEmpty)
//                   ? Colors.grey
//                   : Colors.orange[700], // Changed to orange[700]
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               elevation: 3,
//             ),
//             child: _isApiCalling
//                 ? const CircularProgressIndicator(
//                     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                     strokeWidth: 2, // Added strokeWidth for better visibility
//                   )
//                 : Text(
//                     'SUBMIT',
//                     style: GoogleFonts.poppins(
//                       color: Colors.white,
//                       fontSize: 16,
//                     ),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }
