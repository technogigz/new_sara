import 'dart:async'; // NEW
import 'dart:convert';
import 'dart:developer';
import 'dart:math' hide log;

import 'package:flutter/material.dart';
import 'package:flutter_pay_upi/flutter_pay_upi_manager.dart';
import 'package:flutter_pay_upi/model/upi_app_model.dart';
import 'package:flutter_pay_upi/model/upi_response.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/Fund/QRPaymentScreen.dart';
import 'package:new_sara/ulits/Constents.dart';

import '../Helper/TranslationHelper.dart';
import '../Helper/UserController.dart';

class CreateTransactionLinkResponse {
  final String msg;
  final bool status;
  final String? paymentLink;

  CreateTransactionLinkResponse({
    required this.msg,
    required this.status,
    this.paymentLink,
  });

  factory CreateTransactionLinkResponse.fromJson(Map<String, dynamic> json) {
    return CreateTransactionLinkResponse(
      msg: (json['msg'] ?? '').toString(),
      status: json['status'] == true,
      paymentLink: json['payment_link']?.toString(),
    );
  }
}

class AddFundScreen extends StatefulWidget {
  const AddFundScreen({super.key});
  @override
  State<AddFundScreen> createState() => _AddFundScreenState();
}

class _AddFundScreenState extends State<AddFundScreen>
    with WidgetsBindingObserver {
  final UserController userController = Get.find<UserController>();

  final TextEditingController amountController = TextEditingController();
  final Random _random = Random();
  final Map<String, String> _translationCache = {};
  final String currentLangCode = (GetStorage().read('language') ?? 'en')
      .toString();

  // Base API
  final String _apiBaseUrl = Constant.apiEndpoint;

  // UPI payee details (will be read from controller)
  String _upiPayeeVPA = '';
  String _upiPayeeName = '';
  static const String _merchantCode = "";

  bool _isProcessingPayment = false;
  int _currentTransactionAmount = 0;
  String _currentTransactionId = '';
  String _currentPaymentMethodType = '';

  List<UpiApp> _apps = [];

  // NEW: local auto-refresh timer for wallet
  Timer? _walletTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial pulls
    userController.fetchAndUpdateUserDetails();
    userController.fetchAndUpdateFeeSettings();

    // Seed UPI details from controller (fallbacks handled at launch time too)
    _upiPayeeVPA = userController.gpayUpiId.value;
    _upiPayeeName = userController.accountHolderName.value;

    _fetchUpiApps();

    // NEW: start live wallet auto-refresh on this screen
    _startWalletAutoRefresh();
  }

  @override
  void dispose() {
    amountController.dispose();
    _stopWalletAutoRefresh(); // NEW
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ---------- lifecycle: refresh on resume ----------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      userController.fetchAndUpdateUserDetails();
      _startWalletAutoRefresh(); // NEW
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopWalletAutoRefresh(); // NEW
    }
  }

  void _hideKeyboard() {
    final scope = FocusScope.of(context);
    if (!scope.hasPrimaryFocus) {
      scope.unfocus();
    }
  }

  // NEW: start/stop wallet polling local to this screen
  void _startWalletAutoRefresh({
    Duration interval = const Duration(seconds: 3),
  }) {
    _walletTimer?.cancel();
    _walletTimer = Timer.periodic(interval, (_) async {
      await userController.fetchAndUpdateUserDetails();
    });
    log('▶️ AddFundScreen wallet auto-refresh started');
  }

  void _stopWalletAutoRefresh() {
    _walletTimer?.cancel();
    _walletTimer = null;
    log('⏹ AddFundScreen wallet auto-refresh stopped');
  }

  // ---------- utilities ----------
  String _url(String path) {
    final base = _apiBaseUrl.endsWith('/') ? _apiBaseUrl : '$_apiBaseUrl/';
    final p = path.startsWith('/') ? path.substring(1) : path;
    return '$base$p';
  }

  Future<String> _t(String text) async {
    if (_translationCache.containsKey(text)) return _translationCache[text]!;
    final t = await TranslationHelper.translate(text, currentLangCode);
    if (mounted) _translationCache[text] = t;
    return t;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, String> _buildHeaders() {
    final deviceId = (GetStorage().read('deviceId') ?? '').toString();
    final deviceName = (GetStorage().read('deviceName') ?? '').toString();
    final accessTok = (userController.accessToken.value).toString();
    return {
      'Authorization': 'Bearer $accessTok',
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      'deviceId': deviceId,
      'deviceName': deviceName,
      'accessStatus': '1',
    };
  }

  String _mapDepositType(String appName) {
    final name = appName.toLowerCase();
    if (name.contains('google') || name.contains('gpay')) return 'googlePay';
    if (name.contains('phonepe')) return 'phonePe';
    if (name.contains('paytm')) return 'paytm';
    return 'bank';
  }

  Future<Map<String, dynamic>> _postJsonSafe(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse(_url(path));
    final res = await http.post(
      uri,
      headers: _buildHeaders(),
      body: json.encode(body),
    );

    Map<String, dynamic> out;
    try {
      final decoded = json.decode(res.body);
      out = decoded is Map<String, dynamic>
          ? decoded
          : {'status': false, 'msg': 'Invalid response format'};
    } catch (_) {
      out = {'status': false, 'msg': res.body.trim()};
    }
    out['_statusCode'] = res.statusCode;
    return out;
  }

  // ---------- UPI ----------
  void _fetchUpiApps() async {
    try {
      final apps = await FlutterPayUpiManager.getListOfAndroidUpiApps();
      log('UPI apps: ${apps.map((a) => a.name).toList()}');
      if (mounted) setState(() => _apps = apps);
    } catch (e) {
      log('Failed to load UPI apps: $e');
    }
  }

  Future<void> _validateAndPreparePayment() async {
    // ✅ 1) pehle keyboard hide
    _hideKeyboard();

    // ✅ 2) aur turant spinner on
    if (mounted) setState(() => _isProcessingPayment = true);

    final text = amountController.text.trim();
    final int? amt = int.tryParse(text);

    final minAmount =
        (double.tryParse(userController.minDeposit.value)?.toInt()) ?? 0;

    if (amt == null || amt < minAmount) {
      _showSnackBar(
        await _t(
          "Please enter a valid amount (min ₹${userController.minDeposit.value}).",
        ),
      );
      return;
    }

    setState(() {
      _isProcessingPayment = true;
      _currentTransactionAmount = amt;
      _currentTransactionId =
          '${DateTime.now().millisecondsSinceEpoch}${_random.nextInt(9999).toString().padLeft(4, '0')}';
    });

    if (_apps.isEmpty) {
      _showSnackBar(
        await _t("No UPI apps found. Please install a UPI app to proceed."),
      );
      setState(() => _isProcessingPayment = false);
      return;
    }

    _showUpiAppSelectionSheet();
  }

  void _showUpiAppSelectionSheet() {
    showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select UPI App',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                itemCount: _apps.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: .9,
                ),
                itemBuilder: (_, i) {
                  final app = _apps[i];
                  final name = app.name ?? 'UPI App';
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _currentPaymentMethodType = name;
                      _launchUpiWithApp(app);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 48,
                          width: 48,
                          child: app.icon != null
                              ? Image.memory(app.icon!)
                              : const Icon(Icons.payment, size: 48),
                        ),
                        const SizedBox(height: 6),
                        Text(name, textAlign: TextAlign.center, maxLines: 2),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (_isProcessingPayment && _currentPaymentMethodType.isEmpty) {
        if (mounted) setState(() => _isProcessingPayment = false);
      }
    });
  }

  Future<void> _launchUpiWithApp(UpiApp app) async {
    setState(() {
      _isProcessingPayment = true;
      _currentPaymentMethodType = (app.name ?? '').toString();
    });

    // Always read latest payee details from controller
    _upiPayeeVPA = userController.gpayUpiId.value;
    _upiPayeeName = userController.accountHolderName.value;

    if (_upiPayeeVPA.isEmpty || _upiPayeeName.isEmpty) {
      setState(() {
        _isProcessingPayment = false;
        _currentPaymentMethodType = '';
      });
      _showSnackBar('UPI payee details not configured.');
      return;
    }

    try {
      FlutterPayUpiManager.startPayment(
        paymentApp: app.app!,
        payeeVpa: _upiPayeeVPA,
        payeeName: _upiPayeeName,
        transactionId: _currentTransactionId,
        payeeMerchantCode: _merchantCode,
        description: "Add funds",
        amount: amountController.text.trim(),
        response: (UpiResponse upiResponse, String rawResponse) {
          log('UPI status: ${upiResponse.status} | $rawResponse');
          if (!mounted) return;

          setState(() => _isProcessingPayment = false);

          if ((upiResponse.status ?? '').toLowerCase() == 'success') {
            _reportPaymentStatusToBackend(upiResponse);
          } else {
            _showSnackBar('Payment failed or cancelled.');
          }
        },
        error: (String errorMessage) {
          log('UPI error: $errorMessage');
          if (!mounted) return;
          setState(() {
            _isProcessingPayment = false;
            _currentPaymentMethodType = '';
          });
          _showSnackBar('An error occurred during UPI payment: $errorMessage');
        },
      );
    } catch (e) {
      log('UPI launch error: $e');
      if (!mounted) return;
      setState(() {
        _isProcessingPayment = false;
        _currentPaymentMethodType = '';
      });
      _showSnackBar('Failed to launch UPI app.');
    }
  }

  Future<void> _reportPaymentStatusToBackend(UpiResponse upiResponse) async {
    final paymentHashKey =
        upiResponse.transactionReferenceId ??
        upiResponse.transactionID ??
        'default_hash_key';

    final depositType = _mapDepositType(_currentPaymentMethodType);

    final createBody = {
      "registerId": userController.registerId.value,
      "depositType": depositType,
      "amount": _currentTransactionAmount,
      "hashKey": paymentHashKey,
    };

    try {
      final createJson = await _postJsonSafe(
        'deposit-create-upi-fund-request',
        createBody,
      );

      if (createJson['status'] == true) {
        final infoRaw = createJson['info'];
        final Map<String, dynamic> info = (infoRaw is Map)
            ? Map<String, dynamic>.from(infoRaw as Map)
            : <String, dynamic>{};

        final String paymentHash = (info['paymentHash'] ?? '').toString();
        final int remark = (info['remark'] is num)
            ? (info['remark'] as num).toInt()
            : int.tryParse((info['remark'] ?? '0').toString()) ?? 0;
        final int timestamp = (info['timestamp'] is num)
            ? (info['timestamp'] as num).toInt()
            : int.tryParse((info['timestamp'] ?? '0').toString()) ?? 0;

        if (paymentHash.isEmpty || timestamp == 0) {
          _showSnackBar(
            'Invalid server response (missing paymentHash/timestamp).',
          );
          return;
        }

        final addBody = {
          "registerId": userController.registerId.value,
          "depositType": depositType,
          "amount": _currentTransactionAmount,
          "hashKey": paymentHashKey,
          "timestamp": timestamp,
          "paymentHash": paymentHash,
          "remark": remark,
        };

        final addJson = await _postJsonSafe(
          'add-upi-deposit-fund-request',
          addBody,
        );

        if (addJson['status'] == true) {
          if (mounted) {
            setState(() {
              _isProcessingPayment = false;
              _currentPaymentMethodType = '';
            });
          }
          // Pull latest balance
          await userController.fetchAndUpdateUserDetails();
          // Optional: short soft-poll to catch delayed processing
          _softPollBalance(times: 3);

          amountController.clear();
          _showSnackBar(
            addJson['msg']?.toString() ?? 'Deposit successful and updated',
          );
        } else {
          _showSnackBar(
            addJson['msg']?.toString() ?? 'Failed to add deposit fund',
          );
        }
      } else {
        final code = createJson['_statusCode'];
        _showSnackBar(
          createJson['msg']?.toString() ??
              'Failed to create fund request (HTTP $code)',
        );
      }
    } catch (e) {
      _showSnackBar("Failed to complete payment process: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _currentPaymentMethodType = '';
        });
      }
    }
  }

  // Optional: short polling to reflect latest balance after success
  Future<void> _softPollBalance({int times = 3}) async {
    for (var i = 0; i < times; i++) {
      await Future.delayed(const Duration(seconds: 2));
      await userController.fetchAndUpdateUserDetails();
    }
  }

  Future<void> _createTransactionLink() async {
    // ✅ 1) pehle keyboard hide
    _hideKeyboard();

    // ✅ 2) aur turant spinner on
    if (mounted) setState(() => _isProcessingPayment = true);

    final amountText = amountController.text.trim();
    final parsedAmount = int.tryParse(amountText);
    final parsedMobile = int.tryParse(userController.mobileNo.value);

    final minAmountInt =
        (double.tryParse(userController.minDeposit.value)?.toInt()) ?? 0;

    if (parsedAmount == null) {
      _showSnackBar("Please enter a valid amount.");
      return;
    }
    if (parsedAmount < minAmountInt) {
      _showSnackBar(
        "Please enter an amount greater than or equal to ₹$minAmountInt.",
      );
      return;
    }
    if (parsedMobile == null) {
      _showSnackBar("Invalid mobile number found.");
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      final responseJson = await _postJsonSafe('create-transaction-link', {
        'registerId': userController.registerId.value,
        'amount': parsedAmount,
        'mobile': parsedMobile,
      });

      if ((responseJson['_statusCode'] ?? 0) == 200 &&
          responseJson['status'] == true) {
        final transactionResponse = CreateTransactionLinkResponse.fromJson(
          responseJson,
        );
        final paymentLink = transactionResponse.paymentLink;
        if (paymentLink != null && mounted) {
          final shouldRefresh = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  QRPaymentScreen(paymentLink: paymentLink, amount: amountText),
            ),
          );

          if (shouldRefresh == true) {
            await userController.fetchAndUpdateUserDetails();
            _softPollBalance(times: 3); // optional
          }
        } else {
          _showSnackBar('Payment link not found in response.');
        }
      } else {
        _showSnackBar(
          responseJson['msg']?.toString() ??
              'Failed to create transaction link.',
        );
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF9800); // screenshot-like orange
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      extendBody: true,
      appBar: AppBar(
        title: const Text("Add Fund"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.grey.shade300,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Balance Card (reactive)
              _BalanceCard(orange: orange, userController: userController),
              const SizedBox(height: 8),

              Center(
                child: Text(
                  "Add Fund",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Amount pill
              _AmountPill(controller: amountController, orange: orange),

              const Spacer(),

              // Buttons
              _WideBtn(
                text: "ADD POINT - UPI",
                onPressed: _isProcessingPayment
                    ? null
                    : _validateAndPreparePayment,
                orange: orange,
              ),
              const SizedBox(height: 12),
              _WideBtn(
                text: "ADD POINT - QR - PAYTM - GATEWAY",
                onPressed: _isProcessingPayment ? null : _createTransactionLink,
                orange: orange,
              ),
              const SizedBox(height: 12),
              _WideBtn(
                text: "HOW TO ADD POINT",
                onPressed: _isProcessingPayment
                    ? null
                    : () => _showSnackBar(
                        "Please contact support to know how to add point.",
                      ),
                orange: orange,
              ),

              if (_isProcessingPayment) ...[
                const SizedBox(height: 20),
                const Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Small UI widgets ----------

class _BalanceCard extends StatelessWidget {
  final Color orange;
  final UserController userController;
  const _BalanceCard({required this.orange, required this.userController});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          const SizedBox(height: 35),
          Container(
            height: 50,
            width: double.infinity,
            decoration: const BoxDecoration(color: Colors.black),
            alignment: Alignment.center,
            child: Text(
              "SARA777",
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/ic_wallet.png',
                  height: 60,
                  color: Colors.orange,
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(
                      () => Text(
                        "₹ ${userController.walletBalance.value}",
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Current Balance",
                      style: GoogleFonts.poppins(fontSize: 15),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(-10, 0),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: orange,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountPill extends StatelessWidget {
  final TextEditingController controller;
  final Color orange;
  const _AmountPill({required this.controller, required this.orange});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "",
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: orange,
                child: const Icon(Icons.account_balance, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  cursorColor: Colors.orange,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter Amount',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WideBtn extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color orange;
  const _WideBtn({required this.text, this.onPressed, required this.orange});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 1,
          backgroundColor: orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
