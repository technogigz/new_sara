import 'package:flutter/material.dart';

void closeBidDialogue({
  required BuildContext context,
  required String gameName,
  required String openResultTime,
  required String openBidLastTime,
  required String closeResultTime,
  required String closeBidLastTime,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Red cross icon
              CircleAvatar(
                backgroundColor: Colors.red.shade100,
                radius: 40,
                child: Icon(Icons.close, size: 50, color: Colors.red),
              ),
              SizedBox(height: 16),

              // Title
              Text(
                "Bidding Is Closed For Today",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),

              // Game name
              Text(
                gameName.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 16),

              // Timings
              _buildTimeRow("Open Result Time", openResultTime),
              _buildTimeRow("Open Bid Last Time", openBidLastTime),

              _buildTimeRow("Close Result Time", closeResultTime),
              _buildTimeRow("Close Bid Last Time", closeBidLastTime),

              SizedBox(height: 20),

              // OK Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "OK",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildTimeRow(String label, String time) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "$label :",
          style: TextStyle(color: Colors.grey[700]),
        ),
        Text(
          time.isNotEmpty ? time : "--:--",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    ),
  );
}
