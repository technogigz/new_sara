import 'package:flutter/material.dart';

class Bid {
  final String digit;
  final String amount;
  final String gameType;

  Bid({required this.digit, required this.amount, this.gameType = 'OPEN'});
}

class TwoDigitPanelScreen extends StatefulWidget {
  final String title;

  const TwoDigitPanelScreen({
    Key? key,
    required this.title,
    required int gameId,
    required String gameType,
  }) : super(key: key);

  @override
  _TwoDigitPanelScreenState createState() => _TwoDigitPanelScreenState();
}

class _TwoDigitPanelScreenState extends State<TwoDigitPanelScreen> {
  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  List<Bid> bids = [];

  void addBid() {
    final digit = digitController.text.trim();
    final amount = amountController.text.trim();

    if (digit.isNotEmpty && amount.isNotEmpty) {
      setState(() {
        bids.add(Bid(digit: digit, amount: amount));
        digitController.clear();
        amountController.clear();
      });
    }
  }

  void deleteBid(int index) {
    setState(() {
      bids.removeAt(index);
    });
  }

  int get totalAmount =>
      bids.fold(0, (sum, bid) => sum + (int.tryParse(bid.amount) ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Labels on the left
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 6.0),
                        child: Text(
                          'Enter Single Digit:',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      SizedBox(height: 50), // Space for input field height
                      Text('Enter Points:', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  Spacer(),

                  // Input fields and button
                  Column(
                    children: [
                      SizedBox(
                        height: 40,
                        width: 180,
                        child: TextField(
                          controller: digitController,
                          decoration: InputDecoration(
                            hintText: 'Bid Digits',
                            hintStyle: const TextStyle(fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        width: 180,
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter Amount',
                            hintStyle: const TextStyle(fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: addBid,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          minimumSize: const Size(80, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'ADD BID',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1),

            // Headers
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12,
              ),
              child: Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Digit',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Amount',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Game Type',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Bid List
            Expanded(
              child: bids.isEmpty
                  ? const Center(child: Text('No bids yet'))
                  : ListView.builder(
                      itemCount: bids.length,
                      itemBuilder: (context, index) {
                        final bid = bids[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Text(bid.digit)),
                                  Expanded(child: Text(bid.amount)),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(bid.gameType),
                                        const Spacer(),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Colors.amber,
                                          ),
                                          onPressed: () => deleteBid(index),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            if (bids.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(color: Colors.white),
                child: Row(
                  children: [
                    Column(
                      children: [
                        const Text(
                          "Bid",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text("${bids.length}"),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Column(
                      children: [
                        const Text(
                          "Total",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text("$totalAmount"),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Submit logic
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'SUBMIT',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
