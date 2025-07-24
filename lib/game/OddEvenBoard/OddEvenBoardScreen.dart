import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:marquee/marquee.dart';
import 'package:new_sara/ulits/Constents.dart'; // Retained your original import path for Constents

import '../../components/BidConfirmationDialog.dart';

// AnimatedMessageBar component
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

enum GameType { odd, even }

enum LataDayType { open, close }

class OddEvenBoardScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType;
  final String gameName;

  const OddEvenBoardScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
    this.gameName = "",
  }) : super(key: key);

  @override
  _OddEvenBoardScreenState createState() => _OddEvenBoardScreenState();
}

class _OddEvenBoardScreenState extends State<OddEvenBoardScreen> {
  GameType? _selectedGameType = GameType.odd;
  LataDayType? _selectedLataDayType = LataDayType.close;

  final TextEditingController _pointsController = TextEditingController();

  List<Map<String, String>> _entries = [];

  late GetStorage storage = GetStorage();
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance;

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _pointsController.dispose();
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

    setState(() {
      String points = _pointsController.text.trim();
      String type = _selectedLataDayType == LataDayType.close
          ? 'CLOSE'
          : 'OPEN';

      if (points.isEmpty ||
          int.tryParse(points) == null ||
          int.parse(points) < 10 ||
          int.parse(points) > 1000) {
        _showMessage('Points must be between 10 and 1000.', isError: true);
        return;
      }

      if (_selectedGameType != null) {
        List<String> digitsToAdd;
        String bidType;
        if (_selectedGameType == GameType.odd) {
          digitsToAdd = ['1', '3', '5', '7', '9'];
          bidType = "Odd";
        } else {
          digitsToAdd = ['0', '2', '4', '6', '8'];
          bidType = "Even";
        }

        _entries.removeWhere(
          (entry) =>
              entry['type'] == type &&
              (entry['bidType'] == "Odd" || entry['bidType'] == "Even"),
        );

        for (String digit in digitsToAdd) {
          _entries.add({
            'digit': digit,
            'points': points,
            'type': type,
            'bidType': bidType,
          });
        }
        _pointsController.clear();
        _showMessage('Entry added successfully!', isError: false);
      } else {
        _showMessage(
          'Please select game type and enter points.',
          isError: true,
        );
      }
    });
  }

  void _deleteEntry(int index) {
    _clearMessage();
    setState(() {
      _entries.removeAt(index);
      _showMessage('Entry deleted.', isError: false);
    });
  }

  int getTotalPoints() {
    return _entries.fold(
      0,
      (sum, item) => sum + int.tryParse(item['points'] ?? '0')!,
    );
  }

  void _showConfirmationDialog() {
    _clearMessage();

    if (_entries.isEmpty) {
      _showMessage('Please add at least one entry.', isError: true);
      return;
    }

    final int totalPoints = getTotalPoints();

    if (walletBalance < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
      return;
    }

    List<Map<String, String>> bidsForDialog = _entries.map((entry) {
      return {
        "digit": entry['digit']!,
        "pana": "",
        "points": entry['points']!,
        "type": entry['type']!,
        "bidType": entry['bidType']!,
      };
    }).toList();

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
          bids: bidsForDialog,
          totalBids: bidsForDialog.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            Navigator.pop(dialogContext);
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                _entries.clear();
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
      'deviceId': 'qwert',
      'deviceName': 'sm2233',
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final List<Map<String, dynamic>> bidPayload = _entries.map((entry) {
      String sessionType = entry["type"] ?? "";
      String digit = entry["digit"] ?? "";
      int bidAmount = int.tryParse(entry["points"] ?? '0') ?? 0;

      return {
        "sessionType": sessionType,
        "digit": digit,
        "pana": "",
        "bidAmount": bidAmount,
      };
    }).toList();

    final body = {
      "registerId": registerId,
      "gameId": widget.gameId,
      "bidAmount": getTotalPoints(),
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
        int deductedAmount = getTotalPoints();
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
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.black),
                const SizedBox(width: 4),
                Text(
                  walletBalance.toString(),
                  style: const TextStyle(color: Colors.black, fontSize: 16),
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Game Type',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<LataDayType>(
                              value: _selectedLataDayType,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.amber,
                              ),
                              onChanged: (LataDayType? newValue) {
                                setState(() {
                                  _selectedLataDayType = newValue;
                                });
                              },
                              items:
                                  <LataDayType>[
                                    LataDayType.close,
                                    LataDayType.open,
                                  ].map<DropdownMenuItem<LataDayType>>((
                                    LataDayType value,
                                  ) {
                                    return DropdownMenuItem<LataDayType>(
                                      value: value,
                                      child: SizedBox(
                                        width: 150,
                                        height: 20,
                                        child: Marquee(
                                          text: value == LataDayType.close
                                              ? '${widget.title} CLOSE'
                                              : '${widget.title} OPEN',
                                          style: const TextStyle(fontSize: 16),
                                          scrollAxis: Axis.horizontal,
                                          blankSpace: 40.0,
                                          velocity: 30.0,
                                          pauseAfterRound: const Duration(
                                            seconds: 1,
                                          ),
                                          startPadding: 10.0,
                                          accelerationDuration: const Duration(
                                            seconds: 1,
                                          ),
                                          accelerationCurve: Curves.linear,
                                          decelerationDuration: const Duration(
                                            milliseconds: 500,
                                          ),
                                          decelerationCurve: Curves.easeOut,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<GameType>(
                            title: const Text('Odd'),
                            value: GameType.odd,
                            groupValue: _selectedGameType,
                            onChanged: (GameType? value) {
                              setState(() {
                                _selectedGameType = value;
                              });
                            },
                            activeColor: Colors.amber,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<GameType>(
                            title: const Text('Even'),
                            value: GameType.even,
                            groupValue: _selectedGameType,
                            onChanged: (GameType? value) {
                              setState(() {
                                _selectedGameType = value;
                              });
                            },
                            activeColor: Colors.amber,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Enter Points :',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPointsInputField(_pointsController),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 150,
                          child: ElevatedButton(
                            onPressed: _addEntry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 3,
                            ),
                            child: const Text(
                              'ADD',
                              style: TextStyle(
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
              Divider(height: 1, color: Colors.grey[400]),
              if (_entries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Digit',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'Points',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Type',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              if (_entries.isNotEmpty)
                Divider(height: 1, color: Colors.grey[400]),
              Expanded(
                child: _entries.isEmpty
                    ? Center(
                        child: Text(
                          'No entries yet. Add some data!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          return _buildEntryItem(
                            entry['digit']!,
                            entry['points']!,
                            entry['type']!,
                            index,
                          );
                        },
                      ),
              ),
              if (_entries.isNotEmpty) _buildBottomBar(),
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

  Widget _buildPointsInputField(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        cursorColor: Colors.amber,
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onTap: _clearMessage,
        decoration: InputDecoration(
          hintText: 'Enter Points',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryItem(String digit, String points, String type, int index) {
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
                digit,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                points,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                type,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteEntry(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    int totalBids = _entries.length;
    int totalPoints = getTotalPoints();

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
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              Text(
                '$totalBids',
                style: const TextStyle(
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
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              Text(
                '$totalPoints',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: const Text(
              'SUBMIT',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
