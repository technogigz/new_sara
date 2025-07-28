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

  const SinglePannaScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
    this.gameName = "",
  }) : super(key: key);

  @override
  State<SinglePannaScreen> createState() => _SinglePannaScreenState();
}

class _SinglePannaScreenState extends State<SinglePannaScreen> {
  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
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

  List<String> filteredPanaOptions = [];
  // bool _isPanaSuggestionsVisible = false; // This is now controlled by overlay visibility

  final LayerLink _layerLink =
      LayerLink(); // For connecting overlay to the input field
  OverlayEntry? _overlayEntry; // To manage the suggestion overlay

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadSavedBids();
    digitController.addListener(_onDigitChanged);

    // Add listener for walletBalance
    GetStorage().listenKey('walletBalance', (value) {
      if (mounted) {
        setState(() {
          if (value is int) {
            walletBalance = value;
          } else if (value is String) {
            walletBalance = int.tryParse(value) ?? 0;
          } else {
            walletBalance = 0;
          }
        });
      }
    });

    // Add listener for accessToken
    GetStorage().listenKey('accessToken', (value) {
      if (mounted) {
        setState(() {
          accessToken = value ?? '';
        });
      }
    });

    // Add listener for registerId
    GetStorage().listenKey('registerId', (value) {
      if (mounted) {
        setState(() {
          registerId = value ?? '';
        });
      }
    });

