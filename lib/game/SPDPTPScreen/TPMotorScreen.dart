import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../BidService.dart'; // Import BidService
import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';

class TPMotorsBetScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType; // e.g. "triplePanna" or your key for TP Motors
  final int gameId;
  final String gameName;
  final bool
  selectionStatus; // controls whether "Open" is available along with "Close"

  const TPMotorsBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
    required this.selectionStatus,
  });

  @override
  State<TPMotorsBetScreen> createState() => _TPMotorsBetScreenState();
}

class _TPMotorsBetScreenState extends State<TPMotorsBetScreen> {
  // -------- Session selection (UI only) --------
  late String selectedGameBetType; // "Open" | "Close"

  // -------- Inputs --------
  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  // Valid Triple Panna list
  final List<String> triplePanaOptions = const [
    "111",
    "222",
    "333",
    "444",
    "555",
    "666",
    "777",
    "888",
    "999",
    "000",
  ];
  List<String> filteredDigitOptions = [];
  bool _isDigitSuggestionsVisible = false;

  // Keep entries with session
  // each item: {digit, amount, type: OPEN/CLOSE, gameType}
  final Map<String, List<Map<String, String>>> _entriesBySession = {
    'OPEN': <Map<String, String>>[],
    'CLOSE': <Map<String, String>>[],
  };

  // -------- Services / Auth / Wallet --------
  late GetStorage storage;
  late BidService _bidService;

  late String accessToken;
  late String registerId;
  bool accountStatus = false;
  late int walletBalance; // keep as int for arithmetic

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  // -------- Snackbar/Message bar --------
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  bool _isApiCalling = false;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  // -------- Lifecycle --------
  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _bidService = BidService(storage);
    _loadInitialData();

    // Parse wallet safely
    final num? bal = num.tryParse(userController.walletBalance.value);
    walletBalance = bal?.toInt() ?? 0;

