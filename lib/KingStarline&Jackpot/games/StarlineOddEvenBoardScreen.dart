import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../StarlineBidService.dart' as BidService;

enum GameType { odd, even }

class StarlineOddEvenBoardScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType;
  final String gameName;
  final bool selectionStatus;

  const StarlineOddEvenBoardScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
    this.gameName = "",
    required this.selectionStatus,
  }) : super(key: key);

  @override
  _StarlineOddEvenBoardScreenState createState() =>
      _StarlineOddEvenBoardScreenState();
}

class _StarlineOddEvenBoardScreenState
    extends State<StarlineOddEvenBoardScreen> {
  GameType? _selectedGameType = GameType.odd;
  final String _selectedGameSessionType = 'OPEN';

  final TextEditingController _pointsController = TextEditingController();

  List<Map<String, String>> _entries = [];

  late GetStorage storage = GetStorage();
  late String _registerId;
  late String _preferredLanguage;
  bool _accountStatus = false;
  late int _walletBalance;

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  bool _isApiCalling = false;

  late final BidService.StarlineBidService _bidService;

  @override
  void initState() {
    super.initState();
    _bidService = BidService.StarlineBidService(storage);
    _loadInitialData();
    _setupStorageListeners();
  }

  void _loadInitialData() {
    _registerId = storage.read('registerId') ?? '';
    _accountStatus = storage.read('accountStatus') ?? false;
    _preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    final dynamic storedWalletBalance = storage.read('walletBalance');
    if (storedWalletBalance is String) {
      _walletBalance = int.tryParse(storedWalletBalance) ?? 0;
    } else if (storedWalletBalance is int) {
      _walletBalance = storedWalletBalance;
    } else {
      _walletBalance = 0;
    }
  }

  void _setupStorageListeners() {
    storage.listenKey('registerId', (value) {
      if (mounted) _registerId = value ?? '';
    });
    storage.listenKey('accountStatus', (value) {
      if (mounted) _accountStatus = value ?? false;
    });
    storage.listenKey('selectedLanguage', (value) {
      if (mounted) _preferredLanguage = value ?? 'en';
    });
    storage.listenKey('walletBalance', (value) {
      if (mounted) {
        if (value is String) {
          _walletBalance = int.tryParse(value) ?? 0;
        } else if (value is int) {
          _walletBalance = value;
        } else {
          _walletBalance = 0;
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
  }

  void _clearMessage() {
    if (mounted && _messageToShow != null) {
      setState(() {
        _messageToShow = null;
      });
    }
  }

  void _addEntry() {
    _clearMessage();
    if (_isApiCalling) return;

    String points = _pointsController.text.trim();
    String type = _selectedGameSessionType;

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

      final existingIndex = _entries.indexWhere(
        (entry) => entry['bidType'] == bidType,
      );

      int currentTotalPoints = _getTotalPoints();
      int pointsForThisBid = int.parse(points);
      int totalPointsWithNewBid = currentTotalPoints;

      if (existingIndex != -1) {
        final existingPoints =
            (int.tryParse(_entries[existingIndex]['points']!) ?? 0) *
            digitsToAdd.length;
        totalPointsWithNewBid -= existingPoints;
      }
      totalPointsWithNewBid += pointsForThisBid * digitsToAdd.length;

      if (totalPointsWithNewBid > _walletBalance) {
        _showMessage(
          'Insufficient wallet balance to place this bid. You need $totalPointsWithNewBid points.',
          isError: true,
        );
        return;
      }

      setState(() {
        if (existingIndex != -1) {
          _entries.removeWhere((entry) => entry['bidType'] == bidType);
          for (String digit in digitsToAdd) {
            _entries.add({
              'digit': digit,
              'points': points,
              'type': type,
              'bidType': bidType,
            });
          }
          _showMessage('Updated points for $bidType bid.');
        } else {
          for (String digit in digitsToAdd) {
            _entries.add({
              'digit': digit,
              'points': points,
              'type': type,
              'bidType': bidType,
            });
          }
          _showMessage('Added $bidType bid.');
        }
        _pointsController.clear();
      });
    } else {
      _showMessage('Please select a game type (Odd/Even).', isError: true);
    }
  }

  void _deleteEntry(int index) {
    _clearMessage();
    if (_isApiCalling) return;

    final removedEntryBidType = _entries[index]['bidType'];
    if (removedEntryBidType != null) {
      setState(() {
        _entries.removeWhere(
          (entry) => entry['bidType'] == removedEntryBidType,
        );
        _showMessage(
          'Removed all entries for $removedEntryBidType.',
          isError: false,
        );
      });
    }
  }

  int _getTotalPoints() {
    final uniqueBidTypes = _entries.map((e) => e['bidType']).toSet();
    int totalPoints = 0;
    for (var bidType in uniqueBidTypes) {
      final entry = _entries.firstWhere((e) => e['bidType'] == bidType);
      totalPoints += (int.tryParse(entry['points'] ?? '0') ?? 0) * 5;
    }
    return totalPoints;
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;
    if (_entries.isEmpty) {
      _showMessage('Please add at least one entry.', isError: true);
      return;
    }

    final uniqueBidTypes = _entries.map((e) => e['bidType']).toSet();
    final List<Map<String, String>> bidsForDialog = [];
    for (var bidType in uniqueBidTypes) {
      final entry = _entries.firstWhere((e) => e['bidType'] == bidType);
      bidsForDialog.add({
        "digit": bidType!,
        "pana": "",
        "points": (int.tryParse(entry['points']!)! * 5).toString(),
        "type": entry['type']!,
        "bidType": bidType,
      });
    }

    final int totalPoints = _getTotalPoints();

    if (_walletBalance < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid. You need $totalPoints points.',
        isError: true,
      );
      return;
    }

    // Set the flag here to prevent screen from being popped while dialog is visible
    setState(() {
      _isApiCalling = true;
    });

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false, // Prevents the dialog from being popped
          child: BidConfirmationDialog(
            gameTitle: widget.title,
            gameDate: formattedDate,
            bids: bidsForDialog,
            totalBids: bidsForDialog.length,
            totalBidsAmount: totalPoints,
            walletBalanceBeforeDeduction: _walletBalance,
            walletBalanceAfterDeduction: (_walletBalance - totalPoints)
                .toString(),
            gameId: widget.gameId.toString(),
            gameType: widget.gameType,
            onConfirm: () async {
              // Pop the confirmation dialog first
              Navigator.pop(dialogContext);
              // Then, proceed with the bid submission logic
              _placeFinalBids(totalPoints);
            },
          ),
        );
      },
    );
  }

  // Future<void> _placeFinalBids(int totalPointsForSubmission) async {
  //   _clearMessage();
  //
  //   final String? accessToken = storage.read('accessToken');
  //   final String? deviceId = storage.read('deviceId');
  //   final String? deviceName = storage.read('deviceName');
  //
  //   if (accessToken == null || deviceId == null || deviceName == null) {
  //     if (mounted) {
  //       _showMessage(
  //         'Authentication error. Please log in again.',
  //         isError: true,
  //       );
  //       setState(() {
  //         _isApiCalling = false;
  //       });
  //     }
  //     return;
  //   }
  //
  //   Map<String, String> bidAmounts = {};
  //   for (var entry in _entries) {
  //     bidAmounts[entry['digit']!] = entry['points']!;
  //   }
  //   final String selectedGameType = _entries.first['type']!;
  //
  //   try {
  //     final response = await _bidService.placeFinalBids(
  //       gameName: widget.title,
  //       accessToken: accessToken,
  //       registerId: _registerId,
  //       deviceId: deviceId,
  //       deviceName: deviceName,
  //       accountStatus: _accountStatus,
  //       bidAmounts: bidAmounts,
  //       selectedGameType: selectedGameType,
  //       gameId: widget.gameId,
  //       gameType: widget.gameType,
  //       totalBidAmount: totalPointsForSubmission,
  //     );
  //
  //     // Use addPostFrameCallback to safely show the next dialog after the current one has been fully removed.
  //     WidgetsBinding.instance.addPostFrameCallback((_) async {
  //       if (!mounted) return;
  //
  //       if (response['status'] == true) {
  //         final int newBalance = _walletBalance - totalPointsForSubmission;
  //         await _bidService.updateWalletBalance(newBalance);
  //
  //         if (mounted) {
  //           setState(() {
  //             _walletBalance = newBalance;
  //             _entries.clear();
  //             _pointsController.clear();
  //           });
  //           _showMessage('All bids submitted successfully!');
  //           await showDialog(
  //             context: context,
  //             barrierDismissible: false,
  //             builder: (ctx) => const BidSuccessDialog(),
  //           );
  //         }
  //       } else {
  //         String errorMessage = response['msg'] ?? 'Unknown error occurred.';
  //         if (mounted) {
  //           _showMessage(errorMessage, isError: true);
  //           await showDialog(
  //             context: context,
  //             barrierDismissible: false,
  //             builder: (ctx) => BidFailureDialog(errorMessage: errorMessage),
  //           );
  //         }
  //       }
  //     });
  //   } catch (e) {
  //     log("Bid submission error: $e");
  //     // Use addPostFrameCallback to safely show the next dialog
  //     WidgetsBinding.instance.addPostFrameCallback((_) async {
  //       if (!mounted) return;
  //       _showMessage(
  //         'An unexpected error occurred: ${e.toString()}',
  //         isError: true,
  //       );
  //       await showDialog(
  //         context: context,
  //         barrierDismissible: false,
  //         builder: (ctx) => BidFailureDialog(
  //           errorMessage: 'An unexpected error occurred: ${e.toString()}',
  //         ),
  //       );
  //     });
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isApiCalling = false;
  //       });
  //     }
  //   }
  // }

  Future<void> _placeFinalBids(int totalPointsForSubmission) async {
    if (!mounted) return; // Crucial check at the beginning
    _clearMessage();

    final String? accessToken = storage.read('accessToken');
    final String? deviceId = storage.read('deviceId');
    final String? deviceName = storage.read('deviceName');

    if (accessToken == null || deviceId == null || deviceName == null) {
      if (mounted) {
        _showMessage(
          'Authentication error. Please log in again.',
          isError: true,
        );
        setState(() {
          _isApiCalling = false;
        });
      }
      return;
    }

    Map<String, String> bidAmounts = {};
    for (var entry in _entries) {
      bidAmounts[entry['digit']!] = entry['points']!;
    }
    final String selectedGameType = _entries.first['type']!;

    try {
      final response = await _bidService.placeFinalBids(
        gameName: widget.title,
        accessToken: accessToken,
        registerId: _registerId,
        deviceId: deviceId,
        deviceName: deviceName,
        accountStatus: _accountStatus,
        bidAmounts: bidAmounts,
        selectedGameType: selectedGameType,
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: totalPointsForSubmission,
      );

      if (!mounted) return; // Critical check after the async call completes

      if (response['status'] == true) {
        final int newBalance = _walletBalance - totalPointsForSubmission;
        await _bidService.updateWalletBalance(newBalance);

        if (mounted) {
          // Check again before setState and showDialog
          setState(() {
            _walletBalance = newBalance;
            _entries.clear();
            _pointsController.clear();
          });
          _showMessage('All bids submitted successfully!');

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const BidSuccessDialog(),
          );
        }
      } else {
        String errorMessage = response['msg'] ?? 'Unknown error occurred.';
        if (mounted) {
          // Check again before showing dialog
          _showMessage(errorMessage, isError: true);

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => BidFailureDialog(errorMessage: errorMessage),
          );
        }
      }
    } catch (e) {
      log("Bid submission error: $e");
      if (!mounted) return; // Check again
      _showMessage(
        'An unexpected error occurred: ${e.toString()}',
        isError: true,
      );

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => BidFailureDialog(
          errorMessage: 'An unexpected error occurred: ${e.toString()}',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApiCalling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isApiCalling,
      child: Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: _isApiCalling ? Colors.grey : Colors.black,
            ),
            onPressed: _isApiCalling ? null : () => Navigator.pop(context),
          ),
          title: Text(
            widget.title,
            style: GoogleFonts.poppins(
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
                  Image.asset(
                    "assets/images/ic_wallet.png",
                    width: 22,
                    height: 22,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _walletBalance.toString(),
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
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<GameType>(
                              title: const Text('Odd'),
                              value: GameType.odd,
                              groupValue: _selectedGameType,
                              onChanged: _isApiCalling
                                  ? null
                                  : (GameType? value) {
                                      setState(() {
                                        _selectedGameType = value;
                                      });
                                    },
                              activeColor: Colors.orange,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<GameType>(
                              title: const Text('Even'),
                              value: GameType.even,
                              groupValue: _selectedGameType,
                              onChanged: _isApiCalling
                                  ? null
                                  : (GameType? value) {
                                      setState(() {
                                        _selectedGameType = value;
                                      });
                                    },
                              activeColor: Colors.orange,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Enter Points :',
                              style: GoogleFonts.poppins(
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
                              onPressed: _isApiCalling ? null : _addEntry,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isApiCalling
                                    ? Colors.grey
                                    : Colors.orange,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 3,
                              ),
                              child: _isApiCalling
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'ADD',
                                      style: GoogleFonts.poppins(
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
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Digit',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Points',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Type',
                            style: GoogleFonts.poppins(
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
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _entries
                              .map((e) => e['bidType'])
                              .toSet()
                              .length,
                          itemBuilder: (context, index) {
                            final uniqueBidTypes = _entries
                                .map((e) => e['bidType'])
                                .whereType<String>()
                                .toSet()
                                .toList();

                            if (index >= uniqueBidTypes.length) {
                              return const SizedBox.shrink();
                            }

                            final uniqueEntry = _entries.firstWhere(
                              (e) => e['bidType'] == uniqueBidTypes[index],
                            );

                            return _buildEntryItem(
                              uniqueEntry['bidType']!,
                              (int.tryParse(uniqueEntry['points']!)! * 5)
                                  .toString(),
                              uniqueEntry['type']!,
                              index,
                              uniqueBidTypes,
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
        cursorColor: Colors.orange,
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onTap: _clearMessage,
        enabled: !_isApiCalling,
        decoration: InputDecoration(
          hintText: 'Enter Points',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: _isApiCalling
              ? null
              : Container(
                  margin: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
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

  Widget _buildEntryItem(
    String bidType,
    String points,
    String type,
    int index,
    List<String> uniqueBidTypes,
  ) {
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
                bidType,
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
              onPressed: _isApiCalling
                  ? null
                  : () => _deleteEntryFromUniqueList(index, uniqueBidTypes),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEntryFromUniqueList(int index, List<String> uniqueBidTypes) {
    _clearMessage();
    if (_isApiCalling) return;
    final removedBidType = uniqueBidTypes[index];
    setState(() {
      _entries.removeWhere((entry) => entry['bidType'] == removedBidType);
      _showMessage('Removed all entries for $removedBidType.', isError: false);
    });
  }

  Widget _buildBottomBar() {
    final uniqueBidTypes = _entries.map((e) => e['bidType']).toSet();
    final totalBids = uniqueBidTypes.length;
    final totalPoints = _getTotalPoints();

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
                'Total Bids',
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
                'Total Points',
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
            onPressed: (_isApiCalling || _entries.isEmpty)
                ? null
                : _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: (_isApiCalling || _entries.isEmpty)
                  ? Colors.grey
                  : Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: _isApiCalling
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
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
