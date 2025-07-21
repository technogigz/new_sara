import 'package:flutter/material.dart';

class DigitBasedJodiBoardScreen extends StatelessWidget {
  final TextEditingController leftDigitController = TextEditingController();
  final TextEditingController rightDigitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {},
        ),
        title: Text(
          'PM - DIGIT BASED JODI BOARD',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.account_balance_wallet_outlined, color: Colors.black),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 12,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '5',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Left & Right Digit Inputs
            Row(
              children: [
                // Left Digit
                Expanded(
                  child: TextField(
                    controller: leftDigitController,
                    decoration: InputDecoration(
                      hintText: "Left Digit",
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: Icon(Icons.arrow_forward, color: Colors.orange),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Right Digit
                Expanded(
                  child: TextField(
                    controller: rightDigitController,
                    decoration: InputDecoration(
                      hintText: "Right Digit",
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: Icon(Icons.arrow_forward, color: Colors.orange),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Enter Points
            Row(
              children: [
                Expanded(
                  child: Text("Enter Points :"),
                  flex: 2,
                ),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: pointsController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: Icon(Icons.arrow_forward, color: Colors.orange),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Add Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[400],
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  "ADD",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 24),

            // Table Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Jodi", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Points", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Divider(),
          ],
        ),
      ),
    );
  }
}
