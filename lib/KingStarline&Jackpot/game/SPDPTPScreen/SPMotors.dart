import 'dart:async'; // For Timer
import 'dart:convert'; // For jsonEncode, json.decode
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // For API calls
import 'package:intl/intl.dart'; // Import for date formatting

import '../../../../components/AnimatedMessageBar.dart';
import '../../../../components/BidConfirmationDialog.dart';
import '../../../../components/BidFailureDialog.dart';
import '../../../../components/BidSuccessDialog.dart';
import '../../../ulits/Constents.dart'; // Retained your original import path

class SPMotorsBetScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType;
  final int gameId;
  final String gameName;

  const SPMotorsBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
  });

  @override
  State<SPMotorsBetScreen> createState() => _SPMotorsBetScreenState();
}

class _SPMotorsBetScreenState extends State<SPMotorsBetScreen> {
  final List<String> gameTypesOptions = ["Open", "Close"];
  late String selectedGameBetType;

  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  // --- New State Variables for Suggestions ---
  List<String> digitOptions = [
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
  List<String> filteredDigitOptions = [];
  bool _isDigitSuggestionsVisible = false;
  // --- End New State Variables ---

  List<Map<String, String>> addedEntries = [];
  late GetStorage storage;
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance;

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  // State variable to track API call status
  bool _isApiCalling = false;

  @override
  void initState() {
    super.initState();
    storage = GetStorage(); // Initialize GetStorage
    _loadInitialData();
    _setupStorageListeners();

    // --- Added back digitController listener ---
    digitController.addListener(_onDigitChanged);
    // --- End Added back digitController listener ---

    // Initialize selectedGameBetType here
    selectedGameBetType = gameTypesOptions[0]; // Default to "Open"
  }

  // --- New _onDigitChanged method ---
  void _onDigitChanged() {
    final query = digitController.text.trim();
    if (query.isNotEmpty) {
      setState(() {
        filteredDigitOptions = digitOptions
            .where((digit) => digit.startsWith(query))
            .toList();
        _isDigitSuggestionsVisible = filteredDigitOptions.isNotEmpty;
      });
    } else {
      setState(() {
        filteredDigitOptions = [];
        _isDigitSuggestionsVisible = false;
      });
    }
  }
  // --- End New _onDigitChanged method ---

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = storage.read('accountStatus') ?? false;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is int) {
      walletBalance = storedWalletBalance;
    } else if (storedWalletBalance is String) {
      walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else {
      walletBalance = 0;
    }
  }

