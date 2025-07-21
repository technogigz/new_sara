import 'package:flutter/material.dart';

class WithdrawalHistoryPage extends StatefulWidget {
  const WithdrawalHistoryPage({super.key});

  @override
  State<WithdrawalHistoryPage> createState() => _WithdrawalHistoryPageState();
}

class _WithdrawalHistoryPageState extends State<WithdrawalHistoryPage> {
  late Future<List<WithdrawalItem>> _withdrawFuture;

  @override
  void initState() {
    super.initState();
    _withdrawFuture = fetchMockWithdrawals();
  }

  Future<List<WithdrawalItem>> fetchMockWithdrawals() async {
    await Future.delayed(const Duration(seconds: 2)); // simulate network delay
    return [
      WithdrawalItem('25-03-2025 11:30:45', 100, 'Withdrawn to UPI'),
      WithdrawalItem('20-03-2025 09:10:12', 250, 'Withdrawn to Bank'),
    ];
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
          icon: Icon(Icons.arrow_back_ios_new),
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
                child: CircularProgressIndicator(color: Colors.amber),
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
                            Text(item.dateTime),
                            Row(
                              children: const [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "Completed",
                                  style: TextStyle(color: Colors.green),
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
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              "₹ ${item.amount}",
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        /// Narration
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Narration",
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              item.narration,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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
      ),
    );
  }
}

class WithdrawalItem {
  final String dateTime;
  final int amount;
  final String narration;

  WithdrawalItem(this.dateTime, this.amount, this.narration);
}
