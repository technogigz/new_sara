import 'package:flutter/material.dart';
import 'package:new_sara/Bids/BidHistory/BidHistoryScreen.dart';
import 'package:new_sara/Bids/KingJackpotBidHis/KingJackpotHistoryScreen.dart';
import 'package:new_sara/Bids/KingJackpotResultHis/KingJackpotResultScreen.dart';
import 'package:new_sara/Bids/KingStartlineBidHis/KingStarlineBidHistoryScreen.dart';
import 'package:new_sara/game/GameResults/GameResultScreen.dart';

import 'KingStarlineResultHis/KingStarlineResultHis.dart';

class BidScreen extends StatelessWidget {
  final List<_BidOption> bidOptions = [
    _BidOption(
      "BID HISTORY",
      "You can view your market bid history",
      Icons.trending_up,
    ),

    _BidOption(
      "King Starline Bid History",
      "You can view your starline bid history",
      Icons.account_balance,
    ),

    _BidOption(
      "KING JACKPOT BID HISTORY",
      "You can view your jackpot bid history",
      Icons.attach_money,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: bidOptions.length,
        itemBuilder: (context, index) {
          final item = bidOptions[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.grey.shade200,
            margin: const EdgeInsets.symmetric(vertical: 6),
            elevation: 0,
            child: ListTile(
              leading: Icon(item.icon, color: Colors.red, size: 36),
              title: Text(
                item.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(item.subtitle),
              trailing: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey.shade300,
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.red,
                ),
              ),
              onTap: () {
                // Navigate or perform action for each item according to its title
                if (item.title == "BID HISTORY") {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => BidHistoryPage()),
                  );
                }
                if (item.title == "Game Results") {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => GameResultScreen()),
                  );
                }
                if (item.title == "King Starline Bid History") {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => KingStarlineBidHistoryScreen(),
                    ),
                  );
                }
                if (item.title == "King Starline Result History") {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => KingStarlineResultScreen(),
                    ),
                  );
                }
                if (item.title == "KING JACKPOT BID HISTORY") {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => KingJackpotHistoryScreen(),
                    ),
                  );
                }
                if (item.title == "KING JACKPOT RESULT HISTORY") {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => KingJackpotResultScreen(),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _BidOption {
  final String title;
  final String subtitle;
  final IconData icon;

  _BidOption(this.title, this.subtitle, this.icon);
}
