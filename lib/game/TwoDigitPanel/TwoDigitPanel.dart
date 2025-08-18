// lib/screens/two_digit_panel_screen.dart
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../ulits/Constents.dart';

class Bid {
  final String digit; // user-entered 2-digit string (e.g. "07")
  final String amount; // per-pana points
  final String pana; // expanded pana from API

  const Bid({required this.digit, required this.amount, required this.pana});

  Bid copyWith({String? digit, String? amount, String? pana}) {
    return Bid(
      digit: digit ?? this.digit,
      amount: amount ?? this.amount,
      pana: pana ?? this.pana,
    );
  }
}

class TwoDigitPanelScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType; // "twoDigitsPanel"

  const TwoDigitPanelScreen({
    Key? key,
    required this.title,
    required this.gameId,
    this.gameType = "twoDigitsPanel",
  }) : super(key: key);

  @override
  State<TwoDigitPanelScreen> createState() => _TwoDigitPanelScreenState();
}

class _TwoDigitPanelScreenState extends State<TwoDigitPanelScreen> {
  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  final List<Bid> _bids = <Bid>[];

  final GetStorage storage = GetStorage();
  late String accessToken;
  late String registerId;
  late bool accountStatus;
  late int walletBalance;

  static const String _deviceId = 'test_device_id_flutter';
  static const String _deviceName = 'test_device_name_flutter';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  bool _isAddBidApiCalling = false;
  bool _isSubmitBidApiCalling = false;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
    final num? bal = num.tryParse(userController.walletBalance.value);
    walletBalance = bal?.toInt() ?? 0;
  }

  @override
  void dispose() {
    digitController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _messageToShow = msg;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
  }

  void _clearMessage() {
    if (!mounted) return;
    setState(() => _messageToShow = null);
  }

  int get _totalPoints =>
      _bids.fold(0, (sum, b) => sum + (int.tryParse(b.amount) ?? 0));

  /// ---------------- ADD (Expand panas) ----------------
  Future<void> addBid() async {
    _clearMessage();
    if (_isAddBidApiCalling || _isSubmitBidApiCalling) return;

    final String twoDigit = digitController.text.trim(); // keep "07"
    final String amountText = amountController.text.trim();

    if (twoDigit.isEmpty ||
        twoDigit.length != 2 ||
        int.tryParse(twoDigit) == null) {
      _showMessage('2 digit number do (00–99).', isError: true);
      return;
    }
    final int? perPana = int.tryParse(amountText);
    if (perPana == null || perPana < 10 || perPana > 10000) {
      _showMessage('Points 10 se 10000 ke beech me do.', isError: true);
      return;
    }
    if (accessToken.isEmpty || registerId.isEmpty) {
      _showMessage('Auth issue — dobara login karo.', isError: true);
      return;
    }

    setState(() => _isAddBidApiCalling = true);

    final url = Uri.parse('${Constant.apiEndpoint}two-digits-panel-pana');
    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    // ✅ IMPORTANT: sessionType hata diya (server error de raha tha)
    final body = jsonEncode({
      "digit": twoDigit, // string to keep leading zero
      "amount": perPana,
    });

    log('[TwoDigitsPanel] Expand URL : $url');
    log('[TwoDigitsPanel] Headers    : $headers');
    log('[TwoDigitsPanel] Body       : $body');

    try {
      final resp = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      final map = jsonDecode(resp.body);
      log('[TwoDigitsPanel] Expand HTTP ${resp.statusCode}');
      log('[TwoDigitsPanel] Expand Resp: $map');

      if (resp.statusCode == 200 && map['status'] == true) {
        final List<dynamic> info = (map['info'] ?? []) as List<dynamic>;
        if (info.isEmpty) {
          _showMessage('Is 2 digit ke liye koi pana nahi mila.', isError: true);
          return;
        }

        final temp = List<Bid>.from(_bids);
        int inserted = 0;

        for (final it in info) {
          final String pana = it['pana']?.toString() ?? '';
          final String panaAmount =
              it['amount']?.toString() ?? perPana.toString();
          if (pana.isEmpty) continue;

          final idx = temp.indexWhere((e) => e.pana == pana);
          if (idx >= 0) {
            temp[idx] = temp[idx].copyWith(amount: panaAmount, digit: twoDigit);
          } else {
            temp.add(Bid(digit: twoDigit, amount: panaAmount, pana: pana));
            inserted++;
          }
        }

        final int newTotal = temp.fold(
          0,
          (s, b) => s + (int.tryParse(b.amount) ?? 0),
        );
        if (walletBalance > 0 && newTotal > walletBalance) {
          _showMessage('Wallet me itne points nahi hai.', isError: true);
          return;
        }

        setState(() {
          _bids
            ..clear()
            ..addAll(temp);
          digitController.clear();
          amountController.clear();
        });

        _showMessage(
          inserted > 0 ? '$inserted pana add hue.' : 'Amounts update ho gaye.',
          isError: false,
        );
      } else {
        _showMessage(
          map['msg']?.toString() ?? 'Pana fetch fail.',
          isError: true,
        );
      }
    } catch (e) {
      log('[TwoDigitsPanel] Expand error: $e');
      _showMessage('Network error. Thodi der baad try karo.', isError: true);
    } finally {
      if (mounted) setState(() => _isAddBidApiCalling = false);
    }
  }

  /// ---------------- DELETE ----------------
  void deleteBid(int index) {
    _clearMessage();
    if (_isAddBidApiCalling || _isSubmitBidApiCalling) return;
    final removed = _bids[index].pana;
    setState(() => _bids.removeAt(index));
    _showMessage('Pana $removed remove ho gaya.');
  }

  /// ---------------- CONFIRM (Dialog) ----------------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_bids.isEmpty) {
      _showMessage('Submit se pehle kuch pana add karo.', isError: true);
      return;
    }
    if (walletBalance < _totalPoints) {
      _showMessage('Wallet balance kam hai.', isError: true);
      return;
    }

    // Dialog rows — `points` key chahiye
    final rows = _bids
        .map(
          (b) => {
            "digit": b.pana, // digits column me pana dikhana hai
            "points": b.amount, // dialog needs 'points'
            "type": "TwoDigitsPanel",
            "pana": b.pana,
          },
        )
        .toList();

    final when = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.title,
        gameDate: when,
        bids: rows,
        totalBids: _bids.length,
        totalBidsAmount: _totalPoints,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - _totalPoints).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType, // "twoDigitsPanel"
        onConfirm: () async {
          setState(() => _isSubmitBidApiCalling = true);
          final ok = await _placeFinalBids();
          if (mounted) setState(() => _isSubmitBidApiCalling = false);

          if (ok && mounted) {
            await showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) => const BidSuccessDialog(),
            );
            setState(() => _bids.clear());
          } else if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) => BidFailureDialog(
                errorMessage: _messageToShow ?? 'Bid submit fail ho gaya.',
              ),
            );
          }
        },
      ),
    );
  }

  /// ---------------- SUBMIT (place-bid) ----------------
  Future<bool> _placeFinalBids() async {
    final url = '${Constant.apiEndpoint}place-bid';

    if (accessToken.isEmpty || registerId.isEmpty) {
      _showMessage('Auth issue — dobara login karo.', isError: true);
      return false;
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    // ✅ Tumhari requirement ke hisaab se: pana-only submit
    final List<Map<String, dynamic>> bidPayload = _bids
        .map(
          (b) => {
            "sessionType": "twoDigitsPanel",
            "digit": b.pana, // pana
            "pana": b.pana, // pana
            "bidAmount": int.tryParse(b.amount) ?? 0,
          },
        )
        .toList();

    final int total = bidPayload.fold(0, (s, m) => s + (m['bidAmount'] as int));

    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId,
      "bidAmount": total,
      "gameType": widget.gameType, // "twoDigitsPanel"
      "bid": bidPayload,
    });

    log('[TwoDigitsPanel] Submit URL : $url');
    log('[TwoDigitsPanel] Headers    : $headers');
    log('[TwoDigitsPanel] Body       : $body');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      final map = jsonDecode(response.body);
      log('[TwoDigitsPanel] Submit HTTP ${response.statusCode}');
      log('[TwoDigitsPanel] Submit Resp: $map');

      if (response.statusCode == 200 &&
          (map['status'] == true || map['status'] == 'true')) {
        final newBal = walletBalance - total;
        await storage.write('walletBalance', newBal.toString());
        if (mounted) setState(() => walletBalance = newBal);
        _clearMessage();
        _showMessage('Sab bids successfully submit ho gaye!');
        return true;
      } else {
        _showMessage(
          map['msg']?.toString() ?? 'Place bid failed.',
          isError: true,
        );
        return false;
      }
    } catch (e) {
      log('[TwoDigitsPanel] Submit error: $e');
      _showMessage(
        'Network error aaya. Thodi der baad try karo.',
        isError: true,
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAnyApiCalling = _isAddBidApiCalling || _isSubmitBidApiCalling;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
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
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // labels
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 6.0),
                            child: Text(
                              'Enter Two Digits:',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          SizedBox(height: 50),
                          Text('Enter Points:', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                      const Spacer(),
                      // inputs + add
                      Column(
                        children: [
                          SizedBox(
                            height: 40,
                            width: 180,
                            child: TextField(
                              controller: digitController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              onTap: _clearMessage,
                              enabled: !isAnyApiCalling,
                              decoration: InputDecoration(
                                hintText: 'Bid Digits',
                                hintStyle: const TextStyle(fontSize: 14),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 40,
                            width: 180,
                            child: TextField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(5),
                              ],
                              onTap: _clearMessage,
                              enabled: !isAnyApiCalling,
                              decoration: InputDecoration(
                                hintText: 'Enter Amount',
                                hintStyle: const TextStyle(fontSize: 14),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: isAnyApiCalling ? null : addBid,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isAnyApiCalling
                                  ? Colors.grey
                                  : Colors.red,
                              minimumSize: const Size(80, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isAddBidApiCalling
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'ADD BID',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1),

                if (_bids.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: const [
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pana',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 40),
                        Expanded(
                          child: Text(
                            'Points',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Spacer(),
                      ],
                    ),
                  ),

                Expanded(
                  child: _bids.isEmpty
                      ? const Center(child: Text('No bids yet'))
                      : ListView.builder(
                          itemCount: _bids.length,
                          itemBuilder: (context, index) {
                            final b = _bids[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 0,
                              ),
                              child: Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(b.pana)),
                                      Expanded(child: Text(b.amount)),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: isAnyApiCalling
                                            ? null
                                            : () => deleteBid(index),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                if (_bids.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Bid",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Text("${_bids.length}"),
                        const SizedBox(width: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Total",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Text("$_totalPoints"),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: isAnyApiCalling
                              ? null
                              : _showConfirmationDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAnyApiCalling
                                ? Colors.grey
                                : Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitBidApiCalling
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'SUBMIT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
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
}
