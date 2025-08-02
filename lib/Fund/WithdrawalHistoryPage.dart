import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/ulits/Constents.dart'; // Ensure this path is correct

class WithdrawalHistoryPage extends StatefulWidget {
  const WithdrawalHistoryPage({super.key});

  @override
  State<WithdrawalHistoryPage> createState() => _WithdrawalHistoryPageState();
}

class _WithdrawalHistoryPageState extends State<WithdrawalHistoryPage> {
  late Future<List<WithdrawalItem>> _withdrawFuture;
  final String apiUrl = '${Constant.apiEndpoint}withdrawal-fund-history';
  final GetStorage storage = GetStorage();
  String accessToken = '';
  String registerId = '';

  @override
  void initState() {
    super.initState();
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';

    _withdrawFuture = fetchWithdrawals(); // Initial fetch

    storage.listenKey('accessToken', (value) {
      setState(() {
        accessToken = value ?? '';
        _withdrawFuture = fetchWithdrawals(); // Re-fetch on token change
      });
    });

    storage.listenKey('registerId', (value) {
      setState(() {
        registerId = value ?? '';
        _withdrawFuture = fetchWithdrawals(); // Re-fetch on ID change
      });
    });
  }

  Future<List<WithdrawalItem>> fetchWithdrawals() async {
    if (accessToken.isEmpty || registerId.isEmpty) {
      print('Access Token or Register ID is empty. Skipping API call.');
      return Future.value(
        [],
      ); // Return an empty list if credentials are not available
    }

    final url = Uri.parse(apiUrl);
    final headers = {
      'deviceId': 'qwert',
      'deviceName': 'sm2233',
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final body = jsonEncode({
      'registerId': registerId,
      'pageIndex': 1,
      'recordLimit': 10,
    });

    print('Fetching withdrawals from URL: $url');
    print('Request Headers: $headers');
    print('Request Body: $body');

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        print('API Response Status Code: ${response.statusCode}');
        print('API Response Body: ${response.body}'); // Log the full response

        // **CRITICAL FIX:** Updated based on your Postman response.
        // Data is now under 'info' key, and the list is under 'list' within 'info'.
        if (responseData.containsKey('info') &&
            responseData['info'] is Map &&
            responseData['info'].containsKey('list') &&
            responseData['info']['list'] is List) {
          final List<dynamic> withdrawalListJson = responseData['info']['list'];
          if (withdrawalListJson.isEmpty) {
            print('Withdrawal history list is empty.');
          }
          return withdrawalListJson
              .map((json) => WithdrawalItem.fromJson(json))
              .toList();
        } else {
          print(
            'API response structure unexpected. Missing "info" or "list" key: $responseData',
          );
          throw Exception(
            'Unexpected API response structure for withdrawal history. Check "info" and "list" keys.',
          );
        }
      } else {
        print('Failed to load withdrawals: ${response.statusCode}');
        print('Response body: ${response.body}');
        if (response.statusCode == 401) {
          throw Exception('Authentication failed. Please log in again.');
        } else if (response.statusCode == 404) {
          throw Exception('API endpoint not found.');
        } else if (response.statusCode >= 500) {
          throw Exception(
            'Server error (${response.statusCode}). Please try again later.',
          );
        } else {
          throw Exception(
            'Failed to load withdrawal history: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('Error fetching withdrawals: $e');
      throw Exception(
        'Failed to connect to the server. Please check your internet connection and server status.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: const Text(
          'Fund Withdraw History',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.grey.shade300,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: FutureBuilder<List<WithdrawalItem>>(
          future: _withdrawFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error: ${snapshot.error.toString()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            final list = snapshot.data ?? [];

            if (list.isEmpty) {
              return const Center(child: Text("No withdraw history found."));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Date & Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.requestDate,
                            ), // Updated key to requestDate
                            Row(
                              children: [
                                // Dynamic icon and color based on statusText
                                Icon(
                                  item.statusText.toLowerCase() == 'completed'
                                      ? Icons.check_circle
                                      : item.statusText.toLowerCase() ==
                                            'pending'
                                      ? Icons.access_time
                                      : Icons.cancel,
                                  size: 16,
                                  color:
                                      item.statusText.toLowerCase() ==
                                          'completed'
                                      ? Colors.green
                                      : item.statusText.toLowerCase() ==
                                            'pending'
                                      ? Colors.orange
                                      : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.statusText, // Display actual statusText
                                  style: TextStyle(
                                    color:
                                        item.statusText.toLowerCase() ==
                                            'completed'
                                        ? Colors.green
                                        : item.statusText.toLowerCase() ==
                                              'pending'
                                        ? Colors.orange
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(),

                        /// Amount
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Amount",
                              style: TextStyle(color: Colors.black),
                            ),
                            Text(
                              "₹ ${item.amount.toStringAsFixed(2)}", // Ensure it's parsed as double and formatted
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        /// Narration (using withdrawMode as narration for now)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Withdraw Mode", // Changed label to reflect content
                              style: TextStyle(color: Colors.black),
                            ),
                            Flexible(
                              child: Text(
                                item.withdrawMode, // Using withdrawMode from API
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (item.upiId.isNotEmpty) // Show UPI ID if available
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "UPI ID",
                                  style: TextStyle(color: Colors.black),
                                ),
                                Flexible(
                                  child: Text(
                                    item.upiId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (item
                            .bankName
                            .isNotEmpty) // Show Bank details if available
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Bank Name",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Flexible(
                                      child: Text(
                                        item.bankName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "A/C Holder",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Flexible(
                                      child: Text(
                                        item.accountHolderName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "A/C No.",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Flexible(
                                      child: Text(
                                        item.accountNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "IFSC Code",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Flexible(
                                      child: Text(
                                        item.ifscCode,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class WithdrawalItem {
  final String requestDate;
  final double amount;
  final String fundId;
  final String withdrawMode; // Used for "Narration"
  final String upiId;
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String requestType;
  final String statusText; // The actual status string

  WithdrawalItem({
    required this.requestDate,
    required this.amount,
    required this.fundId,
    required this.withdrawMode,
    required this.upiId,
    required this.bankName,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.requestType,
    required this.statusText,
  });

  factory WithdrawalItem.fromJson(Map<String, dynamic> json) {
    return WithdrawalItem(
      requestDate: json['requestDate'] as String? ?? 'N/A',
      // Amount is a String in API, parse to double
      amount: double.tryParse(json['amount'] as String? ?? '0.0') ?? 0.0,
      fundId: json['fundId'] as String? ?? '',
      withdrawMode: json['withdrawMode'] as String? ?? 'N/A',
      upiId: json['upiId'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      accountHolderName: json['accountHolderName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      ifscCode: json['ifscCode'] as String? ?? '',
      requestType: json['requestType'] as String? ?? 'N/A',
      statusText: json['statusText'] as String? ?? 'Unknown',
    );
  }
}