  void _setupStorageListeners() {
    storage.listenKey('accessToken', (value) {
      if (mounted) setState(() => accessToken = value ?? '');
    });
    storage.listenKey('registerId', (value) {
      if (mounted) setState(() => registerId = value ?? '');
    });
    storage.listenKey('accountStatus', (value) {
      if (mounted) setState(() => accountStatus = value ?? false);
    });
    storage.listenKey('selectedLanguage', (value) {
      if (mounted) setState(() => preferredLanguage = value ?? 'en');
    });
    storage.listenKey('walletBalance', (value) {
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
  }

  @override
  void dispose() {
    // --- Added back digitController.removeListener ---
    digitController.removeListener(_onDigitChanged);
    // --- End Added back digitController.removeListener ---
    digitController.dispose();
    pointsController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
  }

  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  void _addEntry() {
    _clearMessage();
    if (_isApiCalling) return; // Prevent adding entries while API is busy

    final digit = digitController.text.trim();
    final points = pointsController.text.trim();

    if (digit.isEmpty) {
      _showMessage('Please enter a 3-digit number.', isError: true);
      return;
    }

    // Validate for exactly 3 digits
    if (digit.length != 3 || int.tryParse(digit) == null) {
      _showMessage('Please enter a valid 3-digit number.', isError: true);
      return;
    }

    // --- Validate if the digit is in the Single_Pana list ---
    if (!digitOptions.contains(digit)) {
      _showMessage(
        'Invalid 3-digit number. Not in Single Patti list.',
        isError: true,
      );
      return;
    }
    // --- End Validation ---

    if (points.isEmpty) {
      _showMessage('Please enter an Amount.', isError: true);
      return;
    }

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    final existingIndex = addedEntries.indexWhere(
      (entry) =>
          entry['digit'] == digit && entry['type'] == selectedGameBetType,
    );

    setState(() {
      if (existingIndex != -1) {
        final currentPoints = int.parse(addedEntries[existingIndex]['points']!);
        addedEntries[existingIndex]['points'] = (currentPoints + parsedPoints)
            .toString();
        _showMessage(
          'Updated points for Motor Patti: $digit, Type: $selectedGameBetType.',
        );
      } else {
        addedEntries.add({
          "digit": digit,
          "points": points,
          "type": selectedGameBetType,
        });
        _showMessage(
          'Added bid: Motor Patti $digit, Points $points, Type $selectedGameBetType.',
        );
      }
      digitController.clear();
      pointsController.clear();
      _isDigitSuggestionsVisible = false; // Hide suggestions after adding
    });
  }

  void _removeEntry(int index) {
    _clearMessage();
    if (_isApiCalling) return; // Prevent removing entries while API is busy

    setState(() {
      final removedEntry = addedEntries[index];
      addedEntries.removeAt(index);
      _showMessage(
        'Removed bid: Motor Patti ${removedEntry['digit']}, Type ${removedEntry['type']}.',
      );
    });
  }

  int _getTotalPoints() {
    return addedEntries.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return; // Prevent showing dialog if API is busy

    if (addedEntries.isEmpty) {
      _showMessage('Please add at least one bid.', isError: true);
      return;
    }

    final int totalPoints = _getTotalPoints();

    if (walletBalance < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
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
          gameTitle: widget.gameName,
          gameDate: formattedDate,
          bids: addedEntries.map((bid) {
            return {
              "digit": bid['digit']!,
              "points": bid['points']!,
              "type": bid['type']!,
            };
          }).toList(),
          totalBids: addedEntries.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameCategoryType,
          onConfirm: () async {
            Navigator.pop(dialogContext);
            setState(() {
              _isApiCalling = true; // Set API calling state
            });
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                addedEntries.clear();
              });
              // The success message/dialog is now handled inside _placeFinalBids
            }
            // Ensure API calling state is reset regardless of outcome
            if (mounted) {
              setState(() {
                _isApiCalling = false;
              });
            }
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    String url;
    final gameCategory = widget.gameCategoryType.toLowerCase();

    if (gameCategory.contains('jackpot')) {
      url = '${Constant.apiEndpoint}place-jackpot-bid';
    } else if (gameCategory.contains('starline')) {
      url = '${Constant.apiEndpoint}place-starline-bid';
    } else {
      url = '${Constant.apiEndpoint}place-bid';
    }

    // Authentication Check
    if (accessToken.isEmpty || registerId.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const BidFailureDialog(
              errorMessage: 'Authentication error. Please log in again.',
            );
          },
        );
      }
      return false;
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final List<Map<String, dynamic>> bidPayload = addedEntries.map((entry) {
      final String bidDigit = entry['digit'] ?? '';
      final int bidAmount = int.tryParse(entry['points'] ?? '0') ?? 0;

      return {
        "sessionType": entry['type']?.toUpperCase() ?? '',
        "digit": bidDigit, // This will be the 3-digit number for Motor Patti
        "pana":
            bidDigit, // For Motor Patti, pana is often the same as the digit
        "bidAmount": bidAmount,
      };
    }).toList();

    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId,
      "bidAmount": _getTotalPoints(),
      "gameType": widget.gameCategoryType,
      "bid": bidPayload,
    });

    log('Placing bid to URL: $url');
    log('Request Headers: $headers');
    log('Request Body: $body');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      final Map<String, dynamic> responseBody = json.decode(response.body);
      log('API Response: $responseBody');

      if (response.statusCode == 200 && responseBody['status'] == true) {
        int newWalletBalance = walletBalance - _getTotalPoints();
        await storage.write('walletBalance', newWalletBalance.toString());

        if (mounted) {
          setState(() {
            walletBalance = newWalletBalance;
          });
          // Show success dialog ONLY if mounted
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const BidSuccessDialog();
            },
          );
        }
        return true;
      } else {
        String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
        if (mounted) {
          // Show failure dialog ONLY if mounted
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return BidFailureDialog(errorMessage: errorMessage);
            },
          );
        }
        return false;
      }
    } catch (e) {
      log('Error during bid submission: $e');
      if (mounted) {
        // Show network error dialog ONLY if mounted
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return BidFailureDialog(errorMessage: 'Error: ${e.toString()}');
          },
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey.shade300,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        actions: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.black,
          ),
          const SizedBox(width: 6),
          Center(
            child: Text(
              walletBalance.toString(),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    // Game Type Dropdown
                    _inputRow("Select Game Type:", _buildDropdown()),
                    const SizedBox(height: 12),
                    // Digit Input Field (now for 3 digits)
                    _inputRow("Enter 3-Digit Number:", _buildDigitInputField()),
                    // --- Added suggestions list conditionally ---
                    if (_isDigitSuggestionsVisible &&
                        filteredDigitOptions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        constraints: const BoxConstraints(
                          maxHeight: 200,
                        ), // Limit height
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 2,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredDigitOptions.length,
                          itemBuilder: (context, index) {
                            final suggestion = filteredDigitOptions[index];
                            return ListTile(
                              title: Text(suggestion),
                              onTap: () {
                                setState(() {
                                  digitController.text = suggestion;
                                  _isDigitSuggestionsVisible =
                                      false; // Hide on selection
                                  // Move cursor to end of text
                                  digitController.selection =
                                      TextSelection.fromPosition(
                                        TextPosition(
                                          offset: digitController.text.length,
                                        ),
                                      );
                                });
                              },
                            );
                          },
                        ),
                      ),
                    // --- End Added suggestions list ---
                    const SizedBox(
                      height: 12,
                    ), // Adjust spacing after digit input
                    // Points Input Field
                    _inputRow(
                      "Enter Points:",
                      _buildTextField(
                        pointsController,
                        "Enter Amount",
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(
                            4,
                          ), // Max 4 digits for points
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: _isApiCalling
                            ? null
                            : _addEntry, // Disable if API is calling
                        child: _isApiCalling
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                            : const Text(
                                "ADD BID",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
              const Divider(thickness: 1),
              // List Headers
              if (addedEntries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Digit",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Amount",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Game Type",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              if (addedEntries.isNotEmpty) const Divider(thickness: 1),
              // List of Added Entries
              Expanded(
                child: addedEntries.isEmpty
                    ? const Center(child: Text("No data added yet"))
                    : ListView.builder(
                        itemCount: addedEntries.length,
                        itemBuilder: (_, index) {
                          final entry = addedEntries[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry['digit']!,
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry['points']!,
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry['type']!,
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: _isApiCalling
                                      ? null
                                      : () => _removeEntry(
                                          index,
                                        ), // Disable if API is calling
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              // Bottom Summary Bar
              if (addedEntries.isNotEmpty) _buildBottomBar(),
            ],
          ),
          // Animated Message Bar
          if (_messageToShow != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedMessageBar(
                key: _messageBarKey,
                message: _messageToShow!,
                isError: _isErrorForMessage,
                onDismissed: _clearMessage,
              ),
            ),
        ],
      ),
    );
  }

  Widget _inputRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(flex: 3, child: field),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return SizedBox(
      width: 150,
      height: 35,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black54),
          borderRadius: BorderRadius.circular(30),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selectedGameBetType,
            icon: const Icon(Icons.keyboard_arrow_down),
            onChanged: _isApiCalling
                ? null
                : (String? newValue) {
                    // Disable if API is calling
                    setState(() {
                      selectedGameBetType = newValue!;
                      _clearMessage();
                    });
                  },
            items: gameTypesOptions.map<DropdownMenuItem<String>>((
              String value,
            ) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: GoogleFonts.poppins(fontSize: 14)),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Updated to accept 3-digit input and show suggestions
  Widget _buildDigitInputField() {
    return SizedBox(
      width: double.infinity,
      height: 35,
      child: TextFormField(
        controller: digitController,
        cursorColor: Colors.amber,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: [
          LengthLimitingTextInputFormatter(3), // Now accepts 3 digits
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: () {
          _clearMessage();
          _onDigitChanged(); // Trigger suggestions on tap if text is present
        },
        onChanged: (value) {
          _onDigitChanged(); // Filter suggestions as user types
        },
        enabled: !_isApiCalling, // Disable if API is calling
        decoration: InputDecoration(
          hintText: "Enter 3-Digit Number", // Updated hint text
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
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      width: 150,
      height: 35,
      child: TextFormField(
        controller: controller,
        cursorColor: Colors.amber,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: inputFormatters,
        onTap: _clearMessage,
        enabled: !_isApiCalling, // Disable if API is calling
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
      ),
    );
  }

  Widget _buildBottomBar() {
    int totalBids = addedEntries.length;
    int totalPoints = _getTotalPoints();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bids',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '$totalBids',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Points',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '$totalPoints',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _isApiCalling
                ? null
                : _showConfirmationDialog, // Disable if API is calling
            style: ElevatedButton.styleFrom(
              backgroundColor: _isApiCalling
                  ? Colors.grey
                  : Colors.amber, // Dim if disabled
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: _isApiCalling
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : Text(
                    'SUBMIT',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
