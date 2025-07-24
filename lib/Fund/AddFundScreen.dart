import 'dart:convert';
import 'dart:developer'; // For log
import 'dart:math' hide log; // Import for Random class

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // Import http package for API calls
import 'package:new_sara/main.dart'; // Assuming 'storage' comes from here
import 'package:new_sara/ulits/Constents.dart'; // New import for constants
import 'package:url_launcher/url_launcher.dart';

import '../Helper/TranslationHelper.dart';

// Main AddFundScreen Widget
class AddFundScreen extends StatefulWidget {
  const AddFundScreen({super.key});

  @override
  State<AddFundScreen> createState() => _AddFundScreenState();
}

class _AddFundScreenState extends State<AddFundScreen>
    with WidgetsBindingObserver {
  // TextEditingController for the amount input field
  final TextEditingController amountController = TextEditingController();

  // --- GetStorage Initialized Variables ---
  late String accessToken = GetStorage().read('accessToken') ?? '';
  late String registerId = GetStorage().read('registerId') ?? '';
  final String deviceId = GetStorage().read('deviceId') ?? 'unknownDeviceId';
  final String deviceName = GetStorage().read('deviceName') ?? 'unknownDevice';
  late String walletBalance =
      GetStorage().read('walletBalance')?.toString() ?? '0';
  String currentLangCode = GetStorage().read("language") ?? "en";

  // --- General State Variables ---
  String? selectedMethod; // Currently selected deposit method
  final Map<String, String> _translationCache = {}; // Cache for translations
  final String _apiBaseUrl = Constant.apiEndpoint; // Base URL for API calls
  final Random _random =
      Random(); // Random generator for unique paymentHash suffix

  // --- Payment Configuration State ---
  String _minAmount = "300"; // Default minimum amount
  // _isLoadingConfig is removed
  bool _isProcessingPayment = false; // To prevent multiple payment attempts

  // --- Current Transaction Details ---
  String _currentTransactionId = '';
  int _currentTransactionAmount = 0;
  String _currentPaymentMethodType =
      ''; // e.g., "Google Pay", "PhonePe", "Paytm"

  // --- Hardcoded UPI Details ---
  static const String _hardcodedUpiPayeeAddress =
      "OMENTERPRISES.10018009@csbpay";
  static const String _hardcodedUpiPayeeName = "Arvind Lodha";

  // Note: UPI App Package Names are not directly used in the simplified _launchPaymentIntent
  // static const String _googlePayPackage = "com.google.android.apps.nbu.paisa.user";
  // static const String _phonePePackage = "com.phonepe.app";
  // static const String _paytmPackage = "net.one97.paytm";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWalletBalance();
    // You can still fetch minAmount silently if needed, e.g., _fetchMinAmountSilently();
    // For now, it will use the default _minAmount = "300"

    storage.listenKey('language', (value) {
      if (mounted) {
        setState(() {
          currentLangCode = value ?? "en";
          _translationCache.clear(); // Clear cache when language changes
        });
      }
    });

    storage.listenKey('walletBalance', (value) {
      if (mounted) {
        setState(() {
          walletBalance = value?.toString() ?? "0";
        });
      }
    });

    storage.listenKey('registerId', (value) {
      if (mounted) {
        setState(() {
          registerId = value ?? "";
        });
      }
    });

    storage.listenKey('accessToken', (value) {
      if (mounted) {
        setState(() {
          accessToken = value ?? "";
        });
      }
    });
  }

  // Example: If you still need to fetch minAmount without a loading spinner
  // Future<void> _fetchMinAmountSilently() async {
  //   // ... (your API call logic to get min_amt)
  //   // if (successful and mounted) {
  //   //   setState(() {
  //   //     _minAmount = newMinAmount;
  //   //   });
  //   // }
  // }

  @override
  void dispose() {
    amountController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isProcessingPayment) {
      _showPaymentConfirmationDialog();
    }
  }

  void _loadWalletBalance() {
    final dynamic raw = GetStorage().read("walletBalance");
    if (mounted) {
      setState(() {
        if (raw is int) {
          walletBalance = raw.toString();
        } else if (raw is String) {
          walletBalance = raw;
        } else {
          walletBalance = '0';
        }
      });
    }
  }

  Future<String> _t(String text) async {
    if (_translationCache.containsKey(text)) {
      return _translationCache[text]!;
    }
    String translated = await TranslationHelper.translate(
      text,
      currentLangCode,
    );
    if (mounted) {
      _translationCache[text] = translated;
    }
    return translated;
  }

  InputDecoration _buildInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.amber, width: 2),
      ),
    );
  }

  Widget _buildAmountButton(String amount) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: () {
            if (mounted) {
              setState(() {
                if (amount == "OTHER") {
                  amountController.text = "";
                } else {
                  amountController.text = amount;
                }
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.grey),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(amount),
        ),
      ),
    );
  }

  Widget _buildMethodOption(String method, String logoPath) {
    return GestureDetector(
      onTap: () {
        if (mounted) {
          setState(() {
            selectedMethod = method;
          });
        }
      },
      child: Card(
        color: Colors.grey.shade200,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Image.asset(
            logoPath,
            width: 36,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.payment_outlined, size: 36),
          ),
          title: FutureBuilder<String>(
            future: _t(method),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? method,
                style: const TextStyle(fontWeight: FontWeight.bold),
              );
            },
          ),
          subtitle: FutureBuilder<String>(
            future: _t("Manual approve by Admin"),
            builder: (context, snapshot) =>
                Text(snapshot.data ?? "Manual approve by Admin"),
          ),
          trailing: Radio<String>(
            value: method,
            groupValue: selectedMethod,
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  selectedMethod = value;
                });
              }
            },
            activeColor: Colors.amber,
          ),
        ),
      ),
    );
  }

  Future<void> _launchPaymentIntent(
    String depositType,
    int amount,
    String transactionId,
  ) async {
    log(
      'Attempting to launch UPI payment for $depositType with amount $amount, TXN ID: $transactionId',
    );

    final amountDouble = amount.toDouble();
    final baseParams =
        'pa=${Uri.encodeComponent(_hardcodedUpiPayeeAddress)}'
        '&pn=${Uri.encodeComponent(_hardcodedUpiPayeeName)}'
        '&am=${amountDouble.toStringAsFixed(2)}'
        '&cu=INR'
        '&tr=${Uri.encodeComponent(transactionId)}'
        '&tn=${Uri.encodeComponent("Add Fund to Wallet")}';

    final Uri upiUri = Uri.parse('upi://pay?$baseParams');
    log('Attempting to launch URI: $upiUri');

    try {
      final bool launched = await launchUrl(
        upiUri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        log('Successfully initiated UPI payment launch for $depositType.');
      } else {
        log(
          'Failed to launch UPI intent for $depositType. No app might be available or launch was denied.',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                await _t(
                  "Could not launch any UPI app. Please ensure one is installed or try again.",
                ),
              ),
            ),
          );
          setState(() => _isProcessingPayment = false);
        }
      }
    } catch (e) {
      log('Error launching UPI app for $depositType: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              await _t("An error occurred while launching UPI app: $e"),
            ),
          ),
        );
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  Future<void> _onVerifyButtonPressed() async {
    if (_isProcessingPayment) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              await _t("Payment already in progress. Please wait."),
            ),
          ),
        );
      }
      return;
    }

    final amountText = amountController.text.trim();

    if (amountText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(await _t("Please enter an amount."))),
        );
      }
      return;
    }
    if (amountText.contains(".") ||
        amountText.contains(",") ||
        amountText.contains("-")) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              await _t("Please enter a valid amount (whole number)."),
            ),
          ),
        );
      return;
    }
    final int? amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              await _t("Please enter a valid amount (greater than 0)."),
            ),
          ),
        );
      return;
    }
    if (amount < int.parse(_minAmount)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(await _t("Minimum amount is: $_minAmount"))),
        );
      return;
    }
    if (selectedMethod == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(await _t("Please select a deposit method."))),
        );
      return;
    }

    if (mounted) {
      setState(() {
        _isProcessingPayment = true;
      });
    }

    _currentTransactionId =
        '${DateTime.now().millisecondsSinceEpoch}${_random.nextInt(10000).toString().padLeft(4, '0')}';
    _currentTransactionAmount = amount;
    _currentPaymentMethodType = selectedMethod!;

    await _launchPaymentIntent(
      _currentPaymentMethodType,
      _currentTransactionAmount,
      _currentTransactionId,
    );
  }

  Future<void> _showPaymentConfirmationDialog() async {
    if (!_isProcessingPayment || !mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: FutureBuilder<String>(
            future: _t('Payment Confirmation'),
            builder: (context, snapshot) =>
                Text(snapshot.data ?? 'Payment Confirmation'),
          ),
          content: FutureBuilder<String>(
            future: _t(
              'Did your payment of ₹$_currentTransactionAmount for TXN ID: $_currentTransactionId complete successfully?',
            ),
            builder: (context, snapshot) => Text(
              snapshot.data ??
                  'Did your payment of ₹$_currentTransactionAmount for TXN ID: $_currentTransactionId complete successfully?',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: FutureBuilder<String>(
                future: _t('No, Failed'),
                builder: (context, snapshot) =>
                    Text(snapshot.data ?? 'No, Failed'),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _reportPaymentStatusToBackend(
                  _currentTransactionId,
                  _currentTransactionAmount,
                  _currentPaymentMethodType,
                  "FAILED",
                );
              },
            ),
            TextButton(
              child: FutureBuilder<String>(
                future: _t('Yes, Success'),
                builder: (context, snapshot) =>
                    Text(snapshot.data ?? 'Yes, Success'),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _reportPaymentStatusToBackend(
                  _currentTransactionId,
                  _currentTransactionAmount,
                  _currentPaymentMethodType,
                  "SUCCESS",
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _reportPaymentStatusToBackend(
    String transactionId,
    int amount,
    String paymentMethodType,
    String status,
  ) async {
    // Re-fetch from GetStorage in case they changed in background, though less likely for these.
    final String currentAccessToken = GetStorage().read('accessToken') ?? '';
    final String currentRegisterId = GetStorage().read('registerId') ?? '';
    final String currentDeviceId =
        GetStorage().read('deviceId') ?? 'unknownDeviceId';
    final String currentDeviceName =
        GetStorage().read('deviceName') ?? 'unknownDevice';

    Map<String, dynamic> requestBody = {
      "registerId": currentRegisterId,
      "depositType": paymentMethodType,
      "amount": amount,
      "hashKey": "chela",
      "timestamp": (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      "paymentHash": transactionId,
      "remark": 42264,
      "txn_id": transactionId,
      "txn_ref": transactionId,
      "upigpay": paymentMethodType == DepositMethod.googlePay ? "1" : "0",
      "upiphonepe": paymentMethodType == DepositMethod.phonePe ? "1" : "0",
      "otherupi": paymentMethodType == DepositMethod.paytm ? "1" : "0",
      "Status": status.toUpperCase(),
    };

    log("Report Payment Status Request Body: ${json.encode(requestBody)}");

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/add-upi-deposit-fund-request'),
        headers: {
          'deviceId': currentDeviceId,
          'deviceName': currentDeviceName,
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $currentAccessToken',
        },
        body: json.encode(requestBody),
      );

      log("Report Payment Status Response Status: ${response.statusCode}");
      log("Report Payment Status Response Body: ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseBody['msg'] ??
                  await _t(
                    responseBody['status'] == true
                        ? "Payment status reported."
                        : "Failed to report payment status.",
                  ),
            ),
          ),
        );
        if (responseBody['status'] == true) {
          _loadWalletBalance(); // Refresh wallet balance
          amountController.clear();
          setState(() {
            // Also reset selected method for a fresh state
            selectedMethod = null;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              await _t(
                "Server error reporting status: ${response.statusCode}. Please contact support.",
              ),
            ),
          ),
        );
      }
    } catch (e) {
      log("Error reporting payment status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              await _t(
                "An unexpected error occurred while reporting status: $e",
              ),
            ),
          ),
        );
      }
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
    // Determine if the button should be enabled
    bool isButtonEnabled =
        !_isProcessingPayment &&
        amountController.text.isNotEmpty &&
        selectedMethod != null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade300,
        leading: IconButton(
          onPressed: () {
            if (!_isProcessingPayment) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: FutureBuilder<String>(
          future: _t("Add Funds"),
          builder: (context, snapshot) => Text(snapshot.data ?? "Add Funds"),
        ),
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (_isProcessingPayment) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    await _t(
                      "Processing payment, please wait or confirm status.",
                    ),
                  ),
                ),
              );
            }
            return false;
          }
          Navigator.of(context).pop();
          return false;
        },
        child: SafeArea(
          child: SingleChildScrollView(
            // Removed the ternary for _isLoadingConfig
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Balance Card
                Card(
                  elevation: 4,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Colors.black),
                        child: const Center(
                          child: Text(
                            "SARA777",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Image.asset(
                              "assets/images/ic_wallet.png",
                              color: Colors.amber,
                              height: 80,
                              width: 80,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.amber,
                                  size: 80,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "₹ $walletBalance",
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                                FutureBuilder<String>(
                                  future: _t("Current Balance"),
                                  builder: (context, snapshot) =>
                                      Text(snapshot.data ?? "Current Balance"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: FutureBuilder<String>(
                    future: _t("Add Fund"),
                    builder: (context, snapshot) => Text(
                      snapshot.data ?? "Add Fund",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<String>(
                  future: _t("Amount"),
                  builder: (context, snapshot) {
                    return TextField(
                      controller: amountController,
                      cursorColor: Colors.amber,
                      keyboardType: TextInputType.number,
                      decoration:
                          _buildInputDecoration(
                            snapshot.data ?? "Amount",
                          ).copyWith(
                            prefixIcon: const Icon(
                              Icons.currency_rupee,
                              color: Colors.blueGrey,
                              size: 20,
                            ),
                          ),
                      onChanged: (_) =>
                          setState(() {}), // Trigger rebuild for button state
                    );
                  },
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    Row(
                      children: [
                        _buildAmountButton("100"),
                        _buildAmountButton("500"),
                        _buildAmountButton("1000"),
                        _buildAmountButton("2000"),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildAmountButton("5000"),
                        _buildAmountButton("10000"),
                        _buildAmountButton("20000"),
                        _buildAmountButton("OTHER"),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildMethodOption(
                  DepositMethod.googlePay,
                  "assets/images/gpay_deposit.png",
                ),
                _buildMethodOption(
                  DepositMethod.phonePe,
                  "assets/images/phonepe_deposit.png",
                ),
                _buildMethodOption(
                  DepositMethod.paytm,
                  "assets/images/paytm_deposit.png",
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isButtonEnabled
                        ? _onVerifyButtonPressed
                        : null, // Use the calculated boolean
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                    child: _isProcessingPayment
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : FutureBuilder<String>(
                            future: _t("Add Fund"),
                            builder: (context, snapshot) => Text(
                              snapshot.data ?? "Add Fund",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
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

class DepositMethod {
  static const String googlePay = "Google Pay";
  static const String phonePe = "PhonePe";
  static const String paytm = "Paytm";
}