    digitController.addListener(_onDigitChanged);
    selectedGameBetType = widget.selectionStatus ? "Open" : "Close";
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    // Prefer controller flag if available; fall back to storage
    accountStatus =
        userController.accountStatus.value ||
        (storage.read('accountStatus') ?? false);
  }

  @override
  void dispose() {
    digitController.removeListener(_onDigitChanged);
    digitController.dispose();
    pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  // -------- Helpers --------
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

  void _onDigitChanged() {
    final query = digitController.text.trim();
    if (query.isEmpty) {
      setState(() {
        filteredDigitOptions = [];
        _isDigitSuggestionsVisible = false;
      });
      return;
    }
    setState(() {
      filteredDigitOptions = triplePanaOptions
          .where((d) => d.startsWith(query))
          .toList();
      _isDigitSuggestionsVisible = filteredDigitOptions.isNotEmpty;
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

  // -------- Add / Remove --------
  void _addEntry() {
    _clearMessage();
    if (_isApiCalling) return;

    final digit = digitController.text.trim();
    final pointsStr = pointsController.text.trim();

    if (digit.length != 3 || int.tryParse(digit) == null) {
      _showMessage('Enter a valid 3-digit number.', isError: true);
      return;
    }
    if (!triplePanaOptions.contains(digit)) {
      _showMessage('Invalid Triple Panna number.', isError: true);
      return;
    }

    final pts = int.tryParse(pointsStr);
    if (pts == null || pts < 10 || pts > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    final sessionUpper = selectedGameBetType.toUpperCase();
    final list = _entriesBySession[sessionUpper]!;
    final idx = list.indexWhere((e) => e['digit'] == digit);

    setState(() {
      if (idx != -1) {
        final curr = int.tryParse(list[idx]['amount'] ?? '0') ?? 0;
        list[idx]['amount'] = (curr + pts).toString();
        _showMessage("Updated: $digit ($sessionUpper)");
      } else {
        list.add({
          "digit": digit,
          "amount": pointsStr,
          "type": sessionUpper, // OPEN / CLOSE
          "gameType": widget.gameCategoryType, // your game type key
        });
        _showMessage("Added: $digit ($sessionUpper)");
      }
      digitController.clear();
      pointsController.clear();
      _isDigitSuggestionsVisible = false;
    });
  }

  void _removeEntry(String sessionUpper, int index) {
    _clearMessage();
    if (_isApiCalling) return;
    final list = _entriesBySession[sessionUpper]!;
    final removed = list[index]['digit'];
    setState(() {
      list.removeAt(index);
    });
    _showMessage("Removed: $removed ($sessionUpper)");
  }

  // -------- Submit (per session) --------
  Future<bool> _placeBidsForSession(String sessionUpper) async {
    final list = _entriesBySession[sessionUpper]!;
    if (list.isEmpty) return true; // nothing to submit for this session

    final Map<String, String> bidPayload = {};
    int totalForSession = 0;

    for (final e in list) {
      final digit = e['digit'] ?? '';
      final amt = int.tryParse(e['amount'] ?? '0') ?? 0;
      if (digit.isEmpty || amt <= 0) continue;
      bidPayload.update(
        digit,
        (old) => (int.parse(old) + amt).toString(),
        ifAbsent: () => amt.toString(),
      );
      totalForSession += amt;
    }

    log(
      '[$sessionUpper] payload: $bidPayload | total: $totalForSession',
      name: 'TPMotors',
    );

    if (bidPayload.isEmpty) return true;

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
        bidAmounts: bidPayload,
        selectedGameType: sessionUpper, // "OPEN" / "CLOSE"
        gameId: widget.gameId,
        gameType: widget.gameCategoryType,
        totalBidAmount: totalForSession,
      );

      if (result['status'] == true) {
        // Deduct wallet; prefer server's updated balance if provided
        final dynamic updatedRaw = result['updatedWalletBalance'];
        final int updatedBalance =
            int.tryParse(updatedRaw?.toString() ?? '') ??
            (walletBalance - totalForSession);

        setState(() => walletBalance = updatedBalance);
        _bidService.updateWalletBalance(updatedBalance);

        // Clear only this session's entries
        setState(() => _entriesBySession[sessionUpper]!.clear());
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
        'Error during $sessionUpper bid placement: $e',
        name: 'TPMotorsBetScreen',
      );
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

  // -------- Unified confirmation (both sessions together) --------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    final all = _allEntries();
    final totalAll = _totalPointsAll();

    if (all.isEmpty) {
      _showMessage("No bids added.", isError: true);
      return;
    }
    if (walletBalance < totalAll) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    final String whenStr = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    final List<Map<String, String>> dialogRows = all
        .map(
          (e) => {
            "digit": e['digit']!,
            "points": e['amount']!,
            "type": e['type']!, // OPEN / CLOSE
            "pana": e['digit']!, // compatibility
          },
        )
        .toList(growable: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: "${widget.gameName}, Triple Panna",
        gameDate: whenStr,
        bids: dialogRows,
        totalBids: dialogRows.length,
        totalBidsAmount: totalAll,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - totalAll).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameCategoryType,
        onConfirm: () async {
          if (!mounted) return;
          setState(() => _isApiCalling = true);

          bool ok = true;
          if (_hasEntries('OPEN')) ok = await _placeBidsForSession('OPEN');
          if (ok && _hasEntries('CLOSE'))
            ok = await _placeBidsForSession('CLOSE');

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

  // -------- UI --------
  @override
  Widget build(BuildContext context) {
    // Dynamically compute available options
    final List<String> availableGameTypes = [
      if (widget.selectionStatus) "Open",
      "Close",
    ];

    // Ensure current selection is valid if widget.selectionStatus changed
    if (!availableGameTypes.contains(selectedGameBetType)) {
      selectedGameBetType = availableGameTypes.first;
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
                      _inputRow(
                        "Select Game Type:",
                        _buildDropdown(availableGameTypes),
                      ),
                      const SizedBox(height: 12),
                      _inputRow(
                        "Enter 3-Digit Triple Panna:",
                        _buildDigitInputField(),
                      ),
                      if (_isDigitSuggestionsVisible &&
                          filteredDigitOptions.isNotEmpty)
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
                            itemCount: filteredDigitOptions.length,
                            itemBuilder: (context, index) {
                              final suggestion = filteredDigitOptions[index];
                              return ListTile(
                                title: Text(suggestion),
                                onTap: () {
                                  setState(() {
                                    digitController.text = suggestion;
                                    _isDigitSuggestionsVisible = false;
                                    digitController.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(
                                            offset: digitController.text.length,
                                          ),
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
                        _buildTextField(
                          pointsController,
                          "Enter Amount",
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                        ),
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
                      ? const Center(child: Text("No bids added yet"))
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
                                        : () {
                                            final session = e['type']!
                                                .toUpperCase();
                                            final idx =
                                                _entriesBySession[session]!
                                                    .indexOf(e);
                                            if (idx != -1)
                                              _removeEntry(session, idx);
                                          },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                if (all.isNotEmpty) _buildBottomBar(canSubmitAny),
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

  // -------- Small UI helpers --------
  Widget _inputRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
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
                : (String? newValue) {
                    if (newValue == null) return;
                    setState(() {
                      selectedGameBetType = newValue;
                      _clearMessage();
                    });
                  },
            items: options
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDigitInputField() {
    return SizedBox(
      height: 35,
      child: TextFormField(
        controller: digitController,
        cursorColor: Colors.red,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: [
          LengthLimitingTextInputFormatter(3),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: () {
          _clearMessage();
          _onDigitChanged();
        },
        onChanged: (_) => _onDigitChanged(),
        enabled: !_isApiCalling,
        decoration: InputDecoration(
          hintText: "Enter 3-Digit Triple Panna",
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

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      width: 150,
      height: 35,
      child: TextFormField(
        controller: controller,
        cursorColor: Colors.red,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: inputFormatters,
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

  Widget _buildBottomBar(bool canSubmitAny) {
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
              backgroundColor: canSubmitAny ? Colors.red : Colors.grey,
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
