import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

import '../../BidService.dart';
import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';

class JodiBidScreen extends StatefulWidget {
  final String title;
  final String gameType;
  final int gameId;
  final String gameName;

  const JodiBidScreen({
    Key? key,
    required this.title,
    required this.gameType,
    required this.gameId,
    required this.gameName,
  }) : super(key: key);

  @override
  State<JodiBidScreen> createState() => _JodiBidScreenState();
}

class _JodiBidScreenState extends State<JodiBidScreen> {
  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  List<Map<String, String>> bids = [];
  late GetStorage storage;
  late BidService _bidService;

  late String accessToken;
  late String registerId;
  String walletBalance = '0'; // Changed to String
  bool accountStatus = false;
  bool _isSubmitting = false;

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  final UserController userController = Get.put(UserController());

  final List<String> allJodiOptions = List.generate(
    100,
    (i) => i.toString().padLeft(2, '0'),
  );

  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _bidService = BidService(storage);
    // Initialize walletBalance from storage as String
    double _walletBalance = double.parse(userController.walletBalance.value);
    int _walletBalanceInt = _walletBalance.toInt();
    walletBalance = _walletBalanceInt.toString();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
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
    if (mounted) setState(() => _messageToShow = null);
  }

  void _addBid() {
    _clearMessage();
    if (_isSubmitting) return;

    final jodi = digitController.text.trim();
    final amount = amountController.text.trim();

    if (jodi.length != 2 || int.tryParse(jodi) == null) {
      _showMessage('Please enter a valid 2-digit Jodi.', isError: true);
      return;
    }
    final amt = int.tryParse(amount);
    if (amt == null || amt < 10 || amt > 1000) {
      _showMessage('Amount must be between 10 and 1000.', isError: true);
      return;
    }
    if (bids.any((b) => b['digit'] == jodi)) {
      _showMessage('Jodi $jodi already exists.', isError: true);
      return;
    }

    setState(() {
      bids.add({'digit': jodi, 'amount': amount});
      digitController.clear();
      amountController.clear();
      _showMessage('Bid for Jodi $jodi added successfully!');
    });
  }

  void _removeBid(int idx) {
    if (_isSubmitting) return;
    setState(() {
      final removed = bids[idx]['digit'];
      bids.removeAt(idx);
      _showMessage('Bid for Jodi $removed removed.', isError: false);
    });
  }

  int _getTotalPoints() {
    return bids.fold(0, (sum, b) => sum + (int.tryParse(b['amount']!) ?? 0));
  }

  Future<void> _submitBidViaService(int total) async {
    setState(() => _isSubmitting = true);
    final bidMap = {for (var b in bids) b['digit']!: b['amount']!};

    final result = await _bidService.placeFinalBids(
      gameName: widget.gameName,
      accessToken: accessToken,
      registerId: registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: accountStatus,
      bidAmounts: bidMap,
      selectedGameType: "OPEN",
      gameId: widget.gameId,
      gameType: widget.gameType,
      totalBidAmount: total,
    );

    if (result['status'] == true) {
      // Parse current walletBalance to int for calculation
      final currentWalletBalanceInt = int.tryParse(walletBalance) ?? 0;
      final newBalInt = currentWalletBalanceInt - total;
      await _bidService.updateWalletBalance(
        newBalInt,
      ); // update GetStorage with int
      setState(() {
        bids.clear();
        walletBalance = newBalInt
            .toString(); // Convert back to String for state
      });
      showDialog(context: context, builder: (_) => const BidSuccessDialog());
      _showMessage("Bid placed successfully!");
    } else {
      showDialog(
        context: context,
        builder: (_) =>
            BidFailureDialog(errorMessage: result['msg'] ?? "Error"),
      );
      _showMessage(result['msg'] ?? "Bid failed.", isError: true);
    }

    setState(() => _isSubmitting = false);
  }

  void _showConfirmationDialog(int total) {
    if (bids.isEmpty) {
      _showMessage('No bids added yet.', isError: true);
      return;
    }
    // Parse walletBalance to int for comparison
    if (total > (int.tryParse(walletBalance) ?? 0)) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    final date = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    // No change here, walletBalance is already a String,
    // (int.tryParse(walletBalance) ?? 0) - total) is calculated as int then converted to string
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: "${widget.gameName}, ${widget.gameType}",
        gameDate: date,
        bids: bids,
        totalBids: bids.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction:
            int.tryParse(walletBalance) ??
            0, // walletBalance, // Already a String
        walletBalanceAfterDeduction:
            ((int.tryParse(walletBalance) ?? 0) - total).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () => _placeFinalBids(),
      ),
    );
  }

  Future<bool> _placeFinalBids() async {
    final result = await _bidService.placeFinalBids(
      gameName: widget.gameName,
      accessToken: accessToken,
      registerId: registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: accountStatus,
      bidAmounts: _bidService.getBidAmounts(bids),
      selectedGameType: "OPEN",
      gameId: widget.gameId,
      gameType: widget.gameType,
      totalBidAmount: _getTotalPoints(),
    );

    if (!mounted) return false;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => result['status']
            ? const BidSuccessDialog()
            : BidFailureDialog(errorMessage: result['msg']),
      );

      bids.clear();

      if (result['status'] && context.mounted) {
        // Parse current walletBalance to int for calculation
        final currentWalletBalanceInt = int.tryParse(walletBalance) ?? 0;
        final newBalanceInt = currentWalletBalanceInt - _getTotalPoints();
        setState(() {
          walletBalance = newBalanceInt
              .toString(); // Convert back to String for state
        });
        await _bidService.updateWalletBalance(
          newBalanceInt,
        ); // Update GetStorage with int
      }
    });

    return result['status'] == true;
  }

  @override
  void dispose() {
    digitController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _getTotalPoints();
    return Scaffold(
      backgroundColor: const Color(0xfff2f2f2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Image.asset(
                  "assets/images/ic_wallet.png",
                  width: 22,
                  height: 22,
                  color: Colors.black,
                ),
                const SizedBox(width: 4),
                // walletBalance is already a String, so direct use is fine
                Text(
                  walletBalance,
                  style: const TextStyle(color: Colors.black),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _inputRow(
                        "Enter Jodi:",
                        _buildInputField(
                          controller: digitController,
                          hint: "Enter Jodi",
                          borderColor: Colors.orange,
                          selected: 'digit',
                        ),
                      ),
                      _inputRow(
                        "Enter Points:",
                        _buildInputField(
                          controller: amountController,
                          hint: "Enter Amount",
                          borderColor: Colors.orange,
                          selected: 'amount',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _addBid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSubmitting
                                ? Colors.grey
                                : Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "ADD BID",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                _buildTableHeader(),
                const Divider(),
                Expanded(
                  child: bids.isEmpty
                      ? Center(
                          child: Text(
                            'No bids yet. Add some data!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: bids.length,
                          itemBuilder: (_, idx) =>
                              _buildBidItem(bids[idx], idx),
                        ),
                ),
                if (bids.isNotEmpty) _buildBottomBar(),
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

  Widget _inputRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: field),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required Color borderColor,
    required String selected,
  }) {
    if (selected == 'digit') {
      return RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: FocusNode(),
        optionsBuilder: (textEditingValue) {
          if (textEditingValue.text.isEmpty)
            return const Iterable<String>.empty();
          return allJodiOptions.where(
            (opt) => opt.startsWith(textEditingValue.text),
          );
        },
        fieldViewBuilder: (context, controller, focusNode, _) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            maxLength: 2,
            cursorColor: Colors.orange,
            decoration: InputDecoration(
              counterText: "",
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: borderColor),
                borderRadius: BorderRadius.circular(20),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: borderColor, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: borderColor),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      title: Text(option),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
        onSelected: (val) => controller.text = val,
      );
    } else {
      return TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: 4,
        cursorColor: Colors.orange,
        decoration: InputDecoration(
          counterText: "",
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 5,
          ),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor),
            borderRadius: BorderRadius.circular(20),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: const [
          Expanded(
            child: Text('Digit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(
              'Points',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              'Game Type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 40), // for delete icon
        ],
      ),
    );
  }

  Widget _buildBidItem(Map<String, String> bid, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(bid['digit'] ?? '')),
          Expanded(child: Text(bid['amount'] ?? '')),
          Expanded(
            child: Text(
              widget.gameType.toUpperCase(),
              style: const TextStyle(color: Colors.green),
            ),
          ), // use gameType from parent
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _removeBid(index),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final total = _getTotalPoints();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Bids:\n${bids.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Total Amount:\n$total',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () => _showConfirmationDialog(total),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'SUBMIT BID',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
