import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter

class JodiBidScreen extends StatefulWidget {
  final String title;

  const JodiBidScreen({
    Key? key,
    required this.title,
    required String gameType,
    required int gameId,
  }) : super(key: key);

  @override
  State<JodiBidScreen> createState() => _JodiBidScreenState();
}

class _JodiBidScreenState extends State<JodiBidScreen> {
  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  Color digitBorderColor = Colors.black;
  Color amountBorderColor = Colors.black;

  // List to store bids (placeholder for functionality)
  List<Map<String, String>> bids = [];

  @override
  void dispose() {
    digitController.dispose();
    amountController.dispose();
    super.dispose();
  }

  // Function to add a new bid (basic implementation)
  void _addBid() {
    setState(() {
      String jodi = digitController.text
          .trim(); // Renamed 'digit' to 'jodi' for clarity
      String amount = amountController.text.trim();

      if (jodi.isNotEmpty && amount.isNotEmpty) {
        // Validation for 2-digit Jodi
        if (jodi.length == 2 && int.tryParse(jodi) != null) {
          bids.add({
            'digit': jodi,
            'amount': amount,
            'gameType': 'JODI',
          }); // Changed gameType to 'JODI'
          digitController.clear();
          amountController.clear();
          digitBorderColor = Colors.black; // Reset border color
          amountBorderColor = Colors.black; // Reset border color
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid 2-digit Jodi.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter both Jodi and Amount.')),
        );
      }
    });
  }

  // Function to remove a bid
  void _removeBid(int index) {
    setState(() {
      bids.removeAt(index);
    });
  }

  // Helper widget for input rows
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

  // Helper widget to build input fields
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required Color borderColor,
    required VoidCallback onTap,
    List<TextInputFormatter>? inputFormatters, // Added for formatters
  }) {
    return SizedBox(
      height: 35,
      width: 150,
      child: TextFormField(
        controller: controller,
        readOnly: false,
        onTap: onTap,
        cursorColor: Colors.amber,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 14),
        inputFormatters: inputFormatters, // Apply formatters
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            // Add focused border for amber color
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.amber, width: 2),
          ),
        ),
      ),
    );
  }

  // Helper widget for the "ADD BID" button
  Widget _buildAddBidButton() {
    return SizedBox(
      height: 35,
      width: 150,
      child: ElevatedButton(
        onPressed: _addBid, // Call the _addBid function
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 0,
        ),
        child: const Text(
          "ADD BID",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Helper widget for the table header
  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 20,
        bottom: 8.0,
        left: 16,
        right: 16,
      ), // Added horizontal padding
      child: Row(
        children: const [
          Expanded(
            child: Text(
              "Jodi",
              style: TextStyle(fontWeight: FontWeight.w500),
            ), // Changed label to Jodi
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
          SizedBox(width: 48), // Space for delete icon
        ],
      ),
    );
  }

  // Helper widget to build each bid item in the list
  Widget _buildBidItem(Map<String, String> bid, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      // Removed horizontal padding from Container, will add to Row inside
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        // Added Padding here to align content
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                bid['digit']!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                bid['amount']!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                bid['gameType']!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeBid(index),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for bottom bar
  Widget _buildBottomBar() {
    int totalBids = bids.length;
    int totalPoints = bids.fold(
      0,
      (sum, item) => sum + int.tryParse(item['amount'] ?? '0')!,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bids',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              Text(
                '$totalBids',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Points',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              Text(
                '$totalPoints',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Submit button pressed!')),
              );
            },
            child: const Text(
              'SUBMIT',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
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
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
        title: Text(
          widget.title.toUpperCase(),
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
                const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.black,
                ), // Replaced Image.asset
                const SizedBox(width: 4),
                const Text("5", style: TextStyle(color: Colors.black)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inputRow(
                  "Enter Jodi:", // Changed label
                  _buildInputField(
                    controller: digitController,
                    hint: "Enter Jodi", // Changed hint
                    borderColor: digitBorderColor,
                    onTap: () {
                      setState(() {
                        digitBorderColor = Colors.amber;
                        amountBorderColor =
                            Colors.black; // Reset other field's border
                      });
                    },
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(2), // Allow 2 digits
                      FilteringTextInputFormatter
                          .digitsOnly, // Allow only digits
                    ],
                  ),
                ),
                _inputRow(
                  "Enter Points:",
                  _buildInputField(
                    controller: amountController,
                    hint: "Enter Amount",
                    borderColor: amountBorderColor,
                    onTap: () {
                      setState(() {
                        amountBorderColor = Colors.amber;
                        digitBorderColor =
                            Colors.black; // Reset other field's border
                      });
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly, // Allow only digits
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildAddBidButton(),
                ),
              ],
            ),
          ),
          const Divider(), // Divider after input section
          _buildTableHeader(),
          const Divider(), // Divider after table header
          Expanded(
            child: bids.isEmpty
                ? Center(
                    child: Text(
                      'No bids yet. Add some data!',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: bids.length,
                    itemBuilder: (context, index) {
                      return _buildBidItem(bids[index], index);
                    },
                  ),
          ),
          if (bids.isNotEmpty)
            _buildBottomBar(), // Conditionally show bottom bar
        ],
      ),
    );
  }
}
