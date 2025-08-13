// lib/screens/half_sangam_b_board_screen.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../BidService.dart';
import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';

class HalfSangamBBoardScreen extends StatefulWidget {
  final String screenTitle; // e.g., "SRIDEVI NIGHT, HALF SANGAM"
  final String gameType; // "halfSangamB"
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

  final List<Map<String, String>> _bids = []; // {ank, panna, points}
  final GetStorage _storage = GetStorage();
  late final BidService _bidService;

  String _accessToken = '';
  String _registerId = '';
  String _preferredLanguage = 'en';
  bool _accountStatus = false;
  int _walletBalance = 0; // keep as int for math

  bool _isApiCalling = false;

  static const String _deviceId = 'test_device_id_flutter';
  static const String _deviceName = 'test_device_name_flutter';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  // Short pana list (agar full chahiye to HalfSangamA wali list use kar sakte ho)
  static const List<String> _allPannas = [
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

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  @override
  void initState() {
    super.initState();
    log('HalfSangamB: initState');
    _bidService = BidService(_storage);
    _loadInitialData();
    _setupStorageListeners();
  }

  @override
  void dispose() {
    log('HalfSangamB: dispose');
    _ankController.dispose();
    _pannaController.dispose();
    _pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _accessToken = _storage.read('accessToken') ?? '';
    _registerId = _storage.read('registerId') ?? '';
    _accountStatus = userController.accountStatus.value;
    _preferredLanguage = _storage.read('selectedLanguage') ?? 'en';

    final num? bal = num.tryParse(userController.walletBalance.value);
    _walletBalance = bal?.toInt() ?? 0;
    if (mounted) setState(() {});
  }

  void _setupStorageListeners() {
    _storage.listenKey('accessToken', (v) {
      if (mounted) setState(() => _accessToken = (v ?? '').toString());
    });
    _storage.listenKey('registerId', (v) {
      if (mounted) setState(() => _registerId = (v ?? '').toString());
    });
    _storage.listenKey('accountStatus', (v) {
      if (mounted) setState(() => _accountStatus = v == true);
    });
    _storage.listenKey('walletBalance', (v) {
      if (!mounted) return;
      int parsed;
      if (v is int)
        parsed = v;
      else if (v is num)
        parsed = v.toInt();
      else
        parsed = int.tryParse(v?.toString() ?? '0') ?? 0;
      setState(() => _walletBalance = parsed);
    });
    _storage.listenKey('selectedLanguage', (v) {
      if (mounted) setState(() => _preferredLanguage = (v ?? 'en').toString());
    });
  }

  // ---------------- message bar ----------------
  void _showMessage(String message, {bool isError = false}) {
    _messageDismissTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    _messageDismissTimer = Timer(const Duration(seconds: 3), _clearMessage);
  }

  void _clearMessage() {
    if (!mounted) return;
    setState(() => _messageToShow = null);
  }

  // ---------------- helpers ----------------
  int _getTotalPoints() =>
      _bids.fold(0, (s, e) => s + (int.tryParse(e['points'] ?? '0') ?? 0));

  // ---------------- add / remove ----------------
  void _addBid() {
    log('HalfSangamB: _addBid');
    _clearMessage();
    if (_isApiCalling) return;

    final ank = _ankController.text.trim();
    final panna = _pannaController.text.trim();
    final points = _pointsController.text.trim();

    if (ank.length != 1 || int.tryParse(ank) == null) {
      _showMessage('Ank 1 digit ka do (0–9).', isError: true);
      return;
    }
    final ankVal = int.parse(ank);
    if (ankVal < 0 || ankVal > 9) {
      _showMessage('Ank 0 se 9 ke beech do.', isError: true);
      return;
    }

    if (panna.length != 3 || !_allPannas.contains(panna)) {
      _showMessage('Valid 3-digit Panna do (e.g. 119).', isError: true);
      return;
    }

    final int? pts = int.tryParse(points);
    final int minBid =
        int.tryParse(_storage.read('minBid')?.toString() ?? '10') ?? 10;
    if (pts == null || pts < minBid || pts > 1000) {
      _showMessage('Points $minBid se 1000 ke beech do.', isError: true);
      return;
    }

    // Optional guard: tentative total vs wallet
    final nextTotal = _getTotalPoints() + pts;
    if (_walletBalance > 0 && nextTotal > _walletBalance) {
      _showMessage(
        'Itna add karne se total wallet se zyada ho jayega.',
        isError: true,
      );
      return;
    }

    setState(() {
      final idx = _bids.indexWhere(
        (b) => b['ank'] == ank && b['panna'] == panna,
      );
      if (idx != -1) {
        final cur = int.tryParse(_bids[idx]['points'] ?? '0') ?? 0;
        _bids[idx]['points'] = (cur + pts).toString();
        _showMessage('Updated: $ank-$panna.');
      } else {
        _bids.add({"ank": ank, "panna": panna, "points": pts.toString()});
        _showMessage('Added: $ank-$panna — $pts pts.');
      }
      _ankController.clear();
      _pannaController.clear();
      _pointsController.clear();
    });
  }

  void _removeBid(int index) {
    _clearMessage();
    if (_isApiCalling) return;
    if (index < 0 || index >= _bids.length) return;

    setState(() {
      final removed = '${_bids[index]['ank']}-${_bids[index]['panna']}';
      _bids.removeAt(index);
      _showMessage('Removed $removed.');
    });
  }

  // ---------------- confirm & submit ----------------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    if (_bids.isEmpty) {
      _showMessage('Pehle kam se kam 1 bid add karo.', isError: true);
      return;
    }

