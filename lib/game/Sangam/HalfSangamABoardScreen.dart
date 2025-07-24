import 'dart:async'; // For Timer
import 'dart:convert'; // For jsonEncode, json.decode
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
import 'package:http/http.dart' as http; // For API calls
import 'package:intl/intl.dart';

import '../../components/BidConfirmationDialog.dart';
import '../../ulits/Constents.dart'; // Import the Constants file for API endpoint

// AnimatedMessageBar component (Ensure this is a common component or defined here)
// If this component is already defined in a separate file (e.g., components/animated_message_bar.dart)
// then you should import it and remove this duplicate definition.
class AnimatedMessageBar extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback? onDismissed;

  const AnimatedMessageBar({
    Key? key,
    required this.message,
    this.isError = false,
    this.onDismissed,
  }) : super(key: key);

  @override
  _AnimatedMessageBarState createState() => _AnimatedMessageBarState();
}

class _AnimatedMessageBarState extends State<AnimatedMessageBar> {
  double _height = 0.0;
  Timer? _visibilityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showBar();
    });
  }

  void _showBar() {
    if (!mounted) return;
    setState(() {
      _height = 48.0;
    });

    _visibilityTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _height = 0.0;
      });
      Timer(const Duration(milliseconds: 300), () {
        if (mounted && widget.onDismissed != null) {
          widget.onDismissed!();
        }
      });
    });
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      height: _height,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      color: widget.isError ? Colors.red : Colors.green,
      alignment: Alignment.center,
      child: _height > 0.0
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(
                    widget.isError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class HalfSangamABoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;
  final String gameType;

  const HalfSangamABoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId,
    required this.gameType,
  }) : super(key: key);

  @override
  State<HalfSangamABoardScreen> createState() => _HalfSangamABoardScreenState();
}

class _HalfSangamABoardScreenState extends State<HalfSangamABoardScreen> {
  final TextEditingController _openDigitController = TextEditingController();
  final TextEditingController _closePannaController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  List<Map<String, String>> _bids = [];
  late GetStorage storage = GetStorage();
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance;

