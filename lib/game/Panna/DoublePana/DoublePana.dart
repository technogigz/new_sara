import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:new_sara/BidService.dart';

import '../../../Helper/UserController.dart';
import '../../../components/AnimatedMessageBar.dart';
import '../../../components/BidConfirmationDialog.dart';
import '../../../components/BidFailureDialog.dart';
import '../../../components/BidSuccessDialog.dart';

class DoublePanaBetScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType; // "doublePana"
  final int gameId;
  final String gameName;
  final bool selectionStatus;

  const DoublePanaBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
    required this.selectionStatus,
  });

  @override
  State<DoublePanaBetScreen> createState() => _DoublePanaBetScreenState();
}

class _DoublePanaBetScreenState extends State<DoublePanaBetScreen> {
  // ---------- session + options ----------
  List<String> gameTypesOptions = [];
  String selectedGameBetType = "Open"; // UI selector only (Open | Close)
  String get _sessionUpper => selectedGameBetType.toUpperCase();

  // ---------- inputs ----------
  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  // valid double-pana list
  final List<String> doublePanaOptions = const [
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

  // suggestions
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  /// keep entries separate by session to avoid cross-contamination
  /// each item: {digit, amount, type:"OPEN"/"CLOSE", gameType:"doublePana"}
  final Map<String, List<Map<String, String>>> _entriesBySession = {
    'OPEN': <Map<String, String>>[],
    'CLOSE': <Map<String, String>>[],
  };

  // ---------- services / auth ----------
  late final GetStorage storage;
  late final BidService _bidService;
  late String accessToken;
  late String registerId;
  bool accountStatus = false;

  // wallet
  late int walletBalance;

  // device
  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  // msg bar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  bool _isApiCalling = false;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _bidService = BidService(storage);
    _loadInitialData();

    final num? bal = num.tryParse(userController.walletBalance.value);
    walletBalance = bal?.toInt() ?? 0;

    _setupGameTypeOptions();
    digitController.addListener(_onDigitChanged);
  }

  void _setupGameTypeOptions() {
    setState(() {
      gameTypesOptions = widget.selectionStatus ? ["Open", "Close"] : ["Close"];
      if (!gameTypesOptions.contains(selectedGameBetType)) {
        selectedGameBetType = gameTypesOptions.first;
      }
    });
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;

    final dynamic stored = storage.read('walletBalance');
    if (stored is int) {
      walletBalance = stored;
    } else if (stored is String) {
      walletBalance = int.tryParse(stored) ?? walletBalance;
    }
  }