    // refresh wallet from controller
    final num? wb = num.tryParse(userController.walletBalance.value);
    _walletBalance = wb?.toInt() ?? _walletBalance;

    final totalPoints = _getTotalPoints();
    if (_walletBalance < totalPoints) {
      _showMessage('Wallet balance kam hai.', isError: true);
      return;
    }

    // Dialog mapping: Digits = Panna, Game Type = Half Sangam B, Points = amount
    final dialogBids = _bids
        .map(
          (b) => {
            "digit": b['panna']!, // show pana in digits col
            "pana": "",
            "points": b['points']!,
            "type": "Half Sangam B", // show readable type
            "sangam": "${b['ank']}-${b['panna']}",
            "jodi": "",
          },
        )
        .toList();

    final when = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.gameName,
        gameDate: when,
        bids: dialogBids,
        totalBids: dialogBids.length,
        totalBidsAmount: totalPoints,
        walletBalanceBeforeDeduction: _walletBalance,
        walletBalanceAfterDeduction: (_walletBalance - totalPoints).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () async {
          final res = await _placeFinalBids();
          if (!mounted) return;

          if (res['status'] == true) {
            setState(() => _bids.clear());

            final int newBal =
                (res['data']?['wallet_balance'] as num?)?.toInt() ??
                (_walletBalance - totalPoints);

            await _bidService.updateWalletBalance(newBal);
            setState(() => _walletBalance = newBal);

            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const BidSuccessDialog(),
            );
          } else {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => BidFailureDialog(
                errorMessage:
                    res['msg'] ?? 'Bid submission failed. Please try again.',
              ),
            );
          }
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _placeFinalBids() async {
    if (!mounted) return {'status': false, 'msg': 'Screen not mounted.'};
    setState(() => _isApiCalling = true);

    try {
      if (_accessToken.isEmpty || _registerId.isEmpty) {
        return {'status': false, 'msg': 'Auth issue — login dobara karo.'};
      }

      // Key format expected by BidService: "ank-panna"
      final Map<String, String> bidAmounts = {};
      for (final b in _bids) {
        bidAmounts['${b['ank']}-${b['panna']}'] = b['points']!;
      }
      if (bidAmounts.isEmpty) {
        return {'status': false, 'msg': 'No valid bids to submit.'};
      }

      final total = _getTotalPoints();

      // 🔴 Half Sangam B => sessionType = CLOSE (A me OPEN, B me CLOSE)
      const selectedSessionType = "CLOSE";

      final result = await _bidService.placeFinalBids(
        gameName: widget.gameName,
        accessToken: _accessToken,
        registerId: _registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: _accountStatus,
        bidAmounts: bidAmounts,
        selectedGameType: selectedSessionType,
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: total,
      );

      // local fallback update (agar service ne na kiya ho)
      if (result['status'] == true) {
        final int newBal =
            (result['data']?['wallet_balance'] as num?)?.toInt() ??
            (_walletBalance - total);
        await _bidService.updateWalletBalance(newBal);
        if (mounted) setState(() => _walletBalance = newBal);
      }

      return result;
    } catch (e) {
      return {'status': false, 'msg': 'Unexpected error: $e'};
    } finally {
      if (mounted) setState(() => _isApiCalling = false);
    }
  }

  // ---------------- UI ----------------
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
          Obx(() {
            // show live wallet from controller for header UI
            return Text(
              '₹${userController.walletBalance.value}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            );
          }),
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
                      _inputRow(
                        'Ank',
                        _ankController,
                        hintText: 'e.g., 9',
                        maxLength: 1,
                      ),
                      const SizedBox(height: 16),
                      _pannaRow(
                        'Pana',
                        _pannaController,
                        hintText: 'e.g., 119',
                        maxLength: 3,
                      ),
                      const SizedBox(height: 16),
                      _inputRow(
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
                            backgroundColor: _isApiCalling
                                ? Colors.grey
                                : Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: _isApiCalling
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
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Panna - Ank',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Points',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Type',
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
                          itemBuilder: (_, i) {
                            final b = _bids[i];
                            final label = '${b['panna']!} - ${b['ank']!}';
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
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 3, child: Text(label)),
                                    Expanded(
                                      flex: 2,
                                      child: Text(b['points']!),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text('Half Sangam B'),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: _isApiCalling
                                          ? null
                                          : () => _removeBid(i),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                _bottomBar(),
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

  // ---------------- widgets ----------------
  Widget _inputRow(
    String label,
    TextEditingController c, {
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
            controller: c,
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
                borderSide: BorderSide(color: Colors.orange, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pannaRow(
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
            fieldViewBuilder: (context, tec, focusNode, onFieldSubmitted) {
              // memory-safe sync (no listener leaks)
              if (tec.text != controller.text) {
                tec.text = controller.text;
                tec.selection = TextSelection.collapsed(
                  offset: tec.text.length,
                );
              }
              return TextField(
                controller: tec,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  if (maxLength != null)
                    LengthLimitingTextInputFormatter(maxLength),
                ],
                onChanged: (v) => controller.text = v,
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
                    borderSide: BorderSide(color: Colors.orange, width: 2),
                  ),
                  suffixIcon: const Icon(
                    Icons.arrow_forward,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                onSubmitted: (_) => onFieldSubmitted(),
              );
            },
            optionsBuilder: (TextEditingValue v) {
              final q = v.text;
              if (q.isEmpty) return const Iterable<String>.empty();
              return _allPannas.where((s) => s.startsWith(q));
            },
            onSelected: (s) => controller.text = s,
            optionsViewBuilder: (context, onSelected, options) {
              final opts = options.toList(growable: false);
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: SizedBox(
                    height: opts.length > 5 ? 200 : opts.length * 48,
                    width: 150,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: opts.length,
                      itemBuilder: (_, i) {
                        final option = opts[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            option,
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                          onTap: () => onSelected(option),
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

  Widget _bottomBar() {
    final totalBids = _bids.length;
    final totalPoints = _getTotalPoints();

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
          _summary('Bid', '$totalBids'),
          _summary('Total', '$totalPoints'),
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
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
        ],
      ),
    );
  }

  Widget _summary(String t, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t,
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
      ),
      Text(
        v,
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ],
  );
}