  // Placeholder for device info. In a real app, these would be dynamic.
  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  // State management for AnimatedMessageBar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey(); // Key to force rebuild/re-animation

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupStorageListeners();
  }

  // Load initial data from GetStorage
  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = storage.read('accountStatus') ?? false;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is String) {
      walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else if (storedWalletBalance is int) {
      walletBalance = storedWalletBalance;
    } else {
      walletBalance = 0;
    }
  }

  // Set up listeners for GetStorage keys
  void _setupStorageListeners() {
    storage.listenKey('accessToken', (value) {
      setState(() {
        accessToken = value ?? '';
      });
    });

    storage.listenKey('registerId', (value) {
      setState(() {
        registerId = value ?? '';
      });
    });

    storage.listenKey('accountStatus', (value) {
      setState(() {
        accountStatus = value ?? false;
      });
    });

    storage.listenKey('selectedLanguage', (value) {
      setState(() {
        preferredLanguage = value ?? 'en';
      });
    });

    storage.listenKey('walletBalance', (value) {
      setState(() {
        if (value is String) {
          walletBalance = int.tryParse(value) ?? 0;
        } else if (value is int) {
          walletBalance = value;
        } else {
          walletBalance = 0;
        }
      });
    });
  }

  // List of all possible 3-digit pannas for suggestions
  static final List<String> _allPannas = List.generate(
    900,
    (index) => (index + 100).toString(),
  );

  @override
  void dispose() {
    _openDigitController.dispose();
    _closePannaController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  // Helper method to show messages using AnimatedMessageBar
  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey(); // Update key to trigger animation
    });
  }

  // Helper method to clear the message bar
  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  void _addBid() {
    _clearMessage(); // Clear any previous messages
    final openDigit = _openDigitController.text.trim();
    final closePanna = _closePannaController.text.trim();
    final points = _pointsController.text.trim();

    // 1. Validate Open Digit (single digit, 0-9)
    if (openDigit.isEmpty ||
        openDigit.length != 1 ||
        int.tryParse(openDigit) == null) {
      _showMessage(
        'Please enter a single digit for Open Digit (0-9).',
        isError: true,
      );
      return;
    }
    int? parsedOpenDigit = int.tryParse(openDigit);
    if (parsedOpenDigit == null || parsedOpenDigit < 0 || parsedOpenDigit > 9) {
      _showMessage(
        'Open Digit must be a single digit between 0 and 9.',
        isError: true,
      );
      return;
    }

    // 2. Validate Close Panna (3 digits, 100-999)
    if (closePanna.isEmpty ||
        closePanna.length != 3 ||
        int.tryParse(closePanna) == null) {
      _showMessage(
        'Please enter a 3-digit number for Close Panna.',
        isError: true,
      );
      return;
    }
    int? parsedClosePanna = int.tryParse(closePanna);
    if (parsedClosePanna == null ||
        parsedClosePanna < 100 ||
        parsedClosePanna > 999) {
      _showMessage('Close Panna must be between 100 and 999.', isError: true);
      return;
    }

    // 3. Validate Points (10 to 1000)
    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    // Construct the Sangam string
    final sangam = '$openDigit-$closePanna';

    setState(() {
      // Check if an existing bid with the same Sangam already exists
      int existingIndex = _bids.indexWhere((bid) => bid['sangam'] == sangam);

      if (existingIndex != -1) {
        // If it exists, update the points of the existing bid
        _bids[existingIndex]['points'] =
            (int.parse(_bids[existingIndex]['points']!) + parsedPoints)
                .toString();
        _showMessage('Updated points for $sangam.');
      } else {
        // Otherwise, add a new bid
        _bids.add({
          "sangam": sangam,
          "points": points,
          "openDigit": openDigit, // Store openDigit for API
          "closePanna": closePanna, // Store closePanna for API
          "type": "HalfSangamA", // Indicate game type for API
        });
        _showMessage('Added bid: $sangam with $points points.');
      }

      // Clear controllers after adding/updating
      _openDigitController.clear();
      _closePannaController.clear();
      _pointsController.clear();
    });
  }

  void _removeBid(int index) {
    _clearMessage();
    setState(() {
      final removedSangam = _bids[index]['sangam'];
      _bids.removeAt(index);
      _showMessage('Bid for $removedSangam removed from list.');
    });
  }

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + int.tryParse(item['points'] ?? '0')!,
    );
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (_bids.isEmpty) {
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

    // Prepare bids list for the dialog
    List<Map<String, String>> bidsForDialog = _bids.map((bid) {
      // For HalfSangamA, 'digit' is openDigit and 'pana' is closePanna.
      // 'type' is "HalfSangamA"
      return {
        "digit": bid['openDigit']!, // Open Digit goes to 'digit'
        "pana": bid['closePanna']!, // Close Panna goes to 'pana'
        "points": bid['points']!,
        "type": bid['type']!, // Hardcoded type as per your game model
        "sangam": bid['sangam']!, // Keep sangam for display purposes in dialog
      };
    }).toList();

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false, // User must interact with the dialog
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.screenTitle, // Use screenTitle for gameTitle
          gameDate: formattedDate,
          bids: bidsForDialog,
          totalBids: bidsForDialog.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(), // Ensure gameId is String
          gameType: widget
              .gameType, // Pass the correct gameType (e.g., "halfSangamA")
          onConfirm: () async {
            Navigator.pop(dialogContext); // Dismiss the confirmation dialog
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                _bids.clear(); // Clear bids on successful submission
              });
              _showMessage('Bids placed successfully!');
            }
          },
        );
      },
    );
  }

  // Place final bids via API
  Future<bool> _placeFinalBids() async {
    String url;
    // For Sangam, typically it's 'place-bid' but with specific gameType/sessionType
    if (widget.screenTitle.toLowerCase().contains('jackpot')) {
      url = '${Constant.apiEndpoint}place-jackpot-bid';
    } else if (widget.screenTitle.toLowerCase().contains('starline')) {
      url = '${Constant.apiEndpoint}place-starline-bid';
    } else {
      url = '${Constant.apiEndpoint}place-bid'; // General bid placement
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      _showMessage('Authentication error. Please log in again.', isError: true);
      return false;
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0', // Convert bool to '1' or '0'
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final List<Map<String, dynamic>> bidPayload = _bids.map((bid) {
      return {
        "sessionType": bid['type']!.toUpperCase(), // "HALFSANGAMA"
        "digit": bid['openDigit']!, // Open Digit for Half Sangam A
        "pana": bid['closePanna']!, // Close Panna for Half Sangam A
        "bidAmount": int.tryParse(bid['points'] ?? '0') ?? 0,
      };
    }).toList();

    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId,
      "bidAmount": _getTotalPoints(),
      "gameType":
          widget.gameType, // Use the gameType from the widget's properties
      "bid": bidPayload,
    });

    log('Placing final bids to URL: $url');
    log('Request Body: $body');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      final Map<String, dynamic> responseBody = json.decode(response.body);

      log('API Response for Final Bid Submission: ${responseBody}');

      if (response.statusCode == 200 && responseBody['status'] == true) {
        // Update wallet balance in GetStorage and local state on successful bid
        int currentWallet = walletBalance;
        int deductedAmount = _getTotalPoints();
        int newWalletBalance = currentWallet - deductedAmount;
        storage.write(
          'walletBalance',
          newWalletBalance.toString(),
        ); // Update storage
        setState(() {
          walletBalance = newWalletBalance; // Update local state
        });
        return true; // Indicate success
      } else {
        String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
        _showMessage('Bid submission failed: $errorMessage', isError: true);
        return false; // Indicate failure
      }
    } catch (e) {
      log('Network error during bid submission: $e');
      _showMessage('Network error during bid submission: $e', isError: true);
      return false; // Indicate failure
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light gray background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.screenTitle,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
              walletBalance.toString(), // Display actual wallet balance
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
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
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputRow(
                      'Enter Open Digit :',
                      _openDigitController,
                      hintText: 'e.g., 5',
                      maxLength: 1,
                    ),
                    const SizedBox(height: 16),
                    _buildPannaInputRow(
                      'Enter Close Panna :',
                      _closePannaController,
                      hintText: 'e.g., 123',
                      maxLength: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildInputRow(
                      'Enter Points :',
                      _pointsController,
                      hintText: 'e.g., 100',
                      maxLength: 4,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: _addBid,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          "ADD",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(thickness: 1),

              // Table Headers
              if (_bids.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Sangam',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Points',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Space for delete icon
                    ],
                  ),
                ),
              if (_bids.isNotEmpty) const Divider(thickness: 1),

              // Dynamic List of Bids
              Expanded(
                child: _bids.isEmpty
                    ? Center(
                        child: Text(
                          'No Bids Placed',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _bids.length,
                        itemBuilder: (context, index) {
                          final bid = _bids[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      bid['sangam']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      bid['points']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeBid(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Bottom Bar (conditionally rendered)
              if (_bids.isNotEmpty) _buildBottomBar(),
            ],
          ),
          // AnimatedMessageBar positioned at the top
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

  // Helper widget for input rows (standard TextField)
  Widget _buildInputRow(
    String label,
    TextEditingController controller, {
    String hintText = '',
    int? maxLength,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 16)),
        SizedBox(
          width: 150,
          height: 40,
          child: TextField(
            cursorColor: Colors.amber,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              if (maxLength != null)
                LengthLimitingTextInputFormatter(maxLength),
            ],
            onTap: _clearMessage, // Clear message on tap
            decoration: InputDecoration(
              hintText: hintText,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(color: Colors.black),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(color: Colors.black),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(color: Colors.amber, width: 2),
              ),
              suffixIcon: const Icon(
                Icons.arrow_forward,
                color: Colors.amber,
                size: 20,
              ), // Arrow icon
            ),
          ),
        ),
      ],
    );
  }

  // Helper widget for Panna input with Autocomplete suggestions
  Widget _buildPannaInputRow(
    String label,
    TextEditingController controller, {
    String hintText = '',
    int? maxLength,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 16)),
        SizedBox(
          width: 150,
          height: 40,
          child: Autocomplete<String>(
            fieldViewBuilder:
                (
                  BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  // Keep our controller in sync with Autocomplete's internal controller
                  controller.text = textEditingController.text;
                  controller.selection = textEditingController.selection;

                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      if (maxLength != null)
                        LengthLimitingTextInputFormatter(maxLength),
                    ],
                    onTap: _clearMessage, // Clear message on tap
                    decoration: InputDecoration(
                      hintText: hintText,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide(color: Colors.amber, width: 2),
                      ),
                      suffixIcon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.amber,
                        size: 20,
                      ), // Arrow icon
                    ),
                    onSubmitted: (value) => onFieldSubmitted(),
                  );
                },
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return _allPannas.where((String option) {
                return option.startsWith(textEditingValue.text);
              });
            },
            onSelected: (String selection) {
              controller.text = selection;
            },
            optionsViewBuilder:
                (
                  BuildContext context,
                  AutocompleteOnSelected<String> onSelected,
                  Iterable<String> options,
                ) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: SizedBox(
                        height: options.length > 5
                            ? 200.0
                            : options.length * 48.0,
                        width: 150,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return GestureDetector(
                              onTap: () {
                                onSelected(option);
                              },
                              child: ListTile(
                                title: Text(
                                  option,
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
          ),
        ),
      ],
    );
  }

  // Helper for bottom bar
  Widget _buildBottomBar() {
    int totalBids = _bids.length;
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
            onPressed: _showConfirmationDialog, // Call the confirmation dialog
            child: Text(
              'SUBMIT',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
          ),
        ],
      ),
    );
  }
}
