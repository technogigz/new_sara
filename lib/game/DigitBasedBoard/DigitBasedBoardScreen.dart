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
import 'package:new_sara/BidsServicesBulk.dart';
import 'package:new_sara/Helper/UserController.dart';

import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../ulits/Constents.dart';

class DigitBasedBoardScreen extends StatefulWidget {
  final String title;
  final String gameType; // e.g. "digitBasedJodi"
  final String gameId; // parsed to int
  final String gameName; // (display only)

  const DigitBasedBoardScreen({
    Key? key,
    required this.title,
    required this.gameType,
    required this.gameId,
    required this.gameName,
  }) : super(key: key);

  @override
  State<DigitBasedBoardScreen> createState() => _DigitBasedBoardScreenState();
}

class _DigitBasedBoardScreenState extends State<DigitBasedBoardScreen> {
  final TextEditingController _leftDigitController = TextEditingController();
  final TextEditingController _rightDigitController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  final GetStorage _storage = GetStorage();
  late final BidServiceBulk _bidService;

  String _accessToken = '';
  String _registerId = '';
  bool _accountStatus = false;
  late int _walletBalance;

  /// entries: {'digit': 'xy', 'points': 'nn'}
  final List<Map<String, String>> _entries = [];
  bool _isAdding = false; // NEW: add-call loading
  bool _isSubmitting = false; // submit-call loading

  // Message bar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  @override
  void initState() {
    super.initState();
    _bidService = BidServiceBulk(_storage);

    _accessToken = _storage.read('accessToken')?.toString() ?? '';
    _registerId = _storage.read('registerId')?.toString() ?? '';
    _accountStatus = userController.accountStatus.value;

    final num? bal = num.tryParse(userController.walletBalance.value);
    _walletBalance = bal?.toInt() ?? 0;
  }

