import 'dart:async'; // For Timer
import 'dart:convert'; // For jsonEncode, json.decode
import 'dart:developer'; // For log

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get_storage/get_storage.dart'; // Required for wallet balance and tokens
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
import 'package:http/http.dart' as http; // Import for making HTTP requests
// Marquee is not directly visible in the image, but often used for market names.
// I'll omit it for simplicity as it's not explicitly requested for this screen's UI.
// import 'package:marquee/marquee.dart';
import 'package:intl/intl.dart'; // For date formatting in dialog

import '../../../../components/AnimatedMessageBar.dart';
import '../../../../components/BidConfirmationDialog.dart';
import '../../../../components/BidFailureDialog.dart';
import '../../../../components/BidSuccessDialog.dart';
import '../../../ulits/Constents.dart'; // Retained your original import path

class PanelGroupScreen extends StatefulWidget {
  final String title; // e.g., "RADHA MORNING"
  final String gameCategoryType; // e.g., "panelgroup"
  final int gameId;
  final String gameName; // e.g., "Panel Group"

  const PanelGroupScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
  });

  @override
  State<PanelGroupScreen> createState() => _PanelGroupScreenState();
}

class _PanelGroupScreenState extends State<PanelGroupScreen> {
  // Game types options, though not explicitly shown in the image for this screen,
  // it's a common pattern in betting apps. Assuming "Open" is default.
  final List<String> gameTypesOptions = const ["Open", "Close"];
  late String selectedGameBetType; // Default to "Open"

  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  final String deviceId = GetStorage().read('deviceId');
  final String deviceName = GetStorage().read('deviceName');

  List<Map<String, String>> addedEntries = []; // List to store the added bids

  final Set<String> validDigits = {
    "000",
    "100",
    "110",
    "111",
    "112",
    "113",
    "114",
    "115",
    "116",
    "117",
    "118",
    "119",
    "120",
    "122",
    "123",
    "124",
    "125",
    "126",
    "127",
    "128",
    "129",
    "130",
    "133",
    "134",
    "135",
    "136",
    "137",
    "138",
    "139",
    "140",
    "144",
    "145",
    "146",
    "147",
    "148",
    "149",
    "150",
    "155",
    "156",
    "157",
    "158",
    "159",
    "160",
    "166",
    "167",
    "168",
    "169",
    "170",
    "177",
    "178",
    "179",
    "180",
    "188",
    "189",
    "190",
    "199",
    "200",
    "220",
    "222",
    "223",
    "224",
    "225",
    "226",
    "227",
    "228",
    "229",
    "230",
    "233",
    "234",
    "235",
    "236",
    "237",
    "238",
    "239",
    "240",
    "244",
    "245",
    "246",
    "247",
    "248",
    "249",
    "250",
    "255",
    "256",
    "257",
    "258",
    "259",
    "260",
    "266",
    "267",
    "268",
    "269",
    "270",
    "277",
    "278",
    "279",
    "280",
    "288",
    "289",
    "290",
    "299",
    "300",
    "330",
    "333",
    "334",
    "335",
    "336",
    "337",
    "338",
    "339",
    "340",
    "344",
    "345",
    "346",
    "347",
    "348",
    "349",
    "350",
    "355",
    "356",
    "357",
    "358",
    "359",
    "360",
    "366",
    "367",
    "368",
    "369",
    "370",
    "377",
    "378",
    "379",
    "380",
    "388",
    "389",
    "390",
    "399",
    "400",
    "440",
    "444",
    "445",
    "446",
    "447",
    "448",
    "449",
    "450",
    "455",
    "456",
    "457",
    "458",
    "459",
    "460",
    "466",
    "467",
    "468",
    "469",
    "470",
    "477",
    "478",
    "479",
    "480",
    "488",
    "489",
    "490",
    "499",
    "500",
    "550",
    "555",
    "556",
    "557",
    "558",
    "559",
    "560",
    "566",
    "567",
    "568",
    "569",
    "570",
    "577",
    "578",
    "579",
    "580",
    "588",
    "589",
    "590",
    "599",
    "600",
    "660",
    "666",
    "667",
    "668",
    "669",
    "670",
    "677",
    "678",
    "679",
    "680",
    "688",
    "689",
    "690",
    "699",
    "700",
    "770",
    "777",
    "778",
    "779",
    "780",
    "788",
    "789",
    "790",
    "799",
    "800",
    "880",
    "888",
    "889",
    "890",
    "899",
    "900",
    "990",
    "999",
  };

