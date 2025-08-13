// lib/screens/odd_even_board_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:marquee/marquee.dart';

import '../../BidService.dart';
import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';

enum GameType { odd, even }

enum LataDayType { open, close }

class OddEvenBoardScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType; // e.g. "oddEven"
  final String gameName;
  final bool
  selectionStatus; // true => OPEN + CLOSE visible, false => only CLOSE

  const OddEvenBoardScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
    this.gameName = "",
    required this.selectionStatus,
  }) : super(key: key);

  @override
  State<OddEvenBoardScreen> createState() => _OddEvenBoardScreenState();
}

class _OddEvenBoardScreenState extends State<OddEvenBoardScreen> {
  // Inputs
  GameType? _selectedGameType = GameType.odd;
  LataDayType? _selectedLataDayType;
  final TextEditingController _pointsController = TextEditingController();

  /// each entry: { digit, points, type: OPEN/CLOSE, group: ODD/EVEN }
  final List<Map<String, String>> _entries = [];

  // Auth / state
  final GetStorage storage = GetStorage();
  late String _accessToken;
  late String _registerId;
  late bool _accountStatus;
  late int _walletBalance;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  // Services
  late final BidService _bidService;

  // Message bar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _msgTimer;

  bool _isApiCalling = false;

  static const List<String> _oddDigits = ['1', '3', '5', '7', '9'];
  static const List<String> _evenDigits = ['0', '2', '4', '6', '8'];

