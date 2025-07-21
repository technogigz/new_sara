import 'dart:convert'; // Import for JSON encoding/decoding
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
import 'package:http/http.dart' as http; // Import for HTTP requests
import 'package:intl/intl.dart';
import 'package:new_sara/ulits/Constents.dart';

import '../../../components/BidConfirmationDialog.dart'; // For date formatting

// Enum for Open/Close game type selection
enum PattiDayType { open, close }

class SinglePannaBulkBoardScreen extends StatefulWidget {
  final String title; // e.g., "SRIDEVI DAY, SINGLE PATTI"
  final int gameId;
  final String gameName; // e.g., "SRIDEVI DAY"
  final String gameType; // e.g., "Single Patti"

  const SinglePannaBulkBoardScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameType,
  }) : super(key: key);

  @override
  State<SinglePannaBulkBoardScreen> createState() =>
      _SinglePannaBulkBoardScreenState();
}

class _SinglePannaBulkBoardScreenState
    extends State<SinglePannaBulkBoardScreen> {
  PattiDayType _selectedPattiDayType = PattiDayType.close; // Default to Close
  final TextEditingController _pointsController = TextEditingController();

  // Map to store bids: { "pana": { "points": "...", "dayType": "...", "associatedDigit": "..." } }
  // We'll store the 'pana' as the key to uniquely identify the bid from API.
  Map<String, Map<String, String>> _bids = {};

  late GetStorage storage = GetStorage();
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance; // This will reflect the true wallet balance

  bool _isApiCalling = false; // To prevent multiple simultaneous API calls
  bool _isWalletLoading = true; // New state to indicate wallet loading

  // Placeholder for device info. In a real app, these would be dynamic.
  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupStorageListeners();
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = storage.read('accountStatus') ?? false;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    // Initial read of walletBalance from storage (will be overwritten by API call)
    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is String) {
      walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else if (storedWalletBalance is int) {
      walletBalance = storedWalletBalance;
    } else {
      walletBalance = 0;
    }

    // After loading initial data, set _isWalletLoading to false
    setState(() {
      _isWalletLoading = false;
    });
  }

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
    // This listener will now update the UI when walletBalance changes in storage
    storage.listenKey('walletBalance', (value) {
      setState(() {
        if (value is String) {
          walletBalance = int.tryParse(value) ?? 0;
        } else if (value is int) {
          walletBalance = value;
        } else {
          walletBalance = 0;
        }
        // When wallet balance is updated from storage, ensure loading is off
        _isWalletLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _onNumberPressed(String digit) async {
    if (_isApiCalling) return; // Prevent multiple calls

    final points = _pointsController.text.trim();
    final String requestSessionType =
        _selectedPattiDayType == PattiDayType.close
        ? 'close'
        : 'open'; // API expects 'open'/'close' lowercase

    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter points to place a bid.')),
      );
      return;
    }

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Points must be between 10 and 1000.')),
      );
      return;
    }

    if (parsedPoints > walletBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient wallet balance.')),
      );
      return;
    }

    setState(() {
      _isApiCalling = true; // Set loading state
    });

    final url = Uri.parse(
      '${Constant.apiEndpoint}single-pana-bulk',
    ); // Correct API endpoint
    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final body = jsonEncode({
      "game_id": widget.gameId,
      "register_id": registerId,
      "session_type": requestSessionType, // Use the request session type
      "digit": digit, // Send the single digit to get associated panas
      "amount": parsedPoints, // This amount will be applied to each pana
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final responseData = json.decode(response.body);

      log("API Response: ${responseData}");

      if (response.statusCode == 200 && responseData['status'] == true) {
        final List<dynamic> info = responseData['info'] ?? [];
        if (info.isNotEmpty) {
          setState(() {
            for (var item in info) {
              final String pana = item['pana'].toString();
              final String amount = item['amount'].toString();
              // Use sessionType directly from API response for accuracy
              final String apiSessionType = item['sessionType'].toString();

              // Store pana as the key, and include the associated digit if needed for clarity
              _bids[pana] = {
                "points": amount,
                "dayType":
                    apiSessionType, // Use the sessionType directly from API
                "associatedDigit":
                    digit, // Store the digit that generated these panas
              };
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${info.length} bids for digit $digit added successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No panas returned for this digit.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        log("API Response: ${responseData}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to add bid: ${responseData['msg'] ?? 'Unknown error'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isApiCalling = false; // Reset loading state
      });
    }
  }

  void _removeBid(String pana) {
    setState(() {
      _bids.remove(pana);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bid for Pana $pana removed from list.')),
    );
  }

  int _getTotalPoints() {
    return _bids.values
        .map((bid) => int.tryParse(bid['points'] ?? '0') ?? 0)
        .fold(0, (sum, points) => sum + points);
  }

  // This method now triggers the confirmation dialog for submitting all bids.
  void _showConfirmationDialogAndSubmitBids() {
    if (_bids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No bids added yet. Please add bids before submitting.',
          ),
        ),
      );
      return;
    }

    final int totalPointsToSubmit = _getTotalPoints();

    if (totalPointsToSubmit > walletBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient wallet balance to submit all bids.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    List<Map<String, String>> bidsForConfirmationDialog = [];
    _bids.forEach((pana, bidData) {
      bidsForConfirmationDialog.add({
        "digit": pana, // Display pana under 'Digits' column in dialog
        "points": bidData['points']!,
        "type": bidData['dayType']!,
        "gameType": widget.gameType,
      });
    });

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return BidConfirmationDialog(
          gameTitle:
              "${widget.gameName}, ${widget.gameType}-${DateFormat('dd-MM-yyyy').format(DateTime.now())}",
          gameDate: formattedDate,
          bids: bidsForConfirmationDialog,
          totalBids: _bids.length,
          totalBidsAmount: totalPointsToSubmit,
          walletBalanceBeforeDeduction: walletBalance, // Current balance
          walletBalanceAfterDeduction: (walletBalance - totalPointsToSubmit)
              .toString(), // Projected balance
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
        );
      },
    ).then((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
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
                  "assets/images/wallet_icon.png",
                  color: Colors.black,
                  height: 24,
                ),
                const SizedBox(width: 4),
                // Display loading indicator or balance
                _isWalletLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "${walletBalance.toString()}",
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Game Type:',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    ToggleButtons(
                      isSelected: [
                        _selectedPattiDayType == PattiDayType.close,
                        _selectedPattiDayType == PattiDayType.open,
                      ],
                      onPressed: (int index) {
                        setState(() {
                          if (index == 0) {
                            _selectedPattiDayType = PattiDayType.close;
                          } else {
                            _selectedPattiDayType = PattiDayType.open;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(30),
                      selectedColor: Colors.white,
                      fillColor: Colors.amber,
                      color: Colors.black,
                      borderColor: Colors.black,
                      selectedBorderColor: Colors.amber,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Text(
                            'Close',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Text(
                            'Open',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Enter Points:',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      height: 40,
                      child: TextFormField(
                        controller: _pointsController,
                        cursorColor: Colors.amber,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter Amount',
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
                              color: Colors.amber,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                Center(
                  child: _isApiCalling
                      ? const CircularProgressIndicator(color: Colors.amber)
                      : _buildNumberPad(),
                ),
              ],
            ),
          ),
          const Divider(thickness: 1),
          if (_bids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Pana', // Changed to Pana
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Amount',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Game Type',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          if (_bids.isNotEmpty) const Divider(thickness: 1),
          Expanded(
            child: _bids.isEmpty
                ? Center(
                    child: Text(
                      'No bids placed yet. Click a number to add a bid!',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _bids.length,
                    itemBuilder: (context, index) {
                      final pana = _bids.keys.elementAt(index);
                      final bidData = _bids[pana]!;
                      return _buildBidEntryItem(
                        pana, // Pass pana as the digit to display
                        bidData['points']!,
                        bidData['dayType']!,
                      );
                    },
                  ),
          ),
          if (_bids.isNotEmpty) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildNumberPad() {
    final numbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    return Wrap(
      spacing: 3,
      runSpacing: 5,
      alignment: WrapAlignment.center,
      children: numbers.map((number) {
        // bool hasBid = _bids.containsKey(number); // Not needed for color change
        return GestureDetector(
          onTap: () => _onNumberPressed(number),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.amber, // Always amber
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  number,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBidEntryItem(String pana, String points, String type) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                pana, // Display the actual pana received from API
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                points,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                type,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeBid(pana), // Remove by pana
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    int totalBidsCount = _bids.length; // This is the count of individual panas
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
                'Bid',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '$totalBidsCount',
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
                'Total',
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
            onPressed:
                _showConfirmationDialogAndSubmitBids, // Call the new submit logic
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: Text(
              'SUBMIT',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
