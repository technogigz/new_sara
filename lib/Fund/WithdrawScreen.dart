import 'dart:convert';
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // Import http package

import '../Helper/TranslationHelper.dart'; // Assuming this path is correct

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  late int currentBalance;
  final TextEditingController amountController = TextEditingController();
  final TextEditingController paymentNumberController =
      TextEditingController(); // Used for UPI ID/Phone number
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController holderNameController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController ifscCodeController = TextEditingController();

  String selectedMethod = WithdrawalMethod.googlePay; // Default selected method
  String currentLangCode = GetStorage().read("language") ?? "en";
  final Map<String, String> _translationCache = {};

  // Constants for withdrawal methods
  static const String _apiBaseUrl = 'https://sara777.win/api/v1';

  @override
  void initState() {
    super.initState();
    _loadCurrentBalance();
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

  void _loadCurrentBalance() {
    final dynamic raw = GetStorage().read("walletBalance");
    setState(() {
      if (raw is int) {
        currentBalance = raw;
      } else if (raw is String) {
        currentBalance = int.tryParse(raw) ?? 0;
      } else {
        currentBalance = 0;
      }
    });
  }

  // Function to translate text
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

  // Reusable InputDecoration
  InputDecoration _buildInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.amber),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.amber, width: 2),
      ),
    );
  }

  // Widget to build method selection options (Google Pay, PhonePe, Paytm, Bank Account)
  Widget _buildMethodOption(String method, String logoPath) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMethod = method;
        });
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
              if (value != null) {
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
          cursorColor: Colors.amber,
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
    final String? accessToken = GetStorage().read('accessToken');
    final String registerId = GetStorage().read('registerId') ?? '';

    // Input validation
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("Please enter an amount."))),
      );
      return;
    }
    final int? amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(await _t("Please enter a valid amount."))),
      );
      return;
    }

    // New validation: Minimum withdrawal amount of ₹1000 if wallet balance is less than ₹1000
    if (amount < 1000 && currentBalance < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            await _t(
              "Minimum withdrawal amount is ₹1000 when your balance is less than ₹1000.",
            ),
          ),
        ),
      );
      return;
    }

    if (amount > currentBalance) {
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
        Uri.parse('$_apiBaseUrl/withdraw-fund-request'),
        headers: {
          'deviceId': 'qwert', // Consider making these dynamic or from a config
          'deviceName':
              'sm2233', // Consider making these dynamic or from a config
          'accessStatus': '1', // Consider making these dynamic or from a config
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(requestBody),
      );

      log("Withdraw Response Status: ${response.statusCode}");
      log("Withdraw Response Body: ${response.body}");

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
          _loadCurrentBalance(); // Refresh balance after successful withdrawal
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
                            color: Colors.amber,
                            height: 50,
                            width: 50,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.account_balance_wallet,
                                color: Colors.amber,
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
                      backgroundColor: Colors.amber,
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
                                      "Monday to Sunday \u2022 9:00 AM to 6:00 PM",
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

// Using a class for constants to avoid magic strings
class WithdrawalMethod {
  static const String googlePay = "Google Pay";
  static const String phonePe = "PhonePe";
  static const String paytm = "Paytm";
  static const String bankAccount = "Bank Account";
}

// import 'dart:convert';
// import 'dart:developer'; // For log
//
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:http/http.dart' as http; // Import http package
//
// import '../Helper/TranslationHelper.dart';
//
// class WithdrawScreen extends StatefulWidget {
//   const WithdrawScreen({super.key});
//
//   @override
//   State<WithdrawScreen> createState() => _WithdrawScreenState();
// }
//
// class _WithdrawScreenState extends State<WithdrawScreen> {
//   late int currentBalance;
//   final TextEditingController amountController = TextEditingController();
//   final TextEditingController paymentNumberController =
//       TextEditingController(); // Used for UPI ID/Phone number
//   final TextEditingController bankNameController = TextEditingController();
//   final TextEditingController holderNameController = TextEditingController();
//   final TextEditingController accountNumberController = TextEditingController();
//   final TextEditingController ifscCodeController = TextEditingController();
//
//   @override
//   void initState() {
//     super.initState();
//     currentBalance = getCurrentBalance();
//   }
//
//   int getCurrentBalance() {
//     final dynamic raw = GetStorage().read("walletBalance");
//
//     if (raw is int) {
//       return raw;
//     } else if (raw is String) {
//       return int.tryParse(raw) ?? 0;
//     } else {
//       return 0;
//     }
//   }
//
//   String selectedMethod = "Google Pay"; // Default selected method
//   String currentLangCode = GetStorage().read("language") ?? "en";
//   final Map<String, String> _translationCache = {};
//
//   // Function to translate text
//   Future<String> _t(String text) async {
//     if (_translationCache.containsKey(text)) {
//       return _translationCache[text]!;
//     }
//     String translated = await TranslationHelper.translate(
//       text,
//       currentLangCode,
//     );
//     _translationCache[text] = translated;
//     return translated;
//   }
//
//   // Widget to build method selection options (Google Pay, PhonePe, Paytm, Bank Account)
//   Widget _buildMethodOption(String method, String logoPath) {
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           selectedMethod = method;
//         });
//       },
//       child: Card(
//         color: Colors.grey.shade200,
//         elevation: 2,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         child: ListTile(
//           leading: Image.asset(
//             logoPath,
//             width: 36,
//             errorBuilder: (context, error, stackTrace) =>
//                 const Icon(Icons.payment_outlined, size: 36),
//           ),
//           title: FutureBuilder<String>(
//             future: _t(method),
//             builder: (context, snapshot) {
//               return Text(
//                 snapshot.data ?? method,
//                 style: const TextStyle(fontWeight: FontWeight.bold),
//               );
//             },
//           ),
//           subtitle: FutureBuilder<String>(
//             future: _t("Manual approve by Admin"),
//             builder: (context, snapshot) =>
//                 Text(snapshot.data ?? "Manual approve by Admin"),
//           ),
//           trailing: Radio<String>(
//             value: method,
//             groupValue: selectedMethod,
//             onChanged: (value) {
//               if (value != null) {
//                 setState(() {
//                   selectedMethod = value;
//                 });
//               }
//             },
//             activeColor: Colors.amber,
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Widget to build the amount input field
//   Widget _buildAmountField() {
//     return FutureBuilder<String>(
//       future: _t("Enter Amount"),
//       builder: (context, snapshot) {
//         return TextField(
//           controller: amountController,
//           cursorColor: Colors.amber,
//           keyboardType: TextInputType.number,
//           decoration: InputDecoration(
//             hintText: snapshot.data ?? "Enter Amount",
//             filled: true,
//             fillColor: Colors.white,
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: Colors.amber),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: Colors.amber, width: 2),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   // Widget to build payment number/UPI ID field
//   Widget _buildPaymentNumberField(String hint) {
//     return FutureBuilder<String>(
//       future: _t(hint),
//       builder: (context, snapshot) {
//         return TextField(
//           controller: paymentNumberController,
//           cursorColor: Colors.amber,
//           keyboardType: TextInputType.text, // Changed to text for UPI ID
//           decoration: InputDecoration(
//             hintText: snapshot.data ?? hint,
//             filled: true,
//             fillColor: Colors.white,
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: Colors.amber),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: Colors.amber, width: 2),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   // Generic text field builder for bank details
//   Widget _buildTextField(
//     TextEditingController controller,
//     String hint, {
//     TextInputType keyboardType = TextInputType.text,
//   }) {
//     return FutureBuilder<String>(
//       future: _t(hint),
//       builder: (context, snapshot) {
//         return TextField(
//           controller: controller,
//           cursorColor: Colors.amber,
//           keyboardType: keyboardType,
//           decoration: InputDecoration(
//             hintText: snapshot.data ?? hint,
//             filled: true,
//             fillColor: Colors.white,
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: Colors.amber),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: Colors.amber, width: 2),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   // Widget to build bank-specific input fields
//   Widget _buildBankFields() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         _buildAmountField(),
//         const SizedBox(height: 12),
//         _buildTextField(bankNameController, "Bank Name"),
//         const SizedBox(height: 12),
//         _buildTextField(holderNameController, "Account Holder Name"),
//         const SizedBox(height: 12),
//         _buildTextField(
//           accountNumberController,
//           "Account Number",
//           keyboardType: TextInputType.number,
//         ),
//         const SizedBox(height: 12),
//         _buildTextField(ifscCodeController, "IFSC Code"),
//       ],
//     );
//   }
//
//   // Widget to dynamically show fields based on selected method
//   Widget _buildDynamicFields() {
//     String selectedMethodHint =
//         "Enter ${selectedMethod.replaceAll(' ', '')} UPI ID"; // Adjust hint for UPI
//     if (selectedMethod == "Paytm") {
//       selectedMethodHint = "Enter Paytm Number"; // Specific hint for Paytm
//     }
//
//     switch (selectedMethod) {
//       case "Google Pay":
//       case "PhonePe":
//       case "Paytm":
//         return Column(
//           children: [
//             _buildAmountField(),
//             const SizedBox(height: 12),
//             _buildPaymentNumberField(selectedMethodHint),
//           ],
//         );
//       case "Bank Account":
//         return _buildBankFields();
//       default:
//         return const SizedBox();
//     }
//   }
//
//   // Function to handle the withdrawal request API call
//   Future<void> _performWithdrawal() async {
//     final amountText = amountController.text.trim();
//     final paymentDetail = paymentNumberController.text.trim(); // For UPI/Paytm
//     final String? accessToken = GetStorage().read('accessToken');
//     final String registerId =
//         GetStorage().read('registerId') ?? ''; // Example registerId
//
//     // Input validation
//     if (amountText.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(await _t("Please enter an amount."))),
//       );
//       return;
//     }
//     final int? amount = int.tryParse(amountText);
//     if (amount == null || amount <= 0) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(await _t("Please enter a valid amount."))),
//       );
//       return;
//     }
//
//     // New validation: Minimum withdrawal amount of ₹1000 if wallet balance is less than ₹1000
//     if (amount < 1000 && currentBalance < 1000) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             await _t(
//               "Minimum withdrawal amount is ₹1000 when your balance is less than ₹1000.",
//             ),
//           ),
//         ),
//       );
//       return;
//     }
//
//     String withdrawType;
//     String? upiId;
//     Map<String, dynamic> requestBody = {
//       "registerId": registerId,
//       "amount": amount,
//     };
//
//     switch (selectedMethod) {
//       case "Google Pay":
//         withdrawType = "googlePay";
//         if (paymentDetail.isEmpty) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(await _t("Please enter Google Pay number.")),
//             ),
//           );
//           return;
//         }
//         upiId = paymentDetail;
//         requestBody["upiId"] = upiId;
//         break;
//       case "PhonePe":
//         withdrawType = "phonePe";
//         if (paymentDetail.isEmpty) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text(await _t("Please enter PhonePe number."))),
//           );
//           return;
//         }
//         upiId = paymentDetail;
//         requestBody["upiId"] = upiId;
//         break;
//       case "Paytm":
//         withdrawType = "paytm";
//         if (paymentDetail.isEmpty) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text(await _t("Please enter Paytm Number."))),
//           );
//           return;
//         }
//         upiId =
//             paymentDetail; // For Paytm, this is typically the registered phone number
//         requestBody["upiId"] = upiId;
//         break;
//       case "Bank Account":
//         withdrawType = "bank";
//         if (bankNameController.text.trim().isEmpty ||
//             holderNameController.text.trim().isEmpty ||
//             accountNumberController.text.trim().isEmpty ||
//             ifscCodeController.text.trim().isEmpty) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text(await _t("Please fill all bank details."))),
//           );
//           return;
//         }
//         requestBody["bankName"] = bankNameController.text.trim();
//         requestBody["accountHolderName"] = holderNameController.text.trim();
//         requestBody["accountNumber"] = accountNumberController.text.trim();
//         requestBody["ifscCode"] = ifscCodeController.text.trim();
//         break;
//       default:
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(await _t("Please select a withdrawal method.")),
//           ),
//         );
//         return;
//     }
//
//     requestBody["withdrawType"] = withdrawType;
//
//     log("Withdraw Request Body: ${json.encode(requestBody)}");
//
//     try {
//       final response = await http.post(
//         Uri.parse('https://sara777.win/api/v1/withdraw-fund-request'),
//         headers: {
//           'deviceId': 'qwert',
//           'deviceName': 'sm2233',
//           'accessStatus': '1',
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $accessToken', // Use the actual access token
//         },
//         body: json.encode(requestBody),
//       );
//
//       log("Withdraw Response Status: ${response.statusCode}");
//       log("Withdraw Response Body: ${response.body}");
//
//       if (response.statusCode == 200) {
//         final responseBody = json.decode(response.body);
//         if (responseBody['status'] == true) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 await _t("Withdrawal request submitted successfully!"),
//               ),
//             ),
//           );
//           // Clear fields on success
//           amountController.clear();
//           paymentNumberController.clear();
//           bankNameController.clear();
//           holderNameController.clear();
//           accountNumberController.clear();
//           ifscCodeController.clear();
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 responseBody['msg'] ?? await _t("Withdrawal request failed."),
//               ),
//             ),
//           );
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(await _t("Server error: ${response.statusCode}")),
//           ),
//         );
//       }
//     } catch (e) {
//       log("Error during withdrawal request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(await _t("An error occurred: $e"))),
//       );
//     }
//   }
//
//   // Handles submit button press
//   // This function now simply calls _performWithdrawal,
//   // delegating all validation logic to _performWithdrawal.
//   void _handleSubmit() async {
//     await _performWithdrawal();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       resizeToAvoidBottomInset: true,
//       backgroundColor: Colors.grey.shade200,
//       appBar: AppBar(
//         backgroundColor: Colors.grey.shade300,
//         leading: IconButton(
//           onPressed: () {
//             Navigator.pop(context);
//           },
//           icon: const Icon(Icons.arrow_back_ios_new),
//         ),
//         title: FutureBuilder<String>(
//           future: _t("Withdraw Funds"),
//           builder: (context, snapshot) =>
//               Text(snapshot.data ?? "Withdraw Funds"),
//         ),
//       ),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: ListView(
//             children: [
//               Card(
//                 elevation: 4,
//                 color: Colors.white,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const SizedBox(height: 20),
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(12),
//                       color: Colors.black,
//                       child: const Center(
//                         child: Text(
//                           "SARA777",
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Row(
//                         children: [
//                           Image.asset(
//                             "assets/images/ic_wallet.png", // Ensure this asset path is correct
//                             color: Colors.amber,
//                             height: 50,
//                             width: 50,
//                             errorBuilder: (context, error, stackTrace) {
//                               return const Icon(
//                                 Icons.account_balance_wallet,
//                                 color: Colors.amber,
//                                 size: 50,
//                               );
//                             },
//                           ),
//                           const SizedBox(width: 8),
//                           Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 "\u20B9 $currentBalance", // Display current balance
//                                 style: const TextStyle(
//                                   fontSize: 20,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.amber,
//                                 ),
//                               ),
//                               FutureBuilder<String>(
//                                 future: _t("Current Balance"),
//                                 builder: (context, snapshot) =>
//                                     Text(snapshot.data ?? "Current Balance"),
//                               ),
//                             ],
//                           ),
//                           const Spacer(),
//                           Image.asset(
//                             'assets/images/mastercard.png', // Ensure this asset path is correct
//                             height: 60,
//                             width: 60,
//                             errorBuilder: (context, error, stackTrace) {
//                               return const Icon(
//                                 Icons.credit_card,
//                                 color: Colors.grey,
//                                 size: 60,
//                               );
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 10),
//               _buildMethodOption(
//                 "Google Pay",
//                 "assets/images/gpay_deposit.png", // Ensure this asset path is correct
//               ),
//               _buildMethodOption(
//                 "PhonePe",
//                 "assets/images/phonepe_deposit.png", // Ensure this asset path is correct
//               ),
//               _buildMethodOption(
//                 "Paytm",
//                 "assets/images/paytm_deposit.png",
//               ), // Ensure this asset path is correct
//               _buildMethodOption(
//                 "Bank Account",
//                 "assets/images/bank_emoji.png", // Ensure this asset path is correct
//               ),
//               const SizedBox(height: 10),
//               _buildDynamicFields(),
//               const SizedBox(height: 10),
//               FutureBuilder<String>(
//                 future: _t("SUBMIT"),
//                 builder: (context, snapshot) {
//                   return ElevatedButton(
//                     onPressed: _handleSubmit,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.amber,
//                       padding: const EdgeInsets.symmetric(vertical: 16),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                     child: Text(
//                       snapshot.data ?? "SUBMIT",
//                       style: const TextStyle(color: Colors.white, fontSize: 18),
//                     ),
//                   );
//                 },
//               ),
//               const SizedBox(height: 10),
//               FutureBuilder<String>(
//                 future: _t("For withdraw related queries call\nor WhatsApp"),
//                 builder: (context, snapshot1) {
//                   return FutureBuilder<String>(
//                     future: _t("Monday to Sunday \u2022 9:00 AM to 6:00 PM"),
//                     builder: (context, snapshot2) {
//                       return Card(
//                         color: Colors.grey.shade200,
//                         elevation: 2,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Padding(
//                           padding: const EdgeInsets.all(10),
//                           child: Center(
//                             child: Column(
//                               mainAxisSize: MainAxisSize.min,
//                               crossAxisAlignment: CrossAxisAlignment.center,
//                               children: [
//                                 Text(
//                                   snapshot1.data ??
//                                       "For withdraw related queries call\nor WhatsApp",
//                                   textAlign: TextAlign.center,
//                                   style: const TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 8),
//                                 Text(
//                                   snapshot2.data ??
//                                       "Monday to Sunday \u2022 9:00 AM to 6:00 PM",
//                                   textAlign: TextAlign.center,
//                                   style: const TextStyle(
//                                     color: Colors.black,
//                                     fontWeight: FontWeight.bold,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
