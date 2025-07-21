import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
// import 'package:http/http.dart' as http; // Removed for mock API

class SinglePannaScreen extends StatefulWidget {
  final String title;

  const SinglePannaScreen({
    Key? key,
    required this.title,
    required int gameId,
    required String gameType,
  }) : super(key: key);

  @override
  State<SinglePannaScreen> createState() => _SinglePannaScreenState();
}

class _SinglePannaScreenState extends State<SinglePannaScreen> {
  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final List<String> gameTypes = ['Open', 'Close'];
  String selectedGameType = 'Close';

  List<Map<String, String>> bids = [];
  int walletBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedBids();
    _loadWalletBalance(); // This is where the error originates
  }

  void _loadSavedBids() {
    final box = GetStorage();
    final savedBids = box.read<List>('placedBids');
    if (savedBids != null) {
      setState(() {
        // Ensure that each item in savedBids is treated as a Map<String, String>
        bids = savedBids
            .map((item) {
              if (item is Map) {
                return Map<String, String>.from(
                  item.map((k, v) => MapEntry(k.toString(), v.toString())),
                );
              }
              return <String, String>{}; // Return an empty map or handle error
            })
            .where((map) => map.isNotEmpty)
            .toList(); // Filter out empty maps if any
      });
    }
  }

  void _saveBids() {
    GetStorage().write('placedBids', bids);
  }

  void _loadWalletBalance() {
    final box = GetStorage();
    // Read the value, it could be String, int, or null.
    final dynamic storedValue = box.read('walletBalance');

    if (storedValue != null) {
      if (storedValue is int) {
        walletBalance = storedValue;
      } else if (storedValue is String) {
        // Try to parse the string to an int
        walletBalance = int.tryParse(storedValue) ?? 0;
      } else {
        // Handle other unexpected types if necessary, default to 0
        walletBalance = 0;
      }
    } else {
      // If no value is stored, initialize with a default balance
      walletBalance = 1000;
    }
    // No setState here as this is called in initState.
    // walletBalance is directly used in build method, which will reflect changes.
  }

  void _updateWalletBalance(int spentAmount) {
    walletBalance -= spentAmount;
    GetStorage().write('walletBalance', walletBalance);
  }

  Future<void> _addBid() async {
    final digit = digitController.text.trim();
    final amount = amountController.text.trim();

    if (digit.isEmpty || amount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final intAmount = int.tryParse(amount);
    if (intAmount == null || intAmount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    if (intAmount > walletBalance) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Insufficient balance')));
      return;
    }

    // --- Mock API Call Logic ---
    // Show a loading indicator if you have one
    // setState(() { _isLoading = true; });

    // Simulate network delay
    await Future.delayed(
      const Duration(seconds: 1),
    ); // Simulate 1 second network delay

    // Mock API response
    final Map<String, dynamic> mockApiResponse = {
      "status": true,
      "msg": "Bid submitted successfully! (Mock Response)",
      "data": {
        "bidId": "mock_bid_12345",
        "digit": digit,
        "sessionType": selectedGameType.toLowerCase(),
        "amount": intAmount,
        "newWalletBalance":
            walletBalance - intAmount, // Calculate new balance for mock
        "timestamp": DateTime.now().toIso8601String(),
      },
    };

    try {
      // Simulate successful response
      if (mockApiResponse['status'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mockApiResponse['msg'])));

        setState(() {
          bids.add({
            'digit': digit,
            'amount': amount,
            'type': selectedGameType,
          });
          _updateWalletBalance(intAmount); // deduct from wallet
          _saveBids(); // save updated bids
          digitController.clear();
          amountController.clear();
        });
      } else {
        // Simulate an error response from the mock API
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error (Mock): ${mockApiResponse['msg']}")),
        );
      }
    } catch (e) {
      // This catch block would typically handle actual network errors,
      // but for mock it shows a generic error if something goes wrong in the mock logic.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit bid (Mock): $e")),
      );
    } finally {
      // Hide loading indicator
      // setState(() { _isLoading = false; });
    }
  }

  Widget _inputRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          field,
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return SizedBox(
      height: 35,
      width: 150,
      child: DropdownButtonFormField<String>(
        value: selectedGameType,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.amber, width: 2),
          ),
        ),
        items: gameTypes.map((type) {
          return DropdownMenuItem(value: type, child: Text(type));
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => selectedGameType = value);
          }
        },
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint) {
    return SizedBox(
      height: 35,
      width: 150,
      child: TextFormField(
        controller: controller,
        cursorColor: Colors.amber,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.amber, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Expanded(
            child: Text("Digit", style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              "Amount",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              "Game Type",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff2f2f2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/wallet_icon.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  "$walletBalance",
                  style: const TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            _inputRow("Select Game Type:", _buildDropdown()),
            _inputRow(
              "Enter Single Digit:",
              _buildInputField(digitController, "Bid Digits"),
            ),
            _inputRow(
              "Enter Points:",
              _buildInputField(amountController, "Enter Amount"),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 35,
                width: 150,
                child: ElevatedButton(
                  onPressed: _addBid,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    "ADD BID",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            _buildTableHeader(),
            Divider(color: Colors.grey.shade300),
            Expanded(
              child: bids.isEmpty
                  ? const Center(
                      child: Text(
                        "No Bids Added",
                        style: TextStyle(color: Colors.black38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: bids.length,
                      itemBuilder: (context, index) {
                        final bid = bids[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(bid['digit']!)),
                              Expanded(child: Text(bid['amount']!)),
                              Expanded(child: Text(bid['type']!)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