  @override
  void initState() {
    super.initState();
    _bidService = BidService(storage);

    _accessToken = storage.read('accessToken') ?? '';
    _registerId = storage.read('registerId') ?? '';
    _accountStatus = userController.accountStatus.value;

    final num? bal = num.tryParse(userController.walletBalance.value);
    _walletBalance = bal?.toInt() ?? 0;

    _selectedLataDayType = widget.selectionStatus
        ? LataDayType.open
        : LataDayType.close;
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  // -------- messages --------
  void _showMessage(String message, {bool isError = false}) {
    _msgTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    _msgTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _messageToShow = null);
    });
  }

  void _clearMessage() {
    if (!mounted) return;
    setState(() => _messageToShow = null);
  }

  // -------- helpers --------
  int _getTotalPoints() =>
      _entries.fold(0, (s, e) => s + (int.tryParse(e['points'] ?? '0') ?? 0));

  int _totalFor(String session) => _entries
      .where((e) => e['type'] == session)
      .fold(0, (s, e) => s + (int.tryParse(e['points'] ?? '0') ?? 0));

  Map<String, String> _mapFor(String session) => {
    for (final e in _entries.where((e) => e['type'] == session))
      e['digit']!: e['points']!,
  };

  // -------- add / remove --------
  void _addEntry() {
    _clearMessage();
    if (_isApiCalling) return;

    final ptsTxt = _pointsController.text.trim();
    final pts = int.tryParse(ptsTxt);
    if (pts == null || pts < 10 || pts > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }
    if (_selectedGameType == null) {
      _showMessage('Please select Odd or Even.', isError: true);
      return;
    }

    final session = _selectedLataDayType == LataDayType.close
        ? 'CLOSE'
        : 'OPEN';
    final group = _selectedGameType == GameType.odd ? 'ODD' : 'EVEN';
    final digits = _selectedGameType == GameType.odd ? _oddDigits : _evenDigits;

    // wallet guard for this add (5 digits)
    final futureTotal = _getTotalPoints() + (pts * digits.length);
    if (futureTotal > _walletBalance) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    setState(() {
      // merge by (digit + session)
      for (final d in digits) {
        final i = _entries.indexWhere(
          (e) => e['digit'] == d && e['type'] == session,
        );
        if (i != -1) {
          final curr = int.tryParse(_entries[i]['points'] ?? '0') ?? 0;
          _entries[i]['points'] = (curr + pts).toString();
        } else {
          _entries.add({
            'digit': d,
            'points': pts.toString(),
            'type': session,
            'group': group,
          });
        }
      }
      _pointsController.clear();
    });

    _showMessage('Added $group ($session): ${digits.join(", ")}');
  }

  void _deleteEntry(int index) {
    _clearMessage();
    setState(() {
      final removed = _entries.removeAt(index);
      _showMessage('Removed ${removed['digit']} (${removed['type']}).');
    });
  }

  // -------- confirm & submit (now for BOTH sessions) --------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    if (_entries.isEmpty) {
      _showMessage('Please add at least one bid.', isError: true);
      return;
    }

    final totalAll = _getTotalPoints();
    if (_walletBalance < totalAll) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    // show BOTH sessions in the dialog
    final bidsForDialog = _entries
        .map(
          (e) => {
            "digit": e['digit']!,
            "points": e['points']!,
            "type": e['type']!, // OPEN/CLOSE
            "pana":
                e['digit']!, // non-empty to satisfy any validation in dialog
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
        totalBidsAmount: totalAll,
        walletBalanceBeforeDeduction: _walletBalance,
        walletBalanceAfterDeduction: (_walletBalance - totalAll).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () async {
          if (!mounted) return;
          setState(() => _isApiCalling = true);
          final ok = await _submitBothSessions();
          if (mounted) setState(() => _isApiCalling = false);
          if (ok) {
            setState(() => _entries.clear());
          }
        },
      ),
    );
  }

  /// Submits OPEN and CLOSE in separate calls if present.
  Future<bool> _submitBothSessions() async {
    if (_accessToken.isEmpty || _registerId.isEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Authentication error. Please log in again.',
        ),
      );
      return false;
    }

    final hasOpen = _entries.any((e) => e['type'] == 'OPEN');
    final hasClose = _entries.any((e) => e['type'] == 'CLOSE');

    bool openOk = true;
    bool closeOk = true;
    int walletAfter = _walletBalance;

    // helper to submit one session
    Future<Map<String, dynamic>> _submitSession(
      String session,
      Map<String, String> bidMap,
      int sessionTotal,
    ) {
      return _bidService.placeFinalBids(
        gameName: widget.gameName,
        accessToken: _accessToken,
        registerId: _registerId,
        deviceId: storage.read('deviceId')?.toString() ?? 'odd_even_device',
        deviceName: storage.read('deviceName')?.toString() ?? 'OddEvenBoardApp',
        accountStatus: _accountStatus,
        bidAmounts: bidMap,
        selectedGameType: session, // "OPEN" or "CLOSE"
        gameId: widget.gameId,
        gameType: widget.gameType, // "oddEven"
        totalBidAmount: sessionTotal,
      );
    }

    // OPEN first (order doesn't really matter)
    if (hasOpen) {
      final openMap = _mapFor('OPEN');
      final openTotal = _totalFor('OPEN');
      final r = await _submitSession('OPEN', openMap, openTotal);
      if (r['status'] == true) {
        final dynamic updated = r['updatedWalletBalance'];
        walletAfter =
            int.tryParse(updated?.toString() ?? '') ??
            (walletAfter - openTotal);
        // remove OPEN rows from list (they are done)
        setState(() => _entries.removeWhere((e) => e['type'] == 'OPEN'));
      } else {
        openOk = false;
      }
    }

    // CLOSE next
    if (hasClose) {
      final closeMap = _mapFor('CLOSE');
      final closeTotal = _totalFor('CLOSE');
      final r = await _submitSession('CLOSE', closeMap, closeTotal);
      if (r['status'] == true) {
        final dynamic updated = r['updatedWalletBalance'];
        walletAfter =
            int.tryParse(updated?.toString() ?? '') ??
            (walletAfter - closeTotal);
        // remove CLOSE rows from list (they are done)
        setState(() => _entries.removeWhere((e) => e['type'] == 'CLOSE'));
      } else {
        closeOk = false;
      }
    }

    // Update wallet if anything succeeded
    if (openOk || closeOk) {
      await _bidService.updateWalletBalance(walletAfter);
      userController.walletBalance.value = walletAfter.toString();
      setState(() => _walletBalance = walletAfter);
    }

    if (openOk && closeOk) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidSuccessDialog(),
      );
      _clearMessage();
      return true;
    }

    // partial / full fail
    final msg = (!openOk && !closeOk)
        ? 'Place bid failed for all sessions. Please try again later.'
        : 'Some bids were placed, but others failed. Please review.';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidFailureDialog(errorMessage: msg),
    );
    return false;
  }

  // -------- UI --------
  @override
  Widget build(BuildContext context) {
    // session dropdown items
    final items = <DropdownMenuItem<LataDayType>>[];
    if (widget.selectionStatus) {
      items.add(
        DropdownMenuItem<LataDayType>(
          value: LataDayType.open,
          child: SizedBox(
            width: 150,
            height: 20,
            child: Marquee(
              text: '${widget.title} OPEN',
              style: const TextStyle(fontSize: 16),
              scrollAxis: Axis.horizontal,
              blankSpace: 40.0,
              velocity: 30.0,
              pauseAfterRound: const Duration(seconds: 1),
              startPadding: 10.0,
            ),
          ),
        ),
      );
    }
    items.add(
      DropdownMenuItem<LataDayType>(
        value: LataDayType.close,
        child: SizedBox(
          width: 150,
          height: 20,
          child: Marquee(
            text: '${widget.title} CLOSE',
            style: const TextStyle(fontSize: 16),
            scrollAxis: Axis.horizontal,
            blankSpace: 40.0,
            velocity: 30.0,
            pauseAfterRound: const Duration(seconds: 1),
            startPadding: 10.0,
          ),
        ),
      ),
    );

    final totalBids = _entries.length;
    final totalPoints = _getTotalPoints();

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
          style: const TextStyle(
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
                  '$_walletBalance',
                  style: const TextStyle(color: Colors.black, fontSize: 16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // session select
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Game Type',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<LataDayType>(
                                value: _selectedLataDayType,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.orange,
                                ),
                                onChanged: (v) => setState(() {
                                  _selectedLataDayType = v;
                                  _clearMessage();
                                }),
                                items: items,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // odd/even radios
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<GameType>(
                              title: const Text('Odd'),
                              value: GameType.odd,
                              groupValue: _selectedGameType,
                              onChanged: (v) {
                                setState(() {
                                  _selectedGameType = v;
                                  _clearMessage();
                                });
                              },
                              activeColor: Colors.orange,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<GameType>(
                              title: const Text('Even'),
                              value: GameType.even,
                              groupValue: _selectedGameType,
                              onChanged: (v) {
                                setState(() {
                                  _selectedGameType = v;
                                  _clearMessage();
                                });
                              },
                              activeColor: Colors.orange,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // points field
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Enter Points :',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildPointsInputField(_pointsController),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // add button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 150,
                            child: ElevatedButton(
                              onPressed: _isApiCalling ? null : _addEntry,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isApiCalling
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
                              child: _isApiCalling
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'ADD',
                                      style: TextStyle(
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
                      children: const [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Digit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Points',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Type',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        SizedBox(width: 48),
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
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final e = _entries[index];
                            return _buildEntryItem(
                              e['digit']!,
                              e['points']!,
                              e['type']!,
                              index,
                            );
                          },
                        ),
                ),

                if (_entries.isNotEmpty)
                  _buildBottomBar(totalBids, totalPoints),
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

  Widget _buildPointsInputField(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        cursorColor: Colors.orange,
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onTap: _clearMessage,
        decoration: const InputDecoration(
          hintText: 'Enter Points',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildEntryItem(String digit, String points, String type, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                points,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                type,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteEntry(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(int totalBids, int totalPoints) {
    final canSubmit = !_isApiCalling && _entries.isNotEmpty;
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
            children: const [
              Text('Bids', style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
          Text(
            '$totalBids',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Points',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          Text(
            '$totalPoints',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ElevatedButton(
            onPressed: canSubmit ? _showConfirmationDialog : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? Colors.orange : Colors.grey,
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
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'SUBMIT',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
          ),
        ],
      ),
    );
  }
}
