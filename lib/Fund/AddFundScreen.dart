import 'dart:convert';
import 'dart:developer'; // For log
import 'dart:math' hide log; // Import for Random class

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // Import http package for API calls
import 'package:url_launcher/url_launcher.dart'; // Import for launching external URLs (UPI apps)

import '../Helper/TranslationHelper.dart'; // Assuming this path is correct for translation

// Main AddFundScreen Widget
class AddFundScreen extends StatefulWidget {
  const AddFundScreen({super.key});

  @override
  State<AddFundScreen> createState() => _AddFundScreenState();
}

class _AddFundScreenState extends State<AddFundScreen> {
  // TextEditingController for the amount input field
  final TextEditingController amountController = TextEditingController();

  // Wallet balance retrieved from GetStorage
  String walletBalance = GetStorage().read('walletBalance') ?? '0';

  // Currently selected deposit method (defaults to null, meaning none selected)
  String? selectedMethod; // Changed to nullable String

  // Current language code for translation
  String currentLangCode = GetStorage().read("language") ?? "en";

  // Cache for translations to avoid repeated API calls
  final Map<String, String> _translationCache = {};

  // Base URL for API calls
  static const String _apiBaseUrl = 'https://sara777.win/api/v1';

  // Random generator for unique paymentHash suffix
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadWalletBalance(); // Load wallet balance when the screen initializes
    amountController.addListener(() {
      setState(() {
        // This setState is empty but triggers a rebuild if any widgets depend on amountController.text
      });
    });
  }

  @override
  void dispose() {
    amountController
        .dispose(); // Dispose the controller to prevent memory leaks
    super.dispose();
  }

  // Fetches and updates the wallet balance from GetStorage
  void _loadWalletBalance() {
    final dynamic raw = GetStorage().read("walletBalance");
    setState(() {
      if (raw is int) {
        walletBalance = raw.toString();
      } else if (raw is String) {
        walletBalance = raw;
      } else {
        walletBalance = '0'; // Default to '0' if no balance is found
      }
    });
  }

  // Translates text using the TranslationHelper (with caching)
  Future<String> _t(String text) async {
    if (_translationCache.containsKey(text)) {
      return _translationCache[text]!;
    }
    String translated = await TranslationHelper.translate(
      text,
      currentLangCode,
    );
    _translationCache[text] = translated;
    return translated;
  }

  // Reusable InputDecoration for text fields
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

  // Widget to create amount suggestion buttons
  Widget _buildAmountButton(String amount) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              if (amount == "OTHER") {
                amountController.text = ""; // Clear the field for custom input
              } else {
                amountController.text =
                    amount; // Set the amount in the text field
              }
            });
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

  // Widget to build payment method selection options with radio buttons
  Widget _buildMethodOption(String method, String logoPath) {
    return GestureDetector(
      onTap: () async {
        // Set the selected method first
        setState(() {
          selectedMethod = method;
        });
        // Then immediately trigger the add fund request
        await _addFundRequest();
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
                const Icon(Icons.payment_outlined, size: 36), // Fallback icon
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
            groupValue: selectedMethod, // groupValue is now nullable
            onChanged: (value) async {
              if (value != null) {
                setState(() {
                  selectedMethod = value; // Update selected method
                });
                // Also trigger add fund request if radio button is directly changed
                await _addFundRequest();
              }
            },
            activeColor: Colors.amber,
          ),
        ),
      ),
    );
  }

  // Function to launch UPI app or display bank details based on deposit type
  Future<void> _launchPaymentIntent(
    String depositType,
    int amount,
    Map<String, dynamic> apiResponseData,
  ) async {
    log(
      'Attempting to launch payment intent for $depositType with amount $amount',
    );
    log(
      'API Response Data for Intent: $apiResponseData',
    ); // Log the data received from API

    Uri? uri;
    switch (depositType) {
      case "googlePay":
      case "phonePe":
      case "paytm":
        // Extract UPI details from API response
        final String? upiId = apiResponseData['upiId'];
        final String? merchantName = apiResponseData['merchantName'];
        final String? transactionRef = apiResponseData['transactionRef'];
        final String? transactionNote = apiResponseData['remark'];

        // Validate crucial UPI parameters from API response
        if (upiId == null || upiId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                await _t(
                  "Payment setup error: UPI ID missing from server response.",
                ),
              ),
            ),
          );
          log('UPI ID missing from API response.');
          return;
        }
        if (merchantName == null || merchantName.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                await _t(
                  "Payment setup error: Merchant Name missing from server response.",
                ),
              ),
            ),
          );
          log('Merchant Name missing from API response.');
          return;
        }
        if (transactionRef == null || transactionRef.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                await _t(
                  "Payment setup error: Transaction Reference missing from server response.",
                ),
              ),
            ),
          );
          log('Transaction Reference missing from API response.');
          return;
        }

        // Construct the UPI intent URI
        uri = Uri.parse(
          'upi://pay?pa=${Uri.encodeComponent(upiId)}'
          '&pn=${Uri.encodeComponent(merchantName)}'
          '&am=${amount.toStringAsFixed(2)}' // Amount formatted to 2 decimal places
          '&cu=INR'
          '&tr=${Uri.encodeComponent(transactionRef)}'
          '${transactionNote != null && transactionNote.isNotEmpty ? '&tn=${Uri.encodeComponent(transactionNote)}' : ''}',
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(await _t("Unsupported deposit method."))),
        );
        log('Unsupported deposit method: $depositType');
        return;
    }

    if (uri != null) {
      log('Attempting to launch URI: $uri');
      final bool canLaunch = await canLaunchUrl(uri);
      log('canLaunchUrl result: $canLaunch');

      if (canLaunch) {
        await launchUrl(uri); // Launch the UPI app
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              await _t(
                "Could not launch payment app. Please ensure a UPI app is installed and configured.",
              ),
            ),
          ),
        );
        log('Failed to launch $uri: No app found to handle this URI.');
      }
    }
  }

  // Function to handle the add fund request API call
  Future<void> _addFundRequest() async {
    final amountText = amountController.text.trim();
    final String? accessToken = GetStorage().read('accessToken');
    final String registerId = GetStorage().read('registerId') ?? '';
    final String deviceId = GetStorage().read('deviceId') ?? 'unknownDeviceId';
    final String deviceName =
        GetStorage().read('deviceName') ?? 'unknownDevice';

    // Input validation for amount
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("Please enter an amount."))),
      );
      return;
    }
    final int? amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            await _t("Please enter a valid amount (greater than 0)."),
          ),
        ),
      );
      return;
    }

    // Validate that a payment method is selected
    if (selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("Please select a deposit method."))),
      );
      return;
    }

    String depositType;
    switch (selectedMethod) {
      case DepositMethod.googlePay:
        depositType = "googlePay";
        break;
      case DepositMethod.phonePe:
        depositType = "phonePe";
        break;
      case DepositMethod.paytm:
        depositType = "paytm";
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(await _t("Invalid deposit method selected."))),
        );
        return;
    }

    final String hashKey = "chela";
    final String timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final String paymentHash =
        '${DateTime.now().millisecondsSinceEpoch}${_random.nextInt(10000).toString().padLeft(4, '0')}';
    final int remark = 42264;

    Map<String, dynamic> requestBody = {
      "registerId": registerId,
      "depositType": depositType,
      "amount": amount,
      "hashKey": hashKey,
      "timestamp": timestamp,
      "paymentHash": paymentHash,
      "remark": remark,
    };

    log("Add Fund Request Body: ${json.encode(requestBody)}");

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/add-upi-deposit-fund-request'),
        headers: {
          'deviceId': deviceId,
          'deviceName': deviceName,
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(requestBody),
      );

      log("Add Fund Response Status: ${response.statusCode}");
      log("Add Fund Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                await _t(
                  "Add fund request submitted. Redirecting to payment...",
                ),
              ),
            ),
          );
          _launchPaymentIntent(depositType, amount, responseBody['data'] ?? {});
          amountController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                responseBody['msg'] ?? await _t("Add fund request failed."),
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              await _t(
                "Server error: ${response.statusCode}. Please try again.",
              ),
            ),
          ),
        );
      }
    } catch (e) {
      log("Error during add fund request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("An unexpected error occurred: $e"))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade300,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
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
          Navigator.of(context).pop();
          return false;
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
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
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(0),
                            ),
                          ),
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
                                    builder: (context, snapshot) => Text(
                                      snapshot.data ?? "Current Balance",
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Image.asset(
                                'assets/images/mastercard.png',
                                height: 80,
                                width: 80,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.credit_card,
                                    color: Colors.grey,
                                    size: 80,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Add Fund Heading
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

                  // Amount Input Field
                  FutureBuilder<String>(
                    future: _t("Amount"),
                    builder: (context, snapshot) {
                      return TextField(
                        controller: amountController,
                        cursorColor: Colors.amber,
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration(
                          snapshot.data ?? "Amount",
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Amount Suggestion Buttons
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

                  // Payment Method Options
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Using a class for constants to avoid magic strings for deposit methods
class DepositMethod {
  static const String googlePay = "Google Pay";
  static const String phonePe = "PhonePe";
  static const String paytm = "Paytm";
}
