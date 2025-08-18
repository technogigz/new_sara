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

class DPMotorsBetScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType; // e.g. "dpMotor"
  final int gameId;
  final String gameName;
  final bool selectionStatus; // if true => Open + Close; else only Close

  const DPMotorsBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
    required this.selectionStatus,
  });

  @override
  State<DPMotorsBetScreen> createState() => _DPMotorsBetScreenState();
}

class _DPMotorsBetScreenState extends State<DPMotorsBetScreen> {
  // UI
  late String selectedGameBetType; // "Open" | "Close"
  final TextEditingController bidController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  // Auth / env
  late final GetStorage storage;
  late String accessToken;
  late String registerId;
  bool accountStatus = false;
  late int walletBalance;

  // Device
  final String _deviceId = 'qwert';
  final String _deviceName = 'sm2233';

  // Session-wise entries: each {pana, amount, type("OPEN"/"CLOSE")}
  final Map<String, List<Map<String, String>>> _entriesBySession = {
    'OPEN': <Map<String, String>>[],
    'CLOSE': <Map<String, String>>[],
  };

  // Message bar
  String? _message;
  bool _isError = false;
  Key _messageKey = UniqueKey();
  Timer? _dismissTimer;

  bool _isApiCalling = false;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _loadInitialData();
    selectedGameBetType = widget.selectionStatus ? "Open" : "Close";
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
    bidController.dispose();
    pointsController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  // ---------- helpers ----------
  void _showMessage(String msg, {bool isError = false}) {
    _dismissTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _message = msg;
      _isError = isError;
      _messageKey = UniqueKey();
    });
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = null);
    });
  }

  void _clearMessage() {
    if (mounted) setState(() => _message = null);
  }

  List<Map<String, String>> _allEntries() => [
    ..._entriesBySession['OPEN']!,
    ..._entriesBySession['CLOSE']!,
  ];

  int _totalPointsAll() => _allEntries().fold(
    0,
    (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0),
  );

  bool _hasEntries(String sessionUpper) =>
      _entriesBySession[sessionUpper]!.isNotEmpty;

  // ---------- ADD: expand via dp-motor-pana ----------
  Future<void> _addEntry() async {
    _clearMessage();
    if (_isApiCalling) return;

    final raw = bidController.text.trim();
    final amtStr = pointsController.text.trim();

    if (raw.isEmpty) {
      _showMessage('Please enter a number.', isError: true);
      return;
    }
    if (raw.length < 3 || raw.length > 7 || int.tryParse(raw) == null) {
      _showMessage('Please enter a valid number (3-7 digits).', isError: true);
      return;
    }
    // at least 2 unique digits (DP rule)
    if (raw.split('').toSet().length < 2) {
      _showMessage(
        'Number must contain at least two unique digits.',
        isError: true,
      );
      return;
    }

    final amt = int.tryParse(amtStr);
    if (amt == null || amt < 10 || amt > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      _showMessage('Authentication error. Please log in again.', isError: true);
      return;
    }

    setState(() => _isApiCalling = true);
    try {
      // VERY IMPORTANT: send digit as STRING (keep leading zeroes)
      final resp = await http
          .post(
            Uri.parse('${Constant.apiEndpoint}dp-motor-pana'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
              'deviceId': _deviceId,
              'deviceName': _deviceName,
              'accessStatus': accountStatus ? '1' : '0',
            },
            body: jsonEncode({
              "digit": raw, // string, not int.parse(raw)
              "sessionType": selectedGameBetType.toLowerCase(),
              "amount": amt,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final map = jsonDecode(resp.body);
      log('[dp-motor-pana] ${resp.statusCode} $map', name: 'DPMotor');

      if (resp.statusCode == 200 && map['status'] == true) {
        final info = (map['info'] ?? []) as List<dynamic>;
        if (info.isEmpty) {
          _showMessage('No valid bids found for this number.', isError: true);
        } else {
          final session = selectedGameBetType.toUpperCase();
          setState(() {
            for (final item in info) {
              final pana = item['pana']?.toString() ?? '';
              final itemAmt =
                  int.tryParse(item['amount']?.toString() ?? '') ?? amt;
              if (pana.isEmpty) continue;

              final list = _entriesBySession[session]!;
              final idx = list.indexWhere((e) => e['pana'] == pana);
              if (idx != -1) {
                final cur = int.tryParse(list[idx]['amount'] ?? '0') ?? 0;
                list[idx]['amount'] = (cur + itemAmt).toString();
              } else {
                list.add({
                  "pana": pana,
                  "amount": itemAmt.toString(),
                  "type": session, // OPEN / CLOSE
                });
              }
            }
          });
          _showMessage('Bids added from API.');
        }
        setState(() {
          bidController.clear();
          pointsController.clear();
        });
      } else {
        _showMessage(
          map['msg']?.toString() ?? 'Request failed.',
          isError: true,
        );
      }
    } catch (e) {
      log('dp-motor-pana error: $e', name: 'DPMotor');
      _showMessage('Network error. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isApiCalling = false);
    }
  }

  void _removeEntry(String sessionUpper, int index) {
    if (_isApiCalling) return;
    final list = _entriesBySession[sessionUpper]!;
    final removed = list[index]['pana'];
    setState(() => list.removeAt(index));
    _showMessage('Removed: $removed ($sessionUpper)');
  }

  // ---------- Confirm & Submit (both sessions) ----------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    final all = _allEntries();
    if (all.isEmpty) {
      _showMessage('Please add at least one bid.', isError: true);
      return;
    }

    final total = _totalPointsAll();
    if (walletBalance < total) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    final whenStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.gameName,
        gameDate: whenStr,
        bids: all
            .map(
              (e) => {
                "digit": e['pana']!,
                "points": e['amount']!,
                "type": e['type']!,
                "pana": e['pana']!,
              },
            )
            .toList(growable: false),
        totalBids: all.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - total).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameCategoryType,
        onConfirm: () async {
          if (!mounted) return;
          setState(() => _isApiCalling = true);

          bool ok = true;
          if (_hasEntries('OPEN')) ok = await _placeFinalForSession('OPEN');
          if (ok && _hasEntries('CLOSE'))
            ok = await _placeFinalForSession('CLOSE');

          if (mounted) setState(() => _isApiCalling = false);
          if (ok) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const BidSuccessDialog(),
            );
          }
        },
      ),
    );
  }

  Future<bool> _placeFinalForSession(String sessionUpper) async {
    final list = _entriesBySession[sessionUpper]!;
    if (list.isEmpty) return true;

    final totalSession = list.fold<int>(
      0,
      (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0),
    );

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    // DP Motor ke liye bhi 'pana' bhejna hai, digit blank
    final List<Map<String, dynamic>> bidRows = list.map((e) {
      final amt = int.tryParse(e['amount'] ?? '0') ?? 0;
      final pana = e['pana'] ?? '';
      return {
        "sessionType": sessionUpper,
        "digit": "",
        "pana": pana,
        "bidAmount": amt,
      };
    }).toList();

    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId.toString(),
      "bidAmount": totalSession,
      "gameType": widget.gameCategoryType, // e.g. "dpMotor"
      "bid": bidRows,
    });

    log('[BidAPI] Headers: $headers', name: 'BidAPI');
    log('[BidAPI] Body   : $body', name: 'BidAPI');

    try {
      final resp = await http.post(
        Uri.parse('${Constant.apiEndpoint}place-bid'),
        headers: headers,
        body: body,
      );
      log('[BidAPI] HTTP ${resp.statusCode}', name: 'BidAPI');

      final map = jsonDecode(resp.body);
      log('[BidAPI] Resp: $map', name: 'BidAPI');

      if (resp.statusCode == 200 &&
          (map['status'] == true || map['status'] == 'true')) {
        final newBal = walletBalance - totalSession;
        await storage.write('walletBalance', newBal);
        setState(() {
          walletBalance = newBal;
          _entriesBySession[sessionUpper]!.clear();
        });
        return true;
      } else {
        final msg =
            map['msg']?.toString() ??
            'Place bid failed. Please try again later.';
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(errorMessage: msg),
        );
        return false;
      }
    } catch (e) {
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

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final options = <String>[if (widget.selectionStatus) "Open", "Close"];
    if (!options.contains(selectedGameBetType)) {
      selectedGameBetType = options.first;
    }

    final all = _allEntries();
    final canSubmitAny = all.isNotEmpty && !_isApiCalling;

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey.shade300,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 15,
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
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
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
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      _row("Select Game Type:", _buildDropdown(options)),
                      const SizedBox(height: 12),
                      _row("Enter Number:", _buildBidInputField()),
                      const SizedBox(height: 12),
                      _row(
                        "Enter Points:",
                        _amountField(pointsController, "Enter Amount"),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: _isApiCalling ? null : _addEntry,
                          child: _isApiCalling
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                              : const Text(
                                  "ADD BID",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
                const Divider(thickness: 1),

                if (all.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: const [
                        Expanded(
                          child: Text(
                            "Digit",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "Amount",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "Game Type",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 48),
                      ],
                    ),
                  ),
                if (all.isNotEmpty) const Divider(thickness: 1),

                Expanded(
                  child: all.isEmpty
                      ? const Center(child: Text("No data added yet"))
                      : ListView.builder(
                          itemCount: all.length,
                          itemBuilder: (_, i) {
                            final e = all[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e['pana']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      e['amount']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      e['type']!,
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
                                        : () {
                                            final sess = e['type']!
                                                .toUpperCase();
                                            final idx = _entriesBySession[sess]!
                                                .indexOf(e);
                                            if (idx != -1)
                                              _removeEntry(sess, idx);
                                          },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                if (all.isNotEmpty)
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
                              'Bids',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '${all.length}',
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
                              '${_totalPointsAll()}',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: canSubmitAny
                              ? _showConfirmationDialog
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canSubmitAny
                                ? Colors.red
                                : Colors.grey,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 3,
                          ),
                          child: _isApiCalling
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
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
                  ),
              ],
            ),

            if (_message != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedMessageBar(
                  key: _messageKey,
                  message: _message!,
                  isError: _isError,
                  onDismissed: _clearMessage,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- small widgets ----------
  Widget _row(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(flex: 3, child: field),
        ],
      ),
    );
  }

  Widget _buildDropdown(List<String> options) {
    return SizedBox(
      width: 150,
      height: 35,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black54),
          borderRadius: BorderRadius.circular(30),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: options.contains(selectedGameBetType)
                ? selectedGameBetType
                : options.first,
            icon: const Icon(Icons.keyboard_arrow_down),
            onChanged: _isApiCalling
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() {
                      selectedGameBetType = v;
                      _clearMessage();
                    });
                  },
            items: options
                .map(
                  (v) => DropdownMenuItem<String>(
                    value: v,
                    child: Text(v, style: GoogleFonts.poppins(fontSize: 14)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBidInputField() {
    return SizedBox(
      height: 35,
      child: TextFormField(
        controller: bidController,
        cursorColor: Colors.red,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: [
          LengthLimitingTextInputFormatter(7),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: _clearMessage,
        enabled: !_isApiCalling,
        decoration: InputDecoration(
          hintText: "Enter a number",
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _amountField(TextEditingController c, String hint) {
    return SizedBox(
      width: 150,
      height: 35,
      child: TextFormField(
        controller: c,
        cursorColor: Colors.red,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        onTap: _clearMessage,
        enabled: !_isApiCalling,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }
}
