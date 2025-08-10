import 'dart:async';
import 'dart:convert';
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:new_sara/KingStarline&Jackpot/StarlineBidService.dart';

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart'; // Ensure this path is correct
import '../../components/BidConfirmationDialog.dart'; // Ensure this path is correct
import '../../components/BidFailureDialog.dart'; // For API failure dialog (ensure this path is correct)
import '../../components/BidSuccessDialog.dart';
import '../../ulits/Constents.dart'; // For API success dialog (ensure this path is correct)

class StarlineSpDpTpScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;
  final String gameType;

  const StarlineSpDpTpScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId,
    required this.gameType,
  }) : super(key: key);

  @override
  State<StarlineSpDpTpScreen> createState() => _StarlineSpDpTpScreenState();
}

class _StarlineSpDpTpScreenState extends State<StarlineSpDpTpScreen> {
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _pannaController = TextEditingController();

  bool _isSPSelected = false;
  bool _isDPSelected = false;
  bool _isTPSelected = false;

  // Game type is now fixed to 'OPEN'
  final String _selectedGameTypeOption = 'OPEN';

  List<Map<String, String>> _bids = [];

  late int walletBalance;
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  final GetStorage storage = GetStorage();

  late StarlineBidService _bidService;

  final String _deviceId = GetStorage().read('deviceId') ?? '';
  final String _deviceName = GetStorage().read('deviceName') ?? '';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  bool _isApiCalling = false;

  final UserController userController = Get.put(UserController());

