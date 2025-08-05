import 'dart:convert';
import 'dart:developer';
import 'dart:math' hide log;

import 'package:flutter/material.dart';
// Import the main manager and model classes
import 'package:flutter_pay_upi/flutter_pay_upi_manager.dart';
import 'package:flutter_pay_upi/model/upi_app_model.dart';
// UpiTransactionResponse is also needed, ensure it's imported correctly
import 'package:flutter_pay_upi/model/upi_response.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/Fund/QRPaymentScreen.dart';
import 'package:new_sara/ulits/Constents.dart';

import '../Helper/TranslationHelper.dart';

class CreateTransactionLinkResponse {
  final String msg;
  final bool status;
  final String? paymentLink; // payment_link can be null if status is false

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
  final amountController = TextEditingController();
  final Random _random = Random();
  final Map<String, String> _translationCache = {};

  late String accessToken = GetStorage().read('accessToken') ?? '';
  late String registerId = GetStorage().read('registerId') ?? '';
  late String walletBalance =
      GetStorage().read('walletBalance')?.toString() ?? '0';
  late String currentLangCode = GetStorage().read('language') ?? 'en';
  late String mobile = GetStorage().read('mobileNo') ?? '';

  final upiPay = FlutterPayUpiManager(); // Correct instantiation
  final String _apiBaseUrl = Constant.apiEndpoint;
  static const _hardcodedUpiPayeeVPA = "OMENTERPRISES.10018009@csbpay";
  static const _hardcodedUpiPayeeName = "Arvind Lodha";
  static const String _merchantCode = "";

  final GetStorage _storage = GetStorage();

  final String deviceId = GetStorage().read('deviceId') ?? '';
  final String deviceName = GetStorage().read('deviceName') ?? '';

  late final int _minAmount =
      int.tryParse(_storage.read('minDeposit')?.toString() ?? '1000') ?? 1000;

  bool _isProcessingPayment = false;
  int _currentTransactionAmount = 0;
  String _currentTransactionId = '';
  String _currentPaymentMethodType = '';