    // Add listener for accountStatus
    GetStorage().listenKey('accountStatus', (value) {
      if (mounted) {
        setState(() {
          accountStatus = value ?? false;
        });
      }
    });
  }

  void _onDigitChanged() {
    final text = digitController.text;
    if (text.isEmpty) {
      if (mounted) {
        setState(() {
          filteredPanaOptions = [];
          _removeOverlay(); // Hide overlay when text is empty
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
          _showOverlay(); // Show or update overlay
        } else {
          _removeOverlay(); // Hide overlay if no suggestions
        }
      });
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!
          .remove(); // Remove existing overlay if any before creating new one
    }
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context)?.insert(_overlayEntry!);
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

  OverlayEntry _createOverlayEntry() {
    // Find the RenderBox of the CompositedTransformTarget (the TextFormField)
    // to position the overlay correctly.
    // We use the _layerLink which is attached to the CompositedTransformTarget.

    return OverlayEntry(
      builder: (context) => Positioned(
        width: 150, // Match the TextFormField width
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(
            0.0,
            35.0 + 4.0,
          ), // Offset below the TextFormField (height + margin)
          child: Material(
            // Material is needed for elevation, shadow and proper theming
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 150,
              ), // Max height for the list
              decoration: BoxDecoration(
                // Explicit decoration for rounded corners if not using Material directly for shape
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: filteredPanaOptions.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      filteredPanaOptions[index],
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                    onTap: () {
                      if (mounted) {
                        digitController.text = filteredPanaOptions[index];
                        digitController.selection = TextSelection.fromPosition(
                          TextPosition(offset: digitController.text.length),
                        );
                        _removeOverlay(); // Hide overlay after selection
                        FocusScope.of(
                          context,
                        ).unfocus(); // Optionally hide keyboard
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
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
    if (intAmount == null || intAmount <= 0) {
      _showMessage(
        'Please enter a valid amount greater than 0.',
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
        // _isPanaSuggestionsVisible = false; // Now handled by _removeOverlay() via _onDigitChanged
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

  // Future<bool> _placeFinalBids() async {
  //   final _bidService = BidService(GetStorage());
  //
  //   final Map<String, String> bidPayload = {};
  //   int currentBatchTotalPoints =
  //       0; // Total for bids actually sent in this batch
  //
  //   for (var entry in bids) {
  //     if ((entry["type"] ?? "").toUpperCase() ==
  //         selectedGameType.toUpperCase()) {
  //       String digit = entry["digit"] ?? "";
  //       String amount = entry["amount"] ?? "0";
  //
  //       if (digit.isNotEmpty && int.tryParse(amount) != null) {
  //         bidPayload[digit] = amount;
  //         currentBatchTotalPoints += int.parse(amount);
  //       }
  //     }
  //   }
  //
  //   if (bidPayload.isEmpty) {
  //     if (!mounted) return false;
  //     await showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (_) => const BidFailureDialog(
  //         errorMessage: 'No valid bids for the selected game type.',
  //       ),
  //     );
  //     return false;
  //   }
  //
  //   if (accessToken.isEmpty || registerId.isEmpty) {
  //     if (!mounted) return false;
  //
  //     await showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (_) => const BidFailureDialog(
  //         errorMessage: 'Authentication error. Please log in again.',
  //       ),
  //     );
  //     return false;
  //   }
  //
  //   try {
  //     final result = await _bidService.placeFinalBids(
  //       gameName: widget.title,
  //       accessToken: accessToken,
  //       registerId: registerId,
  //       deviceId: deviceId,
  //       deviceName: deviceName,
  //       accountStatus: accountStatus,
  //       bidAmounts: bidPayload, // Pass the Map<String, String>
  //       selectedGameType: selectedGameType,
  //       gameId: widget.gameId,
  //       gameType: widget.gameType,
  //       totalBidAmount:
  //           currentBatchTotalPoints, // Pass the total for this batch
  //     );
  //
  //     if (!mounted) return false;
  //
  //     await showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (_) => result['status']
  //           ? const BidSuccessDialog()
  //           : BidFailureDialog(
  //               errorMessage: result['msg'] ?? 'Something went wrong',
  //             ),
  //     );
  //
  //     if (result['status'] == true) {
  //       final newWalletBalance =
  //           walletBalance -
  //           currentBatchTotalPoints; // Deduct only the sent amount
  //       setState(() {
  //         walletBalance = newWalletBalance;
  //       });
  //       await _bidService.updateWalletBalance(newWalletBalance);
  //
  //       setState(() {
  //         bids.removeWhere(
  //           (element) =>
  //               (element["type"] ?? "").toUpperCase() ==
  //               selectedGameType.toUpperCase(),
  //         );
  //         _saveBids();
  //       });
  //       return true;
  //     } else {
  //       return false;
  //     }
  //   } catch (e) {
  //     log('Error during bid placement: $e', name: 'SinglePannaScreenBidError');
  //     if (!mounted) return false;
  //
  //     await showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (_) => const BidFailureDialog(
  //         errorMessage: 'An unexpected error occurred during bid submission.',
  //       ),
  //     );
  //     return false;
  //   }
  // }

  Future<bool> _placeFinalBids() async {
    final _bidService = BidService(GetStorage());

    final Map<String, String> bidPayload = {};
    int currentBatchTotalPoints =
        0; // Total for bids actually sent in this batch

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

    if (bidPayload.isEmpty) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'No valid bids for the selected game type.',
        ),
      );
      return false;
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      if (!mounted) return false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Authentication error. Please log in again.',
        ),
      );
      return false;
    }

    try {
      final result = await _bidService.placeFinalBids(
        gameName: widget.title,
        accessToken: accessToken,
        registerId: registerId,
        deviceId: deviceId,
        deviceName: deviceName,
        accountStatus: accountStatus,
        bidAmounts: bidPayload, // Pass the Map<String, String>
        selectedGameType: selectedGameType,
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount:
            currentBatchTotalPoints, // Pass the total for this batch
      );

      if (!mounted) return false;

      // Use if-else to show success or failure dialog
      if (result['status'] == true) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );

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
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(
            errorMessage: result['msg'] ?? 'Something went wrong',
          ),
        );
        return false;
      }
    } catch (e) {
      log('Error during bid placement: $e', name: 'SinglePannaScreenBidError');
      if (!mounted) return false;

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
            borderSide: const BorderSide(color: Colors.amber, width: 2),
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

  Widget _buildInputField(TextEditingController controller, String hint) {
    Widget textField = SizedBox(
      height: 35,
      width: 150,
      child: TextFormField(
        controller: controller,
        cursorColor: Colors.amber,
        keyboardType: TextInputType.number,
        // Remove content limit by not applying any input formatters
        onTap: () {
          _clearMessage();
          if (controller == digitController) {
            _onDigitChanged(); // Ensure suggestions show on tap if there's text
          } else {
            _removeOverlay(); // Hide Pana suggestions if tapping amount field
          }
        },
        onEditingComplete: () {
          if (controller == digitController) {
            // Let _onDigitChanged handle overlay based on text, or remove if needed
            if (digitController.text.isEmpty) _removeOverlay();
          }
          FocusScope.of(context).unfocus(); // General behavior
        },
        onTapOutside: (_) {
          // Added to dismiss suggestions when tapping outside
          if (controller == digitController && _overlayEntry != null) {
            _removeOverlay();
          }
        },
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
            borderSide: const BorderSide(color: Colors.amber, width: 2),
          ),
        ),
        style: GoogleFonts.poppins(fontSize: 14),
      ),
    );

    if (controller == digitController) {
      // Wrap the Digit TextFormField with CompositedTransformTarget
      return CompositedTransformTarget(link: _layerLink, child: textField);
    }
    return textField;
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
                    'assets/images/wallet_icon.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.account_balance_wallet, size: 24),
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
        body: Stack(
          // Stack is necessary for the AnimatedMessageBar and potentially the Overlay
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  _inputRow("Select Game Type:", _buildDropdown()),
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
                          backgroundColor: Colors.amber,
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
                                margin: const EdgeInsets.symmetric(vertical: 4),
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
                                backgroundColor: Colors.green.shade500,
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
    );
  }
}

