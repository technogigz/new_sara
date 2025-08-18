// lib/screens/choice_sp_dp_tp_board_screen.dart
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
import 'package:marquee/marquee.dart';

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../ulits/Constents.dart';

class ChoiceSpDpTpBoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;
  final String
  gameType; // e.g. "choicePannaSPDP" (adjust if backend expects something else)
  final String gameName;
  final bool selectionStatus; // if true => OPEN+ CLOSE, else only CLOSE

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
  // inputs
  final TextEditingController _leftDigitController = TextEditingController();
  final TextEditingController _middleDigitController = TextEditingController();
  final TextEditingController _rightDigitController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  // category toggles (mutually exclusive)
  bool _isSP = false;
  bool _isDP = false;
  bool _isTP = false;

  // session dropdown
  String? _session; // "OPEN" | "CLOSE"

  /// bid item shape: { digit: '123', amount:'10', gameType:'SP|DP|TP', session:'OPEN|CLOSE' }
  final List<Map<String, String>> _bids = [];

  // auth / state
  final GetStorage _storage = GetStorage();
  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  late String accessToken;
  late String registerId;
  late bool accountStatus;
  late int walletBalance;

  // device
  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  // ui state
  bool _isApiCalling = false;
  String? _msg;
  bool _msgErr = false;
  Key _msgKey = UniqueKey();
  Timer? _msgTimer;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    accessToken = _storage.read('accessToken') ?? '';
    registerId = _storage.read('registerId') ?? '';
    accountStatus = _storage.read('accountStatus') ?? false;

    final num? bal = num.tryParse(userController.walletBalance.value);
    walletBalance = bal?.toInt() ?? 0;

    _session = widget.selectionStatus ? 'OPEN' : 'CLOSE';
    setState(() {});
  }

  @override
  void dispose() {
    _leftDigitController.dispose();
    _middleDigitController.dispose();
    _rightDigitController.dispose();
    _pointsController.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  // -------- helpers --------
  void _showMsg(String m, {bool err = false}) {
    _msgTimer?.cancel();
    setState(() {
      _msg = m;
      _msgErr = err;
      _msgKey = UniqueKey();
    });
    _msgTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _msg = null);
    });
  }

  void _clearMsg() {
    if (!mounted) return;
    setState(() => _msg = null);
  }

  String? _selectedCategory() {
    if (_isSP) return 'SP';
    if (_isDP) return 'DP';
    if (_isTP) return 'TP';
    return null;
  }

  bool _isValidSP(String p) => p.length == 3 && p.split('').toSet().length == 3;

  bool _isValidDP(String p) {
    if (p.length != 3) return false;
    final d = p.split('')..sort();
    return (d[0] == d[1] && d[1] != d[2]) || (d[0] != d[1] && d[1] == d[2]);
  }

  bool _isValidTP(String p) => p.length == 3 && p[0] == p[1] && p[1] == p[2];

  int _totalPoints() =>
      _bids.fold(0, (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0));

  // -------- add bid --------
  void _onAdd() {
    _clearMsg();
    if (_isApiCalling) return;

    final left = _leftDigitController.text.trim();
    final middle = _middleDigitController.text.trim();
    final right = _rightDigitController.text.trim();
    final ptsTxt = _pointsController.text.trim();

    if (left.isEmpty || middle.isEmpty || right.isEmpty) {
      _showMsg('Please enter all three digits.', err: true);
      return;
    }
    if ([
      left,
      middle,
      right,
    ].any((d) => d.length != 1 || int.tryParse(d) == null)) {
      _showMsg('Each digit must be a single number (0-9).', err: true);
      return;
    }

    final panna = '$left$middle$right';

    final cat = _selectedCategory();
    if (cat == null) {
      _showMsg('Please select SP, DP or TP.', err: true);
      return;
    }
    if (_session == null) {
      _showMsg('Please select OPEN/CLOSE.', err: true);
      return;
    }

    // validate panna against category
    final ok =
        (cat == 'SP' && _isValidSP(panna)) ||
        (cat == 'DP' && _isValidDP(panna)) ||
        (cat == 'TP' && _isValidTP(panna));
    if (!ok) {
      _showMsg(
        cat == 'SP'
            ? 'SP must have 3 unique digits.'
            : cat == 'DP'
            ? 'DP must have exactly two same digits.'
            : 'TP must have all 3 digits same.',
        err: true,
      );
      return;
    }

    final pts = int.tryParse(ptsTxt);
    if (pts == null || pts < 10 || pts > 10000) {
      _showMsg('Points must be between 10 and 10000.', err: true);
      return;
    }

    // merge by (panna + category + session)
    final i = _bids.indexWhere(
      (e) =>
          e['digit'] == panna &&
          e['gameType'] == cat &&
          e['session'] == _session,
    );
    setState(() {
      if (i != -1) {
        final curr = int.tryParse(_bids[i]['amount'] ?? '0') ?? 0;
        _bids[i]['amount'] = (curr + pts).toString();
        _showMsg('Updated: $panna ($cat ${_session!})');
      } else {
        _bids.add({
          'digit': panna,
          'amount': pts.toString(),
          'gameType': cat, // SP | DP | TP
          'session': _session!, // OPEN | CLOSE
        });
        _showMsg('Added: $panna ($cat ${_session!})');
      }
      // keep category/session as-is; just clear fields
      _leftDigitController.clear();
      _middleDigitController.clear();
      _rightDigitController.clear();
      _pointsController.clear();
    });
  }

  void _remove(int index) {
    if (_isApiCalling) return;
    final r = _bids[index];
    setState(() => _bids.removeAt(index));
    _showMsg('Removed: ${r['digit']} (${r['gameType']} ${r['session']})');
  }

  // -------- confirm & submit --------
  void _confirm() {
    _clearMsg();
    if (_isApiCalling) return;

    if (_bids.isEmpty) {
      _showMsg('Please add bids before submitting.', err: true);
      return;
    }

    final total = _totalPoints();
    if (walletBalance < total) {
      _showMsg('Insufficient wallet balance.', err: true);
      return;
    }

    final rows = _bids
        .map(
          (b) => {
            'digit': b['digit']!,
            'points': b['amount']!,
            'type': '${b['gameType']} (${b['session']})',
            'pana': b['digit']!,
            'jodi': '',
          },
        )
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.screenTitle,
        gameDate: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
        bids: rows,
        totalBids: rows.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - total).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () async {
          setState(() => _isApiCalling = true);
          final ok = await _submit();
          if (!mounted) return;
          setState(() => _isApiCalling = false);
          if (ok) setState(() => _bids.clear());
        },
      ),
    );
  }

  Future<bool> _submit() async {
    if (accessToken.isEmpty || registerId.isEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Authentication error. Please log in again.',
        ),
      );
      return false;
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    // IMPORTANT: send pana filled (equal to digit)
    final bidRows = _bids
        .map(
          (b) => {
            "sessionType": b['session'], // OPEN/CLOSE
            "digit": b['digit'], // 3-digit
            "pana": b['digit'], // must not be empty
            "bidAmount": int.tryParse(b['amount'] ?? '0') ?? 0,
          },
        )
        .toList();

    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId.toString(),
      "bidAmount": _totalPoints(),
      "gameType": widget.gameType, // keep whatever your backend expects
      "bid": bidRows,
    });

    final url = '${Constant.apiEndpoint}place-bid';
    log('[BidAPI] Headers: $headers');
    log('[BidAPI] Body   : $body');

    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      log('[BidAPI] HTTP ${resp.statusCode}');
      final map = jsonDecode(resp.body);
      log('[BidAPI] Resp: $map');

      if (resp.statusCode == 200 &&
          (map['status'] == true || map['status'] == 'true')) {
        final newBal = walletBalance - _totalPoints();
        await _storage.write('walletBalance', newBal);
        if (!mounted) return true;
        setState(() => walletBalance = newBal);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );
        _clearMsg();
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

  // -------- UI helpers --------
  Widget _digitBox(String hint, TextEditingController c) {
    return TextField(
      controller: c,
      cursorColor: Colors.red,
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
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      onTap: _clearMsg,
      enabled: !_isApiCalling,
    );
  }

  @override
  Widget build(BuildContext context) {
    final marketName = widget.screenTitle.contains(' - ')
        ? widget.screenTitle.split(' - ').first
        : widget.screenTitle;

    // Session dropdown items
    final items = <DropdownMenuItem<String>>[];
    if (widget.selectionStatus) {
      items.add(
        DropdownMenuItem(
          value: 'OPEN',
          child: SizedBox(
            width: 150,
            height: 20,
            child: Marquee(
              text: '$marketName OPEN',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              scrollAxis: Axis.horizontal,
              blankSpace: 40,
              velocity: 30,
              pauseAfterRound: const Duration(seconds: 2),
              showFadingOnlyWhenScrolling: true,
              fadingEdgeStartFraction: 0.1,
              fadingEdgeEndFraction: 0.1,
            ),
          ),
        ),
      );
    }
    items.add(
      DropdownMenuItem(
        value: 'CLOSE',
        child: SizedBox(
          width: 150,
          height: 20,
          child: Marquee(
            text: '$marketName CLOSE',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            scrollAxis: Axis.horizontal,
            blankSpace: 40,
            velocity: 30,
            pauseAfterRound: const Duration(seconds: 2),
            showFadingOnlyWhenScrolling: true,
            fadingEdgeStartFraction: 0.1,
            fadingEdgeEndFraction: 0.1,
          ),
        ),
      ),
    );

    // footer pre-calc (to avoid closure text)
    final int totalBids = _bids.length;
    final int totalPoints = _totalPoints();
    final bool canSubmit = !_isApiCalling && _bids.isNotEmpty;

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
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // session row
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
                                  value: _session,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.red,
                                  ),
                                  onChanged: _isApiCalling
                                      ? null
                                      : (v) {
                                          setState(() {
                                            _session = v;
                                            _clearMsg();
                                          });
                                        },
                                  items: items,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // category toggles
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _isSP,
                                  onChanged: _isApiCalling
                                      ? null
                                      : (v) {
                                          setState(() {
                                            _isSP = v ?? false;
                                            if (_isSP) {
                                              _isDP = false;
                                              _isTP = false;
                                            }
                                          });
                                        },
                                  activeColor: Colors.red,
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
                              children: [
                                Checkbox(
                                  value: _isDP,
                                  onChanged: _isApiCalling
                                      ? null
                                      : (v) {
                                          setState(() {
                                            _isDP = v ?? false;
                                            if (_isDP) {
                                              _isSP = false;
                                              _isTP = false;
                                            }
                                          });
                                        },
                                  activeColor: Colors.red,
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
                              children: [
                                Checkbox(
                                  value: _isTP,
                                  onChanged: _isApiCalling
                                      ? null
                                      : (v) {
                                          setState(() {
                                            _isTP = v ?? false;
                                            if (_isTP) {
                                              _isSP = false;
                                              _isDP = false;
                                            }
                                          });
                                        },
                                  activeColor: Colors.red,
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

                      // digit boxes
                      Row(
                        children: [
                          Expanded(
                            child: _digitBox('Digit 1', _leftDigitController),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _digitBox('Digit 2', _middleDigitController),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _digitBox('Digit 3', _rightDigitController),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // points
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Enter Points:',
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                          SizedBox(
                            width: 150,
                            height: 40,
                            child: TextField(
                              controller: _pointsController,
                              cursorColor: Colors.red,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(5),
                              ],
                              onTap: _clearMsg,
                              enabled: !_isApiCalling,
                              decoration: InputDecoration(
                                hintText: 'Amount',
                                hintStyle: GoogleFonts.poppins(fontSize: 14),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
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
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                ),
                              ),
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
                            onPressed: _isApiCalling ? null : _onAdd,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
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
                                    'ADD',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(thickness: 1, height: 1),

                if (_bids.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: const [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Panna',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Amount',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Type',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 48),
                      ],
                    ),
                  ),
                if (_bids.isNotEmpty)
                  const Divider(
                    thickness: .5,
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
                          padding: const EdgeInsets.only(top: 0, bottom: 8),
                          itemCount: _bids.length,
                          itemBuilder: (_, i) {
                            final b = _bids[i];
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(.15),
                                    blurRadius: 2,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      b['digit']!,
                                      style: GoogleFonts.poppins(fontSize: 15),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      b['amount']!,
                                      style: GoogleFonts.poppins(fontSize: 15),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '${b['gameType']} (${b['session']})',
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
                                        : () => _remove(i),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Footer (fixed)
                if (_bids.isNotEmpty)
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
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bids',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$totalBids',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Points',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$totalPoints',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: canSubmit ? _confirm : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canSubmit
                                  ? Colors.red
                                  : Colors.grey,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 3,
                            ),
                            child: _isApiCalling
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
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
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            if (_msg != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedMessageBar(
                  key: _msgKey,
                  message: _msg!,
                  isError: _msgErr,
                  onDismissed: _clearMsg,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
