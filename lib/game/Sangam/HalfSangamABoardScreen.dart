import 'dart:async';

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

class HalfSangamABoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;
  final String gameType; // e.g. "halfSangamA"
  final String gameName;

  const HalfSangamABoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId,
    required this.gameType,
    required this.gameName,
  }) : super(key: key);

  @override
  State<HalfSangamABoardScreen> createState() => _HalfSangamABoardScreenState();
}

class _HalfSangamABoardScreenState extends State<HalfSangamABoardScreen> {
  final TextEditingController _openDigitController = TextEditingController();
  final TextEditingController _closePannaController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  final List<Map<String, String>> _bids =
      []; // {sangam, points, openDigit, closePanna, type}
  final GetStorage _storage = GetStorage();
  late final BidService _bidService;

  String _accessToken = '';
  String _registerId = '';
  String _preferredLanguage = 'en';
  bool _accountStatus = false;
  int _walletBalance = 0;

  bool _isApiCalling = false;

  // NOTE: replace with real device params if app me available ho
  static const String _deviceId = 'test_device_id_flutter';
  static const String _deviceName = 'test_device_name_flutter';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  // Panna list (const for perf)
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
    "120",
    "122",
    "123",
    "124",
    "125",
    "126",
    "127",
    "128",
    "129",
    "130",
    "133",
    "134",
    "135",
    "136",
    "137",
    "138",
    "139",
    "140",
    "144",
    "145",
    "146",
    "147",
    "148",
    "149",
    "150",
    "155",
    "156",
    "157",
    "158",
    "159",
    "160",
    "166",
    "167",
    "168",
    "169",
    "170",
    "177",
    "178",
    "179",
    "180",
    "188",
    "189",
    "190",
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
    "230",
    "233",
    "234",
    "235",
    "236",
    "237",
    "238",
    "239",
    "240",
    "244",
    "245",
    "246",
    "247",
    "248",
    "249",
    "250",
    "255",
    "256",
    "257",
    "258",
    "259",
    "260",
    "266",
    "267",
    "268",
    "269",
    "270",
    "277",
    "278",
    "279",
    "280",
    "288",
    "289",
    "290",
    "299",
    "300",
    "330",
    "334",
    "335",
    "336",
    "337",
    "338",
    "339",
    "340",
    "344",
    "345",
    "346",
    "347",
    "348",
    "349",
    "350",
    "355",
    "356",
    "357",
    "358",
    "359",
    "360",
    "366",
    "367",
    "368",
    "369",
    "370",
    "377",
    "378",
    "379",
    "380",
    "388",
    "389",
    "390",
    "399",
    "400",
    "440",
    "445",
    "446",
    "447",
    "448",
    "449",
    "450",
    "455",
    "456",
    "457",
    "458",
    "459",
    "460",
    "466",
    "467",
    "468",
    "469",
    "470",
    "477",
    "478",
    "479",
    "480",
    "488",
    "489",
    "490",
    "499",
    "500",
    "550",
    "556",
    "557",
    "558",
    "559",
    "560",
    "566",
    "567",
    "568",
    "569",
    "570",
    "577",
    "578",
    "579",
    "580",
    "588",
    "589",
    "590",
    "599",
    "600",
    "660",
    "667",
    "668",
    "669",
    "670",
    "677",
    "678",
    "679",
    "680",
    "688",
    "689",
    "690",
    "699",
    "700",
    "770",
    "778",
    "779",
    "780",
    "788",
    "789",
    "790",
    "799",
    "800",
    "880",
    "889",
    "890",
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
    _bidService = BidService(_storage);
    _loadInitialData();
  }

  @override
  void dispose() {
    _openDigitController.dispose();
    _closePannaController.dispose();
    _pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _accessToken = _storage.read('accessToken') ?? '';
    _registerId = _storage.read('registerId') ?? '';
    _accountStatus = _storage.read('accountStatus') ?? false;
    _preferredLanguage = _storage.read('selectedLanguage') ?? 'en';

    final balanceStr = userController.walletBalance.value;
    final parsed = num.tryParse(balanceStr);
    _walletBalance = parsed?.toInt() ?? 0;

    if (mounted) setState(() {});
  }

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

  // ---------- Add / Remove ----------
  void _addBid() {
    _clearMessage();
    if (_isApiCalling) return;

    final openDigit = _openDigitController.text.trim();
    final closePanna = _closePannaController.text.trim();
    final points = _pointsController.text.trim();

    // Open digit validation
    if (openDigit.length != 1 || int.tryParse(openDigit) == null) {
      _showMessage('Open Digit ek hi hona chahiye (0-9).', isError: true);
      return;
    }
    final parsedOpenDigit = int.parse(openDigit);
    if (parsedOpenDigit < 0 || parsedOpenDigit > 9) {
      _showMessage('Open Digit 0 se 9 ke beech do.', isError: true);
      return;
    }

    // Panna validation
    if (closePanna.length != 3 || !_allPannas.contains(closePanna)) {
      _showMessage('Valid 3-digit Panna do (e.g. 123).', isError: true);
      return;
    }

    // Points validation (min from storage if present)
    final parsedPoints = int.tryParse(points);
    final int minBid =
        int.tryParse(_storage.read('minBid')?.toString() ?? '10') ?? 10;
    if (parsedPoints == null || parsedPoints < minBid || parsedPoints > 1000) {
      _showMessage('Points $minBid se 1000 ke beech do.', isError: true);
      return;
    }

    // Optional wallet guard on add (total tentative)
    final nextTotal = _getTotalPoints() + parsedPoints;
    if (_walletBalance > 0 && nextTotal > _walletBalance) {
      _showMessage(
        'Itna add karoge to total wallet se zyada ho jayega.',
        isError: true,
      );
      return;
    }

    final sangam = '$openDigit-$closePanna';

    setState(() {
      final existingIndex = _bids.indexWhere((bid) => bid['sangam'] == sangam);
      if (existingIndex != -1) {
        _bids[existingIndex]['points'] =
            (int.parse(_bids[existingIndex]['points']!) + parsedPoints)
                .toString();
        _showMessage('Updated points for $sangam.');
      } else {
        _bids.add({
          "sangam": sangam,
          "points": points,
          "openDigit": openDigit,
          "closePanna": closePanna,
          "type": widget.gameType,
        });
        _showMessage('Added: $sangam — $points pts.');
      }

      _openDigitController.clear();
      _closePannaController.clear();
      _pointsController.clear();
    });
  }

  void _removeBid(int index) {
    _clearMessage();
    if (_isApiCalling) return;
    if (index < 0 || index >= _bids.length) return;

    setState(() {
      final removedSangam = _bids[index]['sangam'];
      _bids.removeAt(index);
      _showMessage('Removed $removedSangam.');
    });
  }

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  // ---------- Submit flow ----------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    if (_bids.isEmpty) {
      _showMessage('Pehle kam se kam 1 bid add karo.', isError: true);
      return;
    }

    // sync latest wallet from controller before check
    final parsed = num.tryParse(userController.walletBalance.value);
    _walletBalance = parsed?.toInt() ?? _walletBalance;

    final totalPoints = _getTotalPoints();
    if (_walletBalance < totalPoints) {
      _showMessage('Wallet balance kam hai.', isError: true);
      return;
    }

    // Dialog me: Digits = Panna, Game Type = "Half Sangam A", Points = amount
    final bidsForDialog = _bids.map((bid) {
      return {
        "digit": bid['closePanna']!, // Panna as digits
        "pana": "",
        "points": bid['points']!,
        "type": "Half Sangam A",
        "sangam": bid['sangam']!,
        "jodi": "",
      };
    }).toList();

    final formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.gameName,
          gameDate: formattedDate,
          bids: bidsForDialog,
          totalBids: bidsForDialog.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: _walletBalance,
          walletBalanceAfterDeduction: (_walletBalance - totalPoints)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            final result = await _placeFinalBids();
            if (!mounted) return;

            if (result['status'] == true) {
              setState(() => _bids.clear());

              final int newBalance =
                  (result['data']?['wallet_balance'] as num?)?.toInt() ??
                  (_walletBalance - totalPoints);

              await _bidService.updateWalletBalance(newBalance);
              // local sync bhi
              setState(() => _walletBalance = newBalance);

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
                      result['msg'] ??
                      "Bid submission failed. Please try again.",
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _placeFinalBids() async {
    if (!mounted) return {'status': false, 'msg': 'Screen not mounted.'};
    setState(() => _isApiCalling = true);

    try {
      if (_accessToken.isEmpty || _registerId.isEmpty) {
        return {'status': false, 'msg': 'Auth issue — login dobara karo.'};
      }

      // Map payload: "openDigit-closePanna" -> points
      final Map<String, String> bidAmountsMap = {};
      for (final bid in _bids) {
        final key = '${bid['openDigit']!}-${bid['closePanna']!}';
        bidAmountsMap[key] = bid['points']!;
      }
      if (bidAmountsMap.isEmpty) {
        return {'status': false, 'msg': 'No valid bids to submit.'};
      }

      final totalPoints = _getTotalPoints();
      const selectedSessionType = "OPEN"; // Half Sangam A = OPEN

      final result = await _bidService.placeFinalBids(
        gameName: widget.gameName,
        accessToken: _accessToken,
        registerId: _registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: _accountStatus,
        bidAmounts: bidAmountsMap,
        selectedGameType: selectedSessionType,
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: totalPoints,
      );

      // wallet local fallback update (service already karta ho to bhi safe)
      if (result['status'] == true) {
        final int newBalance =
            (result['data']?['wallet_balance'] as num?)?.toInt() ??
            (_walletBalance - totalPoints);
        await _bidService.updateWalletBalance(newBalance);
        if (mounted) setState(() => _walletBalance = newBalance);
      }

      return result;
    } catch (e) {
      return {'status': false, 'msg': 'Unexpected error: $e'};
    } finally {
      if (mounted) setState(() => _isApiCalling = false);
    }
  }

  // ---------- UI ----------
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
          Center(
            child: Obx(
              () => Text(
                '₹${userController.walletBalance.value}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
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
                      _buildInputRow(
                        'Enter Open Digit :',
                        _openDigitController,
                        hintText: 'e.g., 5',
                        maxLength: 1,
                        enabled: !_isApiCalling,
                      ),
                      const SizedBox(height: 16),
                      _buildPannaInputRow(
                        'Enter Close Panna :',
                        _closePannaController,
                        hintText: 'e.g., 123',
                        maxLength: 3,
                        enabled: !_isApiCalling,
                      ),
                      const SizedBox(height: 16),
                      _buildInputRow(
                        'Enter Points :',
                        _pointsController,
                        hintText: 'e.g., 100',
                        maxLength: 4,
                        enabled: !_isApiCalling,
                        onSubmitted: _addBid,
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
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "ADD",
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
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Panna - Digit',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Points',
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
                            final displaySangam =
                                '${bid['closePanna']!} - ${bid['openDigit']!}';
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
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displaySangam,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        bid['points']!,
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
                                          : () => _removeBid(index),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Bottom summary bar
                SafeArea(top: false, child: _buildBottomBar()),
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

  // ---------- Widgets ----------
  Widget _buildInputRow(
    String label,
    TextEditingController controller, {
    String hintText = '',
    int? maxLength,
    bool enabled = true,
    Function()? onSubmitted,
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
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              if (maxLength != null)
                LengthLimitingTextInputFormatter(maxLength),
            ],
            onTap: _clearMessage,
            enabled: enabled,
            onSubmitted: (_) => onSubmitted?.call(),
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

  Widget _buildPannaInputRow(
    String label,
    TextEditingController controller, {
    String hintText = '',
    int? maxLength,
    bool enabled = true,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 16)),
        SizedBox(
          width: 150,
          height: 40,
          child: Autocomplete<String>(
            fieldViewBuilder:
                (context, textEditingController, focusNode, onFieldSubmitted) {
                  // keep in sync (without jitter)
                  if (textEditingController.text != controller.text) {
                    textEditingController.text = controller.text;
                    textEditingController.selection = TextSelection.collapsed(
                      offset: textEditingController.text.length,
                    );
                  }
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      if (maxLength != null)
                        LengthLimitingTextInputFormatter(maxLength),
                    ],
                    onChanged: (v) => controller.text = v,
                    onTap: _clearMessage,
                    enabled: enabled,
                    decoration: InputDecoration(
                      hintText: hintText,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
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
            optionsBuilder: (TextEditingValue value) {
              final q = value.text;
              if (q.isEmpty) return const Iterable<String>.empty();
              return _allPannas.where((s) => s.startsWith(q));
            },
            onSelected: (selection) => controller.text = selection,
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

  Widget _buildBottomBar() {
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
          _SummaryTile(title: 'Bid', value: '$totalBids'),
          _SummaryTile(title: 'Total', value: '$totalPoints'),
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
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final String value;
  const _SummaryTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