// import 'dart:async'; // Added for Timer in AnimatedMessageBar logic
//
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
//
// import '../../../BidService.dart';
// import '../../../components/AnimatedMessageBar.dart';
// import '../../../components/BidConfirmationDialog.dart';
// import '../../../components/BidFailureDialog.dart'; // Import BidFailureDialog
// import '../../../components/BidSuccessDialog.dart'; // Import BidSuccessDialog
//
// // Define the Single_Pana list globally or as a static member
// const List<String> Single_Pana = [
//   "120",
//   "123",
//   "124",
//   "125",
//   "126",
//   "127",
//   "128",
//   "129",
//   "130",
//   "134",
//   "135",
//   "136",
//   "137",
//   "138",
//   "139",
//   "140",
//   "145",
//   "146",
//   "147",
//   "148",
//   "149",
//   "150",
//   "156",
//   "157",
//   "158",
//   "159",
//   "160",
//   "167",
//   "168",
//   "169",
//   "170",
//   "178",
//   "179",
//   "180",
//   "189",
//   "190",
//   "230",
//   "234",
//   "235",
//   "236",
//   "237",
//   "238",
//   "239",
//   "240",
//   "245",
//   "246",
//   "247",
//   "248",
//   "249",
//   "250",
//   "256",
//   "257",
//   "258",
//   "259",
//   "260",
//   "267",
//   "268",
//   "269",
//   "270",
//   "278",
//   "279",
//   "280",
//   "289",
//   "290",
//   "340",
//   "345",
//   "346",
//   "347",
//   "348",
//   "349",
//   "350",
//   "356",
//   "357",
//   "358",
//   "359",
//   "360",
//   "367",
//   "368",
//   "369",
//   "370",
//   "378",
//   "379",
//   "380",
//   "389",
//   "390",
//   "450",
//   "456",
//   "457",
//   "458",
//   "459",
//   "460",
//   "467",
//   "468",
//   "469",
//   "470",
//   "478",
//   "479",
//   "480",
//   "489",
//   "490",
//   "560",
//   "567",
//   "568",
//   "569",
//   "570",
//   "578",
//   "579",
//   "580",
//   "589",
//   "590",
//   "670",
//   "678",
//   "679",
//   "680",
//   "689",
//   "690",
//   "780",
//   "789",
//   "790",
//   "890",
// ];
//
// class SinglePannaScreen extends StatefulWidget {
//   final String title;
//   final int gameId;
//   final String gameType;
//   final String gameName;
//
//   const SinglePannaScreen({
//     Key? key,
//     required this.title,
//     required this.gameId,
//     required this.gameType,
//     this.gameName = "",
//   }) : super(key: key);
//
//   @override
//   State<SinglePannaScreen> createState() => _SinglePannaScreenState();
// }
//
// class _SinglePannaScreenState extends State<SinglePannaScreen> {
//   final TextEditingController digitController = TextEditingController();
//   final TextEditingController amountController = TextEditingController();
//   final List<String> gameTypes = ['Open', 'Close'];
//   String selectedGameType = 'Close';
//   late String deviceId = "flutter_device"; // Placeholder, get actual value
//   late String deviceName = "Flutter_App"; // Placeholder, get actual value;
//   late bool accountActiveStatus;
//
//   List<Map<String, String>> bids = [];
//   int walletBalance = 0;
//   late String accessToken;
//   late String registerId;
//   bool accountStatus = false;
//
//   String? _messageToShow;
//   bool _isErrorForMessage = false;
//   Key _messageBarKey = UniqueKey();
//
//   List<String> filteredPanaOptions = [];
//   // bool _isPanaSuggestionsVisible = false; // This is now controlled by overlay visibility
//
//   final LayerLink _layerLink =
//       LayerLink(); // For connecting overlay to the input field
//   OverlayEntry? _overlayEntry; // To manage the suggestion overlay
//
//   @override
//   void initState() {
//     super.initState();
//     _loadInitialData();
//     _loadSavedBids();
//     digitController.addListener(_onDigitChanged);
//
//     // Add listener for walletBalance
//     GetStorage().listenKey('walletBalance', (value) {
//       if (mounted) {
//         setState(() {
//           if (value is int) {
//             walletBalance = value;
//           } else if (value is String) {
//             walletBalance = int.tryParse(value) ?? 0;
//           } else {
//             walletBalance = 0;
//           }
//         });
//       }
//     });
//
//     // Add listener for accessToken
//     GetStorage().listenKey('accessToken', (value) {
//       if (mounted) {
//         setState(() {
//           accessToken = value ?? '';
//         });
//       }
//     });
//
//     // Add listener for registerId
//     GetStorage().listenKey('registerId', (value) {
//       if (mounted) {
//         setState(() {
//           registerId = value ?? '';
//         });
//       }
//     });
//
//     // Add listener for accountStatus
//     GetStorage().listenKey('accountStatus', (value) {
//       if (mounted) {
//         setState(() {
//           accountStatus = value ?? false;
//         });
//       }
//     });
//   }
//
//   void _onDigitChanged() {
//     final text = digitController.text;
//     if (text.isEmpty) {
//       if (mounted) {
//         setState(() {
//           filteredPanaOptions = [];
//           _removeOverlay(); // Hide overlay when text is empty
//         });
//       }
//       return;
//     }
//
//     if (mounted) {
//       setState(() {
//         filteredPanaOptions = Single_Pana.where(
//           (pana) => pana.startsWith(text),
//         ).toList();
//         if (filteredPanaOptions.isNotEmpty) {
//           _showOverlay(); // Show or update overlay
//         } else {
//           _removeOverlay(); // Hide overlay if no suggestions
//         }
//       });
//     }
//   }
//
//   void _showOverlay() {
//     if (_overlayEntry != null) {
//       _overlayEntry!
//           .remove(); // Remove existing overlay if any before creating new one
//     }
//     _overlayEntry = _createOverlayEntry();
//     Overlay.of(context)?.insert(_overlayEntry!);
//   }
//
//   void _removeOverlay() {
//     _overlayEntry?.remove();
//     _overlayEntry = null;
//     if (mounted) {
//       // Ensure state update if overlay is removed externally
//       setState(() {
//         // This ensures that if _isPanaSuggestionsVisible was used before,
//         // its equivalent logic is covered by overlay being null.
//       });
//     }
//   }
//
//   OverlayEntry _createOverlayEntry() {
//     // Find the RenderBox of the CompositedTransformTarget (the TextFormField)
//     // to position the overlay correctly.
//     // We use the _layerLink which is attached to the CompositedTransformTarget.
//
//     return OverlayEntry(
//       builder: (context) => Positioned(
//         width: 150, // Match the TextFormField width
//         child: CompositedTransformFollower(
//           link: _layerLink,
//           showWhenUnlinked: false,
//           offset: const Offset(
//             0.0,
//             35.0 + 4.0,
//           ), // Offset below the TextFormField (height + margin)
//           child: Material(
//             // Material is needed for elevation, shadow and proper theming
//             elevation: 4.0,
//             borderRadius: BorderRadius.circular(8),
//             child: Container(
//               constraints: const BoxConstraints(
//                 maxHeight: 150,
//               ), // Max height for the list
//               decoration: BoxDecoration(
//                 // Explicit decoration for rounded corners if not using Material directly for shape
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: ListView.builder(
//                 padding: EdgeInsets.zero,
//                 shrinkWrap: true,
//                 itemCount: filteredPanaOptions.length,
//                 itemBuilder: (context, index) {
//                   return ListTile(
//                     dense: true,
//                     title: Text(
//                       filteredPanaOptions[index],
//                       style: GoogleFonts.poppins(fontSize: 13),
//                     ),
//                     onTap: () {
//                       if (mounted) {
//                         digitController.text = filteredPanaOptions[index];
//                         digitController.selection = TextSelection.fromPosition(
//                           TextPosition(offset: digitController.text.length),
//                         );
//                         _removeOverlay(); // Hide overlay after selection
//                         FocusScope.of(
//                           context,
//                         ).unfocus(); // Optionally hide keyboard
//                       }
//                     },
//                   );
//                 },
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _loadInitialData() {
//     final box = GetStorage();
//     accessToken = box.read('accessToken') ?? '';
//     registerId = box.read('registerId') ?? '';
//     final dynamic storedValue = box.read('walletBalance');
//
//     if (storedValue != null) {
//       if (storedValue is int) {
//         walletBalance = storedValue;
//       } else if (storedValue is String) {
//         walletBalance = int.tryParse(storedValue) ?? 0;
//       } else {
//         walletBalance = 0;
//       }
//     } else {
//       walletBalance = 0;
//     }
//   }
//
//   @override
//   void dispose() {
//     digitController.removeListener(_onDigitChanged);
//     _removeOverlay(); // Crucial: Remove overlay when the widget is disposed
//     digitController.dispose();
//     amountController.dispose();
//     super.dispose();
//   }
//
//   void _loadSavedBids() {
//     final box = GetStorage();
//     final dynamic savedBidsRaw = box.read('placedBids');
//     if (savedBidsRaw is List) {
//       if (mounted) {
//         setState(() {
//           bids = savedBidsRaw
//               .whereType<Map>()
//               .map((item) {
//                 return {
//                   'digit': item['digit']?.toString() ?? '',
//                   'amount': item['amount']?.toString() ?? '',
//                   'type': item['type']?.toString() ?? '',
//                 };
//               })
//               .where(
//                 (map) =>
//                     map['digit']!.isNotEmpty &&
//                     map['amount']!.isNotEmpty &&
//                     map['type']!.isNotEmpty,
//               )
//               .toList();
//         });
//       }
//     }
//   }
//
//   void _saveBids() {
//     GetStorage().write('placedBids', bids);
//   }
//
//   void _showMessage(String message, {bool isError = false}) {
//     if (mounted) {
//       setState(() {
//         _messageToShow = message;
//         _isErrorForMessage = isError;
//         _messageBarKey = UniqueKey();
//       });
//     }
//   }
//
//   void _clearMessage() {
//     if (mounted) {
//       setState(() {
//         _messageToShow = null;
//       });
//     }
//   }
//
//   Future<void> _addBid() async {
//     _clearMessage();
//     _removeOverlay(); // Hide suggestions when add bid is pressed
//
//     final digit = digitController.text.trim();
//     final amount = amountController.text.trim();
//
//     if (digit.isEmpty || amount.isEmpty) {
//       _showMessage('Please fill in all fields.', isError: true);
//       return;
//     }
//
//     if (!Single_Pana.contains(digit)) {
//       _showMessage('Please enter a valid Single Panna number.', isError: true);
//       return;
//     }
//
//     final intAmount = int.tryParse(amount);
//     if (intAmount == null || intAmount <= 0) {
//       _showMessage(
//         'Please enter a valid amount greater than 0.',
//         isError: true,
//       );
//       return;
//     }
//
//     final existingIndex = bids.indexWhere(
//       (entry) => entry['digit'] == digit && entry['type'] == selectedGameType,
//     );
//
//     if (mounted) {
//       setState(() {
//         if (existingIndex != -1) {
//           final currentAmount = int.parse(bids[existingIndex]['amount']!);
//           bids[existingIndex]['amount'] = (currentAmount + intAmount)
//               .toString();
//           _showMessage(
//             'Updated amount for Panna: $digit, Type: $selectedGameType.',
//           );
//         } else {
//           bids.add({
//             'digit': digit,
//             'amount': amount,
//             'type': selectedGameType,
//           });
//           _showMessage(
//             'Added bid: Panna $digit, Amount $amount, Type $selectedGameType.',
//           );
//         }
//         _saveBids();
//         digitController.clear();
//         amountController.clear();
//         // _isPanaSuggestionsVisible = false; // Now handled by _removeOverlay() via _onDigitChanged
//         FocusScope.of(context).unfocus();
//       });
//     }
//   }
//
//   void _showBidConfirmationDialog() {
//     _clearMessage();
//     _removeOverlay(); // Hide suggestions
//
//     if (bids.isEmpty) {
//       _showMessage('Please add at least one bid to confirm.', isError: true);
//       return;
//     }
//
//     int totalPoints = _getTotalPoints();
//
//     if (totalPoints > walletBalance) {
//       _showMessage('Insufficient wallet balance for all bids.', isError: true);
//       return;
//     }
//
//     final String formattedDate = DateFormat(
//       'dd MMM yyyy, hh:mm a',
//     ).format(DateTime.now());
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return BidConfirmationDialog(
//           gameTitle: widget.title,
//           gameDate: formattedDate,
//           bids: bids,
//           totalBids: bids.length,
//           totalBidsAmount: totalPoints,
//           walletBalanceBeforeDeduction: walletBalance,
//           walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameType,
//           onConfirm: () async {
//             Navigator.pop(dialogContext);
//             bool success = await _placeFinalBids();
//             if (success) {
//               if (mounted) {
//                 setState(() {
//                   bids.clear();
//                 });
//               }
//               _saveBids();
//             }
//           },
//         );
//       },
//     );
//   }
//
//   // Future<bool> _placeFinalBids() async {
//   //   String url;
//   //   if (widget.gameName.toLowerCase().contains('jackpot')) {
//   //     url = '${Constant.apiEndpoint}place-jackpot-bid';
//   //   } else if (widget.gameName.toLowerCase().contains('starline')) {
//   //     url = '${Constant.apiEndpoint}place-starline-bid';
//   //   } else {
//   //     url = '${Constant.apiEndpoint}place-bid';
//   //   }
//   //
//   //   if (accessToken.isEmpty || registerId.isEmpty) {
//   //     if (mounted) {
//   //       showDialog(
//   //         context: context,
//   //         builder: (BuildContext context) {
//   //           return const BidFailureDialog(
//   //             errorMessage: 'Authentication error. Please log in again.',
//   //           );
//   //         },
//   //       );
//   //     }
//   //     return false;
//   //   }
//   //
//   //   final String deviceId =
//   //       GetStorage().read('deviceId') ?? 'unknown_device_id';
//   //   final String deviceName =
//   //       GetStorage().read('deviceName') ?? 'unknown_device_name';
//   //
//   //   final headers = {
//   //     'deviceId': deviceId,
//   //     'deviceName': deviceName,
//   //     'accessStatus': '1',
//   //     'Content-Type': 'application/json',
//   //     'Authorization': 'Bearer $accessToken',
//   //   };
//   //
//   //   final List<Map<String, dynamic>> bidPayload = bids.map((entry) {
//   //     String sessionType = entry["type"] ?? "CLOSE";
//   //     String digit = entry["digit"] ?? "";
//   //     int bidAmount = int.tryParse(entry["amount"] ?? '0') ?? 0;
//   //
//   //     return {
//   //       "sessionType": sessionType.toUpperCase(),
//   //       "digit": "",
//   //       "pana": digit,
//   //       "bidAmount": bidAmount,
//   //     };
//   //   }).toList();
//   //
//   //   final body = {
//   //     "registerId": registerId,
//   //     "gameId": widget.gameId,
//   //     "bidAmount": _getTotalPoints(),
//   //     "gameType": widget.gameType,
//   //     "bid": bidPayload,
//   //   };
//   //
//   //   String curlCommand = 'curl -X POST \\\n  ${Uri.parse(url)} \\';
//   //   headers.forEach((key, value) {
//   //     curlCommand += '\n  -H "$key: $value" \\';
//   //   });
//   //   curlCommand += '\n  -d \'${jsonEncode(body)}\'';
//   //
//   //   log('CURL Command for Final Bid Submission:\n$curlCommand');
//   //   log('Request Headers for Final Bid Submission: $headers');
//   //   log('Request Body for Final Bid Submission: ${jsonEncode(body)}');
//   //
//   //   try {
//   //     final response = await http.post(
//   //       Uri.parse(url),
//   //       headers: headers,
//   //       body: jsonEncode(body),
//   //     );
//   //
//   //     log('Response Status Code: ${response.statusCode}');
//   //     log('Response Body: ${response.body}');
//   //
//   //     final Map<String, dynamic> responseBody = json.decode(response.body);
//   //
//   //     if (mounted) {
//   //       if (response.statusCode == 200 && responseBody['status'] == true) {
//   //         int currentWallet = walletBalance;
//   //         int deductedAmount = _getTotalPoints();
//   //         int newWalletBalance = currentWallet - deductedAmount;
//   //
//   //         GetStorage().write('walletBalance', newWalletBalance.toString());
//   //         setState(() {
//   //           walletBalance = newWalletBalance;
//   //         });
//   //
//   //         showDialog(
//   //           context: context,
//   //           barrierDismissible: false,
//   //           builder: (BuildContext context) {
//   //             return const BidSuccessDialog();
//   //           },
//   //         );
//   //         return true;
//   //       } else {
//   //         String errorMessage =
//   //             responseBody['msg'] ?? "Unknown error occurred.";
//   //         showDialog(
//   //           context: context,
//   //           builder: (BuildContext context) {
//   //             return BidFailureDialog(errorMessage: errorMessage);
//   //           },
//   //         );
//   //         return false;
//   //       }
//   //     }
//   //     return false;
//   //   } catch (e) {
//   //     log('Network error during bid submission: $e');
//   //     if (mounted) {
//   //       showDialog(
//   //         context: context,
//   //         builder: (BuildContext context) {
//   //           return BidFailureDialog(
//   //             errorMessage: 'Network error: ${e.toString()}',
//   //           );
//   //         },
//   //       );
//   //     }
//   //     return false;
//   //   }
//   // }
//
//   Future<bool> _placeFinalBids() async {
//     final _bidService = BidService(GetStorage());
//     final Map<String, String> bidAmounts = {
//       for (var entry in bids) entry['jodi']!: entry['points'] ?? '0',
//     };
//
//     if (accessToken.isEmpty || registerId.isEmpty) {
//       if (!mounted) return false;
//
//       await showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => const BidFailureDialog(
//           errorMessage: 'Authentication error. Please log in again.',
//         ),
//       );
//       return false;
//     }
//
//     try {
//       final result = await _bidService.placeFinalBids(
//         gameName: widget.title,
//         accessToken: accessToken,
//         registerId: registerId,
//         deviceId: deviceId,
//         deviceName: deviceName,
//         accountStatus: accountActiveStatus,
//         bidAmounts: bidAmounts,
//         selectedGameType: "OPEN",
//         gameId: widget.gameId,
//         gameType: widget.gameType,
//         totalBidAmount: _getTotalPoints(),
//       );
//
//       if (!mounted) return false;
//
//       await showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => result['status']
//             ? const BidSuccessDialog()
//             : BidFailureDialog(
//                 errorMessage: result['msg'] ?? 'Something went wrong',
//               ),
//       );
//
//       if (result['status'] == true) {
//         final newWalletBalance = walletBalance - _getTotalPoints();
//         setState(() {
//           walletBalance = newWalletBalance;
//         });
//         await _bidService.updateWalletBalance(newWalletBalance);
//         return true;
//       } else {
//         return false;
//       }
//     } catch (e) {
//       if (!mounted) return false;
//
//       await showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => const BidFailureDialog(
//           errorMessage: 'An unexpected error occurred.',
//         ),
//       );
//       return false;
//     }
//   }
//
//   Widget _inputRow(String label, Widget field) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Text(
//             label,
//             style: GoogleFonts.poppins(
//               fontSize: 13,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           field,
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDropdown() {
//     return Container(
//       height: 35,
//       width: 150,
//       alignment: Alignment.center,
//       child: DropdownButtonFormField<String>(
//         value: selectedGameType,
//         isDense: true,
//         decoration: InputDecoration(
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 12,
//             vertical: 0,
//           ),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.black),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.black),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.amber, width: 2),
//           ),
//         ),
//         items: gameTypes.map((type) {
//           return DropdownMenuItem(
//             value: type,
//             child: Text(type, style: GoogleFonts.poppins(fontSize: 14)),
//           );
//         }).toList(),
//         onChanged: (value) {
//           if (value != null && mounted) {
//             setState(() => selectedGameType = value);
//             _removeOverlay(); // Hide suggestions if dropdown changes
//           }
//         },
//       ),
//     );
//   }
//
//   Widget _buildInputField(TextEditingController controller, String hint) {
//     Widget textField = SizedBox(
//       height: 35,
//       width: 150,
//       child: TextFormField(
//         controller: controller,
//         cursorColor: Colors.amber,
//         keyboardType: TextInputType.number,
//         // Remove content limit by not applying any input formatters
//         onTap: () {
//           _clearMessage();
//           if (controller == digitController) {
//             _onDigitChanged(); // Ensure suggestions show on tap if there's text
//           } else {
//             _removeOverlay(); // Hide Pana suggestions if tapping amount field
//           }
//         },
//         onEditingComplete: () {
//           if (controller == digitController) {
//             // Let _onDigitChanged handle overlay based on text, or remove if needed
//             if (digitController.text.isEmpty) _removeOverlay();
//           }
//           FocusScope.of(context).unfocus(); // General behavior
//         },
//         onTapOutside: (_) {
//           // Added to dismiss suggestions when tapping outside
//           if (controller == digitController && _overlayEntry != null) {
//             _removeOverlay();
//           }
//         },
//         textAlignVertical: TextAlignVertical.center,
//         decoration: InputDecoration(
//           hintText: hint,
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 0,
//           ),
//           filled: true,
//           fillColor: Colors.white,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.black),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.black),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.amber, width: 2),
//           ),
//         ),
//         style: GoogleFonts.poppins(fontSize: 14),
//       ),
//     );
//
//     if (controller == digitController) {
//       // Wrap the Digit TextFormField with CompositedTransformTarget
//       return CompositedTransformTarget(link: _layerLink, child: textField);
//     }
//     return textField;
//   }
//
//   Widget _buildTableHeader() {
//     return Padding(
//       padding: const EdgeInsets.only(top: 20, bottom: 8),
//       child: Row(
//         children: [
//           Expanded(
//             flex: 2,
//             child: Text(
//               "Panna",
//               textAlign: TextAlign.center,
//               style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
//             ),
//           ),
//           Expanded(
//             flex: 2,
//             child: Text(
//               "Amount",
//               textAlign: TextAlign.center,
//               style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
//             ),
//           ),
//           Expanded(
//             flex: 3,
//             child: Text(
//               "Game Type",
//               textAlign: TextAlign.center,
//               style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
//             ),
//           ),
//           const SizedBox(width: 48),
//         ],
//       ),
//     );
//   }
//
//   void _removeBid(int index) {
//     _clearMessage();
//     if (mounted) {
//       setState(() {
//         bids.removeAt(index);
//       });
//     }
//     _saveBids();
//     _showMessage('Bid removed from list.');
//   }
//
//   int _getTotalPoints() {
//     return bids.fold(
//       0,
//       (sum, bid) => sum + (int.tryParse(bid['amount'] ?? '0') ?? 0),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       // Wrap with GestureDetector to unfocus and hide overlay on tap outside
//       onTap: () {
//         FocusScopeNode currentFocus = FocusScope.of(context);
//         if (!currentFocus.hasPrimaryFocus &&
//             currentFocus.focusedChild != null) {
//           FocusManager.instance.primaryFocus?.unfocus();
//         }
//         _removeOverlay(); // Also explicitly remove overlay
//       },
//       child: Scaffold(
//         backgroundColor: const Color(0xfff2f2f2),
//         appBar: AppBar(
//           backgroundColor: Colors.white,
//           elevation: 0,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
//             onPressed: () => Navigator.pop(context),
//           ),
//           title: Text(
//             widget.title,
//             style: GoogleFonts.poppins(
//               fontWeight: FontWeight.bold,
//               fontSize: 16,
//               color: Colors.black,
//             ),
//           ),
//           actions: [
//             Padding(
//               padding: const EdgeInsets.only(right: 16),
//               child: Row(
//                 children: [
//                   Image.asset(
//                     'assets/images/wallet_icon.png',
//                     width: 24,
//                     height: 24,
//                     errorBuilder: (context, error, stackTrace) =>
//                         const Icon(Icons.account_balance_wallet, size: 24),
//                   ),
//                   const SizedBox(width: 4),
//                   Text(
//                     "$walletBalance",
//                     style: GoogleFonts.poppins(
//                       color: Colors.black,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         body: Stack(
//           // Stack is necessary for the AnimatedMessageBar and potentially the Overlay
//           children: [
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//               child: Column(
//                 children: [
//                   _inputRow("Select Game Type:", _buildDropdown()),
//                   _inputRow(
//                     "Enter Single Panna:",
//                     _buildInputField(digitController, "Bid Panna"),
//                   ),
//                   _inputRow(
//                     "Enter Points:",
//                     _buildInputField(amountController, "Enter Amount"),
//                   ),
//                   const SizedBox(height: 10),
//                   Align(
//                     alignment: Alignment.centerRight,
//                     child: SizedBox(
//                       height: 35,
//                       width: 150,
//                       child: ElevatedButton(
//                         onPressed: _addBid,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.amber,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                         ),
//                         child: Text(
//                           "ADD BID",
//                           style: GoogleFonts.poppins(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                   _buildTableHeader(),
//                   Divider(color: Colors.grey.shade300),
//                   Expanded(
//                     child: bids.isEmpty
//                         ? Center(
//                             child: Text(
//                               "No Bids Added",
//                               style: GoogleFonts.poppins(
//                                 color: Colors.black38,
//                                 fontSize: 16,
//                               ),
//                             ),
//                           )
//                         : ListView.builder(
//                             itemCount: bids.length,
//                             itemBuilder: (context, index) {
//                               final bid = bids[index];
//                               return Card(
//                                 margin: const EdgeInsets.symmetric(vertical: 4),
//                                 elevation: 1,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 child: Padding(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 12.0,
//                                     vertical: 10.0,
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       Expanded(
//                                         flex: 2,
//                                         child: Text(
//                                           bid['digit']!,
//                                           textAlign: TextAlign.center,
//                                           style: GoogleFonts.poppins(),
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 2,
//                                         child: Text(
//                                           bid['amount']!,
//                                           textAlign: TextAlign.center,
//                                           style: GoogleFonts.poppins(),
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 3,
//                                         child: Text(
//                                           bid['type']!,
//                                           textAlign: TextAlign.center,
//                                           style: GoogleFonts.poppins(),
//                                         ),
//                                       ),
//                                       SizedBox(
//                                         width: 48,
//                                         child: IconButton(
//                                           icon: const Icon(
//                                             Icons.delete,
//                                             color: Colors.red,
//                                             size: 20,
//                                           ),
//                                           onPressed: () => _removeBid(index),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               );
//                             },
//                           ),
//                   ),
//                   if (bids.isNotEmpty)
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 12,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.grey.withOpacity(0.3),
//                             spreadRadius: 2,
//                             blurRadius: 5,
//                             offset: const Offset(0, -3),
//                           ),
//                         ],
//                         borderRadius: const BorderRadius.only(
//                           topLeft: Radius.circular(12),
//                           topRight: Radius.circular(12),
//                         ),
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 'Bids',
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 14,
//                                   color: Colors.grey[700],
//                                 ),
//                               ),
//                               Text(
//                                 '${bids.length}',
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 'Points',
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 14,
//                                   color: Colors.grey[700],
//                                 ),
//                               ),
//                               Text(
//                                 '${_getTotalPoints()}',
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           ElevatedButton(
//                             onPressed: _showBidConfirmationDialog,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.amber,
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 24,
//                                 vertical: 12,
//                               ),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               elevation: 3,
//                             ),
//                             child: Text(
//                               'SUBMIT',
//                               style: GoogleFonts.poppins(
//                                 color: Colors.white,
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//
//             // This is where the AnimatedMessageBar is positioned within the Stack
//             if (_messageToShow != null)
//               Positioned(
//                 top: 0,
//                 left: 0,
//                 right: 0,
//                 child: AnimatedMessageBar(
//                   key: _messageBarKey,
//                   message: _messageToShow!,
//                   isError: _isErrorForMessage,
//                   onDismissed: _clearMessage,
//                 ),
//               ),
//             // The Overlay for suggestions is not explicitly placed here in the Stack.
//             // It's managed by Overlay.of(context).insert(_overlayEntry!),
//             // which places it in the app's top-level overlay stack.
//           ],
//         ),
//       ),
//     );
//   }
// }
