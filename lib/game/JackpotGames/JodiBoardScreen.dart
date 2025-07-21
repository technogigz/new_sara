import 'package:flutter/material.dart';

class JodiBoardScreen extends StatelessWidget {
  final TextEditingController pointsController = TextEditingController();
  final TextEditingController jodiController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // Light gray background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {},
        ),
        title: Text(
          '01:00 PM - JODI BOARD',
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Enter Points Row
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
            SizedBox(height: 12),

            // Enter Jodi Row
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
            SizedBox(height: 24),

            // Jodi and Points Headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Jodi", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Points", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Divider(),
            // Add dynamic data here using ListView.builder if needed
          ],
        ),
      ),
    );
  }
}
