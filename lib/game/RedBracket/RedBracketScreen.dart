// lib/screens/red_bracket_board_screen.dart
import 'dart:async';
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

enum BracketType { half, full }

class RedBracketBoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;
  final String gameType; // "redBracket"

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
  final TextEditingController _amountController = TextEditingController();

  // entries: { digit: "xy", points: "nn", source: "HALF" | "FULL" }
  final List<Map<String, String>> _bids = [];
  BracketType _bracketType = BracketType.half;

  final GetStorage _storage = GetStorage();

  String _accessToken = '';
  String _registerId = '';
  bool _accountStatus = false;
  int _walletBalance = 0;

  bool _isBusy = false;

  String get _deviceId =>
      _storage.read('deviceId')?.toString() ?? 'device_red_bracket';
  String get _deviceName =>
      _storage.read('deviceName')?.toString() ?? 'RedBracketScreen';

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  // Message bar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _initAuthAndWallet();
  }

  Future<void> _initAuthAndWallet() async {
    _accessToken = _storage.read('accessToken')?.toString() ?? '';
    _registerId = _storage.read('registerId')?.toString() ?? '';
    _accountStatus = userController.accountStatus.value;

    final num? bal = num.tryParse(userController.walletBalance.value);
    _walletBalance = bal?.toInt() ?? 0;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  // ---------------- message bar ----------------
  void _showMessage(String msg, {bool isError = false}) {
    _dismissTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messageToShow = msg;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _messageToShow = null);
    });
  }

  void _clearMessage() {
    if (!mounted) return;
    setState(() => _messageToShow = null);
  }

  // ---------------- helpers ----------------
  int _getTotalPoints() =>
      _bids.fold(0, (s, e) => s + (int.tryParse(e['points'] ?? '0') ?? 0));

  void _mergeOrAdd(String digit, int amount, String source) {
    final i = _bids.indexWhere(
      (b) => b['digit'] == digit && b['source'] == source,
    );
    if (i >= 0) {
      final cur = int.tryParse(_bids[i]['points'] ?? '0') ?? 0;
      _bids[i]['points'] = (cur + amount).toString();
    } else {
      _bids.add({
        'digit': digit,
        'points': amount.toString(),
        'source': source,
      });
    }
  }

  // ---------------- ADD (expand) ----------------
  Future<void> _addBid() async {
    if (_isBusy) return;
    _clearMessage();

    final txt = _amountController.text.trim();
    final int? amt = int.tryParse(txt);
    if (amt == null || amt < 10 || amt > 10000) {
      _showMessage('Amount 10–10000 ke beech do.', isError: true);
      return;
    }

    if (_accessToken.isEmpty) {
      _showMessage('Auth issue — login dobara karo.', isError: true);
      return;
    }

    final String typeForApi = _bracketType == BracketType.half
        ? 'halfBracket'
        : 'fullBracket'; // <- API ko agar 'half'/'full' chahiye ho to yaha change karo
    final String sourceLabel = _bracketType == BracketType.half
        ? 'HALF'
        : 'FULL';

    final String base = Constant.apiEndpoint.endsWith('/')
        ? Constant.apiEndpoint
        : '${Constant.apiEndpoint}/';
    final String url = '${base}red-bracket-jodi';

    setState(() => _isBusy = true);
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
          'deviceId': _deviceId,
          'deviceName': _deviceName,
          'accessStatus': _accountStatus ? '1' : '0',
        },
        body: jsonEncode({'type': typeForApi, 'amount': amt}),
      );

      final Map<String, dynamic> data = json.decode(resp.body);
      log('[RedBracket] expand HTTP ${resp.statusCode}');
      log('[RedBracket] expand resp: $data');

      if (resp.statusCode == 200 && data['status'] == true) {
        final List<dynamic> info = data['info'] ?? [];
        if (info.isEmpty) {
          _showMessage('Server se koi jodi/pana nahi aaya.', isError: true);
        } else {
          // Wallet guard: tentative total check
          final temp = List<Map<String, String>>.from(_bids);
          for (final it in info) {
            final d = it['pana']?.toString() ?? '';
            final a = int.tryParse(it['amount']?.toString() ?? '0') ?? 0;
            if (d.isEmpty || a <= 0) continue;
            final idx = temp.indexWhere(
              (e) => e['digit'] == d && e['source'] == sourceLabel,
            );
            if (idx >= 0) {
              final cur = int.tryParse(temp[idx]['points'] ?? '0') ?? 0;
              temp[idx]['points'] = (cur + a).toString();
            } else {
              temp.add({
                'digit': d,
                'points': a.toString(),
                'source': sourceLabel,
              });
            }
          }
          final newTotal = temp.fold(
            0,
            (s, e) => s + (int.tryParse(e['points'] ?? '0') ?? 0),
          );
          if (_walletBalance > 0 && newTotal > _walletBalance) {
            _showMessage(
              'Itna add karoge to total wallet se zyada ho jayega.',
              isError: true,
            );
          } else {
            setState(() {
              for (final it in info) {
                final d = it['pana']?.toString() ?? '';
                final a = int.tryParse(it['amount']?.toString() ?? '0') ?? 0;
                if (d.isNotEmpty && a > 0) _mergeOrAdd(d, a, sourceLabel);
              }
              _amountController.clear();
            });
            _showMessage('Bids add ho gaye.', isError: false);
          }
        }
      } else {
        _showMessage(data['msg']?.toString() ?? 'Add failed.', isError: true);
      }
    } catch (e) {
      _showMessage('Network error. Thodi der baad try karo.', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _removeBid(int index) {
    if (_isBusy) return;
    final removed = _bids[index]['digit'];
    setState(() => _bids.removeAt(index));
    _showMessage('Removed $removed.');
  }

  // ---------------- SUBMIT ----------------
  void _openConfirmDialog() {
    _clearMessage();
    if (_isBusy) return;

    if (_bids.isEmpty) {
      _showMessage('Pehle kuch bids add karo.', isError: true);
      return;
    }

    final total = _getTotalPoints();
    if (_walletBalance < total) {
      _showMessage('Wallet balance kam hai.', isError: true);
      return;
    }

    // Dialog rows: Digits = pana, Points = amount, Game Type = RED BRACKET (HALF/FULL)
    final bidsForDialog = _bids
        .map(
          (b) => {
            'digit': b['digit']!,
            'pana': b['digit']!,
            'points': b['points']!,
            'type': 'RED BRACKET (${b['source']})',
            'jodi': b['digit']!,
          },
        )
        .toList();

    final when = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.screenTitle,
        gameDate: when,
        bids: bidsForDialog,
        totalBids: bidsForDialog.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction: _walletBalance,
        walletBalanceAfterDeduction: (_walletBalance - total).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () async {
          setState(() => _isBusy = true);
          final ok = await _submitBids(total);
          if (ok) setState(() => _bids.clear());
          if (mounted) setState(() => _isBusy = false);
        },
      ),
    );
  }

  Future<bool> _submitBids(int totalPoints) async {
    if (_accessToken.isEmpty || _registerId.isEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Auth issue — login dobara karo.',
        ),
      );
      return false;
    }

    final payload = {
      "registerId": _registerId,
      "gameId": widget.gameId, // int
      "bidAmount": totalPoints,
      "gameType": "redBracket",
      "bid": _bids
          .map(
            (b) => {
              "sessionType": "redBracket",
              "digit": b['digit'],
              "pana": b['digit'],
              "bidAmount": int.tryParse(b['points'] ?? '0') ?? 0,
            },
          )
          .toList(),
    };

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': _accountStatus ? '1' : '0',
    };

    log('[RedBracket] place-bid headers: $headers');
    log('[RedBracket] place-bid body: $payload');

    try {
      final uri = Uri.parse(
        '${Constant.apiEndpoint}${Constant.apiEndpoint.endsWith('/') ? '' : '/'}place-bid',
      );
      final resp = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      );
      final Map<String, dynamic> data = json.decode(resp.body);

      log('[RedBracket] place-bid HTTP ${resp.statusCode}');
      log('[RedBracket] place-bid resp: $data');

      if (resp.statusCode == 200 &&
          (data['status'] == true || data['status'] == 'true')) {
        final dynamic serverBal = data['updatedWalletBalance'];
        final int newBal =
            int.tryParse(serverBal?.toString() ?? '') ??
            (_walletBalance - totalPoints);

        await _storage.write('walletBalance', newBal.toString());
        userController.walletBalance.value = newBal.toString();
        setState(() => _walletBalance = newBal);

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );
        _clearMessage();
        return true;
      } else {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(
            errorMessage:
                data['msg']?.toString() ??
                'Place bid failed. Please try again later.',
          ),
        );
        return false;
      }
    } catch (e) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Network error. Internet check karo.',
        ),
      );
      return false;
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final totalBids = _bids.length;
    final totalPoints = _getTotalPoints();

    return Scaffold(
      backgroundColor: Colors.white,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Image.asset(
                  "assets/images/ic_wallet.png",
                  color: Colors.black,
                  height: 20,
                ),
                const SizedBox(width: 6),
                Obx(
                  () => Text(
                    userController.walletBalance.value,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
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
                // Controls
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _bracketRadio(BracketType.half, 'Half Bracket'),
                          const SizedBox(width: 20),
                          _bracketRadio(BracketType.full, 'Full Bracket'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            "Enter Amount",
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _amountField(
                              controller: _amountController,
                              hintText: 'Enter Amount',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _isBusy ? null : _addBid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isBusy
                                ? Colors.grey
                                : Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: _isBusy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "ADD BID",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: .5,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_bids.isNotEmpty) const Divider(thickness: 1, height: 1),
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
                            'Type',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),
                if (_bids.isNotEmpty) const Divider(thickness: 1, height: 1),

                // List
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
                          itemBuilder: (_, i) => _bidTile(i, _bids[i]),
                        ),
                ),

                // Footer
                if (_bids.isNotEmpty) _bottomBar(totalBids, totalPoints),
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

  // ---------------- small widgets ----------------
  Widget _bracketRadio(BracketType type, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<BracketType>(
          value: type,
          groupValue: _bracketType,
          onChanged: (v) => setState(() => _bracketType = v!),
          activeColor: Colors.orange,
        ),
        Text(label, style: GoogleFonts.poppins()),
      ],
    );
  }

  Widget _amountField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
      decoration: const InputDecoration(
        hintText: 'Enter Amount',
        border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.orange, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onTap: _clearMessage,
      enabled: !_isBusy,
    );
  }

  Widget _bidTile(int index, Map<String, String> bid) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(bid['digit']!, style: GoogleFonts.poppins())),
          Expanded(child: Text(bid['points']!, style: GoogleFonts.poppins())),
          Expanded(
            child: Text('RED ${bid['source']}', style: GoogleFonts.poppins()),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _isBusy ? null : () => _removeBid(index),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(int totalBids, int totalPoints) {
    final canSubmit = !_isBusy && _bids.isNotEmpty;
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
            onPressed: canSubmit ? _openConfirmDialog : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? Colors.orange : Colors.grey,
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
