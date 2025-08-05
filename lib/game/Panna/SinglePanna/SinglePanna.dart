import 'dart:async'; // Added for Timer in AnimatedMessageBar logic
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../BidService.dart';
import '../../../components/AnimatedMessageBar.dart';
import '../../../components/BidConfirmationDialog.dart';
import '../../../components/BidFailureDialog.dart'; // Import BidFailureDialog
import '../../../components/BidSuccessDialog.dart'; // Import BidSuccessDialog

// Define the Single_Pana list globally or as a static member
const List<String> Single_Pana = [
  "120",
  "123",
  "124",
  "125",
  "126",
  "127",
  "128",
  "129",
  "130",
  "134",
  "135",
  "136",
  "137",
  "138",
  "139",
  "140",
  "145",
  "146",
  "147",
  "148",
  "149",
  "150",
  "156",
  "157",
  "158",
  "159",
  "160",
  "167",
  "168",
  "169",
  "170",
  "178",
  "179",
  "180",
  "189",
  "190",
  "230",
  "234",
  "235",
  "236",
  "237",
  "238",
  "239",
  "240",
  "245",
  "246",
  "247",
  "248",
  "249",
  "250",
  "256",
  "257",
  "258",
  "259",
  "260",
  "267",
  "268",
  "269",
  "270",
  "278",
  "279",
  "280",
  "289",
  "290",
  "340",
  "345",
  "346",
  "347",
  "348",
  "349",
  "350",
  "356",
  "357",
  "358",
  "359",
  "360",
  "367",
  "368",
  "369",
  "370",
  "378",
  "379",
  "380",
  "389",
  "390",
  "450",
  "456",
  "457",
  "458",
  "459",
  "460",
  "467",
  "468",
  "469",
  "470",
  "478",
  "479",
  "480",
  "489",
  "490",
  "560",
  "567",
  "568",
  "569",
  "570",
  "578",
  "579",
  "580",
  "589",
  "590",
  "670",
  "678",
  "679",
  "680",
  "689",
  "690",
  "780",
  "789",
  "790",
  "890",
];

class SinglePannaScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType;
  final String gameName;
  final bool selectionStatus;

  const SinglePannaScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
    this.gameName = "",
    required this.selectionStatus,
  }) : super(key: key);

  @override
  State<SinglePannaScreen> createState() => _SinglePannaScreenState();
}

class _SinglePannaScreenState extends State<SinglePannaScreen> {
  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<String> filteredPanaOptions = [];
  final FocusNode _digitFocusNode = FocusNode();

  final List<String> gameTypes = ['Open', 'Close'];
  String selectedGameType = 'Close';
  late String deviceId = "flutter_device"; // Placeholder, get actual value
  late String deviceName = "Flutter_App"; // Placeholder, get actual value;
  late bool accountActiveStatus;

  List<Map<String, String>> bids = [];
  int walletBalance = 0;
  late String accessToken;
  late String registerId;
  bool accountStatus = false;

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadSavedBids();
    digitController.addListener(_onDigitChanged);

    // Add listener for walletBalance
    GetStorage().listenKey('walletBalance', (value) {
      if (value is int) {
        walletBalance = value;
      } else if (value is String) {
        walletBalance = int.tryParse(value) ?? 0;
      } else {
        walletBalance = 0;
      }
    });

    // Add listener for accessToken
    GetStorage().listenKey('accessToken', (value) {
      accessToken = value ?? '';
    });

    // Add listener for registerId
    GetStorage().listenKey('registerId', (value) {
      registerId = value ?? '';
    });

