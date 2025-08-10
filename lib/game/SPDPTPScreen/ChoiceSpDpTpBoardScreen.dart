// lib/screens/choice_sp_dp_tp_board_screen.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:marquee/marquee.dart';
import 'package:new_sara/components/AnimatedMessageBar.dart';
import 'package:new_sara/components/BidConfirmationDialog.dart';
import 'package:new_sara/components/BidFailureDialog.dart';
import 'package:new_sara/components/BidSuccessDialog.dart';

import '../../BidService.dart';
import '../../Helper/UserController.dart';

class ChoiceSpDpTpBoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;
  final String gameType;
  final String gameName;
  final bool selectionStatus; // This will control the dropdown options

  const ChoiceSpDpTpBoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId,
    required this.gameType,
    required this.gameName,
    required this.selectionStatus,
  }) : super(key: key);

  @override
  State<ChoiceSpDpTpBoardScreen> createState() =>
      _ChoiceSpDpTpBoardScreenState();
}

class _ChoiceSpDpTpBoardScreenState extends State<ChoiceSpDpTpBoardScreen> {
  final TextEditingController _leftDigitController = TextEditingController();
  final TextEditingController _middleDigitController = TextEditingController();
  final TextEditingController _rightDigitController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  bool _isSPSelected = false;
  bool _isDPSelected = false;
  bool _isTPSelected = false;

  String? _selectedGameTypeOption;

  List<Map<String, String>> _bids = [];

  late String walletBalance;
  final GetStorage _storage = GetStorage();
  late String accessToken;
  late String registerId;
  bool accountStatus = false;
  late String preferredLanguage;

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  late BidService _bidService;

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  bool _isApiCalling = false;

  final UserController userController = Get.put(UserController());

  @override
  void initState() {
    super.initState();
    // Set initial dropdown value based on widget.selectionStatus
    if (widget.selectionStatus) {
      _selectedGameTypeOption = 'OPEN';
    } else {
      _selectedGameTypeOption = 'CLOSE';
    }

    _loadInitialData();

    _bidService = BidService(_storage);
  }

  Future<void> _loadInitialData() async {
    accessToken = _storage.read('accessToken') ?? '';
    registerId = _storage.read('registerId') ?? '';
    accountStatus = _storage.read('accountStatus') ?? false;
    preferredLanguage = _storage.read('selectedLanguage') ?? 'en';

    double _walletBalance = double.parse(userController.walletBalance.value);
    walletBalance = _walletBalance.toInt().toString();
  }

