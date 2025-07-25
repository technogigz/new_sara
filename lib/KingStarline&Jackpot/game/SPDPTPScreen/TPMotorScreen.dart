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

class TPMotorsBetScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType;
  final int gameId;
  final String gameName;

  const TPMotorsBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
  });

  @override
  State<TPMotorsBetScreen> createState() => _TPMotorsBetScreenState();
}

class _TPMotorsBetScreenState extends State<TPMotorsBetScreen> {
  final List<String> gameTypesOptions = const ["Open", "Close"];
  late String selectedGameBetType;

  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  // --- Triple Patti specific list ---
  List<String> triplePanaOptions = [
    "111",
    "222",
    "333",
    "444",
    "555",
    "666",
    "777",
    "888",
    "999",
    "000",
  ];
  List<String> filteredDigitOptions = [];
  bool _isDigitSuggestionsVisible = false;
  // --- End Triple Patti specific list ---

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
    storage = GetStorage();
    _loadInitialData();
    _setupStorageListeners();

    // Add listener for digitController
    digitController.addListener(_onDigitChanged);

    selectedGameBetType = gameTypesOptions[0];
  }

  // _onDigitChanged method for filtering Triple Patti
  void _onDigitChanged() {
    final query = digitController.text.trim();
    if (query.isNotEmpty) {
      setState(() {
        filteredDigitOptions = triplePanaOptions
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
    // Remove listener for digitController
    digitController.removeListener(_onDigitChanged);
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
    if (_isApiCalling) return;

    final digit = digitController.text.trim();
    final points = pointsController.text.trim();

    if (digit.isEmpty) {
      _showMessage('Please enter a 3-digit number.', isError: true);
      return;
    }

    if (digit.length != 3 || int.tryParse(digit) == null) {
      _showMessage(
        'Please enter a valid 3-digit number (e.g., 123).',
        isError: true,
      );
      return;
    }

    // Validate if the digit is in the Triple_Pana list
    if (!triplePanaOptions.contains(digit)) {
      _showMessage(
        'Invalid 3-digit number. Not a valid Triple Patti.',
        isError: true,
      );
      return;
    }

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
          'Updated points for Triple Patti: $digit, Type: $selectedGameBetType.',
        );
      } else {
        addedEntries.add({
          "digit": digit,
          "points": points,
          "type": selectedGameBetType,
        });
        _showMessage(
          'Added bid: Triple Patti $digit, Points $points, Type $selectedGameBetType.',
        );
      }
      digitController.clear();
      pointsController.clear();
      _isDigitSuggestionsVisible = false; // Hide suggestions after adding
    });
  }

  void _removeEntry(int index) {
    if (_isApiCalling) return;

    setState(() {
      final removedEntry = addedEntries[index];
      addedEntries.removeAt(index);
      _showMessage(
        'Removed bid: Triple Patti ${removedEntry['digit']}, Type ${removedEntry['type']}.',
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

    // --- Authentication Check ---
    // This check is good as it provides an immediate error without an API call.
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
      return false; // Return false immediately on auth error
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
        "pana": bidDigit,
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

      // Handle success
      if (response.statusCode == 200 &&
          (responseBody['status'] == true ||
              responseBody['status'] == 'true')) {
        // Added string 'true' check for robustness
        int newWalletBalance = walletBalance - _getTotalPoints();
        await storage.write('walletBalance', newWalletBalance);

        if (mounted) {
          setState(() {
            walletBalance = newWalletBalance;
          });
          // Show success dialog
          await showDialog(
            // Use await to ensure dialog is dismissed before continuing
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const BidSuccessDialog();
            },
          );
          // After success, it might be good to clear any previous messages
          _clearMessage();
        }
        return true; // Return true on successful bid
      }
      // Handle API-specific errors (status code 200 but backend 'status' is false)
      else if (responseBody['status'] == false ||
          responseBody['status'] == 'false') {
        String errorMessage =
            responseBody['msg'] ?? "An error occurred during the bid process.";
        if (mounted) {
          await showDialog(
            // Use await here too
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return BidFailureDialog(errorMessage: errorMessage);
            },
          );
        }
        return false; // Return false on API-reported failure
      }
      // Handle other HTTP status codes (e.g., 400, 401, 500)
      else {
        String errorMessage =
            'Server error (${response.statusCode}): ${responseBody['msg'] ?? 'Unknown error'}.';
        if (mounted) {
          await showDialog(
            // Use await here too
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return BidFailureDialog(errorMessage: errorMessage);
            },
          );
        }
        return false; // Return false on generic HTTP error
      }
    } catch (e) {
      log('Error during bid submission: $e');
      if (mounted) {
        await showDialog(
          // Use await here too
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
      return false; // Return false on network/exception error
    } finally {
      // This `finally` block is important. It ensures _isApiCalling is reset
      // regardless of whether the try or catch block was executed.
      // However, in your current structure, it's being handled in _showConfirmationDialog.
      // Let's ensure consistency. If you reset it there, you don't strictly need it here,
      // but this pattern is generally safer for complex async operations.
      // For now, let's keep it as is, but be mindful of duplicated state management.
    }
  }
  // Future<bool> _placeFinalBids() async {
  //   String url;
  //   final gameCategory = widget.gameCategoryType.toLowerCase();
  //
  //   if (gameCategory.contains('jackpot')) {
  //     url = '${Constant.apiEndpoint}place-jackpot-bid';
  //   } else if (gameCategory.contains('starline')) {
  //     url = '${Constant.apiEndpoint}place-starline-bid';
  //   } else {
  //     url = '${Constant.apiEndpoint}place-bid';
  //   }
  //
  //   if (accessToken.isEmpty || registerId.isEmpty) {
  //     if (mounted) {
  //       showDialog(
  //         context: context,
  //         barrierDismissible: false,
  //         builder: (BuildContext context) {
  //           return const BidFailureDialog(
  //             errorMessage: 'Authentication error. Please log in again.',
  //           );
  //         },
  //       );
  //     }
  //     return false;
  //   }
  //
  //   final headers = {
  //     'deviceId': _deviceId,
  //     'deviceName': _deviceName,
  //     'accessStatus': accountStatus ? '1' : '0',
  //     'Content-Type': 'application/json',
  //     'Authorization': 'Bearer $accessToken',
  //   };
  //
  //   final List<Map<String, dynamic>> bidPayload = addedEntries.map((entry) {
  //     final String bidDigit = entry['digit'] ?? '';
  //     final int bidAmount = int.tryParse(entry['points'] ?? '0') ?? 0;
  //
  //     return {
  //       "sessionType": entry['type']?.toUpperCase() ?? '',
  //       "digit": bidDigit,
  //       "pana": bidDigit,
  //       "bidAmount": bidAmount,
  //     };
  //   }).toList();
  //
  //   final body = jsonEncode({
  //     "registerId": registerId,
  //     "gameId": widget.gameId,
  //     "bidAmount": _getTotalPoints(),
  //     "gameType": gameCategory,
  //     "bid": bidPayload,
  //   });
  //
  //   log('Placing bid to URL: $url');
  //   log('Request Headers: $headers');
  //   log('Request Body: $body');
  //
  //   try {
  //     final response = await http.post(
  //       Uri.parse(url),
  //       headers: headers,
  //       body: body,
  //     );
  //
  //     final Map<String, dynamic> responseBody = json.decode(response.body);
  //     log('API Response: $responseBody');
  //
  //     if (response.statusCode == 200 && responseBody['status'] == true) {
  //       int newWalletBalance = walletBalance - _getTotalPoints();
  //       await storage.write('walletBalance', newWalletBalance);
  //
  //       if (mounted) {
  //         setState(() {
  //           walletBalance = newWalletBalance;
  //         });
  //         showDialog(
  //           context: context,
  //           barrierDismissible: false,
  //           builder: (BuildContext context) {
  //             return const BidSuccessDialog();
  //           },
  //         );
  //       }
  //       return true;
  //     } else {
  //       String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
  //       if (mounted) {
  //         showDialog(
  //           context: context,
  //           barrierDismissible: false,
  //           builder: (BuildContext context) {
  //             return BidFailureDialog(errorMessage: errorMessage);
  //           },
  //         );
  //       }
  //       return false;
  //     }
  //   } catch (e) {
  //     log('Error during bid submission: $e');
  //     if (mounted) {
  //       showDialog(
  //         context: context,
  //         barrierDismissible: false,
  //         builder: (BuildContext context) {
  //           return const BidFailureDialog(
  //             errorMessage:
  //                 'Network error. Please check your internet connection.',
  //           );
  //         },
  //       );
  //     }
  //     return false;
  //   }
  // }

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
                    // Digit Input Field with suggestions
                    _inputRow(
                      "Enter 3-Digit Triple Panna:",
                      _buildDigitInputField(),
                    ),
                    // Added suggestions list conditionally
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
                    // End Added suggestions list
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
          LengthLimitingTextInputFormatter(3),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: () {
          _clearMessage();
          _onDigitChanged(); // Trigger suggestions on tap if text is present
        },
        onChanged: (value) {
          _onDigitChanged(); // Filter suggestions as user types
        },
        enabled: !_isApiCalling,
        decoration: InputDecoration(
          hintText: "Enter 3-Digit Triple Panna",
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