    // Add listener for accountStatus
    GetStorage().listenKey('accountStatus', (value) {
      accountStatus = value ?? false;
    });
  }

  // DIGIT CHANGE HANDLER
  void _onDigitChanged() {
    final text = digitController.text;
    if (text.isEmpty) {
      if (mounted) {
        setState(() {
          filteredPanaOptions = [];
          _removeOverlay();
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        filteredPanaOptions = Single_Pana.where(
          (pana) => pana.startsWith(text),
        ).toList();

        if (filteredPanaOptions.isNotEmpty) {
          _showOverlay(filteredPanaOptions);
        } else {
          _removeOverlay();
        }
      });
    }
  }

  // SHOW SUGGESTIONS
  void _showOverlay(List<String> suggestions) {
    _removeOverlay(); // remove old overlay first
    late int selectedIndex;

    _overlayEntry = OverlayEntry(
      builder: (context) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 40),
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 150,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return InkWell(
                  onTap: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        digitController.text = suggestion;

                        digitController.selection = TextSelection.fromPosition(
                          TextPosition(offset: suggestion.length),
                        );
                      });

                      _removeOverlay();
                      FocusScope.of(context).unfocus();
                      _digitFocusNode.requestFocus();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(
                      suggestion,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Overlay.of(context).insert(_overlayEntry!);
      }
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      // Ensure state update if overlay is removed externally
      setState(() {
        // This ensures that if _isPanaSuggestionsVisible was used before,
        // its equivalent logic is covered by overlay being null.
      });
    }
  }

  void _loadInitialData() {
    final box = GetStorage();
    accessToken = box.read('accessToken') ?? '';
    registerId = box.read('registerId') ?? '';
    final dynamic storedValue = box.read('walletBalance');

    if (storedValue != null) {
      if (storedValue is int) {
        walletBalance = storedValue;
      } else if (storedValue is String) {
        walletBalance = int.tryParse(storedValue) ?? 0;
      } else {
        walletBalance = 0;
      }
    } else {
      walletBalance = 0;
    }
  }

  @override
  void dispose() {
    digitController.removeListener(_onDigitChanged);
    _removeOverlay(); // Crucial: Remove overlay when the widget is disposed
    digitController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void _loadSavedBids() {
    final box = GetStorage();
    final dynamic savedBidsRaw = box.read('placedBids');
    if (savedBidsRaw is List) {
      if (mounted) {
        setState(() {
          bids = savedBidsRaw
              .whereType<Map>()
              .map((item) {
                return {
                  'digit': item['digit']?.toString() ?? '',
                  'amount': item['amount']?.toString() ?? '',
                  'type': item['type']?.toString() ?? '',
                };
              })
              .where(
                (map) =>
                    map['digit']!.isNotEmpty &&
                    map['amount']!.isNotEmpty &&
                    map['type']!.isNotEmpty,
              )
              .toList();
        });
      }
    }
  }

  void _saveBids() {
    GetStorage().write('placedBids', bids);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      setState(() {
        _messageToShow = message;
        _isErrorForMessage = isError;
        _messageBarKey = UniqueKey();
      });
    }
  }

  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  // Future<void> _addBid() async {
  //   _clearMessage();
  //   _removeOverlay(); // Hide suggestions when add bid is pressed
  //
  //   final digit = digitController.text.trim();
  //   final amount = amountController.text.trim();
  //
  //   if (digit.isEmpty || amount.isEmpty) {
  //     _showMessage('Please fill in all fields.', isError: true);
  //     return;
  //   }
  //
  //   if (!Single_Pana.contains(digit)) {
  //     _showMessage('Please enter a valid Single Panna number.', isError: true);
  //     return;
  //   }
  //
  //   final intAmount = int.tryParse(amount);
  //   if (intAmount == null || intAmount <= 0) {
  //     _showMessage(
  //       'Please enter a valid amount greater than 0.',
  //       isError: true,
  //     );
  //     return;
  //   }
  //
  //   final existingIndex = bids.indexWhere(
  //     (entry) => entry['digit'] == digit && entry['type'] == selectedGameType,
  //   );
  //
  //   if (mounted) {
  //     setState(() {
  //       if (existingIndex != -1) {
  //         final currentAmount = int.parse(bids[existingIndex]['amount']!);
  //         bids[existingIndex]['amount'] = (currentAmount + intAmount)
  //             .toString();
  //         _showMessage(
  //           'Updated amount for Panna: $digit, Type: $selectedGameType.',
  //         );
  //       } else {
  //         bids.add({
  //           'digit': digit,
  //           'amount': amount,
  //           'type': selectedGameType,
  //         });
  //         _showMessage(
  //           'Added bid: Panna $digit, Amount $amount, Type $selectedGameType.',
  //         );
  //       }
  //       _saveBids();
  //       digitController.clear();
  //       amountController.clear();
  //       // _isPanaSuggestionsVisible = false; // Now handled by _removeOverlay() via _onDigitChanged
  //       FocusScope.of(context).unfocus();
  //     });
  //   }
  // }

  Future<void> _addBid() async {
    _clearMessage();
    _removeOverlay(); // Hide suggestions when add bid is pressed

    final digit = digitController.text.trim();
    final amount = amountController.text.trim();

    if (digit.isEmpty || amount.isEmpty) {
      _showMessage('Please fill in all fields.', isError: true);
      return;
    }

    if (!Single_Pana.contains(digit)) {
      _showMessage('Please enter a valid Single Panna number.', isError: true);
      return;
    }

    final intAmount = int.tryParse(amount);
    if (intAmount == null || intAmount < 10) {
      // <-- MODIFIED THIS LINE
      _showMessage(
        'Minimum amount is 10. Please enter a valid amount of 10 or more.', // <-- MODIFIED THIS LINE
        isError: true,
      );
      return;
    }

    final existingIndex = bids.indexWhere(
      (entry) => entry['digit'] == digit && entry['type'] == selectedGameType,
    );

    if (mounted) {
      setState(() {
        if (existingIndex != -1) {
          final currentAmount = int.parse(bids[existingIndex]['amount']!);
          bids[existingIndex]['amount'] = (currentAmount + intAmount)
              .toString();
          _showMessage(
            'Updated amount for Panna: $digit, Type: $selectedGameType.',
          );
        } else {
          bids.add({
            'digit': digit,
            'amount': amount,
            'type': selectedGameType,
          });
          _showMessage(
            'Added bid: Panna $digit, Amount $amount, Type $selectedGameType.',
          );
        }
        _saveBids();
        digitController.clear();
        amountController.clear();
        FocusScope.of(context).unfocus();
      });
    }
  }

  void _showBidConfirmationDialog() {
    _clearMessage();
    _removeOverlay(); // Hide suggestions

    if (bids.isEmpty) {
      _showMessage('Please add at least one bid to confirm.', isError: true);
      return;
    }

    int totalPoints = _getTotalPoints();

    if (totalPoints > walletBalance) {
      _showMessage('Insufficient wallet balance for all bids.', isError: true);
      return;
    }

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.title,
          gameDate: formattedDate,
          bids: bids,
          totalBids: bids.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            // Navigator.pop(dialogContext);
            bool success = await _placeFinalBids();
            if (success) {
              if (mounted) {
                setState(() {
                  bids.clear();
                });
              }
              _saveBids();
            }
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    final _bidService = BidService(GetStorage());

    final Map<String, String> bidPayload = {};
    int currentBatchTotalPoints = 0;

    for (var entry in bids) {
      if ((entry["type"] ?? "").toUpperCase() ==
          selectedGameType.toUpperCase()) {
        String digit = entry["digit"] ?? "";
        String amount = entry["amount"] ?? "0";

        if (digit.isNotEmpty && int.tryParse(amount) != null) {
          bidPayload[digit] = amount;
          currentBatchTotalPoints += int.parse(amount);
        }
      }
    }

    // 🟥 Validate empty payload
    if (bidPayload.isEmpty) {
      if (!context.mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'No valid bids for the selected game type.',
        ),
      );
      return false;
    }

    // 🟥 Validate auth
    if (accessToken.isEmpty || registerId.isEmpty) {
      if (!context.mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Authentication error. Please log in again.',
        ),
      );
      return false;
    }

    // 🟩 Try placing bid
    try {
      final result = await _bidService.placeFinalBids(
        gameName: widget.title,
        accessToken: accessToken,
        registerId: registerId,
        deviceId: deviceId,
        deviceName: deviceName,
        accountStatus: accountStatus,
        bidAmounts: bidPayload,
        selectedGameType: selectedGameType,
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: currentBatchTotalPoints,
      );

      if (!context.mounted) return false;

      final isSuccess = result['status'] == true;

      if (isSuccess) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );

        if (!context.mounted) return false;

        final newWalletBalance = walletBalance - currentBatchTotalPoints;

        setState(() {
          walletBalance = newWalletBalance;
        });
        await _bidService.updateWalletBalance(newWalletBalance);

        setState(() {
          bids.removeWhere(
            (element) =>
                (element["type"] ?? "").toUpperCase() ==
                selectedGameType.toUpperCase(),
          );
          _saveBids();
        });

        return true;
      } else {
        if (!context.mounted) return false;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(
            errorMessage: result['msg'] ?? 'Something went wrong',
          ),
        );

        setState(() {
          bids.removeWhere(
            (element) =>
                (element["type"] ?? "").toUpperCase() ==
                selectedGameType.toUpperCase(),
          );
          _saveBids();
        });
        return false;
      }
    } catch (e) {
      log('Error during bid placement: $e', name: 'SinglePannaScreenBidError');

      if (!context.mounted) return false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'An unexpected error occurred during bid submission.',
        ),
      );
      return false;
    }
  }

  Widget _inputRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          field,
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    // Build dropdown options based on selectionStatus
    final List<String> gameTypes = widget.selectionStatus
        ? ['Open', 'Close']
        : ['Close'];

    // Ensure selected value is valid for current list
    if (!gameTypes.contains(selectedGameType)) {
      selectedGameType = gameTypes.first;
    }

    return Container(
      height: 35,
      width: 150,
      alignment: Alignment.center,
      child: DropdownButtonFormField<String>(
        value: selectedGameType,
        isDense: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.orange, width: 2),
          ),
        ),
        items: gameTypes.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(type, style: GoogleFonts.poppins(fontSize: 14)),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null && mounted) {
            setState(() => selectedGameType = value);
            _removeOverlay(); // Hide suggestions if dropdown changes
          }
        },
      ),
    );
  }

  // INPUT FIELD BUILDER
  // INPUT FIELD BUILDER
  Widget _buildInputField(TextEditingController controller, String hint) {
    // If the controller is not the digit controller, use a standard TextFormField.
    if (controller != digitController) {
      return SizedBox(
        height: 35,
        width: 150,
        child: TextFormField(
          controller: controller,
          cursorColor: Colors.orange,
          keyboardType: TextInputType.number,
          onTap: () => _clearMessage(),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 0,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Colors.black),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Colors.black),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Colors.orange, width: 2),
            ),
          ),
          style: GoogleFonts.poppins(fontSize: 14),
        ),
      );
    }

    // Use Autocomplete for the digit controller.
    return SizedBox(
      height: 35,
      width: 150,
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            // No suggestions if the field is empty
            return const Iterable<String>.empty();
          }
          // Filter options based on user input
          return Single_Pana.where(
            (pana) => pana.startsWith(textEditingValue.text),
          );
        },
        onSelected: (String selection) {
          // Set the text field value to the selected option
          digitController.text = selection;
          _clearMessage();
          FocusScope.of(context).unfocus();
        },
        fieldViewBuilder:
            (
              BuildContext context,
              TextEditingController textEditingController,
              FocusNode focusNode,
              VoidCallback onFieldSubmitted,
            ) {
              // This builds the actual text field. Use the provided controllers and focus node.
              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                cursorColor: Colors.orange,
                keyboardType: TextInputType.number,
                onTap: () => _clearMessage(),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: hint,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(
                      color: Colors.orange,
                      width: 2,
                    ),
                  ),
                ),
                style: GoogleFonts.poppins(fontSize: 14),
              );
            },
        optionsViewBuilder:
            (
              BuildContext context,
              AutocompleteOnSelected<String> onSelected,
              Iterable<String> options,
            ) {
              // This builds the dropdown list of suggestions.
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 150,
                    height: 200, // You can set a fixed or max height
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String option = options.elementAt(index);
                        return InkWell(
                          onTap: () {
                            onSelected(option);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(option, style: GoogleFonts.poppins()),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "Panna",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Amount",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "Game Type",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  void _removeBid(int index) {
    _clearMessage();
    if (mounted) {
      setState(() {
        bids.removeAt(index);
      });
    }
    _saveBids();
    _showMessage('Bid removed from list.');
  }

  int _getTotalPoints() {
    return bids.fold(
      0,
      (sum, bid) => sum + (int.tryParse(bid['amount'] ?? '0') ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Wrap with GestureDetector to unfocus and hide overlay on tap outside
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus &&
            currentFocus.focusedChild != null) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
        _removeOverlay(); // Also explicitly remove overlay
      },
      child: Scaffold(
        backgroundColor: const Color(0xfff2f2f2),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Image.asset(
                    "assets/images/ic_wallet.png",
                    width: 22,
                    height: 22,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "$walletBalance",
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            // Stack is necessary for the AnimatedMessageBar and potentially the Overlay
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    _inputRow(
                      "Enter Single Panna:",
                      _buildInputField(digitController, "Bid Panna"),
                    ),
                    _inputRow(
                      "Enter Points:",
                      _buildInputField(amountController, "Enter Amount"),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        height: 35,
                        width: 150,
                        child: ElevatedButton(
                          onPressed: _addBid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            "ADD BID",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildTableHeader(),
                    Divider(color: Colors.grey.shade300),
                    Expanded(
                      child: bids.isEmpty
                          ? Center(
                              child: Text(
                                "No Bids Added",
                                style: GoogleFonts.poppins(
                                  color: Colors.black38,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: bids.length,
                              itemBuilder: (context, index) {
                                final bid = bids[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                      vertical: 10.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            bid['digit']!,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            bid['amount']!,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            bid['type']!,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 48,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            onPressed: () => _removeBid(index),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (bids.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total Points:",
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "${_getTotalPoints()}",
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                            SizedBox(
                              height: 40,
                              child: ElevatedButton(
                                onPressed: _showBidConfirmationDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  "CONFIRM",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_messageToShow != null)
                AnimatedMessageBar(
                  key: _messageBarKey,
                  message: _messageToShow!,
                  isError: _isErrorForMessage,
                  onDismissed: _clearMessage,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
