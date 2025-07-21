import 'package:flutter/material.dart';
import 'package:new_sara/Fund/BankDetailsFragment.dart';

import 'AddFundScreen.dart';
import 'DepositHistoryPage.dart';
import 'WithdrawScreen.dart';
import 'WithdrawalHistoryPage.dart';

class FundsScreen extends StatelessWidget {
  final void Function(String title)? onItemTap;

  FundsScreen({super.key, this.onItemTap});

  final List<_FundOption> fundOptions = [
    _FundOption(
      "Add Fund",
      "You can add fund to your wallet",
      "assets/images/add_fund.png",
    ),
    _FundOption(
      "Withdraw Fund",
      "You can withdraw winnings",
      "assets/images/withdrawl_fund.png",
    ),
    _FundOption(
      "Add Bank Details",
      "You can add your bank details for withdrawls",
      "assets/images/add_bank_details.png",
    ),
    _FundOption(
      "Fund Deposit History",
      "You can see history of your deposit",
      "assets/images/fund_deposite_history.png",
    ),
    _FundOption(
      "Fund Withdraw History",
      "You can see history of your fund withdrawls",
      "assets/images/fund_withdraw_history.png",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade300,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: fundOptions.length,
        itemBuilder: (context, index) {
          final item = fundOptions[index];
          return InkWell(
            onTap: () {
              if (onItemTap == null) {
                onItemTap!(item.title);
              } else {
                switch (item.title) {
                  case "Add Fund":
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddFundScreen()),
                    );
                    break;
                  case "Withdraw Fund":
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => WithdrawScreen()),
                    );
                    break;
                  case "Add Bank Details":
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BankDetailsFragment(),
                      ),
                    );
                    break;
                  case "Fund Deposit History":
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DepositHistoryPage(),
                      ),
                    );
                    break;
                  case "Fund Withdraw History":
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WithdrawalHistoryPage(),
                      ),
                    );
                    break;
                  default:
                    break;
                }
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.symmetric(vertical: 6),
              elevation: 0,
              color: Colors.grey.shade200,
              child: ListTile(
                leading: Image.asset(
                  item.assetIconPath,
                  width: 36,
                  height: 36,
                  errorBuilder: (_, __, ___) => const Icon(Icons.error),
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Text(item.subtitle),
                trailing: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.grey.shade300,
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.amber,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FundOption {
  final String title;
  final String subtitle;
  final String assetIconPath;

  _FundOption(this.title, this.subtitle, this.assetIconPath);
}

// import 'package:flutter/material.dart';
//
// import 'AddFundScreen.dart';
//
// class FundsScreen extends StatelessWidget {
//   final void Function(String title)? onItemTap; // <-- new optional param
//   FundsScreen({super.key, this.onItemTap});
//
//   final List<_FundOption> fundOptions = [
//     _FundOption("Add Fund", "You can add fund to your wallet", "assets/images/add_fund.png"),
//     _FundOption("Withdraw Fund", "You can withdraw winnings", "assets/images/withdrawl_fund.png"),
//     _FundOption("Add Bank Details", "You can add your bank details for withdrawls", "assets/images/add_bank_details.png"),
//     _FundOption("Fund Deposit History", "You can see history of your deposit", "assets/images/fund_deposite_history.png"),
//     _FundOption("Fund Withdraw History", "You can see history of your fund withdrawls", "assets/images/fund_withdraw_history.png"),
//     _FundOption("Bank Changes History", "You can see history of your bank accounts", "assets/images/bank_change_history.png"),
//   ];
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: Colors.grey.shade300, // Light grey background
//       child: ListView.builder(
//         padding: const EdgeInsets.all(12),
//         itemCount: fundOptions.length,
//         itemBuilder: (context, index) {
//           final item = fundOptions[index];
//           return InkWell(
//             onTap: () {
//               if (onItemTap != null) {
//                 onItemTap!(item.title);
//               } else {
//                 switch (item.title) {
//                   case "Add Fund":
//                     Navigator.push(context, MaterialPageRoute(builder: (_) => AddFundScreen()));
//                     break;
//                   default:
//                   // add more cases as needed
//                 }
//               }
//             },
//             borderRadius: BorderRadius.circular(12),
//             child: Card(
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               margin: const EdgeInsets.symmetric(vertical: 6),
//               elevation: 0,
//               color: Colors.grey.shade200,
//               child: ListTile(
//                 leading: Image.asset(
//                   item.assetIconPath,
//                   width: 36,
//                   height: 36,
//                   errorBuilder: (_, __, ___) => const Icon(Icons.error),
//                 ),
//
//                 title: Text(
//                   item.title,
//                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
//                 ),
//                 subtitle: Text(item.subtitle),
//                 trailing: CircleAvatar(
//                   radius: 14,
//                   backgroundColor: Colors.grey.shade300,
//                   child: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.amber),
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
//
// }
//
//
// class _FundOption {
//   final String title;
//   final String subtitle;
//   final String assetIconPath;
//
//   _FundOption(this.title, this.subtitle, this.assetIconPath);
// }
//
