// File: lib/Helper/UserController.dart

import 'dart:convert';
import 'dart:developer';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

import '../ulits/Constents.dart';

class UserController extends GetxController {
  final GetStorage _storage = GetStorage();

  // Observable variables. The `.obs` makes them reactive,
  // so the UI will automatically update when their value changes.
  var fullName = ''.obs;
  var mobileNo = ''.obs;
  var mobileNoEnc = ''.obs;
  var walletBalance = '0'.obs;
  var accessToken = ''.obs;
  var registerId = ''.obs;
  var accountStatus = false.obs;

  // Fee settings
  var minBid = '0'.obs;
  var minDeposit = '0'.obs;
  var minWithdraw = '0'.obs;
  var withdrawFees = '0'.obs;
  var withdrawOpenTime = ''.obs;
  var withdrawCloseTime = ''.obs;
  var withdrawStatus = false.obs;

  // Device info, initialized once
  var _deviceId;
  var _deviceName;

  @override
  void onInit() {
    super.onInit();
    // Load initial data from GetStorage when the controller is initialized.
    loadInitialData();
  }

  void loadInitialData() {
    accessToken.value = _storage.read('accessToken') ?? '';
    registerId.value = _storage.read('registerId') ?? '';
    fullName.value = _storage.read('fullName') ?? '';
    mobileNo.value = _storage.read('mobileNo') ?? '';
    mobileNoEnc.value = _storage.read('mobileNoEnc') ?? '';
    walletBalance.value = _storage.read('walletBalance')?.toString() ?? '0';
    accountStatus.value = _storage.read('accountStatus') ?? false;

    // Load initial device info
    _deviceId = _storage.read('deviceId') ?? 'qwert';
    _deviceName = _storage.read('deviceName') ?? 'sm2233';

    // Load initial fee settings
    minBid.value = _storage.read('minBid')?.toString() ?? '0';
    minDeposit.value = _storage.read('minDeposit')?.toString() ?? '0';
    minWithdraw.value = _storage.read('minWithdraw')?.toString() ?? '0';
    withdrawFees.value = _storage.read('withdrawFees')?.toString() ?? '0';
    withdrawOpenTime.value = _storage.read('withdrawOpenTime') ?? '';
    withdrawCloseTime.value = _storage.read('withdrawCloseTime') ?? '';
    withdrawStatus.value = _storage.read('withdrawStatus') ?? false;

    // Load device info
    _deviceId = _storage.read('deviceId') ?? 'qwert';
    _deviceName = _storage.read('deviceName') ?? 'sm2233';
  }

