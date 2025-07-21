import 'package:flutter/material.dart';

class KingJackpotBiddingClosedDialog extends StatelessWidget {
  final String time;
  final String resultTime;
  final String bidLastTime;

  const KingJackpotBiddingClosedDialog({
    super.key,
    required this.time,
    required this.resultTime,
    required this.bidLastTime,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: Colors.red.shade50,
            radius: 30,
            child: const Icon(Icons.close, size: 40, color: Colors.red),
          ),
          const SizedBox(height: 16),
          const Text(
            "Bidding Is Closed For Today",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 10),
          Text(
            time,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black),
          ),
          const SizedBox(height: 20),
          _infoRow("Open Result Time :", resultTime),
          const SizedBox(height: 6),
          _infoRow("Open Bid Last Time :", bidLastTime),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
