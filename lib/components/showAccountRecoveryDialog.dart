import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/SetMPIN/SetNewPinScreen.dart';

import '../Helper/Toast.dart';
import '../ulits/Constents.dart';

void showAccountRecoveryDialog(BuildContext context, String mobile) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      bool isLoading = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            titlePadding: const EdgeInsets.all(0),
            title: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Text(
                'Account Recovery',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            content: const Text(
              "Recover your existing account by providing generated OTP\n\nDo you want to continue?",
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            actions: [
              Center(
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(color: Colors.red),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () async {
                          setState(() => isLoading = true);

                          try {
                            final response = await http.post(
                              Uri.parse('${Constant.apiEndpoint}send-otp'),
                              headers: {
                                'deviceId':
                                    'qwert', // Replace with actual values
                                'deviceName': 'sm2233',
                                'accessStatus': '1',
                                'Content-Type': 'application/json',
                              },
                              body: jsonEncode({"mobileNo": mobile}),
                            );

                            final data = jsonDecode(response.body);
                            log("OTP API response: $data");

                            if (response.statusCode == 200 &&
                                data['status'] == true) {
                              if (context.mounted) {
                                Navigator.of(
                                  dialogContext,
                                ).pop(); // Close dialog
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        SetNewPinScreen(mobile: mobile),
                                  ),
                                );
                              }
                            } else {
                              setState(() => isLoading = false);
                              popToast(
                                data['message'] ?? "OTP sending failed",
                                4,
                                Colors.white,
                                Colors.red,
                              );
                            }
                          } catch (e) {
                            setState(() => isLoading = false);
                            popToast(
                              "Network error: $e",
                              4,
                              Colors.white,
                              Colors.red,
                            );
                          }
                        },
                        child: const Text(
                          "RECOVER",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}
