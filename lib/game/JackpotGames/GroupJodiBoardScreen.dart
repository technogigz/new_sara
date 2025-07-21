import 'package:flutter/material.dart';

class GroupJodiBoardScreen extends StatelessWidget {
  final TextEditingController jodiController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // light grey background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {},
        ),
        title: Text(
          '01:00 PM - GROUP JODI BOARD',
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
            // Enter Jodi
            Row(
              children: [
                Expanded(flex: 2, child: Text("Enter Jodi :")),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: jodiController,
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
            SizedBox(height: 12),

            // Enter Points
            Row(
              children: [
                Expanded(flex: 2, child: Text("Enter Points :")),
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

            // ADD Button
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

            // Table Headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Jodi", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Points", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Divider(),
            // Dynamic List to show added data can be placed here
          ],
        ),
      ),
    );
  }
}