  // Fetches user details from the server and updates state.
  Future<void> fetchAndUpdateUserDetails() async {
    if (registerId.value.isEmpty || accessToken.value.isEmpty) {
      log('User ID or Access Token is missing. Cannot fetch details.');
      return;
    }

    final url = Uri.parse('${Constant.apiEndpoint}user-details-by-register-id');
    try {
      final response = await http.post(
        url,
        headers: {
          'deviceId': _deviceId,
          'deviceName': _deviceName,
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${accessToken.value}',
        },
        body: jsonEncode({"registerId": registerId.value}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final info = responseData['info'];

        if (info != null) {
          // Save to GetStorage
          _storage.write('userId', info['userId']);
          _storage.write('fullName', info['fullName']);
          _storage.write('mobileNo', info['mobileNo']);
          _storage.write('walletBalance', info['walletBalance']);
          _storage.write('accountStatus', info['accountStatus']);

          // Update observable variables. This triggers UI update.
          fullName.value = info['fullName'] ?? '';
          mobileNo.value = info['mobileNo'] ?? '';
          walletBalance.value = info['walletBalance']?.toString() ?? '0';
          accountStatus.value = info['accountStatus'] ?? false;

          log("✅ User details updated and UI refreshed.");
        }
      } else {
        log("❌ Failed to fetch user details: ${response.statusCode}");
        log("Response body: ${response.body}");
      }
    } catch (e) {
      log("❌ Exception fetching user details: $e");
    }
  }

  // Fetches fee settings and updates state.
  Future<void> fetchAndUpdateFeeSettings() async {
    if (mobileNo.value.isEmpty || accessToken.value.isEmpty) {
      log('Mobile number or Access Token is missing. Cannot fetch fees.');
      return;
    }

    final url = Uri.parse('${Constant.apiEndpoint}fees-settings');
    try {
      final response = await http.get(
        url,
        headers: {
          'deviceId': _deviceId,
          'deviceName': _deviceName,
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${accessToken.value}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['info'] != null) {
          final info = data['info'];
          // Save all of the data in GetStorage
          _storage.write('minBid', info['minBid']);
          _storage.write('minDeposit', info['minDeposit']);
          _storage.write('minWithdraw', info['minWithdraw']);
          _storage.write('withdrawFees', info['withdrawFees']);
          _storage.write('withdrawOpenTime', info['withdrawOpenTime']);
          _storage.write('withdrawCloseTime', info['withdrawCloseTime']);
          _storage.write('withdrawStatus', info['withdrawStatus']);

          // Update observable variables.
          minBid.value = info['minBid']?.toString() ?? '0';
          minDeposit.value = info['minDeposit']?.toString() ?? '0';
          minWithdraw.value = info['minWithdraw']?.toString() ?? '0';
          withdrawFees.value = info['withdrawFees']?.toString() ?? '0';
          withdrawOpenTime.value = info['withdrawOpenTime'] ?? '';
          withdrawCloseTime.value = info['withdrawCloseTime'] ?? '';
          withdrawStatus.value = info['withdrawStatus'] ?? false;

          log('✅ Fee settings updated and saved to GetStorage.');
        }
      } else {
        log('Fee settings Request failed with status: ${response.statusCode}');
        log('Fee settings Response body: ${response.body}');
      }
    } catch (e) {
      log('In fetchFeeSettings An error occurred: $e');
    }
  }

  // Manual update methods for specific fields
  void updateName(String name) => fullName.value = name;
  void updateMobile(String mobile) => mobileNo.value = mobile;
  void updateWalletBalance(String balance) => walletBalance.value = balance;
  void updateMinBid(String value) => minBid.value = value;
  void updateMinDeposit(String value) => minDeposit.value = value;
  void updateMinWithdraw(String value) => minWithdraw.value = value;
  void updateWithdrawFees(String value) => withdrawFees.value = value;
  void updateWithdrawStatus(bool status) => withdrawStatus.value = status;
  void updateWithdrawTime(String openTime, String closeTime) {
    withdrawOpenTime.value = openTime;
    withdrawCloseTime.value = closeTime;
  }

  void updateAccessToken(String token) => accessToken.value = token;

  // Method to clear all user data on logout
  void logout() {
    // Reset all reactive variables to their initial state
    fullName.value = '';
    mobileNo.value = '';
    mobileNoEnc.value = '';
    walletBalance.value = '0';
    accessToken.value = '';
    registerId.value = '';
    accountStatus.value = false;
    minBid.value = '0';
    minDeposit.value = '0';
    minWithdraw.value = '0';
    withdrawFees.value = '0';
    withdrawOpenTime.value = '';
    withdrawCloseTime.value = '';
    withdrawStatus.value = false;
    log("✅ User data cleared for logout.");
  }
}

// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:get/get.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:http/http.dart' as http;
//
// import '../ulits/Constents.dart';
//
// class UserController extends GetxController {
//   final GetStorage _storage = GetStorage();
//
//   // Observable variables. The `.obs` makes them reactive,
//   // so the UI will automatically update when their value changes.
//   var fullName = ''.obs;
//   var mobileNo = ''.obs;
//   var walletBalance = '0'.obs;
//   var accessToken = ''.obs;
//   var registerId = ''.obs;
//
//   // Fee settings are also managed here
//   var minBid = '0'.obs;
//   var minDeposit = '1000'.obs;
//   var minWithdraw = '0'.obs;
//   var withdrawFees = '0'.obs;
//   var withdrawOpenTime = ''.obs;
//   var withdrawCloseTime = ''.obs;
//   var withdrawStatus = ''.obs;
//
//   // device info
//   late String _deviceId = ''.obs as String;
//   late String _deviceName = ''.obs as String;
//
//   // Method to update the user details
//   void updateDetails(String key, String value) {
//     switch (key) {
//       case 'fullName':
//         fullName.value = value;
//         break;
//       case 'mobileNo':
//         mobileNo.value = value;
//         break;
//       case 'walletBalance':
//         walletBalance.value = value;
//         break;
//       default:
//         break;
//     }
//   }
//
//   // Method to update the fee settings
//   void updateFeeSettings(String key, String value) {
//     switch (key) {
//       case 'minBid':
//         minBid.value = value;
//         break;
//       case 'minDeposit':
//         minDeposit.value = value;
//         break;
//       case 'minWithdraw':
//         minWithdraw.value = value;
//         break;
//       case 'withdrawFees':
//         withdrawFees.value = value;
//         break;
//       default:
//         break;
//     }
//   }
//
//   // Method to update the withdraw status
//   void updateWithdrawStatus(String status) {
//     withdrawStatus.value = status;
//   }
//
//   // Method to update the withdraw open and close time
//   void updateWithdrawTime(String openTime, String closeTime) {
//     withdrawOpenTime.value = openTime;
//     withdrawCloseTime.value = closeTime;
//   }
//
//   // Method to update the access token
//   void updateAccessToken(String accessToken) {
//     this.accessToken.value = accessToken;
//   }
//
//   @override
//   void onInit() {
//     super.onInit();
//     // Load initial data from GetStorage when the controller is initialized.
//     loadInitialData();
//   }
//
//   void loadInitialData() {
//     accessToken.value = _storage.read('accessToken') ?? '';
//     registerId.value = _storage.read('registerId') ?? '';
//     fullName.value = _storage.read('fullName') ?? '';
//     mobileNo.value = _storage.read('mobileNo') ?? '';
//     walletBalance.value = _storage.read('walletBalance')?.toString() ?? '0';
//
//     // Load initial fee settings
//     minBid.value = _storage.read('minBid')?.toString() ?? '0';
//     minDeposit.value = _storage.read('minDeposit')?.toString() ?? '1000';
//     minWithdraw.value = _storage.read('minWithdraw')?.toString() ?? '0';
//     withdrawFees.value = _storage.read('withdrawFees')?.toString() ?? '0';
//
//     // Load initial device info
//     _deviceId = _storage.read('deviceId') ?? '';
//     _deviceName = _storage.read('deviceName') ?? '';
//   }
//
//   // Fetches user details from the server and updates state.
//   Future<void> fetchAndUpdateUserDetails() async {
//     if (registerId.value.isEmpty || accessToken.value.isEmpty) {
//       log('User ID or Access Token is missing. Cannot fetch details.');
//       return;
//     }
//
//     final url = Uri.parse('${Constant.apiEndpoint}user-details-by-register-id');
//     try {
//       final response = await http.post(
//         url,
//         headers: {
//           'deviceId': 'qwert', // Replace with dynamic device ID
//           'deviceName': 'sm2233', // Replace with dynamic device name
//           'accessStatus': '1',
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer ${accessToken.value}',
//         },
//         body: jsonEncode({"registerId": registerId.value}),
//       );
//
//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);
//         final info = responseData['info'];
//
//         if (info != null) {
//           // Save to GetStorage
//           _storage.write('userId', info['userId']);
//           _storage.write('fullName', info['fullName']);
//           _storage.write('mobileNo', info['mobileNo']);
//           _storage.write('walletBalance', info['walletBalance']);
//
//           // Update observable variables. This triggers UI update.
//           fullName.value = info['fullName'] ?? '';
//           mobileNo.value = info['mobileNo'] ?? '';
//           walletBalance.value = info['walletBalance']?.toString() ?? '0';
//
//           log("✅ User details updated and UI refreshed.");
//         }
//       } else {
//         log("❌ Failed to fetch user details: ${response.statusCode}");
//         log("Response body: ${response.body}");
//       }
//     } catch (e) {
//       log("❌ Exception fetching user details: $e");
//     }
//   }
//
//   // Fetches fee settings and updates state.
//   Future<void> fetchAndUpdateFeeSettings() async {
//     if (mobileNo.value.isEmpty || accessToken.value.isEmpty) {
//       log('Mobile number or Access Token is missing. Cannot fetch fees.');
//       return;
//     }
//
//     final url = Uri.parse('${Constant.apiEndpoint}fees-settings');
//     try {
//       final response = await http.get(
//         url,
//         headers: {
//           'deviceId': 'qwert', // Replace with dynamic device ID
//           'deviceName': 'sm2233', // Replace with dynamic device name
//           'accessStatus': '1',
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer ${accessToken.value}',
//         },
//       );
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         if (data['status'] == true && data['info'] != null) {
//           final info = data['info'];
//           // Save all of the data in GetStorage
//           _storage.write('minBid', info['minBid']);
//           _storage.write('minDeposit', info['minDeposit']);
//           _storage.write('minWithdraw', info['minWithdraw']);
//           _storage.write('withdrawFees', info['withdrawFees']);
//           // You can add other fee settings here
//
//           // Update observable variables.
//           minBid.value = info['minBid']?.toString() ?? '0';
//           minDeposit.value = info['minDeposit']?.toString() ?? '1000';
//           minWithdraw.value = info['minWithdraw']?.toString() ?? '0';
//           withdrawFees.value = info['withdrawFees']?.toString() ?? '0';
//
//           log('✅ Fee settings updated and saved to GetStorage.');
//         }
//       } else {
//         log('Fee settings Request failed with status: ${response.statusCode}');
//         log('Fee settings Response body: ${response.body}');
//       }
//     } catch (e) {
//       log('In fetchFeeSettings An error occurred: $e');
//     }
//   }
// }
