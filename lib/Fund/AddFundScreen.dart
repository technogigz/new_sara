import 'dart:convert';
import 'dart:developer';
import 'dart:math' hide log;

import 'package:flutter/material.dart';
import 'package:flutter_pay_upi/flutter_pay_upi_manager.dart';
import 'package:flutter_pay_upi/model/upi_app_model.dart';
import 'package:flutter_pay_upi/model/upi_response.dart';
import 'package:get/get.dart'; // Import Get package
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/Fund/QRPaymentScreen.dart';
import 'package:new_sara/ulits/Constents.dart';

import '../Helper/TranslationHelper.dart';
// Import the UserController
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
      msg: json['msg'],
      status: json['status'],
      paymentLink: json['payment_link'],
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
  // Use Get.find to get the UserController instance
  final UserController userController = Get.find<UserController>();

  final amountController = TextEditingController();
  final Random _random = Random();
  final Map<String, String> _translationCache = {};

  // Get current language from GetStorage, or set a default
  late String currentLangCode = GetStorage().read('language') ?? 'en';

  late String minDepositAmount = userController.minDeposit.value;

  final upiPay = FlutterPayUpiManager();
  final String _apiBaseUrl = Constant.apiEndpoint;
  static const _hardcodedUpiPayeeVPA = "OMENTERPRISES.10018009@csbpay";
  static const _hardcodedUpiPayeeName = "Arvind Lodha";
  static const String _merchantCode = "";

  bool _isProcessingPayment = false;
  int _currentTransactionAmount = 0;
  String _currentTransactionId = '';
  String _currentPaymentMethodType = '';

  List<UpiApp> _apps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Call the controller method to load and fetch data
    // No need for _fetchAndSaveUserDetails(), controller handles it
    userController.fetchAndUpdateUserDetails();
    userController.fetchAndUpdateFeeSettings();

    log("Minimum amount: ${userController.minDeposit.value}");

    _fetchUpiApps();
  }

  @override
  void dispose() {
    amountController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<String> _t(String text) async {
    if (_translationCache.containsKey(text)) return _translationCache[text]!;
    final t = await TranslationHelper.translate(text, currentLangCode);
    if (mounted) _translationCache[text] = t;
    return t;
  }

  void _fetchUpiApps() async {
    try {
      final apps = await FlutterPayUpiManager.getListOfAndroidUpiApps();
      log('Discovered UPI apps: ${apps.map((a) => a.name).toList()}');
      if (mounted) setState(() => _apps = apps);
    } catch (e) {
      log('Failed to load UPI apps: $e');
    }
  }

  Future<void> _validateAndPreparePayment() async {
    final text = amountController.text.trim();
    final amt = int.tryParse(text);
    final minAmountDouble = double.tryParse(minDepositAmount);
    final minAmountInt = minAmountDouble?.toInt();

    log("Minimum UPI amount: ${minDepositAmount}");
    if (amt == null || minAmountInt == null || amt < minAmountInt) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            await _t(
              "Please enter a valid amount (min ₹${userController.minDeposit.value}).",
            ),
          ),
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
      await Future.delayed(Duration.zero);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            await _t("No UPI apps found. Please install a UPI app to proceed."),
          ),
        ),
      );
      return setState(() => _isProcessingPayment = false);
    }

    _showUpiAppSelectionSheet();
  }

  void _showUpiAppSelectionSheet() {
    showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      backgroundColor: Colors.grey.shade300,
      isScrollControlled: true,
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16),
                  Text(
                    'Select UPI App',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.black, indent: 16, endIndent: 16),
            GridView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _apps.length,
              shrinkWrap: true,
              controller: ScrollController(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (_, i) {
                final app = _apps[i];
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _currentPaymentMethodType = app.name!;
                    _launchUpiWithApp(_apps[i]);
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
                      const SizedBox(height: 4),
                      Text(app.name!, textAlign: TextAlign.center),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      if (_isProcessingPayment && _currentPaymentMethodType.isEmpty) {
        if (mounted) {
          setState(() => _isProcessingPayment = false);
        }
      }
    });
  }

  Future<void> _launchUpiWithApp(UpiApp app) async {
    if (mounted) {
      setState(() {
        _isProcessingPayment = true;
        _currentPaymentMethodType = app.name.toString();
      });
    }

    try {
      FlutterPayUpiManager.startPayment(
        paymentApp: app.app!,
        payeeVpa: _hardcodedUpiPayeeVPA,
        payeeName: _hardcodedUpiPayeeName,
        transactionId: _currentTransactionId,
        payeeMerchantCode: _merchantCode,
        description: "Add funds",
        amount: amountController.text,
        response: (UpiResponse upiResponse, String response) {
          log('UPI Response received: ${upiResponse.status}');

          if (mounted) {
            setState(() {
              _isProcessingPayment = false;
              _currentPaymentMethodType = app.name!;

              if (upiResponse.status == 'success') {
                _reportPaymentStatusToBackend(upiResponse);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payment failed or cancelled.')),
                );
              }
            });
          }
        },
        error: (String errorMessage) {
          log('UPI Payment Error: $errorMessage');
          if (mounted) {
            setState(() {
              _isProcessingPayment = false;
              _currentPaymentMethodType = '';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'An error occurred during UPI payment: $errorMessage',
                ),
              ),
            );
          }
        },
      );
    } catch (e) {
      log('UPI Launch Error: $e');
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _currentPaymentMethodType = '';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to launch UPI app.')));
      }
    }
  }

  Future<void> _reportPaymentStatusToBackend(UpiResponse upiResponse) async {
    final paymentHashKey =
        upiResponse.transactionReferenceId ??
        upiResponse.transactionID ??
        'default_hash_key';

    String depositType = '';
    if (_currentPaymentMethodType == 'GPay') {
      depositType = 'googlePay';
    } else if (_currentPaymentMethodType == 'PhonePe') {
      depositType = 'phonePe';
    } else if (_currentPaymentMethodType == 'paytm') {
      depositType = 'paytm';
    } else {
      depositType = 'bank';
    }

    final createFundRequestBody = {
      "registerId": userController.registerId.value, // Use controller
      "depositType": depositType,
      "amount": _currentTransactionAmount,
      "hashKey": paymentHashKey,
    };

    log('Creating fund request with body: $createFundRequestBody');

    try {
      final createFundRequestResponse = await http.post(
        Uri.parse('${_apiBaseUrl}deposit-create-upi-fund-request'),
        headers: {
          'Authorization':
              'Bearer ${userController.accessToken.value}', // Use controller
          'Content-Type': 'application/json',
          'deviceId': GetStorage().read('deviceId'), // Use controller
          'deviceName': GetStorage().read('deviceName'), // Use controller
          'accessStatus': '1',
        },
        body: json.encode(createFundRequestBody),
      );

      final createFundRequestResult = json.decode(
        createFundRequestResponse.body,
      );
      log('Create fund request response: $createFundRequestResult');

      if (createFundRequestResult['status'] == true) {
        final info = createFundRequestResult['info'];
        final String paymentHash = info['paymentHash'];
        final int remark = info['remark'];
        final int timestamp = info['timestamp'];

        final addFundRequestBody = {
          "registerId": userController.registerId.value, // Use controller
          "depositType": depositType,
          "amount": _currentTransactionAmount,
          "hashKey": paymentHashKey,
          "timestamp": timestamp,
          "paymentHash": paymentHash,
          "remark": remark,
        };

        log('Adding UPI deposit with body: $addFundRequestBody');

        final addFundRequestResponse = await http.post(
          Uri.parse('${_apiBaseUrl}add-upi-deposit-fund-request'),
          headers: {
            'Authorization':
                'Bearer ${userController.accessToken.value}', // Use controller
            'Content-Type': 'application/json',
            'deviceId': GetStorage().read('deviceId'), // Use controller
            'deviceName': GetStorage().read('deviceName'), // Use controller
            'accessStatus': '1',
          },
          body: json.encode(addFundRequestBody),
        );

        final addFundRequestResult = json.decode(addFundRequestResponse.body);
        log('Add fund request response: $addFundRequestResult');

        if (addFundRequestResult['status'] == true) {
          if (mounted) {
            setState(() {
              _isProcessingPayment = false;
              _currentPaymentMethodType = '';
            });
          }
          // Call the controller method to fetch the new balance
          userController.fetchAndUpdateUserDetails();
          amountController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                addFundRequestResult['msg'] ??
                    (await _t('Deposit successful and updated')),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                addFundRequestResult['msg'] ??
                    (await _t('Failed to add deposit fund')),
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              createFundRequestResult['msg'] ??
                  (await _t('Failed to create fund request')),
            ),
          ),
        );
      }
    } catch (e) {
      log('API call failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            await _t("Failed to complete payment process: ${e.toString()}"),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _currentPaymentMethodType = '';
        });
      }
    }
  }

  Future<void> _createTransactionLink() async {
    final amountText = amountController.text.trim();
    final parsedAmount = int.tryParse(amountText);
    final parsedMobile = int.tryParse(userController.mobileNo.value);

    final minAmountDouble = double.tryParse(userController.minDeposit.value);
    final minAmountInt = minAmountDouble?.toInt();

    // --- Validation Checks ---
    if (parsedAmount == null) {
      _showSnackBar("Please enter a valid amount.");
      return;
    }

    if (minAmountInt == null) {
      _showSnackBar("Minimum deposit amount is not configured.");
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
    // --- End Validation Checks ---

    if (!mounted) return;

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final String apiUrl = '${Constant.apiEndpoint}create-transaction-link';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'deviceId': GetStorage().read('deviceId') ?? '',
          'deviceName': GetStorage().read('deviceName') ?? '',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${userController.accessToken.value}',
        },
        body: jsonEncode(<String, dynamic>{
          'registerId': userController.registerId.value,
          'amount': parsedAmount,
          'mobile': parsedMobile,
        }),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == true) {
        log('API Response (Success): ${response.body}');
        final transactionResponse = CreateTransactionLinkResponse.fromJson(
          responseData,
        );
        final paymentLink = transactionResponse.paymentLink;

        if (paymentLink != null) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QRPaymentScreen(
                  paymentLink: paymentLink,
                  amount: amountText,
                ),
              ),
            );
          }
        } else {
          throw Exception('Payment link not found in response.');
        }
      } else {
        log('API Response (Error): ${response.body}');
        throw Exception(
          responseData['msg'] ?? 'Failed to create transaction link.',
        );
      }
    } catch (e) {
      log('Error creating transaction link: $e');
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  // Show SnackBar
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade300,
        leading: IconButton(
          onPressed: () {
            if (!_isProcessingPayment) Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: FutureBuilder<String>(
          future: _t("Add Funds"),
          builder: (_, s) => Text(s.data ?? "Add Funds"),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 100),
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          color: Colors.black,
                          child: SizedBox(
                            height: 35,
                            child: Center(
                              child: Text(
                                "Sara777",
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Image.asset(
                                "assets/images/ic_wallet.png",
                                height: 60,
                                width: 60,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Use Obx to listen for changes to the wallet balance
                                  Obx(
                                    () => Text(
                                      "\u20b9 ${userController.walletBalance.value}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                  FutureBuilder<String>(
                                    future: _t("Current Balance"),
                                    builder: (_, s) =>
                                        Text(s.data ?? "Current Balance"),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Image.asset(
                                "assets/images/mastercard.png",
                                height: 60,
                                width: 60,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  cursorColor: Colors.orange,
                  decoration: InputDecoration(
                    hintText: "Amount",
                    prefixIcon: Card(
                      color: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset(
                          "assets/images/fund.png",
                          height: 24,
                          width: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: const BorderSide(
                        color: Colors.orange,
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 200),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isProcessingPayment
                        ? null
                        : _validateAndPreparePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isProcessingPayment
                        ? const CircularProgressIndicator(color: Colors.white)
                        : FutureBuilder<String>(
                            future: _t("ADD POINT - UPI"),
                            builder: (_, s) => Text(
                              s.data ?? "ADD POINT - UPI",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _createTransactionLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: FutureBuilder<String>(
                      future: _t("ADD POINT - QR - PAYTM - GATEWAY"),
                      builder: (_, s) => Text(
                        s.data ?? "ADD POINT - QR - PAYTM - GATEWAY",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      print('SARA777 button pressed!');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: FutureBuilder<String>(
                      future: _t("HOW TO ADD POINT"),
                      builder: (_, s) => Text(
                        s.data ?? "HOW TO ADD POINT",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