  // Initialize _apps as an empty list and populate it in _fetchUpiApps
  List<UpiApp> _apps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchAndSaveUserDetails(registerId);
    _loadWalletBalance();
    _fetchUpiApps(); // Call this to populate _apps
  }

  @override
  void dispose() {
    amountController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _fetchAndSaveUserDetails(String registerId) async {
    final url = Uri.parse('${Constant.apiEndpoint}user-details-by-register-id');
    final String currentAccessToken = _storage.read('accessToken') ?? '';
    log("Fetching user details for Register Id: $registerId");
    log("Using Access Token: $currentAccessToken");
    try {
      final response = await http.post(
        url,
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $currentAccessToken',
        },
        body: jsonEncode({"registerId": registerId}),
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final info = responseData['info'];
        log("User details received: $info");
        _storage.write('userId', info['userId']);
        _storage.write('fullName', info['fullName']);
        _storage.write('emailId', info['emailId']);
        _storage.write('mobileNo', info['mobileNo']);
        _storage.write('mobileNoEnc', info['mobileNoEnc']);
        _storage.write('walletBalance', info['walletBalance']);
        _storage.write('profilePicture', info['profilePicture']);
        _storage.write('accountStatus', info['accountStatus']);
        _storage.write('betStatus', info['betStatus']);
        log("✅ User details saved to GetStorage.");
      } else {
        log(
          "❌ Failed to fetch user details: ${response.statusCode} => ${response.body}",
        );
      }
    } catch (e) {
      log("❌ Exception fetching user details: $e");
    }
  }

  Future<String> _t(String text) async {
    if (_translationCache.containsKey(text)) return _translationCache[text]!;
    final t = await TranslationHelper.translate(text, currentLangCode);
    if (mounted) _translationCache[text] = t;
    return t;
  }

  void _loadWalletBalance() {
    final raw = GetStorage().read('walletBalance');
    if (mounted) setState(() => walletBalance = raw?.toString() ?? '0');
  }

  void _fetchUpiApps() async {
    try {
      // Correct way to get UPI apps with FlutterPayUpiManager
      final apps = await FlutterPayUpiManager.getListOfAndroidUpiApps();
      log(
        'Discovered UPI apps: ${apps.map((a) => a.name).toList()}',
      ); // Access appName directly
      if (mounted) setState(() => _apps = apps); // Populate _apps
    } catch (e) {
      log('Failed to load UPI apps: $e');
    }
  }

  Future<void> _validateAndPreparePayment() async {
    final text = amountController.text.trim();
    final amt = int.tryParse(text);
    if (amt == null || amt < _minAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            await _t("Please enter a valid amount (min ₹$_minAmount)."),
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
                    // Accessing the app name and launching the payment
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

  // Future<void> _launchUpiWithApp(UpiApp app) async {
  //   if (mounted) {
  //     setState(() {
  //       _isProcessingPayment = true;
  //       _currentPaymentMethodType = app.name.toString(); // Use app.appName here
  //     });
  //   }
  //
  //   try {
  //     FlutterPayUpiManager.startPayment(
  //       paymentApp: app.app!,
  //       // Use app.packageName here for the identifier
  //       payeeVpa: _hardcodedUpiPayeeVPA,
  //       payeeName: _hardcodedUpiPayeeName,
  //       transactionId: _currentTransactionId,
  //       payeeMerchantCode: _merchantCode,
  //       description: "Add funds",
  //       amount: amountController.text,
  //       response: (UpiResponse, String) {
  //         log(
  //           'UPI Response before: $UpiResponse.status: ${UpiResponse.status}',
  //         );
  //
  //         if (mounted) {
  //           setState(() {
  //             _isProcessingPayment = false;
  //             _currentPaymentMethodType = app.name!;
  //             log(
  //               'UPI Response after: $UpiResponse.status: ${UpiResponse.status}',
  //             );
  //             _reportPaymentStatusToBackend(UpiResponse);
  //           });
  //         }
  //       },
  //       error: (String) {
  //         log('UPI Response error: $String.status: $String');
  //
  //         if (mounted) {
  //           setState(() {
  //             _isProcessingPayment = false;
  //             _currentPaymentMethodType = '';
  //             _reportPaymentStatusToBackend(UpiResponse as UpiResponse);
  //           });
  //         }
  //       }, // amountController.text is already a String
  //     );
  //   } catch (e) {
  //     log('UPI Launch Error: $e');
  //     // Report failure to backend if an exception occurs
  //     if (mounted) {
  //       setState(() {
  //         _isProcessingPayment = false;
  //         _currentPaymentMethodType = '';
  //         _reportPaymentStatusToBackend(UpiResponse as UpiResponse);
  //       });
  //     }
  //   } finally {
  //     // Always reset processing state in finally block to ensure it happens regardless of success or error
  //     if (mounted) {
  //       setState(() {
  //         _isProcessingPayment = false;
  //         _currentPaymentMethodType = '';
  //       });
  //     }
  //   }
  // }

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

              // Check if the payment was a success before reporting to backend
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

    // --- STEP 1: Make the first API call to create the fund request ---
    final createFundRequestBody = {
      "registerId": registerId,
      "depositType": depositType,
      "amount": _currentTransactionAmount,
      "hashKey": paymentHashKey,
    };

    log('Creating fund request with body: $createFundRequestBody');

    try {
      final createFundRequestResponse = await http.post(
        Uri.parse('${_apiBaseUrl}deposit-create-upi-fund-request'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'deviceId': deviceId,
          'deviceName': deviceName,
          'accessStatus': '1',
        },
        body: json.encode(createFundRequestBody),
      );

      final createFundRequestResult = json.decode(
        createFundRequestResponse.body,
      );
      log('Create fund request response: $createFundRequestResult');

      // Check if the first API call was successful
      if (createFundRequestResult['status'] == true) {
        // --- STEP 2: Extract data from the first response ---
        final info = createFundRequestResult['info'];
        final String paymentHash = info['paymentHash'];
        final int remark = info['remark'];
        final int timestamp = info['timestamp'];

        // --- STEP 3: Make the second API call with the extracted data ---
        final addFundRequestBody = {
          "registerId": registerId,
          "depositType": depositType,
          "amount": _currentTransactionAmount,
          "hashKey": paymentHashKey,
          "timestamp": timestamp, // Keep as int
          "paymentHash": paymentHash,
          "remark": remark,
        };

        log('Adding UPI deposit with body: $addFundRequestBody');

        final addFundRequestResponse = await http.post(
          Uri.parse('${_apiBaseUrl}add-upi-deposit-fund-request'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'deviceId': deviceId,
            'deviceName': deviceName,
            'accessStatus': '1',
          },
          body: json.encode(addFundRequestBody),
        );

        final addFundRequestResult = json.decode(addFundRequestResponse.body);
        log('Add fund request response: $addFundRequestResult');

        // Now, you can handle the final result from the second API call
        if (addFundRequestResult['status'] == true) {
          // Final success logic
          if (mounted) {
            setState(() {
              _isProcessingPayment = false;
              _currentPaymentMethodType = '';
            });
          }
          _loadWalletBalance();
          amountController.clear();
          // Show success dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                addFundRequestResult['msg'] ??
                    (await _t('Deposit successful and updated')),
              ),
            ),
          );
        } else {
          // Handle failure of the second API call
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
        // Handle failure of the first API call
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

  // Refactored and corrected method for the QR payment gateway
  Future<void> _createTransactionLink() async {
    // Validate input before making the API call
    final amountText = amountController.text.trim();
    final parsedAmount = int.tryParse(amountText);
    final parsedMobile = int.tryParse(mobile);

    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid amount.")),
      );
      return;
    }

    if (parsedMobile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid mobile number found.")),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isProcessingPayment = true;
      });
    }

    try {
      final String apiUrl = '${Constant.apiEndpoint}create-transaction-link';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'deviceId': deviceId,
          'deviceName': deviceName,
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(<String, dynamic>{
          'registerId': registerId,
          'amount': parsedAmount,
          'mobile': parsedMobile,
        }),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == true) {
        log('API Response (Success): ${response.body}');
        // If the API call is successful, extract the payment link
        final transactionResponse = CreateTransactionLinkResponse.fromJson(
          responseData,
        );
        final paymentLink = transactionResponse.paymentLink;

        if (paymentLink != null) {
          // Navigate to the QR Payment Screen
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
        // Throw an exception for any API-level errors
        throw Exception(
          responseData['msg'] ?? 'Failed to create transaction link.',
        );
      }
    } catch (e) {
      log('Error creating transaction link: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
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
          // Wrap the Padding with SingleChildScrollView
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
                                  Text(
                                    "\u20b9 $walletBalance",
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
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
                      // TODO: Implement action for "SARA777" button
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