  @override
  void dispose() {
    _leftDigitController.dispose();
    _middleDigitController.dispose();
    _rightDigitController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    // Automatically clear the message after a few seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _messageToShow = null;
        });
      }
    });
  }

  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  bool _isValidSpPanna(String panna) {
    if (panna.length != 3) return false;
    Set<String> uniqueDigits = panna.split('').toSet();
    return uniqueDigits.length == 3;
  }

  bool _isValidDpPanna(String panna) {
    if (panna.length != 3) return false;
    List<String> digits = panna.split('');
    digits.sort(); // Sort to easily check for two same digits
    return (digits[0] == digits[1] && digits[1] != digits[2]) ||
        (digits[0] != digits[1] && digits[1] == digits[2]);
  }

  bool _isValidTpPanna(String panna) {
    if (panna.length != 3) return false;
    return panna[0] == panna[1] && panna[1] == panna[2];
  }

  void _addBid() {
    _clearMessage();
    if (_isApiCalling) return;

    log("ADD button pressed - entering _addBid");
    final leftDigit = _leftDigitController.text.trim();
    final middleDigit = _middleDigitController.text.trim();
    final rightDigit = _rightDigitController.text.trim();
    final points = _pointsController.text.trim();

    if (leftDigit.isEmpty || middleDigit.isEmpty || rightDigit.isEmpty) {
      _showMessage('Please enter all three digits.', isError: true);
      return;
    }
    if (leftDigit.length != 1 ||
        middleDigit.length != 1 ||
        rightDigit.length != 1 ||
        int.tryParse(leftDigit) == null ||
        int.tryParse(middleDigit) == null ||
        int.tryParse(rightDigit) == null) {
      _showMessage(
        'Please enter single digits for Left, Middle, and Right.',
        isError: true,
      );
      return;
    }

    final pannaInput = '$leftDigit$middleDigit$rightDigit';

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 10000) {
      _showMessage('Points must be between 10 and 10000.', isError: true);
      return;
    }

    String gameCategory = '';
    int selectedCount = 0;
    if (_isSPSelected) {
      gameCategory = 'SP';
      selectedCount++;
    }
    if (_isDPSelected) {
      gameCategory = 'DP';
      selectedCount++;
    }
    if (_isTPSelected) {
      gameCategory = 'TP';
      selectedCount++;
    }

    if (selectedCount == 0) {
      _showMessage('Please select SP, DP, or TP.', isError: true);
      return;
    }
    if (selectedCount > 1) {
      _showMessage('Please select only one of SP, DP, or TP.', isError: true);
      return;
    }

    bool isValidPanna = false;
    if (gameCategory == 'SP') {
      isValidPanna = _isValidSpPanna(pannaInput);
      if (!isValidPanna) {
        _showMessage('SP Panna must have 3 unique digits.', isError: true);
        return;
      }
    } else if (gameCategory == 'DP') {
      isValidPanna = _isValidDpPanna(pannaInput);
      if (!isValidPanna) {
        _showMessage(
          'DP Panna must have two same digits and one different.',
          isError: true,
        );
        return;
      }
    } else if (gameCategory == 'TP') {
      isValidPanna = _isValidTpPanna(pannaInput);
      if (!isValidPanna) {
        _showMessage('TP Panna must have 3 identical digits.', isError: true);
        return;
      }
    }

    if (isValidPanna) {
      setState(() {
        bool alreadyExists = _bids.any(
          (entry) =>
              entry['digit'] == pannaInput &&
              entry['gameType'] == gameCategory &&
              entry['type'] == _selectedGameTypeOption,
        );

        if (!alreadyExists) {
          log(
            "Adding single bid: Digit-$pannaInput, Points-$points, Type-$_selectedGameTypeOption, GameType-$gameCategory",
          );
          _bids.add({
            "digit": pannaInput,
            "points": points,
            "type": _selectedGameTypeOption!,
            "gameType": gameCategory,
          });
          _leftDigitController.clear();
          _middleDigitController.clear();
          _rightDigitController.clear();
          _pointsController.clear();
          _isSPSelected = false; // Reset checkboxes
          _isDPSelected = false; // Reset checkboxes
          _isTPSelected = false; // Reset checkboxes
          _showMessage(
            'Bid added successfully for $gameCategory: $pannaInput.',
          );
        } else {
          _showMessage(
            'Panna $pannaInput already added for $gameCategory ($_selectedGameTypeOption).',
            isError: true,
          );
        }
      });
    }
  }

  void _removeBid(int index) {
    _clearMessage();
    if (_isApiCalling) return;

    setState(() {
      final removedBid = _bids.removeAt(index);
      _showMessage(
        'Removed bid: ${removedBid['gameType']} ${removedBid['digit']}.',
      );
    });
  }

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  void _showBidConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    if (_bids.isEmpty) {
      _showMessage('Please add bids before submitting.', isError: true);
      return;
    }

    final int currentTotalPoints = _getTotalPoints();
    final int currentWalletBalance = int.tryParse(walletBalance) ?? 0;

    if (currentWalletBalance < currentTotalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
      return;
    }

    final List<Map<String, String>> bidsForDialog = _bids.map((bid) {
      return {
        'digit': bid['digit']!,
        'points': bid['points']!,
        'type': '${bid['gameType']} (${bid['type']})',
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
          totalBidsAmount: currentTotalPoints,
          walletBalanceBeforeDeduction: currentWalletBalance,
          walletBalanceAfterDeduction:
              (currentWalletBalance - currentTotalPoints).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            log('Bids Confirmed for API submission: $bidsForDialog');
            // Navigator.pop(dialogContext); // Dismiss the confirmation dialog

            setState(() {
              _isApiCalling = true;
            });

            bool success = await _placeFinalBidsWithService();

            if (success) {
              setState(() {
                _bids.clear();
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

  Future<bool> _placeFinalBidsWithService() async {
    Map<String, String> bidAmounts = {};
    for (var bid in _bids) {
      bidAmounts[bid['digit']!] = bid['points']!;
    }

    try {
      final response = await _bidService.placeFinalBids(
        gameName: widget.screenTitle,
        accessToken: accessToken,
        registerId: registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: accountStatus,
        bidAmounts: bidAmounts,
        selectedGameType: _selectedGameTypeOption!,
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: _getTotalPoints(),
      );

      if (response['status'] == true) {
        int newWalletBalance =
            (int.tryParse(walletBalance) ?? 0) - _getTotalPoints();
        await _bidService.updateWalletBalance(newWalletBalance);

        if (mounted) {
          setState(() {
            walletBalance = newWalletBalance.toString();
          });
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const BidSuccessDialog();
            },
          );
        }
        return true;
      } else {
        String errorMessage = response['msg'] ?? "Unknown error occurred.";
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return BidFailureDialog(errorMessage: errorMessage);
            },
          );
        }
        return false;
      }
    } catch (e) {
      log('Error placing bids: $e', name: 'ChoiceSpDpTpBoardScreen');
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const BidFailureDialog(
              errorMessage: 'An unexpected error occurred. Please try again.',
            );
          },
        );
      }
      return false;
    }
  }

  Widget _buildDigitInputField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      cursorColor: Colors.orange,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [
        LengthLimitingTextInputFormatter(1),
        FilteringTextInputFormatter.digitsOnly,
      ],
      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black54),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black54),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
      onTap: _clearMessage,
      enabled: !_isApiCalling,
    );
  }

  @override
  Widget build(BuildContext context) {
    String marketName = widget.screenTitle.contains(" - ")
        ? widget.screenTitle.split(' - ')[0]
        : widget.screenTitle;

    // Build dropdown items dynamically based on selectionStatus
    List<DropdownMenuItem<String>> dropdownItems = [];
    if (widget.selectionStatus) {
      dropdownItems.add(
        DropdownMenuItem<String>(
          value: 'OPEN',
          child: SizedBox(
            width: 150,
            height: 20,
            child: Marquee(
              text: '$marketName OPEN',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              scrollAxis: Axis.horizontal,
              blankSpace: 40.0,
              velocity: 30.0,
              pauseAfterRound: const Duration(seconds: 2),
              showFadingOnlyWhenScrolling: true,
              fadingEdgeStartFraction: 0.1,
              fadingEdgeEndFraction: 0.1,
              startPadding: 10.0,
              accelerationDuration: const Duration(milliseconds: 500),
              accelerationCurve: Curves.linear,
              decelerationDuration: const Duration(milliseconds: 500),
              decelerationCurve: Curves.easeOut,
            ),
          ),
        ),
      );
    }
    // 'CLOSE' option is always added
    dropdownItems.add(
      DropdownMenuItem<String>(
        value: 'CLOSE',
        child: SizedBox(
          width: 150,
          height: 20,
          child: Marquee(
            text: '$marketName CLOSE',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            scrollAxis: Axis.horizontal,
            blankSpace: 40.0,
            velocity: 30.0,
            pauseAfterRound: const Duration(seconds: 2),
            showFadingOnlyWhenScrolling: true,
            fadingEdgeStartFraction: 0.1,
            fadingEdgeEndFraction: 0.1,
            startPadding: 10.0,
            accelerationDuration: const Duration(milliseconds: 500),
            accelerationCurve: Curves.linear,
            decelerationDuration: const Duration(milliseconds: 500),
            decelerationCurve: Curves.easeOut,
          ),
        ),
      ),
    );

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
              walletBalance,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Game Type',
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                          SizedBox(
                            width: 180,
                            height: 40,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.black54),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedGameTypeOption,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.orange,
                                  ),
                                  onChanged: _isApiCalling
                                      ? null
                                      : (String? newValue) {
                                          setState(() {
                                            _selectedGameTypeOption = newValue;
                                            _clearMessage();
                                          });
                                        },
                                  items:
                                      dropdownItems, // Use the dynamically built list
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: _isSPSelected,
                                  onChanged: _isApiCalling
                                      ? null
                                      : (bool? value) {
                                          setState(() {
                                            _isSPSelected = value ?? false;
                                            if (_isSPSelected) {
                                              _isDPSelected = false;
                                              _isTPSelected = false;
                                            }
                                            _clearMessage();
                                          });
                                        },
                                  activeColor: Colors.orange,
                                  checkColor: Colors.white,
                                ),
                                Text(
                                  'SP',
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: _isDPSelected,
                                  onChanged: _isApiCalling
                                      ? null
                                      : (bool? value) {
                                          setState(() {
                                            _isDPSelected = value ?? false;
                                            if (_isDPSelected) {
                                              _isSPSelected = false;
                                              _isTPSelected = false;
                                            }
                                            _clearMessage();
                                          });
                                        },
                                  activeColor: Colors.orange,
                                  checkColor: Colors.white,
                                ),
                                Text(
                                  'DP',
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: _isTPSelected,
                                  onChanged: _isApiCalling
                                      ? null
                                      : (bool? value) {
                                          setState(() {
                                            _isTPSelected = value ?? false;
                                            if (_isTPSelected) {
                                              _isSPSelected = false;
                                              _isDPSelected = false;
                                            }
                                            _clearMessage();
                                          });
                                        },
                                  activeColor: Colors.orange,
                                  checkColor: Colors.white,
                                ),
                                Text(
                                  'TP',
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildDigitInputField(
                              'Digit 1',
                              _leftDigitController,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDigitInputField(
                              'Digit 2',
                              _middleDigitController,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDigitInputField(
                              'Digit 3',
                              _rightDigitController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Enter Points:',
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                          SizedBox(
                            width: 150,
                            height: 40,
                            child: TextField(
                              cursorColor: Colors.orange,
                              controller: _pointsController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(5),
                              ],
                              decoration: InputDecoration(
                                hintText: 'Amount',
                                hintStyle: GoogleFonts.poppins(fontSize: 14),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 8.0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Colors.black54,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Colors.black54,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Colors.orange,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onTap: _clearMessage,
                              enabled: !_isApiCalling,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 150,
                          height: 45,
                          child: ElevatedButton(
                            onPressed: _isApiCalling ? null : _addBid,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: _isApiCalling
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : Text(
                                    "ADD",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                const Divider(thickness: 1, height: 1),
                if (_bids.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Panna',
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
                            'Type',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // Space for delete icon
                      ],
                    ),
                  ),
                if (_bids.isNotEmpty)
                  const Divider(
                    thickness: 0.5,
                    indent: 16,
                    endIndent: 16,
                    height: 10,
                  ),
                Expanded(
                  child: _bids.isEmpty
                      ? Center(
                          child: Text(
                            'No Bids Added Yet',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 0, bottom: 8.0),
                          itemCount: _bids.length,
                          itemBuilder: (context, index) {
                            final bid = _bids[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 8.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.15),
                                    spreadRadius: 1,
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      bid['digit']!,
                                      style: GoogleFonts.poppins(fontSize: 15),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      bid['points']!,
                                      style: GoogleFonts.poppins(fontSize: 15),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '${bid['gameType']} (${bid['type']})',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        color: Colors.green[700],
                                      ),
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
            onPressed: _isApiCalling || _bids.isEmpty
                ? null
                : _showBidConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isApiCalling || _bids.isEmpty
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

// // lib/screens/choice_sp_dp_tp_board_screen.dart
// import 'dart:async';
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:marquee/marquee.dart';
// import 'package:new_sara/components/AnimatedMessageBar.dart';
// import 'package:new_sara/components/BidConfirmationDialog.dart';
// import 'package:new_sara/components/BidFailureDialog.dart';
// import 'package:new_sara/components/BidSuccessDialog.dart';
//
// import '../../BidService.dart';
//
// class ChoiceSpDpTpBoardScreen extends StatefulWidget {
//   final String screenTitle;
//   final int gameId;
//   final String gameType;
//   final String gameName;
//   final bool selectionStatus;
//
//   const ChoiceSpDpTpBoardScreen({
//     Key? key,
//     required this.screenTitle,
//     required this.gameId,
//     required this.gameType,
//     required this.gameName,
//     required this.selectionStatus,
//   }) : super(key: key);
//
//   @override
//   State<ChoiceSpDpTpBoardScreen> createState() =>
//       _ChoiceSpDpTpBoardScreenState();
// }
//
// class _ChoiceSpDpTpBoardScreenState extends State<ChoiceSpDpTpBoardScreen> {
//   final TextEditingController _leftDigitController = TextEditingController();
//   final TextEditingController _middleDigitController = TextEditingController();
//   final TextEditingController _rightDigitController = TextEditingController();
//   final TextEditingController _pointsController = TextEditingController();
//
//   bool _isSPSelected = false;
//   bool _isDPSelected = false;
//   bool _isTPSelected = false;
//
//   String? _selectedGameTypeOption;
//
//   List<Map<String, String>> _bids = [];
//
//   late String walletBalance;
//   final GetStorage _storage = GetStorage();
//   late String accessToken;
//   late String registerId;
//   bool accountStatus = false;
//   late String preferredLanguage;
//
//   final String _deviceId = 'test_device_id_flutter';
//   final String _deviceName = 'test_device_name_flutter';
//
//   late BidService _bidService;
//
//   String? _messageToShow;
//   bool _isErrorForMessage = false;
//   Key _messageBarKey = UniqueKey();
//
//   bool _isApiCalling = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _selectedGameTypeOption = 'OPEN';
//
//     _loadInitialData();
//     _setupStorageListeners();
//
//     _bidService = BidService(_storage);
//   }
//
//   Future<void> _loadInitialData() async {
//     accessToken = _storage.read('accessToken') ?? '';
//     registerId = _storage.read('registerId') ?? '';
//     accountStatus = _storage.read('accountStatus') ?? false;
//     preferredLanguage = _storage.read('selectedLanguage') ?? 'en';
//
//     final dynamic storedWalletBalance = _storage.read('walletBalance');
//     if (storedWalletBalance is int) {
//       walletBalance = storedWalletBalance.toString();
//     } else if (storedWalletBalance is String) {
//       walletBalance = storedWalletBalance;
//     } else {
//       walletBalance = '0';
//     }
//   }
//
//   void _setupStorageListeners() {
//     _storage.listenKey('accessToken', (value) {
//       if (mounted) setState(() => accessToken = value ?? '');
//     });
//     _storage.listenKey('registerId', (value) {
//       if (mounted) setState(() => registerId = value ?? '');
//     });
//     _storage.listenKey('accountStatus', (value) {
//       if (mounted) setState(() => accountStatus = value ?? false);
//     });
//     _storage.listenKey('selectedLanguage', (value) {
//       if (mounted) setState(() => preferredLanguage = value ?? 'en');
//     });
//     _storage.listenKey('walletBalance', (value) {
//       if (mounted) {
//         setState(() {
//           if (value is int) {
//             walletBalance = value.toString();
//           } else if (value is String) {
//             walletBalance = value;
//           } else {
//             walletBalance = '0';
//           }
//         });
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _leftDigitController.dispose();
//     _middleDigitController.dispose();
//     _rightDigitController.dispose();
//     _pointsController.dispose();
//     super.dispose();
//   }
//
//   void _showMessage(String message, {bool isError = false}) {
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
//   bool _isValidSpPanna(String panna) {
//     if (panna.length != 3) return false;
//     Set<String> uniqueDigits = panna.split('').toSet();
//     return uniqueDigits.length == 3;
//   }
//
//   bool _isValidDpPanna(String panna) {
//     if (panna.length != 3) return false;
//     List<String> digits = panna.split('');
//     digits.sort();
//     return (digits[0] == digits[1] && digits[1] != digits[2]) ||
//         (digits[0] != digits[1] && digits[1] == digits[2]);
//   }
//
//   bool _isValidTpPanna(String panna) {
//     if (panna.length != 3) return false;
//     return panna[0] == panna[1] && panna[1] == panna[2];
//   }
//
//   void _addBid() {
//     _clearMessage();
//     if (_isApiCalling) return;
//
//     log("ADD button pressed - entering _addBid");
//     final leftDigit = _leftDigitController.text.trim();
//     final middleDigit = _middleDigitController.text.trim();
//     final rightDigit = _rightDigitController.text.trim();
//     final points = _pointsController.text.trim();
//
//     if (leftDigit.isEmpty || middleDigit.isEmpty || rightDigit.isEmpty) {
//       _showMessage('Please enter all three digits.', isError: true);
//       return;
//     }
//     if (leftDigit.length != 1 ||
//         middleDigit.length != 1 ||
//         rightDigit.length != 1 ||
//         int.tryParse(leftDigit) == null ||
//         int.tryParse(middleDigit) == null ||
//         int.tryParse(rightDigit) == null) {
//       _showMessage(
//         'Please enter single digits for Left, Middle, and Right.',
//         isError: true,
//       );
//       return;
//     }
//
//     final pannaInput = '$leftDigit$middleDigit$rightDigit';
//
//     int? parsedPoints = int.tryParse(points);
//     if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 10000) {
//       _showMessage('Points must be between 10 and 10000.', isError: true);
//       return;
//     }
//
//     String gameCategory = '';
//     int selectedCount = 0;
//     if (_isSPSelected) {
//       gameCategory = 'SP';
//       selectedCount++;
//     }
//     if (_isDPSelected) {
//       gameCategory = 'DP';
//       selectedCount++;
//     }
//     if (_isTPSelected) {
//       gameCategory = 'TP';
//       selectedCount++;
//     }
//
//     if (selectedCount == 0) {
//       _showMessage('Please select SP, DP, or TP.', isError: true);
//       return;
//     }
//     if (selectedCount > 1) {
//       _showMessage('Please select only one of SP, DP, or TP.', isError: true);
//       return;
//     }
//
//     bool isValidPanna = false;
//     if (gameCategory == 'SP') {
//       isValidPanna = _isValidSpPanna(pannaInput);
//       if (!isValidPanna) {
//         _showMessage('SP Panna must have 3 unique digits.', isError: true);
//         return;
//       }
//     } else if (gameCategory == 'DP') {
//       isValidPanna = _isValidDpPanna(pannaInput);
//       if (!isValidPanna) {
//         _showMessage(
//           'DP Panna must have two same digits and one different.',
//           isError: true,
//         );
//         return;
//       }
//     } else if (gameCategory == 'TP') {
//       isValidPanna = _isValidTpPanna(pannaInput);
//       if (!isValidPanna) {
//         _showMessage('TP Panna must have 3 identical digits.', isError: true);
//         return;
//       }
//     }
//
//     if (isValidPanna) {
//       setState(() {
//         bool alreadyExists = _bids.any(
//           (entry) =>
//               entry['digit'] == pannaInput &&
//               entry['gameType'] == gameCategory &&
//               entry['type'] == _selectedGameTypeOption,
//         );
//
//         if (!alreadyExists) {
//           log(
//             "Adding single bid: Digit-$pannaInput, Points-$points, Type-$_selectedGameTypeOption, GameType-$gameCategory",
//           );
//           _bids.add({
//             "digit": pannaInput,
//             "points": points,
//             "type": _selectedGameTypeOption!,
//             "gameType": gameCategory,
//           });
//           _leftDigitController.clear();
//           _middleDigitController.clear();
//           _rightDigitController.clear();
//           _pointsController.clear();
//           _isSPSelected = false;
//           _isDPSelected = false;
//           _isTPSelected = false;
//           _showMessage(
//             'Bid added successfully for $gameCategory: $pannaInput.',
//           );
//         } else {
//           _showMessage(
//             'Panna $pannaInput already added for $gameCategory ($_selectedGameTypeOption).',
//             isError: true,
//           );
//         }
//       });
//     }
//   }
//
//   void _removeBid(int index) {
//     _clearMessage();
//     if (_isApiCalling) return;
//
//     setState(() {
//       final removedBid = _bids.removeAt(index);
//       _showMessage(
//         'Removed bid: ${removedBid['gameType']} ${removedBid['digit']}.',
//       );
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
//   void _showBidConfirmationDialog() {
//     _clearMessage();
//     if (_isApiCalling) return;
//
//     if (_bids.isEmpty) {
//       _showMessage('Please add bids before submitting.', isError: true);
//       return;
//     }
//
//     final int currentTotalPoints = _getTotalPoints();
//     final int currentWalletBalance = int.tryParse(walletBalance) ?? 0;
//
//     if (currentWalletBalance < currentTotalPoints) {
//       _showMessage(
//         'Insufficient wallet balance to place this bid.',
//         isError: true,
//       );
//       return;
//     }
//
//     final List<Map<String, String>> bidsForDialog = _bids.map((bid) {
//       return {
//         'digit': bid['digit']!,
//         'points': bid['points']!,
//         'type': '${bid['gameType']} (${bid['type']})',
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
//           gameTitle: widget.screenTitle,
//           gameDate: formattedDate,
//           bids: bidsForDialog,
//           totalBids: bidsForDialog.length,
//           totalBidsAmount: currentTotalPoints,
//           walletBalanceBeforeDeduction: currentWalletBalance,
//           walletBalanceAfterDeduction:
//               (currentWalletBalance - currentTotalPoints).toString(),
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameType,
//           onConfirm: () async {
//             log('Bids Confirmed for API submission: $bidsForDialog');
//             // Navigator.pop(dialogContext);
//
//             setState(() {
//               _isApiCalling = true;
//             });
//
//             bool success = await _placeFinalBidsWithService();
//
//             if (success) {
//               setState(() {
//                 _bids.clear();
//               });
//             }
//             if (mounted) {
//               setState(() {
//                 _isApiCalling = false;
//               });
//             }
//           },
//         );
//       },
//     );
//   }
//
//   Future<bool> _placeFinalBidsWithService() async {
//     Map<String, String> bidAmounts = {};
//     for (var bid in _bids) {
//       bidAmounts[bid['digit']!] = bid['points']!;
//     }
//
//     final response = await _bidService.placeFinalBids(
//       gameName: widget.screenTitle,
//       accessToken: accessToken,
//       registerId: registerId,
//       deviceId: _deviceId,
//       deviceName: _deviceName,
//       accountStatus: accountStatus,
//       bidAmounts: bidAmounts,
//       selectedGameType: _selectedGameTypeOption!,
//       gameId: widget.gameId,
//       gameType: widget.gameType,
//       totalBidAmount: _getTotalPoints(),
//     );
//
//     if (response['status'] == true) {
//       int newWalletBalance =
//           (int.tryParse(walletBalance) ?? 0) - _getTotalPoints();
//       await _bidService.updateWalletBalance(newWalletBalance);
//
//       if (mounted) {
//         setState(() {
//           walletBalance = newWalletBalance.toString();
//         });
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (BuildContext context) {
//             return const BidSuccessDialog();
//           },
//         );
//       }
//       return true;
//     } else {
//       String errorMessage = response['msg'] ?? "Unknown error occurred.";
//       if (mounted) {
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (BuildContext context) {
//             return BidFailureDialog(errorMessage: errorMessage);
//           },
//         );
//       }
//       return false;
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     String marketName = widget.screenTitle.contains(" - ")
//         ? widget.screenTitle.split(' - ')[0]
//         : widget.screenTitle;
//
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
//               walletBalance,
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
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Select Game Type',
//                           style: GoogleFonts.poppins(fontSize: 16),
//                         ),
//                         SizedBox(
//                           width: 180,
//                           height: 40,
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 12),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               border: Border.all(color: Colors.black54),
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                             child: DropdownButtonHideUnderline(
//                               child: DropdownButton<String>(
//                                 isExpanded: true,
//                                 value: _selectedGameTypeOption,
//                                 icon: const Icon(
//                                   Icons.keyboard_arrow_down,
//                                   color: Colors.orange,
//                                 ),
//                                 onChanged: _isApiCalling
//                                     ? null
//                                     : (String? newValue) {
//                                         setState(() {
//                                           _selectedGameTypeOption = newValue;
//                                           _clearMessage();
//                                         });
//                                       },
//                                 items: const <String>['OPEN', 'CLOSE']
//                                     .map<DropdownMenuItem<String>>((
//                                       String value,
//                                     ) {
//                                       return DropdownMenuItem<String>(
//                                         value: value,
//                                         child: SizedBox(
//                                           width: 150,
//                                           height: 20,
//                                           child: Marquee(
//                                             text: '$marketName $value',
//                                             style: GoogleFonts.poppins(
//                                               fontSize: 14,
//                                               color: Colors.black87,
//                                             ),
//                                             scrollAxis: Axis.horizontal,
//                                             blankSpace: 40.0,
//                                             velocity: 30.0,
//                                             pauseAfterRound: const Duration(
//                                               seconds: 2,
//                                             ),
//                                             showFadingOnlyWhenScrolling: true,
//                                             fadingEdgeStartFraction: 0.1,
//                                             fadingEdgeEndFraction: 0.1,
//                                             startPadding: 10.0,
//                                             accelerationDuration:
//                                                 const Duration(
//                                                   milliseconds: 500,
//                                                 ),
//                                             accelerationCurve: Curves.linear,
//                                             decelerationDuration:
//                                                 const Duration(
//                                                   milliseconds: 500,
//                                                 ),
//                                             decelerationCurve: Curves.easeOut,
//                                           ),
//                                         ),
//                                       );
//                                     })
//                                     .toList(),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Checkbox(
//                                 value: _isSPSelected,
//                                 onChanged: _isApiCalling
//                                     ? null
//                                     : (bool? value) {
//                                         setState(() {
//                                           _isSPSelected = value ?? false;
//                                           if (_isSPSelected) {
//                                             _isDPSelected = false;
//                                             _isTPSelected = false;
//                                           }
//                                           _clearMessage();
//                                         });
//                                       },
//                                 activeColor: Colors.orange,
//                                 checkColor: Colors.white,
//                               ),
//                               Text(
//                                 'SP',
//                                 style: GoogleFonts.poppins(fontSize: 16),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Expanded(
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Checkbox(
//                                 value: _isDPSelected,
//                                 onChanged: _isApiCalling
//                                     ? null
//                                     : (bool? value) {
//                                         setState(() {
//                                           _isDPSelected = value ?? false;
//                                           if (_isDPSelected) {
//                                             _isSPSelected = false;
//                                             _isTPSelected = false;
//                                           }
//                                           _clearMessage();
//                                         });
//                                       },
//                                 activeColor: Colors.orange,
//                                 checkColor: Colors.white,
//                               ),
//                               Text(
//                                 'DP',
//                                 style: GoogleFonts.poppins(fontSize: 16),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Expanded(
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Checkbox(
//                                 value: _isTPSelected,
//                                 onChanged: _isApiCalling
//                                     ? null
//                                     : (bool? value) {
//                                         setState(() {
//                                           _isTPSelected = value ?? false;
//                                           if (_isTPSelected) {
//                                             _isSPSelected = false;
//                                             _isDPSelected = false;
//                                           }
//                                           _clearMessage();
//                                         });
//                                       },
//                                 activeColor: Colors.orange,
//                                 checkColor: Colors.white,
//                               ),
//                               Text(
//                                 'TP',
//                                 style: GoogleFonts.poppins(fontSize: 16),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Expanded(
//                           child: _buildDigitInputField(
//                             'Digit 1',
//                             _leftDigitController,
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: _buildDigitInputField(
//                             'Digit 2',
//                             _middleDigitController,
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: _buildDigitInputField(
//                             'Digit 3',
//                             _rightDigitController,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       crossAxisAlignment: CrossAxisAlignment.center,
//                       children: [
//                         Text(
//                           'Enter Points:',
//                           style: GoogleFonts.poppins(fontSize: 16),
//                         ),
//                         SizedBox(
//                           width: 150,
//                           height: 40,
//                           child: TextField(
//                             cursorColor: Colors.orange,
//                             controller: _pointsController,
//                             keyboardType: TextInputType.number,
//                             inputFormatters: [
//                               FilteringTextInputFormatter.digitsOnly,
//                               LengthLimitingTextInputFormatter(5),
//                             ],
//                             decoration: InputDecoration(
//                               hintText: 'Amount',
//                               hintStyle: GoogleFonts.poppins(fontSize: 14),
//                               contentPadding: const EdgeInsets.symmetric(
//                                 horizontal: 12.0,
//                                 vertical: 8.0,
//                               ),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(20),
//                                 borderSide: const BorderSide(
//                                   color: Colors.black54,
//                                 ),
//                               ),
//                               enabledBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(20),
//                                 borderSide: const BorderSide(
//                                   color: Colors.black54,
//                                 ),
//                               ),
//                               focusedBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(20),
//                                 borderSide: const BorderSide(
//                                   color: Colors.orange,
//                                   width: 2,
//                                 ),
//                               ),
//                             ),
//                             onTap: _clearMessage,
//                             enabled: !_isApiCalling,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 20),
//                     Align(
//                       alignment: Alignment.centerRight,
//                       child: SizedBox(
//                         width: 150,
//                         height: 45,
//                         child: ElevatedButton(
//                           onPressed: _isApiCalling ? null : _addBid,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.orange,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             elevation: 2,
//                           ),
//                           child: _isApiCalling
//                               ? const CircularProgressIndicator(
//                                   color: Colors.white,
//                                   strokeWidth: 2,
//                                 )
//                               : Text(
//                                   "ADD",
//                                   textAlign: TextAlign.center,
//                                   style: GoogleFonts.poppins(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.w600,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                   ],
//                 ),
//               ),
//               const Divider(thickness: 1, height: 1),
//               if (_bids.isNotEmpty)
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         flex: 2,
//                         child: Text(
//                           'Panna',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         flex: 2,
//                         child: Text(
//                           'Amount',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         flex: 3,
//                         child: Text(
//                           'Type',
//                           style: GoogleFonts.poppins(
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 48),
//                     ],
//                   ),
//                 ),
//               if (_bids.isNotEmpty)
//                 const Divider(
//                   thickness: 0.5,
//                   indent: 16,
//                   endIndent: 16,
//                   height: 10,
//                 ),
//               Expanded(
//                 child: _bids.isEmpty
//                     ? Center(
//                         child: Text(
//                           'No Bids Added Yet',
//                           style: GoogleFonts.poppins(
//                             fontSize: 16,
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                       )
//                     : ListView.builder(
//                         padding: const EdgeInsets.only(top: 0, bottom: 8.0),
//                         itemCount: _bids.length,
//                         itemBuilder: (context, index) {
//                           final bid = _bids[index];
//                           return Container(
//                             margin: const EdgeInsets.symmetric(
//                               horizontal: 16,
//                               vertical: 4,
//                             ),
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 12.0,
//                               vertical: 8.0,
//                             ),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(8),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.grey.withOpacity(0.15),
//                                   spreadRadius: 1,
//                                   blurRadius: 2,
//                                   offset: const Offset(0, 1),
//                                 ),
//                               ],
//                             ),
//                             child: Row(
//                               children: [
//                                 Expanded(
//                                   flex: 2,
//                                   child: Text(
//                                     bid['digit']!,
//                                     style: GoogleFonts.poppins(fontSize: 15),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   flex: 2,
//                                   child: Text(
//                                     bid['points']!,
//                                     style: GoogleFonts.poppins(fontSize: 15),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   flex: 3,
//                                   child: Text(
//                                     '${bid['gameType']} (${bid['type']})',
//                                     style: GoogleFonts.poppins(
//                                       fontSize: 14,
//                                       color: Colors.blueGrey[700],
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ),
//                                 IconButton(
//                                   icon: const Icon(
//                                     Icons.delete_outline,
//                                     color: Colors.redAccent,
//                                   ),
//                                   iconSize: 22,
//                                   splashRadius: 20,
//                                   padding: EdgeInsets.zero,
//                                   constraints: const BoxConstraints(),
//                                   onPressed: _isApiCalling
//                                       ? null
//                                       : () => _removeBid(index),
//                                 ),
//                               ],
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
//   Widget _buildDigitInputField(String hint, TextEditingController controller) {
//     return SizedBox(
//       height: 40,
//       child: TextField(
//         cursorColor: Colors.orange,
//         controller: controller,
//         textAlign: TextAlign.center,
//         style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
//         keyboardType: TextInputType.number,
//         inputFormatters: [
//           LengthLimitingTextInputFormatter(1),
//           FilteringTextInputFormatter.digitsOnly,
//         ],
//         decoration: InputDecoration(
//           hintText: hint,
//           hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
//           contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(20),
//             borderSide: const BorderSide(color: Colors.black54),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(20),
//             borderSide: const BorderSide(color: Colors.black54),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(20),
//             borderSide: const BorderSide(color: Colors.orange, width: 2),
//           ),
//         ),
//         onTap: _clearMessage,
//         enabled: !_isApiCalling,
//       ),
//     );
//   }
//
//   Widget _buildBottomBar() {
//     int totalBids = _bids.length;
//     int totalPoints = _getTotalPoints();
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             spreadRadius: 0,
//             blurRadius: 10,
//             offset: const Offset(0, -2),
//           ),
//         ],
//         border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 'Total Bids',
//                 style: GoogleFonts.poppins(
//                   fontSize: 13,
//                   color: Colors.blueGrey[700],
//                 ),
//               ),
//               Text(
//                 '$totalBids',
//                 style: GoogleFonts.poppins(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 'Total Points',
//                 style: GoogleFonts.poppins(
//                   fontSize: 13,
//                   color: Colors.blueGrey[700],
//                 ),
//               ),
//               Text(
//                 '$totalPoints',
//                 style: GoogleFonts.poppins(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//           ElevatedButton(
//             onPressed: _isApiCalling ? null : _showBidConfirmationDialog,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _isApiCalling ? Colors.grey : Colors.orange,
//               padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               elevation: 2,
//             ),
//             child: _isApiCalling
//                 ? const CircularProgressIndicator(
//                     color: Colors.white,
//                     strokeWidth: 2,
//                   )
//                 : Text(
//                     'SUBMIT',
//                     style: GoogleFonts.poppins(
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }
