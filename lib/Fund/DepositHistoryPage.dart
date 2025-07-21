import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

class DepositHistoryPage extends StatefulWidget {
  const DepositHistoryPage({Key? key}) : super(key: key);

  @override
  State<DepositHistoryPage> createState() => _DepositHistoryPageState();
}

class _DepositHistoryPageState extends State<DepositHistoryPage> {
  late Future<List<DepositHistoryItem>> _depositFuture;
  final storage = GetStorage();

  String accessToken = '';
  String registerId = '';

  @override
  void initState() {
    super.initState();

    // Read accessToken and registerId using readKey (initial fetch)
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';

    // Listen to changes for real-time updates if needed (optional, depends on app flow)
    // storage.listenKey('accessToken', (value) {
    //   setState(() {
    //     accessToken = value ?? '';
    //   });
    // });
    // storage.listenKey('registerId', (value) {
    //   setState(() {
    //     registerId = value ?? '';
    //   });
    // });

    log("Access Token: $accessToken");
    log("Register Id: $registerId");

    _depositFuture = fetchDepositHistory();
  }

  Future<List<DepositHistoryItem>> fetchDepositHistory() async {
    final uri = Uri.parse('https://sara777.win/api/v1/deposit-fund-history');

    final requestBody = jsonEncode({
      'registerId': registerId,
      'pageIndex': 1,
      'recordLimit': 10,
    });

    log("Deposit History Request Body: $requestBody");

    try {
      final response = await http.post(
        uri,
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: requestBody,
      );

      final data = jsonDecode(response.body);
      debugPrint('API Response: $data');
      log('API Response Status Code: ${response.statusCode}');
      log('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        if (data['status'] == true && data['info'] != null) {
          final List<dynamic> list =
              data['info']['list'] ?? []; // Access 'info' then 'list'
          return list.map((item) => DepositHistoryItem.fromJson(item)).toList();
        } else {
          // Handle "No Record." case gracefully or other non-true status
          debugPrint('API status is false or info is null: ${data['msg']}');
          return [];
        }
      } else {
        throw Exception(
          'Failed to load deposit history: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Exception fetching deposit history: $e');
      throw Exception('Failed to load deposit history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: const Text(
          'Fund Deposit History',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.grey.shade300,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<DepositHistoryItem>>(
        future: _depositFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final list = snapshot.data ?? [];

          if (list.isEmpty) {
            return const Center(child: Text('No deposit history found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              // Determine status color and icon based on statusText
              Color statusColor = Colors.grey;
              IconData statusIcon = Icons.info_outline;
              if (item.statusText.toLowerCase() == 'completed') {
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
              } else if (item.statusText.toLowerCase() == 'pending') {
                statusColor = Colors.orange;
                statusIcon = Icons.access_time;
              } else if (item.statusText.toLowerCase() == 'failed' ||
                  item.statusText.toLowerCase() == 'rejected') {
                statusColor = Colors.red;
                statusIcon = Icons.cancel;
              }

              return Card(
                color: Colors
                    .white, // Changed card color to white for better contrast
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.requestDate, // Use requestDate
                            style: const TextStyle(color: Colors.black54),
                          ),
                          Row(
                            children: [
                              Icon(statusIcon, size: 16, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                item.statusText, // Use statusText
                                style: TextStyle(color: statusColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Amount",
                            style: TextStyle(color: Colors.black),
                          ),
                          Text(
                            "₹ ${item.amount}", // Amount is now String, ensure it's parsed if needed for calculations
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors
                                  .green, // Assuming deposit is always positive
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Narration",
                            style: TextStyle(color: Colors.black),
                          ),
                          Text(
                            item.remark, // Use remark for narration
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DepositHistoryItem {
  final String txId;
  final String requestDate;
  final String amount; // Changed to String as per API response
  final String remark; // Changed from narration to remark
  final String statusText; // New field for status

  DepositHistoryItem({
    required this.txId,
    required this.requestDate,
    required this.amount,
    required this.remark,
    required this.statusText,
  });

  factory DepositHistoryItem.fromJson(Map<String, dynamic> json) {
    return DepositHistoryItem(
      txId: json['txId'] ?? '',
      requestDate: json['requestDate'] ?? 'Unknown Date',
      amount: json['amount']?.toString() ?? '0', // Ensure it's a string
      remark: json['remark'] ?? 'No Details',
      statusText: json['statusText'] ?? 'Unknown Status',
    );
  }
}