  // Wallet and user data from GetStorage
  late int walletBalance; // Changed to int for consistency with GetStorage
  final GetStorage _storage = GetStorage();
  late String accessToken;
  late String registerId;
  bool accountStatus = false;
  late String preferredLanguage;

  late final String _deviceId;
  late final String _deviceName;

  // State management for AnimatedMessageBar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  // State variable to track API call status
  bool _isApiCalling = false;

  @override
  void initState() {
    super.initState();
    selectedGameBetType = gameTypesOptions[0]; // Default to "Open"
    _loadInitialData();
    _setupStorageListeners();
  }

  Future<void> _loadInitialData() async {
    accessToken = _storage.read('accessToken') ?? '';
    registerId = _storage.read('registerId') ?? '';
    accountStatus = _storage.read('accountStatus') ?? false;
    preferredLanguage = _storage.read('selectedLanguage') ?? 'en';
    _deviceId = GetStorage().read('deviceId');
    _deviceName = GetStorage().read('deviceName');

    final dynamic storedWalletBalance = _storage.read('walletBalance');
    if (storedWalletBalance is int) {
      walletBalance = storedWalletBalance;
    } else if (storedWalletBalance is String) {
      walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else {
      walletBalance = 0;
    }
  }

  void _setupStorageListeners() {
    _storage.listenKey('accessToken', (value) {
      if (mounted) setState(() => accessToken = value ?? '');
    });
    _storage.listenKey('registerId', (value) {
      if (mounted) setState(() => registerId = value ?? '');
    });
    _storage.listenKey('accountStatus', (value) {
      if (mounted) setState(() => accountStatus = value ?? false);
    });
    _storage.listenKey('selectedLanguage', (value) {
      if (mounted) setState(() => preferredLanguage = value ?? 'en');
    });
    _storage.listenKey('walletBalance', (value) {
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

  Future<void> _addEntry() async {
    if (!mounted) return;

    if (_isApiCalling) {
      _showMessage('An operation is already in progress.', isError: true);
      return;
    }

    final String digit = digitController.text.trim();
    final String points = pointsController.text.trim();

    if (digit.isEmpty || digit.length != 3 || int.tryParse(digit) == null) {
      _showMessage('Please enter a valid 3-digit number.', isError: true);
      return;
    }

    if (!validDigits.contains(digit)) {
      _showMessage(
        'Invalid digit. The entered 3-digit number is not in the allowed list.',
        isError: true,
      );
      return;
    }

    final int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage(
        'Points must be a number between 10 and 1000.',
        isError: true,
      );
      return;
    }

    if (accessToken == null || accessToken.isEmpty) {
      _showMessage('Authentication error. Please log in again.', isError: true);
      log(
        'Error: Access token is missing in _addEntry.',
        name: 'PanelGroupAddEntry',
      );
      return;
    }

    if (deviceId == null || deviceId.isEmpty) {
      log(
        'Warning: Device ID is missing in _addEntry. API call might fail.',
        name: 'PanelGroupAddEntry',
      );
    }

    if (!mounted) return;

    setState(() => _isApiCalling = true);

    try {
      final List<Map<String, String>> newEntries = await _callAddEntryApi(
        digit: digit,
        points: parsedPoints,
      );

      if (mounted) {
        if (newEntries.isNotEmpty) {
          setState(() => addedEntries.addAll(newEntries));
          _showMessage('Added ${newEntries.length} bid(s) successfully.');
        } else {
          _showMessage(
            'API returned data, but no valid panas to add.',
            isError: false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApiCalling = false;
          digitController.clear();
          pointsController.clear();
        });
      }
    }
  }

  Future<List<Map<String, String>>> _callAddEntryApi({
    required String digit,
    required int points,
  }) async {
    final headers = {
      'deviceId': deviceId ?? '',
      'deviceName': deviceName ?? '',
      'accessStatus': accountStatus == true ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final body = jsonEncode({
      'digit': digit,
      'sessionType': selectedGameBetType?.toLowerCase() ?? 'open',
      'amount': points,
    });

    log(
      "API Call to panel-group-pana: Headers: $headers, Body: $body",
      name: "PanelGroupAddEntry",
    );

    final response = await http
        .post(
          Uri.parse('${Constant.apiEndpoint}panel-group-pana'),
          headers: headers,
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    final responseData = jsonDecode(response.body);
    log(
      "API Response panel-group-pana (Status ${response.statusCode}): $responseData",
      name: "PanelGroupAddEntry",
    );

    if (response.statusCode == 200 && responseData['status'] == true) {
      final List<dynamic>? info = responseData['info'] as List<dynamic>?;
      if (info == null || info.isEmpty) {
        throw Exception(
          'No bids returned from the server for the provided digit.',
        );
      }

      final List<Map<String, String>> newEntries = [];
      for (var item in info) {
        final String? panaValue = item['pana']?.toString();
        if (panaValue != null && panaValue.isNotEmpty) {
          newEntries.add({
            'digit': panaValue,
            'points': points.toString(),
            'type': selectedGameBetType ?? 'Unknown',
          });
        } else {
          log(
            "Warning: API response item missing 'pana': $item",
            name: "PanelGroupAddEntry",
          );
        }
      }

      return newEntries;
    } else {
      final errorMessage =
          responseData['msg']?.toString() ?? 'Unknown API error occurred.';
      throw Exception(
        'API error: $errorMessage (Status: ${response.statusCode})',
      );
    }
  }

  void _removeEntry(int index) {
    if (_isApiCalling) return;

    setState(() {
      final removedEntry = addedEntries[index];
      addedEntries.removeAt(index);
      _showMessage(
        'Removed bid: Digit ${removedEntry['digit']}, Type ${removedEntry['type']}.',
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
    if (_isApiCalling) return;

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
              "pana": bid['digit']!,
              "jodi": "",
            };
          }).toList(),
          totalBids: addedEntries.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameCategoryType,
          onConfirm: () async {
            // Navigator.pop(dialogContext);
            setState(() {
              _isApiCalling = true;
            });
            bool success = await _placeFinalBids();
            if (success) {
              setState(() {
                addedEntries.clear();
              });
            }
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
        "digit": bidDigit,
        "pana":
            bidDigit, // For single digit, pana is often the same as the digit
        "bidAmount": bidAmount,
      };
    }).toList();

    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId,
      "bidAmount": _getTotalPoints(),
      "gameType": gameCategory,
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

      if (response.statusCode == 200 &&
          (responseBody['status'] == true ||
              responseBody['status'] == 'true')) {
        int newWalletBalance = walletBalance - _getTotalPoints();
        await _storage.write('walletBalance', newWalletBalance);

        if (mounted) {
          setState(() {
            walletBalance = newWalletBalance;
          });
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const BidSuccessDialog();
            },
          );
          _clearMessage(); // Clear message after success dialog
        }
        return true;
      } else {
        String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
        if (mounted) {
          await showDialog(
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
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const BidFailureDialog(
              errorMessage:
                  'Network error. Please check your internet connection.',
            );
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
          // Use widget.title for the dynamic market name
          "${widget.title}, PANEL GROUP",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        actions: [
          Image.asset(
            "assets/images/ic_wallet.png",
            width: 22,
            height: 22,
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
      body: SafeArea(
        child: Stack(
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
                      // Enter Points Row
                      _buildInputRow(
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
                      const SizedBox(height: 12),
                      // Enter Single Digit Row
                      _buildInputRow(
                        "Enter Digit:",
                        _buildTextField(
                          digitController,
                          "Bid Digits",
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(
                              3,
                            ), // Single digit input
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
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
                          flex: 2,
                          child: Text(
                            "Digit",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "Amount",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
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
                                    flex: 2,
                                    child: Text(
                                      entry['digit']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      entry['points']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      entry['type']!, // This will be "Open" or "Close"
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
                // Bottom Summary Bar (conditional on addedEntries)
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
      ),
    );
  }

  // Helper method for input rows (label + field)
  Widget _buildInputRow(String label, Widget field) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center, // Center align items
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 15, // Slightly larger font for labels
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: field),
      ],
    );
  }

  // Generic TextField builder for consistency
  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      width: double.infinity, // Take full width of the expanded parent
      height: 40, // Consistent height for text fields
      child: TextFormField(
        controller: controller,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: inputFormatters,
        onTap: _clearMessage,
        enabled: !_isApiCalling,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30), // Rounded corners
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
      ),
    );
  }

  // Bottom bar with total bids/points and submit button
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
                  : Colors.orange, // Dim if disabled
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