  @override
  void dispose() {
    _leftDigitController.dispose();
    _rightDigitController.dispose();
    _pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  // ---------------- Message bar ----------------
  void _showMessage(String msg, {bool isError = false}) {
    _messageDismissTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messageToShow = msg;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    _messageDismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _messageToShow = null);
    });
  }

  void _clearMessage() {
    if (!mounted) return;
    setState(() => _messageToShow = null);
  }

  // ---------------- Helpers ----------------
  int _getTotalPoints() =>
      _entries.fold(0, (s, e) => s + (int.tryParse(e['points'] ?? '0') ?? 0));

  void _mergeOrAdd(String digit, int amount) {
    final idx = _entries.indexWhere((e) => e['digit'] == digit);
    if (idx >= 0) {
      final cur = int.tryParse(_entries[idx]['points'] ?? '0') ?? 0;
      _entries[idx]['points'] = (cur + amount).toString();
    } else {
      _entries.add({'digit': digit, 'points': amount.toString()});
    }
  }

  // ---------------- Add flow (expand via API) ----------------
  Future<void> _addEntry() async {
    _clearMessage();
    if (_isAdding || _isSubmitting) return;

    final leftTxt = _leftDigitController.text.trim();
    final rightTxt = _rightDigitController.text.trim();
    final ptsTxt = _pointsController.text.trim();

    if (leftTxt.isEmpty && rightTxt.isEmpty) {
      _showMessage('Left ya Right me se kam se kam 1 digit do.', isError: true);
      return;
    }

    final int? pts = int.tryParse(ptsTxt);
    if (pts == null || pts < 10 || pts > 1000) {
      _showMessage('Points 10 se 1000 ke beech me do.', isError: true);
      return;
    }

    if (leftTxt.isNotEmpty &&
        (leftTxt.length != 1 || int.tryParse(leftTxt) == null)) {
      _showMessage(
        'Left digit 0-9 ka single number hona chahiye.',
        isError: true,
      );
      return;
    }
    if (rightTxt.isNotEmpty &&
        (rightTxt.length != 1 || int.tryParse(rightTxt) == null)) {
      _showMessage(
        'Right digit 0-9 ka single number hona chahiye.',
        isError: true,
      );
      return;
    }

    if (_accessToken.isEmpty || _registerId.isEmpty) {
      _showMessage('Auth issue — please login again.', isError: true);
      return;
    }

    final Map<String, dynamic> body;
    if (leftTxt.isNotEmpty && rightTxt.isEmpty) {
      body = {"leftDigit": int.parse(leftTxt), "amount": pts};
    } else if (leftTxt.isEmpty && rightTxt.isNotEmpty) {
      body = {"rightDigit": int.parse(rightTxt), "amount": pts};
    } else {
      body = {
        "leftDigit": int.parse(leftTxt),
        "rightDigit": int.parse(rightTxt),
        "amount": pts,
      };
    }

    final headers = {
      'deviceId': _storage.read('deviceId')?.toString() ?? 'device_digit_based',
      'deviceName':
          _storage.read('deviceName')?.toString() ?? 'DigitBasedBoard',
      'accessStatus': _accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

    setState(() => _isAdding = true);

    try {
      final resp = await http.post(
        Uri.parse('${Constant.apiEndpoint}digit-based-jodi'),
        headers: headers,
        body: jsonEncode(body),
      );

      final Map<String, dynamic> data = json.decode(resp.body);
      log('[DigitBased] expand HTTP ${resp.statusCode}');
      log('[DigitBased] expand resp: $data');

      if (resp.statusCode == 200 && data['status'] == true) {
        final List<dynamic> info = data['info'] ?? [];
        if (info.isEmpty) {
          _showMessage('Server se koi pana/jodi nahi aaya.', isError: true);
          return;
        }

        // tentative list banake wallet overflow check (optional)
        final temp = List<Map<String, String>>.from(_entries);
        for (final item in info) {
          final d = item['pana']?.toString() ?? '';
          final a = int.tryParse(item['amount']?.toString() ?? '0') ?? 0;
          if (d.isNotEmpty && a > 0) {
            final idx = temp.indexWhere((e) => e['digit'] == d);
            if (idx >= 0) {
              final cur = int.tryParse(temp[idx]['points'] ?? '0') ?? 0;
              temp[idx]['points'] = (cur + a).toString();
            } else {
              temp.add({'digit': d, 'points': a.toString()});
            }
          }
        }
        final newTotal = temp.fold(
          0,
          (s, e) => s + (int.tryParse(e['points'] ?? '0') ?? 0),
        );
        if (_walletBalance > 0 && newTotal > _walletBalance) {
          _showMessage(
            'Itne add karoge to total wallet se zyada ho jayega.',
            isError: true,
          );
          return;
        }

        setState(() {
          for (final item in info) {
            final d = item['pana']?.toString() ?? '';
            final a = int.tryParse(item['amount']?.toString() ?? '0') ?? 0;
            if (d.isNotEmpty && a > 0) {
              _mergeOrAdd(d, a);
            }
          }
          _leftDigitController.clear();
          _rightDigitController.clear();
          _pointsController.clear();
        });

        _showMessage('Pairs/Pana add ho gaye.', isError: false);
      } else {
        _showMessage(
          data['msg']?.toString() ?? 'Expand failed.',
          isError: true,
        );
      }
    } catch (e) {
      log('expand error: $e');
      _showMessage('Network error. Thodi der baad try karo.', isError: true);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  void _deleteEntry(int index) {
    if (_isSubmitting) return;
    setState(() {
      final removed = _entries.removeAt(index);
      _showMessage('Removed ${removed['digit']}.');
    });
  }

  // ---------------- Submit flow ----------------
  void _openConfirmDialog() {
    _clearMessage();
    if (_isSubmitting || _isAdding) return;

    if (_entries.isEmpty) {
      _showMessage('Pehle kuch bids add karo.', isError: true);
      return;
    }

    final total = _getTotalPoints();
    if (total > _walletBalance) {
      _showMessage('Wallet balance kam hai.', isError: true);
      return;
    }

    final bidsForDialog = _entries
        .map(
          (e) => {
            'digit': e['digit']!, // dialog me "Digits" me pana/jodi
            'points': e['points']!, // amount spent
            'type': 'Digit Based', // sirf display
            'pana': e['digit']!,
          },
        )
        .toList();

    final whenStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.title,
        gameDate: whenStr,
        bids: bidsForDialog,
        totalBids: bidsForDialog.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction: _walletBalance,
        walletBalanceAfterDeduction: (_walletBalance - total).toString(),
        gameId: widget.gameId,
        gameType: widget.gameType,
        onConfirm: () async {
          if (!mounted) return;
          setState(() => _isSubmitting = true);
          final ok = await _submitBids(total);
          if (mounted) setState(() => _isSubmitting = false);
          if (ok) {
            setState(() => _entries.clear());
          }
        },
      ),
    );
  }

  Future<bool> _submitBids(int totalPoints) async {
    if (_accessToken.isEmpty || _registerId.isEmpty) {
      _showMessage('Auth issue — please login again.', isError: true);
      return false;
    }

    final int gameIdInt = int.tryParse(widget.gameId) ?? 0;

    final headers = {
      'deviceId': _storage.read('deviceId')?.toString() ?? 'device_digit_based',
      'deviceName':
          _storage.read('deviceName')?.toString() ?? 'DigitBasedBoard',
      'accessStatus': _accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

    // EXACT payload
    final payload = {
      "registerId": _registerId,
      "gameId": gameIdInt,
      "bidAmount": totalPoints,
      "gameType": widget.gameType, // "digitBasedJodi"
      "bid": _entries
          .map(
            (e) => {
              "sessionType": widget.gameType, // "digitBasedJodi"
              "digit": e['digit'],
              "pana": e['digit'],
              "bidAmount": int.tryParse(e['points'] ?? '0') ?? 0,
            },
          )
          .toList(),
    };

    log('[DigitBased] place-bid headers: $headers');
    log('[DigitBased] place-bid body: $payload');

    try {
      final resp = await http.post(
        Uri.parse('${Constant.apiEndpoint}place-bid'),
        headers: headers,
        body: jsonEncode(payload),
      );

      final Map<String, dynamic> data = json.decode(resp.body);
      log('[DigitBased] place-bid HTTP ${resp.statusCode}');
      log('[DigitBased] place-bid resp: $data');

      if (resp.statusCode == 200 &&
          (data['status'] == true || data['status'] == 'true')) {
        final dynamic serverBal = data['updatedWalletBalance'];
        final int newBal =
            int.tryParse(serverBal?.toString() ?? '') ??
            (_walletBalance - totalPoints);

        await _bidService.updateWalletBalance(newBal);
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
      log('place-bid error: $e');
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Network error. Please check your internet connection.',
        ),
      );
      return false;
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final totalBids = _entries.length;
    final totalPoints = _getTotalPoints();
    final isBusy = _isAdding || _isSubmitting;

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
          style: GoogleFonts.poppins(
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
                  '₹$_walletBalance',
                  style: GoogleFonts.poppins(color: Colors.black, fontSize: 16),
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
                            child: _digitField(
                              'Left Digit',
                              _leftDigitController,
                              isBusy,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _digitField(
                              'Right Digit',
                              _rightDigitController,
                              isBusy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Enter Points :',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _pointsField(_pointsController, isBusy),
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
                              onPressed: isBusy ? null : _addEntry,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isBusy
                                    ? Colors.grey
                                    : Colors.orange,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 3,
                              ),
                              child: (_isAdding)
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      'ADD',
                                      style: GoogleFonts.poppins(
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
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Digits', // Pana/Jodi digits
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Points',
                            style: GoogleFonts.poppins(
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
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final e = _entries[index];
                            return _entryTile(
                              e['digit']!,
                              e['points']!,
                              index,
                              isBusy,
                            );
                          },
                        ),
                ),
                if (_entries.isNotEmpty)
                  _bottomBar(totalBids, totalPoints, isBusy),
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

  // ---------------- Widgets ----------------
  Widget _digitField(String label, TextEditingController c, bool disabled) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        cursorColor: Colors.orange,
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: _clearMessage,
        enabled: !disabled,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _pointsField(TextEditingController c, bool disabled) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        cursorColor: Colors.orange,
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onTap: _clearMessage,
        enabled: !disabled,
        decoration: InputDecoration(
          hintText: 'Enter Points',
          hintStyle: GoogleFonts.poppins(color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _entryTile(String digits, String points, int index, bool disabled) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                digits,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                points,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: disabled ? null : () => _deleteEntry(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(int totalBids, int totalPoints, bool disabled) {
    final canSubmit = !disabled && _entries.isNotEmpty;
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
            onPressed: canSubmit ? _openConfirmDialog : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? Colors.orange : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
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
