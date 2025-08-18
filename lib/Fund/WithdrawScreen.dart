import 'dart:convert';
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // Import http package
import 'package:new_sara/ulits/Constents.dart';

import '../Helper/TranslationHelper.dart';
import '../Helper/UserController.dart'; // Assuming this path is correct

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

// Using a class for constants to avoid magic strings
class WithdrawalMethod {
  static const String googlePay = "Google Pay";
  static const String phonePe = "PhonePe";
  static const String paytm = "Paytm";
  static const String bankAccount = "Bank Account";
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  // --- State ---
  int currentBalance = 0; // fixed: no 'late' needed, default 0

  final TextEditingController amountController = TextEditingController();
  final TextEditingController paymentNumberController =
      TextEditingController(); // Used for UPI ID/Phone number
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController holderNameController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController ifscCodeController = TextEditingController();

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  String selectedMethod = WithdrawalMethod.googlePay; // Default selected method
  String currentLangCode = GetStorage().read("language")?.toString() ?? "en";
  late final int minimumWithdrawalAmount; // computed in initState
  final Map<String, String> _translationCache = {};

  // Constants for withdrawal methods
  final String _apiBaseUrl = Constant.apiEndpoint;

  @override
  void initState() {
    super.initState();
    minimumWithdrawalAmount = _readMinWithdrawalFromStorage();
    _loadCurrentBalance(); // safe, no setState needed in init
  }

  @override
  void dispose() {
    amountController.dispose();
    paymentNumberController.dispose();
    bankNameController.dispose();
    holderNameController.dispose();
    accountNumberController.dispose();
    ifscCodeController.dispose();
    super.dispose();
  }

  // ---- Helpers ----

