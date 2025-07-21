import 'package:flutter/material.dart';

class JodiDigitScreen extends StatelessWidget {
  final TextEditingController jodiController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // Light background like the screenshot
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {},
        ),
        title: Text(
          '01:00 PM - JODI DIGIT',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.account_balance_wallet, color: Colors.black),
                onPressed: () {},
              ),
              Positioned(
                right: 6,
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
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Jodi Input
            Row(
              children: [
                Expanded(flex: 2, child: Text("Enter Jodi :")),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: jodiController,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      suffixIcon: Icon(Icons.arrow_forward, color: Colors.orange),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Points Input
            Row(
              children: [
                Expanded(flex: 2, child: Text("Enter Points :")),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: pointsController,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      suffixIcon: Icon(Icons.arrow_forward, color: Colors.orange),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Add Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text("ADD", style: TextStyle(fontSize: 16, color: Colors.black)),
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
            // You can add dynamically loaded entries below this row.
          ],
        ),
      ),
    );
  }
}
