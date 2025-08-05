// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
//
// import '../Helper/TranslationHelper.dart';
// import 'AddFundScreen.dart';
// import 'BankDetailsFragment.dart';
// import 'DepositHistoryPage.dart';
// import 'WithdrawScreen.dart';
// import 'WithdrawalHistoryPage.dart';
//
// class FundsScreen extends StatefulWidget {
//   final void Function(String title)? onItemTap;
//
//   FundsScreen({super.key, this.onItemTap});
//
//   @override
//   _FundsScreenState createState() => _FundsScreenState();
// }
//
// class _FundsScreenState extends State<FundsScreen> {
//   final GetStorage _storage = GetStorage();
//   late final String _targetLanguageCode;
//   final TranslationHelper _translationHelper = TranslationHelper();
//
//   final List<_FundOption> _originalOptions = [
//     _FundOption(
//       "Add Fund",
//       "You can add fund to your wallet",
//       "assets/images/add_fund.png",
//     ),
//     _FundOption(
//       "Withdraw Fund",
//       "You can withdraw winnings",
//       "assets/images/withdrawl_fund.png",
//     ),
//     _FundOption(
//       "Add Bank Details",
//       "You can add your bank details for withdrawls",
//       "assets/images/add_bank_details.png",
//     ),
//     _FundOption(
//       "Fund Deposit History",
//       "You can see history of your deposit",
//       "assets/images/fund_deposite_history.png",
//     ),
//     _FundOption(
//       "Fund Withdraw History",
//       "You can see history of your fund withdrawls",
//       "assets/images/fund_withdraw_history.png",
//     ),
//   ];
//
//   late List<_FundOption> _translatedOptions;
//
//   @override
//   void initState() {
//     super.initState();
//     _targetLanguageCode = _storage.read('language') ?? 'en';
//     _translatedOptions = List.from(_originalOptions);
//     _translateOptions();
//   }
//
//   Future<void> _translateOptions() async {
//     if (_targetLanguageCode == 'en') {
//       return;
//     }
//
//     final List<_FundOption> newTranslatedOptions = [];
//     for (var option in _originalOptions) {
//       final translatedTitle = await TranslationHelper.translate(
//         option.title,
//         _targetLanguageCode,
//       );
//       final translatedSubtitle = await TranslationHelper.translate(
//         option.subtitle,
//         _targetLanguageCode,
//       );
//       newTranslatedOptions.add(
//         _FundOption(translatedTitle, translatedSubtitle, option.assetIconPath),
//       );
//     }
//
//     if (mounted) {
//       setState(() {
//         _translatedOptions = newTranslatedOptions;
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Container(
//         color: Colors.grey.shade300,
//         child: ListView.builder(
//           padding: const EdgeInsets.all(12),
//           itemCount: _translatedOptions.length,
//           itemBuilder: (context, index) {
//             final translatedItem = _translatedOptions[index];
//             final originalItem = _originalOptions[index];
//
//             return InkWell(
//               onTap: () {
//                 if (widget.onItemTap != null) {
//                   widget.onItemTap!(originalItem.title);
//                 } else {
//                   switch (originalItem.title) {
//                     case "Add Fund":
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => AddFundScreen(),
//                         ),
//                       );
//                       break;
//                     case "Withdraw Fund":
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => WithdrawScreen(),
//                         ),
//                       );
//                       break;
//                     case "Add Bank Details":
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => BankDetailsFragment(),
//                         ),
//                       );
//                       break;
//                     case "Fund Deposit History":
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => DepositHistoryPage(),
//                         ),
//                       );
//                       break;
//                     case "Fund Withdraw History":
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => WithdrawalHistoryPage(),
//                         ),
//                       );
//                       break;
//                     default:
//                       break;
//                   }
//                 }
//               },
//               borderRadius: BorderRadius.circular(12),
//               child: Card(
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 margin: const EdgeInsets.symmetric(vertical: 6),
//                 elevation: 0,
//                 color: Colors.grey.shade200,
//                 child: ListTile(
//                   leading: Image.asset(
//                     translatedItem.assetIconPath,
//                     width: 36,
//                     height: 36,
//                     color: Colors.orange,
//                     errorBuilder: (_, __, ___) => const Icon(Icons.error),
//                   ),
//                   title: Text(
//                     translatedItem.title,
//                     style: const TextStyle(
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black87,
//                     ),
//                   ),
//                   subtitle: Text(translatedItem.subtitle),
//                   trailing: CircleAvatar(
//                     radius: 14,
//                     backgroundColor: Colors.grey.shade300,
//                     child: const Icon(
//                       Icons.arrow_forward_ios,
//                       size: 16,
//                       color: Colors.orange,
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
//
// class _FundOption {
//   final String title;
//   final String subtitle;
//   final String assetIconPath;
//
//   _FundOption(this.title, this.subtitle, this.assetIconPath);
// }

import 'package:flutter/material.dart';
import 'package:new_sara/Fund/BankDetailsFragment.dart';

import '../Helper/TranslationHelper.dart';
import 'AddFundScreen.dart';
import 'DepositHistoryPage.dart';
import 'WithdrawScreen.dart';
import 'WithdrawalHistoryPage.dart';

class FundsScreen extends StatelessWidget {
  final void Function(String title)? onItemTap;
  TranslationHelper translationHelper = TranslationHelper();

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
    return SafeArea(
      child: Container(
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
                        MaterialPageRoute(
                          builder: (context) => AddFundScreen(),
                        ),
                      );
                      break;
                    case "Withdraw Fund":
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WithdrawScreen(),
                        ),
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
                    color: Colors.orange,
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
                      color: Colors.orange,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
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