  int _readMinWithdrawalFromStorage() {
    final v = GetStorage().read("minimumWithdrawalAmount");
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null) return parsed;
      final asDouble = double.tryParse(v);
      if (asDouble != null) return asDouble.toInt();
    }
    return 1000; // default fallback
  }

  void _loadCurrentBalance({bool refreshUI = false}) {
    // This is robust to String/num from GetX Rx or any source.
    final raw = userController.walletBalance.value;
    double asDouble;

    if (raw is num) {
      asDouble = raw as double;
    } else if (raw is String) {
      asDouble = double.tryParse(raw) ?? 0.0;
    } else {
      asDouble = 0.0;
    }

    final next = asDouble.floor(); // or .round() if you prefer

    if (refreshUI && mounted) {
      setState(() => currentBalance = next);
    } else {
      currentBalance = next;
    }
  }

  // Function to translate text
  Future<String> _t(String text) async {
    if (_translationCache.containsKey(text)) {
      return _translationCache[text]!;
    }
    final translated = await TranslationHelper.translate(text, currentLangCode);
    _translationCache[text] = translated;
    return translated;
  }

  // Reusable InputDecoration
  InputDecoration _buildInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  // Widget to build method selection options (Google Pay, PhonePe, Paytm, Bank Account)
  Widget _buildMethodOption(String method, String logoPath) {
    return Card(
      color: Colors.grey.shade200,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: RadioListTile<String>(
        value: method,
        groupValue: selectedMethod,
        onChanged: (value) {
          if (value != null) {
            setState(() {
              selectedMethod = value;
              // Clear previous inputs when method changes
              if (value != WithdrawalMethod.bankAccount) {
                bankNameController.clear();
                holderNameController.clear();
                accountNumberController.clear();
                ifscCodeController.clear();
              } else {
                paymentNumberController.clear();
              }
            });
          }
        },
        secondary: Image.asset(
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
        activeColor: Colors.red,
      ),
    );
  }

  // Generic text field builder for all inputs
  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return FutureBuilder<String>(
      future: _t(hint),
      builder: (context, snapshot) {
        return TextField(
          controller: controller,
          cursorColor: Colors.red,
          keyboardType: keyboardType,
          decoration: _buildInputDecoration(snapshot.data ?? hint),
        );
      },
    );
  }

  // Widget to build bank-specific input fields
  Widget _buildBankFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTextField(bankNameController, "Bank Name"),
        const SizedBox(height: 12),
        _buildTextField(holderNameController, "Account Holder Name"),
        const SizedBox(height: 12),
        _buildTextField(
          accountNumberController,
          "Account Number",
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(ifscCodeController, "IFSC Code"),
      ],
    );
  }

  // Widget to dynamically show fields based on selected method
  Widget _buildDynamicFields() {
    String selectedMethodHint;
    switch (selectedMethod) {
      case WithdrawalMethod.googlePay:
        selectedMethodHint = "Enter Google Pay UPI ID";
        break;
      case WithdrawalMethod.phonePe:
        selectedMethodHint = "Enter PhonePe UPI ID";
        break;
      case WithdrawalMethod.paytm:
        selectedMethodHint = "Enter Paytm Number";
        break;
      default:
        selectedMethodHint = "Enter UPI ID/Number"; // Fallback
    }

    return Column(
      children: [
        _buildTextField(
          amountController,
          "Enter Amount",
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        if (selectedMethod != WithdrawalMethod.bankAccount)
          _buildTextField(
            paymentNumberController,
            selectedMethodHint,
            keyboardType: selectedMethod == WithdrawalMethod.paytm
                ? TextInputType.phone
                : TextInputType.text, // Paytm usually phone, others UPI ID
          )
        else
          _buildBankFields(),
      ],
    );
  }

  // Function to handle the withdrawal request API call
  Future<void> _performWithdrawal() async {
    final amountText = amountController.text.trim();
    final paymentDetail = paymentNumberController.text.trim();
    final String? accessToken = GetStorage().read('accessToken')?.toString();
    final String registerId = GetStorage().read('registerId')?.toString() ?? '';

    // Basic auth guard
    if (accessToken == null || accessToken.isEmpty || registerId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("Please log in again to continue."))),
      );
      return;
    }

    // Input validation
    if (amountText.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("Please enter an amount."))),
      );
      return;
    }
    final int? amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("Please enter a valid amount."))),
      );
      return;
    }

    if (amount < minimumWithdrawalAmount) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            await _t("Minimum withdrawal amount is ₹$minimumWithdrawalAmount."),
          ),
        ),
      );
      return;
    }

    if (amount > currentBalance) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("Insufficient balance."))),
      );
      return;
    }

    String withdrawType;
    Map<String, dynamic> requestBody = {
      "registerId": registerId,
      "amount": amount,
    };

    switch (selectedMethod) {
      case WithdrawalMethod.googlePay:
        withdrawType = "googlePay";
        if (paymentDetail.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(await _t("Please enter Google Pay UPI ID.")),
            ),
          );
          return;
        }
        requestBody["upiId"] = paymentDetail;
        break;
      case WithdrawalMethod.phonePe:
        withdrawType = "phonePe";
        if (paymentDetail.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(await _t("Please enter PhonePe UPI ID."))),
          );
          return;
        }
        requestBody["upiId"] = paymentDetail;
        break;
      case WithdrawalMethod.paytm:
        withdrawType = "paytm";
        if (paymentDetail.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(await _t("Please enter Paytm Number."))),
          );
          return;
        }
        requestBody["upiId"] =
            paymentDetail; // Paytm often uses phone number as UPI ID
        break;
      case WithdrawalMethod.bankAccount:
        withdrawType = "bank";
        if (bankNameController.text.trim().isEmpty ||
            holderNameController.text.trim().isEmpty ||
            accountNumberController.text.trim().isEmpty ||
            ifscCodeController.text.trim().isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(await _t("Please fill all bank details."))),
          );
          return;
        }
        requestBody["bankName"] = bankNameController.text.trim();
        requestBody["accountHolderName"] = holderNameController.text.trim();
        requestBody["accountNumber"] = accountNumberController.text.trim();
        requestBody["ifscCode"] = ifscCodeController.text.trim();
        break;
      default:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(await _t("Please select a withdrawal method.")),
          ),
        );
        return;
    }

    requestBody["withdrawType"] = withdrawType;

    log("Withdraw Request Body: ${json.encode(requestBody)}");

    try {
      final response = await http.post(
        Uri.parse('${_apiBaseUrl}withdraw-fund-request'),
        headers: {
          'deviceId': 'qwert', // TODO: make dynamic/config-driven
          'deviceName': 'sm2233', // TODO: make dynamic/config-driven
          'accessStatus': '1', // TODO: make dynamic/config-driven
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(requestBody),
      );

      log("Withdraw Response Status: ${response.statusCode}");
      log("Withdraw Response Body: ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                await _t("Withdrawal request submitted successfully!"),
              ),
            ),
          );
          _clearFields();
          _loadCurrentBalance(refreshUI: true); // Refresh balance after success
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                responseBody['msg'] ?? await _t("Withdrawal request failed."),
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(await _t("Server error: ${response.statusCode}")),
          ),
        );
      }
    } catch (e) {
      log("Error during withdrawal request: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("An error occurred: $e"))),
      );
    }
  }

  void _clearFields() {
    amountController.clear();
    paymentNumberController.clear();
    bankNameController.clear();
    holderNameController.clear();
    accountNumberController.clear();
    ifscCodeController.clear();
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade300,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: FutureBuilder<String>(
          future: _t("Withdraw Funds"),
          builder: (context, snapshot) =>
              Text(snapshot.data ?? "Withdraw Funds"),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
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
                      color: Colors.black,
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
                            color: Colors.red,
                            height: 50,
                            width: 50,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.red,
                                size: 50,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "\u20B9 $currentBalance", // Display current balance
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              FutureBuilder<String>(
                                future: _t("Current Balance"),
                                builder: (context, snapshot) =>
                                    Text(snapshot.data ?? "Current Balance"),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Image.asset(
                            'assets/images/mastercard.png',
                            height: 60,
                            width: 60,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.credit_card,
                                color: Colors.grey,
                                size: 60,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildMethodOption(
                WithdrawalMethod.googlePay,
                "assets/images/gpay_deposit.png",
              ),
              _buildMethodOption(
                WithdrawalMethod.phonePe,
                "assets/images/phonepe_deposit.png",
              ),
              _buildMethodOption(
                WithdrawalMethod.paytm,
                "assets/images/paytm_deposit.png",
              ),
              _buildMethodOption(
                WithdrawalMethod.bankAccount,
                "assets/images/bank_emoji.png",
              ),
              const SizedBox(height: 10),
              _buildDynamicFields(),
              const SizedBox(height: 10),
              FutureBuilder<String>(
                future: _t("SUBMIT"),
                builder: (context, snapshot) {
                  return ElevatedButton(
                    onPressed: _performWithdrawal, // Direct call
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      snapshot.data ?? "SUBMIT",
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              FutureBuilder<String>(
                future: _t("For withdraw related queries call\nor WhatsApp"),
                builder: (context, snapshot1) {
                  return FutureBuilder<String>(
                    future: _t("Monday to Sunday \u2022 9:00 AM to 6:00 PM"),
                    builder: (context, snapshot2) {
                      return Card(
                        color: Colors.grey.shade200,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  snapshot1.data ??
                                      "For withdraw related queries call\nor WhatsApp",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  snapshot2.data ??
                                      "Monday to Sunday \n \u2022 9:00 AM to 6:00 PM",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
