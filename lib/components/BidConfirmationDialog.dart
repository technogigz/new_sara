// BidConfirmationDialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// BidSuccessDialog.dart और BidFailureDialog.dart को अब यहां से इंपोर्ट करने की जरूरत नहीं है
// क्योंकि वे JodiBidScreen में उपयोग किए जाएंगे।

class BidConfirmationDialog extends StatelessWidget {
  final String gameTitle;
  final String gameDate;
  final List<Map<String, String>> bids;
  final int totalBids;
  final int totalBidsAmount;
  final int walletBalanceBeforeDeduction;
  final String? walletBalanceAfterDeduction;
  final String gameId;
  final String gameType;
  final VoidCallback onConfirm; // <--- Changed to VoidCallback

  const BidConfirmationDialog({
    Key? key,
    required this.gameTitle,
    required this.gameDate,
    required this.bids,
    required this.totalBids,
    required this.totalBidsAmount,
    required this.walletBalanceBeforeDeduction,
    this.walletBalanceAfterDeduction,
    required this.gameId,
    required this.gameType,
    required this.onConfirm, // <--- onConfirm is now a VoidCallback
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Safely parse walletBalanceAfterDeduction
    final int finalWalletBalanceAfterDeduction =
        int.tryParse(walletBalanceAfterDeduction ?? '') ??
        (walletBalanceBeforeDeduction - totalBidsAmount);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$gameTitle - $gameDate',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Digits',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Points',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Type',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(thickness: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: bids.length,
                itemBuilder: (context, index) {
                  final bid = bids[index];
                  final displayPoints = bid['points'] ?? bid['amount'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            bid['digit'] ?? '',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            displayPoints,
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            bid['type'] ?? '',
                            style: GoogleFonts.poppins(
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(thickness: 1),
            const SizedBox(height: 16),
            _buildSummaryRow('Total Bids', totalBids.toString()),
            _buildSummaryRow('Total Bids Amount', totalBidsAmount.toString()),
            _buildSummaryRow(
              'Wallet Balance Before Deduction',
              walletBalanceBeforeDeduction.toString(),
            ),
            _buildSummaryRow(
              'Wallet Balance After Deduction',
              finalWalletBalanceAfterDeduction.toString(),
              isNegative: finalWalletBalanceAfterDeduction < 0,
            ),
            const SizedBox(height: 16),
            Text(
              'Note: Bid Once Played Can Not Be Cancelled',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Simply pop the dialog
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Pop the dialog
                      onConfirm(); // <--- Call the onConfirm callback
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Submit',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isNegative ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
