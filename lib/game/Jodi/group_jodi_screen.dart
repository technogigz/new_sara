import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for TextInputFormatter

class GroupJodiScreen extends StatefulWidget {
  final String title;
  const GroupJodiScreen({
    super.key,
    required this.title,
    required int gameId,
    required String gameType,
  });

  @override
  State<GroupJodiScreen> createState() => _GroupJodiScreenState();
}

class _GroupJodiScreenState extends State<GroupJodiScreen> {
  final TextEditingController jodiController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  List<Map<String, String>> bids = [];

  @override
  void dispose() {
    jodiController.dispose();
    pointsController.dispose();
    super.dispose();
  }

  // Helper function to calculate the "cut" of a digit
  String _getCutDigit(String digit) {
    int d = int.parse(digit);
    return ((d + 5) % 10).toString();
  }

  void addBid() {
    String jodiInput = jodiController.text.trim();
    String points = pointsController.text.trim();

    // Validate Jodi input: must be 2 digits and numeric
    if (jodiInput.length != 2 || int.tryParse(jodiInput) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 2-digit Jodi.')),
      );
      return;
    }

    // Validate Points input: must not be empty
    if (points.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter Points.')));
      return;
    }

    // Parse the two digits from the Jodi input
    String digit1 = jodiInput[0];
    String digit2 = jodiInput[1];

    // Calculate their "cut" digits
    String cutDigit1 = _getCutDigit(digit1);
    String cutDigit2 = _getCutDigit(digit2);

    // Generate the 8 combinations
    List<String> generatedJodis = [
      '$digit1$digit2', // Original Jodi
      '$digit1$cutDigit2', // First digit and cut of second
      '$cutDigit1$digit2', // Cut of first digit and second
      '$cutDigit1$cutDigit2', // Cut of both digits
      '$digit2$digit1', // Reverse Jodi
      '$digit2$cutDigit1', // Second digit and cut of first
      '$cutDigit2$digit1', // Cut of second digit and first
      '$cutDigit2$cutDigit1', // Cut of second and cut of first
    ];

    setState(() {
      // Add each generated Jodi with the entered points
      for (String jodi in generatedJodis) {
        // Ensure no duplicate Jodis are added if they somehow generate the same number
        // This simple check prevents exact string duplicates.
        if (!bids.any((bid) => bid['jodi'] == jodi)) {
          bids.add({'jodi': jodi, 'points': points});
        }
      }
      // Clear the text fields after adding
      jodiController.clear();
      pointsController.clear();
    });
  }

  void removeBid(int index) {
    setState(() {
      bids.removeAt(index);
    });
  }

  int get totalPoints =>
      bids.fold(0, (sum, item) => sum + int.parse(item['points']!));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Colors.black),
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        actions: [
          Row(
            children: const [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.black,
              ), // Wallet icon
              SizedBox(width: 4),
              Padding(
                padding: EdgeInsets.only(top: 2.0),
                child: Text(
                  '5',
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
              SizedBox(width: 10),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Input row for "Enter Jodi"
                _buildInputRow("Enter Jodi", jodiController, isJodi: true),
                const SizedBox(height: 10),
                // Input row for "Enter Points"
                _buildInputRow("Enter Points", pointsController),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: addBid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5B544),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          8,
                        ), // Consistent rounded corners
                      ),
                      elevation: 3, // Subtle shadow
                    ),
                    child: const Text(
                      "ADD",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ), // White text
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (bids.isNotEmpty) // Conditionally render header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 2, // Adjusted flex for 'Jodi'
                    child: Text(
                      'Jodi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3, // Adjusted flex for 'Points'
                    child: Text(
                      'Points',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(width: 48), // Space for delete icon alignment
                ],
              ),
            ),
          Expanded(
            child: bids.isEmpty
                ? Center(
                    child: Text(
                      'No entries yet. Add some data!',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: bids.length,
                    itemBuilder: (context, index) {
                      final bid = bids[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            8,
                          ), // Consistent rounded corners
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1), // Subtle shadow
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  bid['jodi']!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ), // Display 'jodi'
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  bid['points']!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => removeBid(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (bids.isNotEmpty) // Conditionally render footer
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ), // Increased vertical padding
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
                        "Bids",
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      Text(
                        "${bids.length}", // Use bids.length
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
                        "Points",
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      Text(
                        "$totalPoints",
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
                        const SnackBar(content: Text('Submit pressed')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5B544),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 3,
                    ),
                    child: const Text(
                      "SUBMIT",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Helper widget for input rows
  Widget _buildInputRow(
    String label,
    TextEditingController controller, {
    bool isJodi = false,
  }) {
    return Row(
      children: [
        Expanded(
          // Use Expanded for the label to align better
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ), // Bold and larger font for labels
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3, // Give more space to the input field
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8), // More rounded corners
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, // Allow only digits
                if (isJodi)
                  LengthLimitingTextInputFormatter(
                    2,
                  ), // Limit to 2 digits for Jodi
              ],
              decoration: InputDecoration(
                hintText: isJodi
                    ? 'Enter 2-digit Jodi'
                    : 'Enter Points', // Hint text
                border: InputBorder.none, // Remove default border
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12, // Increased vertical padding
                ),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5B544), // Orange background
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 16,
                  ), // Arrow icon
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