  @override
  void didUpdateWidget(covariant DoublePanaBetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectionStatus != oldWidget.selectionStatus) {
      _setupGameTypeOptions();
    }
  }

  @override
  void dispose() {
    digitController.removeListener(_onDigitChanged);
    digitController.dispose();
    pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  // ---------- helpers ----------
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

  void _onDigitChanged() {
    final q = digitController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    setState(() {
      _suggestions = doublePanaOptions.where((d) => d.startsWith(q)).toList();
      _showSuggestions = _suggestions.isNotEmpty;
    });
  }

  List<Map<String, String>> _allEntries() => [
    ..._entriesBySession['OPEN']!,
    ..._entriesBySession['CLOSE']!,
  ];

  int _totalPointsAll() => _allEntries().fold(
    0,
    (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0),
  );

  int _totalPointsForSession(String sessionUpper) =>
      _entriesBySession[sessionUpper]!.fold(
        0,
        (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0),
      );

  bool _hasEntries(String sessionUpper) =>
      _entriesBySession[sessionUpper]!.isNotEmpty;

  // ---------- add/remove ----------
  void _addEntry() {
    if (_isApiCalling) return;

    final digit = digitController.text.trim();
    final pointsStr = pointsController.text.trim();

    if (digit.length != 3 ||
        int.tryParse(digit) == null ||
        !doublePanaOptions.contains(digit)) {
      _showMessage(
        'Enter a valid Double Pana (3-digit) number.',
        isError: true,
      );
      return;
    }

    final pts = int.tryParse(pointsStr);
    if (pts == null || pts < 10 || pts > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    final list = _entriesBySession[_sessionUpper]!;
    final idx = list.indexWhere((e) => e['digit'] == digit);

    setState(() {
      if (idx != -1) {
        final curr = int.tryParse(list[idx]['amount'] ?? '0') ?? 0;
        list[idx]['amount'] = (curr + pts).toString();
        _showMessage('Updated: $digit ($_sessionUpper)');
      } else {
        list.add({
          "digit": digit, // PANNA
          "amount": pointsStr,
          "type": _sessionUpper, // "OPEN"/"CLOSE"
          "gameType": widget.gameCategoryType, // "doublePana"
        });
        _showMessage('Added: $digit ($_sessionUpper)');
      }
      digitController.clear();
      pointsController.clear();
      _showSuggestions = false;
    });
  }

  void _removeEntry(String sessionUpper, int index) {
    if (_isApiCalling) return;
    final list = _entriesBySession[sessionUpper]!;
    final removed = list[index]['digit'];
    setState(() {
      list.removeAt(index);
    });
    _showMessage('Removed: $removed ($sessionUpper)');
  }

  // ---------- submit (per-session) ----------
  Future<bool> _submitSession(String sessionUpper) async {
    final list = _entriesBySession[sessionUpper]!;
    if (list.isEmpty) return true; // nothing to do for this session

    // Build payload & sum
    final payload = <String, String>{};
    int sum = 0;
    for (final e in list) {
      final key = e['digit'] ?? '';
      final amt = int.tryParse(e['amount'] ?? '0') ?? 0;
      if (key.isEmpty || amt <= 0) continue;
      payload.update(
        key,
        (old) => (int.parse(old) + amt).toString(),
        ifAbsent: () => amt.toString(),
      );
      sum += amt;
    }

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

    try {
      final result = await _bidService.placeFinalBids(
        gameName: widget.gameName,
        accessToken: accessToken,
        registerId: registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: accountStatus,
        bidAmounts: payload, // PANNA -> points
        selectedGameType: sessionUpper, // OPEN / CLOSE
        gameId: widget.gameId,
        gameType: widget.gameCategoryType, // "doublePana"
        totalBidAmount: sum,
      );

      if (result['status'] == true) {
        // Deduct and persist
        final newBal = walletBalance - sum;
        setState(() => walletBalance = newBal);
        _bidService.updateWalletBalance(newBal);

        // Clear only this session after success
        setState(() {
          _entriesBySession[sessionUpper]!.clear();
        });
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

  // ---------- unified confirmation ----------
  void _showConfirmationDialog() {
    final all = _allEntries();
    final totalPoints = _totalPointsAll();

    if (all.isEmpty) {
      _showMessage('No bids added.', isError: true);
      return;
    }
    if (walletBalance < totalPoints) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    // Build FRESH rows for dialog including BOTH sessions
    final rows = all
        .map(
          (e) => {
            "digit": e['digit']!, // show PANNA in Digits column
            "points": e['amount']!,
            "type": e['type']!, // OPEN / CLOSE
            "pana": e['digit']!, // compatibility
          },
        )
        .toList(growable: false);

    final whenStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: "${widget.gameName}, Double Pana",
        gameDate: whenStr,
        bids: rows,
        totalBids: rows.length,
        totalBidsAmount: totalPoints,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameCategoryType,
        onConfirm: () async {
          if (!mounted) return;
          setState(() => _isApiCalling = true);

          // Submit both sessions sequentially (OPEN then CLOSE)
          bool ok = true;
          if (_hasEntries('OPEN')) {
            ok = await _submitSession('OPEN');
          }
          if (ok && _hasEntries('CLOSE')) {
            ok = await _submitSession('CLOSE');
          }

          if (mounted) setState(() => _isApiCalling = false);

          if (ok) {
            // success dialog once for the combined operation
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

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    // SUBMIT enabled if there is ANY bid now (previously was just current session)
    final canSubmitAny = _totalPointsAll() > 0 && !_isApiCalling;
    final all = _allEntries(); // for table view

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
                      _inputRow("Select Game Type:", _buildDropdown()),
                      const SizedBox(height: 12),
                      _inputRow("Enter 3-Digit Number:", _digitField()),
                      if (_showSuggestions && _suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            itemBuilder: (_, i) {
                              final s = _suggestions[i];
                              return ListTile(
                                title: Text(s),
                                onTap: () {
                                  setState(() {
                                    digitController.text = s;
                                    _showSuggestions = false;
                                    digitController.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(offset: s.length),
                                        );
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      _inputRow(
                        "Enter Points:",
                        _numberField(pointsController, "Enter Amount", [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
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
                      ? Center(
                          child: Text(
                            "No bids added yet",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: all.length,
                          itemBuilder: (_, index) {
                            final e = all[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e['digit']!,
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
                                        : () => _removeEntry(
                                            e['type']!.toUpperCase(),
                                            _entriesBySession[e['type']!
                                                    .toUpperCase()]!
                                                .indexOf(e),
                                          ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                if (all.isNotEmpty) _bottomBar(canSubmitAny),
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
                  onDismissed: () => setState(() => _messageToShow = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- small UI helpers ----------
  Widget _inputRow(String label, Widget field) {
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

  Widget _buildDropdown() {
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
            value: gameTypesOptions.contains(selectedGameBetType)
                ? selectedGameBetType
                : gameTypesOptions.first,
            icon: const Icon(Icons.keyboard_arrow_down),
            onChanged: _isApiCalling
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() => selectedGameBetType = v);
                  },
            items: gameTypesOptions
                .map(
                  (v) => DropdownMenuItem(
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

  Widget _digitField() {
    return SizedBox(
      height: 35,
      child: TextFormField(
        controller: digitController,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: [
          LengthLimitingTextInputFormatter(3),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: () {
          if (digitController.text.isNotEmpty) _onDigitChanged();
        },
        onChanged: (_) => _onDigitChanged(),
        enabled: !_isApiCalling,
        decoration: InputDecoration(
          hintText: "Enter 3-Digit Number",
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
            borderSide: const BorderSide(color: Colors.orange, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController c,
    String hint,
    List<TextInputFormatter> fmts,
  ) {
    return SizedBox(
      width: 150,
      height: 35,
      child: TextFormField(
        controller: c,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: fmts,
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
            borderSide: const BorderSide(color: Colors.orange, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(bool canSubmitAny) {
    final totalBids = _allEntries().length;
    final totalPoints = _totalPointsAll();

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
            onPressed: canSubmitAny ? _showConfirmationDialog : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmitAny ? Colors.orange : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    );
  }
}