  @override
  void initState() {
    super.initState();
    _bidService = StarlineBidService(storage);
    _loadInitialData();
    double walletBalanceDouble = double.parse(
      userController.walletBalance.value,
    );
    walletBalance = walletBalanceDouble.toInt();
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
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

  @override
  void dispose() {
    _pointsController.dispose();
    _pannaController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
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

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
    );
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;
    if (_bids.isEmpty) {
      _showMessage('Please add bids before submitting.', isError: true);
      return;
    }

    int currentTotalPoints = _getTotalPoints();

    if (walletBalance < currentTotalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
      return;
    }

    final List<Map<String, String>> validBids = _bids
        .where((bid) {
          return bid['digit'] != null &&
              bid['digit']!.isNotEmpty &&
              bid['amount'] != null &&
              bid['amount']!.isNotEmpty &&
              bid['gameType'] != null &&
              bid['gameType']!.isNotEmpty;
        })
        .map((bid) {
          return {
            'digit': bid['digit']!,
            'points': bid['amount']!,
            'type': _selectedGameTypeOption,
            'pana': bid['digit']!,
            'jodi': '',
          };
        })
        .toList();

    if (validBids.isEmpty) {
      _showMessage('No valid bids to submit.', isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.screenTitle,
          bids: validBids,
          totalBids: validBids.length,
          totalBidsAmount: currentTotalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - currentTotalPoints)
              .toString(),
          gameDate: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            setState(() {
              _isApiCalling = true;
            });
            await _placeFinalBids();
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
    final Map<String, String> bidPayload = {};
    int currentBatchTotalPoints = _getTotalPoints();

    if (accessToken.isEmpty || registerId.isEmpty) {
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

    for (var bid in _bids) {
      String digit = bid["digit"] ?? "";
      String amount = bid["amount"] ?? "0";

      if (digit.isNotEmpty && int.tryParse(amount) != null) {
        bidPayload[digit] = amount;
      }
    }

    if (bidPayload.isEmpty) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const BidFailureDialog(errorMessage: 'No valid bids to submit.'),
      );
      return false;
    }

    try {
      final result = await _bidService.placeFinalBids(
        gameName: widget.screenTitle,
        accessToken: accessToken,
        registerId: registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: accountStatus,
        bidAmounts: bidPayload,
        selectedGameType: _selectedGameTypeOption,
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: currentBatchTotalPoints,
      );

      if (!mounted) return false;

      if (result['status'] == true) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );

        final dynamic updatedBalanceRaw = result['updatedWalletBalance'];
        final int updatedBalance =
            int.tryParse(updatedBalanceRaw.toString()) ??
            (walletBalance - currentBatchTotalPoints);
        setState(() {
          walletBalance = updatedBalance;
          _bids.clear();
        });
        _bidService.updateWalletBalance(updatedBalance);
        return true;
      } else {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(
            errorMessage: result['msg'] ?? 'Something went wrong',
          ),
        );
        return false;
      }
    } catch (e) {
      log(
        'Error during bid placement: $e',
        name: 'StarlineSpDpTpScreenBidError',
      );
      if (!mounted) return false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'An unexpected error occurred during bid submission.',
        ),
      );
      return false;
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
    Map<String, int> freq = {};
    for (var d in digits) {
      freq[d] = (freq[d] ?? 0) + 1;
    }
    return freq.length == 2 && freq.values.contains(2);
  }

  bool _isValidTpPanna(String panna) {
    if (panna.length != 3) return false;
    return panna[0] == panna[1] && panna[1] == panna[2];
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

  Future<List<String>> singlePanaBulk({
    required int digit,
    required int amount,
    required String sessionType,
    required String gameId,
    required String registerId,
  }) async {
    return await _fetchBulkPannaBids(
      digit: digit,
      amount: amount,
      sessionType: sessionType,
      apiEndpoint: '${Constant.apiEndpoint}single-pana-bulk',
      gameId: gameId,
      registerId: registerId,
    );
  }

  Future<List<String>> doublePanaBulk({
    required int digit,
    required int amount,
    required String sessionType,
    required String gameId,
    required String registerId,
  }) async {
    return await _fetchBulkPannaBids(
      digit: digit,
      amount: amount,
      sessionType: sessionType,
      apiEndpoint: '${Constant.apiEndpoint}double-pana-bulk',
      gameId: gameId,
      registerId: registerId,
    );
  }

  Future<List<String>> triplePanaBulk({
    required int digit,
    required int amount,
    required String sessionType,
    required String gameId,
    required String registerId,
  }) async {
    return await _fetchBulkPannaBids(
      digit: digit,
      amount: amount,
      sessionType: sessionType,
      apiEndpoint: '${Constant.apiEndpoint}triple-pana-bulk',
      gameId: gameId,
      registerId: registerId,
    );
  }

  // ✅ Common Fetch Function
  Future<List<String>> _fetchBulkPannaBids({
    required int digit,
    required int amount,
    required String sessionType,
    required String apiEndpoint,
    required String gameId,
    required String registerId,
  }) async {
    final uri = Uri.parse(apiEndpoint);

    final deviceId = GetStorage().read('deviceId')?.toString() ?? '';
    final deviceName = GetStorage().read('deviceName')?.toString() ?? '';
    final accessToken = GetStorage().read('accessToken')?.toString() ?? '';
    final accessStatus = GetStorage().read('accountStatus') == true ? '1' : '0';

    final headers = <String, String>{
      'deviceId': deviceId,
      'deviceName': deviceName,
      'accessStatus': accessStatus,
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final body = jsonEncode({
      "game_id": gameId,
      "register_id": registerId,
      "session_type": sessionType,
      "digit": digit,
      "amount": amount,
    });

    try {
      final response = await http.post(uri, headers: headers, body: body);
      final responseData = json.decode(response.body);

      log("API Response from $apiEndpoint: $responseData");

      if (response.statusCode == 200 && responseData['status'] == true) {
        final List<dynamic> info = responseData['info'] ?? [];
        return info.map<String>((item) => item['pana'].toString()).toList();
      } else {
        throw 'API Error: ${responseData['msg'] ?? 'Unknown error'}';
      }
    } catch (e) {
      log("Error fetching panna bids from $apiEndpoint: $e");
      throw 'Network/API Error: $e';
    }
  }

  void _addBid() async {
    _clearMessage();
    if (_isApiCalling) return;

    final digitText = _pannaController.text.trim();
    final pointsText = _pointsController.text.trim();

    // Determine selected Game Category
    String? gameCategory;
    if (_isSPSelected) gameCategory = 'SP';
    if (_isDPSelected) gameCategory = 'DP';
    if (_isTPSelected) gameCategory = 'TP';

    if (gameCategory == null) {
      _showMessage('Please select SP, DP, or TP.', isError: true);
      return;
    }

    if (digitText.isEmpty || digitText.length != 1) {
      _showMessage('Please enter a valid single digit (0-9).', isError: true);
      return;
    }

    final digit = int.tryParse(digitText);
    if (digit == null || digit < 0 || digit > 9) {
      _showMessage('Digit must be a number from 0 to 9.', isError: true);
      return;
    }

    final points = int.tryParse(pointsText);
    if (points == null || points < 10) {
      _showMessage('Points must be at least 10.', isError: true);
      return;
    }

    final sessionType = gameCategory.toLowerCase(); // 'sp', 'dp', 'tp'

    setState(() => _isApiCalling = true);

    try {
      final apiMap = {
        'SP': '${Constant.apiEndpoint}single-pana-bulk',
        'DP': '${Constant.apiEndpoint}double-pana-bulk',
        'TP': '${Constant.apiEndpoint}triple-pana-bulk',
      };

      final selectedEndpoint = apiMap[gameCategory]!;

      final pannaList = await _fetchBulkPannaBids(
        digit: digit,
        amount: points,
        sessionType: sessionType,
        apiEndpoint: selectedEndpoint,
        gameId: widget.gameId.toString(),
        registerId:
            '', // You can replace it with GetStorage().read('registerId') if needed
      );

      int addedCount = 0;

      setState(() {
        for (String item in pannaList) {
          bool alreadyExists = _bids.any(
            (bid) =>
                bid['digit'] == item &&
                bid['amount'] == points.toString() &&
                bid['gameType'] == gameCategory,
          );

          if (!alreadyExists) {
            _bids.add({
              'digit': item,
              'amount': points.toString(),
              'gameType':
                  _selectedGameTypeOption, // ✅ FIXED: Use selected game category directly
            });
            addedCount++;
          }
        }

        _pannaController.clear();
        _pointsController.clear();

        if (addedCount > 0) {
          _showMessage('$addedCount bids added for $gameCategory.');
        } else {
          _showMessage('All bids already exist.', isError: true);
        }
      });
    } catch (e) {
      _showMessage('Error: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isApiCalling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String marketName = widget.screenTitle.split(' - ')[0];

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
              userController.walletBalance.value,
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
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _isSPSelected,
                                  onChanged: _isApiCalling
                                      ? null
                                      : (bool? value) {
                                          setState(() {
                                            _isSPSelected = value!;
                                            if (value) {
                                              _isDPSelected = false;
                                              _isTPSelected = false;
                                            }
                                            _clearMessage();
                                          });
                                        },
                                  activeColor: Colors.orange,
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
                              children: [
                                Checkbox(
                                  value: _isDPSelected,
                                  onChanged: _isApiCalling
                                      ? null
                                      : (bool? value) {
                                          setState(() {
                                            _isDPSelected = value!;
                                            if (value) {
                                              _isSPSelected = false;
                                              _isTPSelected = false;
                                            }
                                            _clearMessage();
                                          });
                                        },
                                  activeColor: Colors.orange,
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
                              children: [
                                Checkbox(
                                  value: _isTPSelected,
                                  onChanged: _isApiCalling
                                      ? null
                                      : (bool? value) {
                                          setState(() {
                                            _isTPSelected = value!;
                                            if (value) {
                                              _isSPSelected = false;
                                              _isDPSelected = false;
                                            }
                                            _clearMessage();
                                          });
                                        },
                                  activeColor: Colors.orange,
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
                          const Text(
                            'Enter Single Digit:',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(
                            width: 150,
                            height: 40,
                            child: TextField(
                              cursorColor: Colors.orange,
                              controller: _pannaController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(3),
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                hintText: 'Enter Single Digit',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                  borderSide: BorderSide(
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
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Enter Points:',
                            style: TextStyle(fontSize: 16),
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
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: const InputDecoration(
                                hintText: 'Enter Amount',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                  borderSide: BorderSide(
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
                      const SizedBox(height: 15),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 150,
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
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : Text(
                                    "ADD",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      fontSize: 16,
                                    ),
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 2),
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
                                        bid['digit']!,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        bid['amount']!,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${bid['gameType']} ($_selectedGameTypeOption)',
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
