import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:new_sara/ulits/Constents.dart';

import '../../../components/BidConfirmationDialog.dart';

// AnimatedMessageBar component (as provided by you)
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
// End of AnimatedMessageBar component

enum PattiDayType { open, close }

class SinglePannaBulkBoardScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameName;
  final String gameType;

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
  PattiDayType _selectedPattiDayType = PattiDayType.close;
  final TextEditingController _pointsController = TextEditingController();

  Map<String, Map<String, String>> _bids = {};

  late GetStorage storage = GetStorage();
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance;

  bool _isApiCalling = false;
  bool _isWalletLoading = true;

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  // --- AnimatedMessageBar State Management ---
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  // --- End AnimatedMessageBar State Management ---

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

    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is String) {
      walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else if (storedWalletBalance is int) {
      walletBalance = storedWalletBalance;
    } else {
      walletBalance = 0;
    }

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
    storage.listenKey('walletBalance', (value) {
      setState(() {
        if (value is String) {
          walletBalance = int.tryParse(value) ?? 0;
        } else if (value is int) {
          walletBalance = value;
        } else {
          walletBalance = 0;
        }
        _isWalletLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  // --- AnimatedMessageBar Helper Methods ---
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
  // --- End AnimatedMessageBar Helper Methods ---

  Future<void> _onNumberPressed(String digit) async {
    _clearMessage();
    if (_isApiCalling) return;

    final points = _pointsController.text.trim();
    final String requestSessionType =
        _selectedPattiDayType == PattiDayType.close ? 'close' : 'open';

    if (points.isEmpty) {
      _showMessage('Please enter points to place a bid.', isError: true);
      return;
    }

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    if (parsedPoints > walletBalance) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    setState(() {
      _isApiCalling = true;
    });

    final url = Uri.parse('${Constant.apiEndpoint}single-pana-bulk');
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
      "session_type": requestSessionType,
      "digit": digit,
      "amount": parsedPoints,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final responseData = json.decode(response.body);

      log("API Response for Single Pana Bulk: $responseData");

      if (response.statusCode == 200 && responseData['status'] == true) {
        final List<dynamic> info = responseData['info'] ?? [];
        if (info.isNotEmpty) {
          setState(() {
            for (var item in info) {
              final String pana = item['pana'].toString();
              final String amount = item['amount'].toString();
              String bidDisplayType;
              final String? apiSessionType = item['sessionType']?.toString();

              if (apiSessionType != null && apiSessionType.isNotEmpty) {
                bidDisplayType = apiSessionType;
              } else {
                bidDisplayType = requestSessionType;
              }

              _bids[pana] = {
                "points": amount,
                "dayType": bidDisplayType.toLowerCase(),
                "associatedDigit": digit,
              };
            }
          });
          _showMessage(
            '${info.length} bids for digit $digit added successfully!',
          );
        } else {
          _showMessage('No panas returned for this digit.', isError: true);
        }
      } else {
        log(
          "API Error for Single Pana Bulk: Status: ${response.statusCode}, Body: ${response.body}",
        );
        _showMessage(
          'Failed to add bid: ${responseData['msg'] ?? 'Unknown error'}',
          isError: true,
        );
      }
    } catch (e) {
      log("Network/Other Error placing Single Pana Bulk bid: $e");
      _showMessage('Network error: $e', isError: true);
    } finally {
      setState(() {
        _isApiCalling = false;
      });
    }
  }

  void _removeBid(String pana) {
    _clearMessage();
    setState(() {
      _bids.remove(pana);
    });
    _showMessage('Bid for Pana $pana removed from list.');
  }

  int _getTotalPoints() {
    return _bids.values
        .map((bid) => int.tryParse(bid['points'] ?? '0') ?? 0)
        .fold(0, (sum, points) => sum + points);
  }

  void _showConfirmationDialogAndSubmitBids() {
    _clearMessage();
    if (_bids.isEmpty) {
      _showMessage(
        'No bids added yet. Please add bids before submitting.',
        isError: true,
      );
      return;
    }

    final int totalPointsToSubmit = _getTotalPoints();

    if (totalPointsToSubmit > walletBalance) {
      _showMessage(
        'Insufficient wallet balance to submit all bids.',
        isError: true,
      );
      return;
    }

    List<Map<String, String>> bidsForConfirmationDialog = [];
    _bids.forEach((pana, bidData) {
      bidsForConfirmationDialog.add({
        "digit": pana,
        "points": bidData['points']!,
        "type": bidData['dayType']!.toUpperCase(),
        "pana": pana, // Ensure pana is also passed in the bid map
      });
    });

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle:
              "${widget.gameName}, ${widget.gameType}-${DateFormat('dd-MM-yyyy').format(DateTime.now())}",
          gameDate: formattedDate,
          bids: bidsForConfirmationDialog,
          totalBids: _bids.length,
          totalBidsAmount: totalPointsToSubmit,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPointsToSubmit)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            Navigator.pop(dialogContext); // Dismiss the confirmation dialog
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                _bids.clear();
              });
              _showMessage('Bids placed successfully!', isError: false);
            }
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    String url;
    if (widget.gameName.toLowerCase().contains('jackpot')) {
      url = '${Constant.apiEndpoint}place-jackpot-bid';
    } else if (widget.gameName.toLowerCase().contains('starline')) {
      url = '${Constant.apiEndpoint}place-starline-bid';
    } else {
      url = '${Constant.apiEndpoint}place-bid';
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      _showMessage('Authentication error. Please log in again.', isError: true);
      return false;
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final List<Map<String, dynamic>> bidPayload = _bids.entries.map((entry) {
      String sessionType = entry.value["dayType"] ?? "";
      String digit = entry.key; // The pana is the digit for submission
      int bidAmount = int.tryParse(entry.value["points"] ?? '0') ?? 0;

      return {
        "sessionType": sessionType.toUpperCase(),
        "digit": digit,
        "pana": digit, // For patti, digit is the pana itself
        "bidAmount": bidAmount,
      };
    }).toList();

    final body = {
      "registerId": registerId,
      "gameId": widget.gameId,
      "bidAmount": _getTotalPoints(),
      "gameType": widget.gameType,
      "bid": bidPayload,
    };

    // Log the cURL and headers here
    String curlCommand = 'curl -X POST \\';
    curlCommand += '\n  ${Uri.parse(url)} \\';
    headers.forEach((key, value) {
      curlCommand += '\n  -H "$key: $value" \\';
    });
    curlCommand += '\n  -d \'$body\'';

    log('CURL Command for Final Bid Submission:\n$curlCommand');
    log('Request Headers for Final Bid Submission: $headers');
    log('Request Body for Final Bid Submission: $body');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      final Map<String, dynamic> responseBody = json.decode(response.body);

      if (response.statusCode == 200 && responseBody['status'] == true) {
        int currentWallet = walletBalance;
        int deductedAmount = _getTotalPoints();
        int newWalletBalance = currentWallet - deductedAmount;
        storage.write('walletBalance', newWalletBalance.toString());
        setState(() {
          walletBalance = newWalletBalance;
        });
        return true;
      } else {
        String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
        _showMessage('Bid submission failed: $errorMessage', isError: true);
        return false;
      }
    } catch (e) {
      _showMessage('Network error during bid submission: $e', isError: true);
      return false;
    }
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
                            onTap: _clearMessage, // Clear message on tap
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
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                ),
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
                          'Pana',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Amount',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Game Type',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
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
                            pana,
                            bidData['points']!,
                            bidData['dayType']!,
                          );
                        },
                      ),
              ),
              if (_bids.isNotEmpty) _buildBottomBar(),
            ],
          ),
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

  Widget _buildNumberPad() {
    final numbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    return Wrap(
      spacing: 3,
      runSpacing: 5,
      alignment: WrapAlignment.center,
      children: numbers.map((number) {
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
                  color: Colors.amber,
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
                pana,
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
                type.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeBid(pana),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    int totalBidsCount = _bids.length;
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
            onPressed: _showConfirmationDialogAndSubmitBids,
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
