import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/components/AppNameBold.dart';
import 'package:new_sara/ulits/Constents.dart';

class BankDetailsFragment extends StatefulWidget {
  const BankDetailsFragment({super.key});

  @override
  State<BankDetailsFragment> createState() => _BankDetailsFragmentState();
}

class _BankDetailsFragmentState extends State<BankDetailsFragment> {
  final nameController = TextEditingController();
  final accNumberController = TextEditingController();
  final ifscController = TextEditingController();
  final bankNameController = TextEditingController();
  final branchController = TextEditingController();

  final String token = GetStorage().read(
    "accessToken",
  ); // ideally store securely

  Future<void> submitBankDetails() async {
    final String url = '${Constant.apiEndpoint}user-bank-details';
    final String registerId = GetStorage().read("registerId");

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "registerId": registerId,
          // optionally send form data here if backend requires
          // "accountName": nameController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Success: $data");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bank details submitted successfully")),
        );

        // Clear fields on success
        nameController.clear();
        accNumberController.clear();
        ifscController.clear();
        bankNameController.clear();
        branchController.clear();

        Navigator.pop(context);
      } else {
        print("Error: ${response.statusCode} ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.reasonPhrase}")),
        );
      }
    } catch (e) {
      print("Exception: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
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
          icon: Icon(Icons.arrow_back_ios_new),
        ),
        title: Text("Add Bank Details"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [AppNameBold(), SizedBox(width: 10)],
                ),
              ),
              const SizedBox(height: 40),
              _inputField(
                Icons.person_outline,
                "Account Holder Name",
                nameController,
              ),
              _inputField(
                Icons.credit_card,
                "Account Number",
                accNumberController,
              ),
              _inputField(Icons.code, "IFSC CODE", ifscController),
              _inputField(
                Icons.account_balance,
                "Bank Name",
                bankNameController,
              ),
              _inputField(
                Icons.account_balance_outlined,
                "Branch Name",
                branchController,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitBankDetails,
                  style: ElevatedButton.styleFrom(
                    elevation: 3,
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "SAVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    IconData icon,
    String hintText,
    TextEditingController controller,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: TextFormField(
        controller: controller,
        cursorColor: Colors.orange,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.orange,
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
