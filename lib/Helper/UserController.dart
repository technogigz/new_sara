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

  // Payment Details
  var bankName = ''.obs;
  var accountHolderName = ''.obs;
  var accountNumber = ''.obs;
  var ifscCode = ''.obs;
  var accountType = ''.obs;
  var gpayUpiId = ''.obs;
  var gpayQrCode = ''.obs;
  var phonepeUpiId = ''.obs;
  var phonepeQrCode = ''.obs;
  var paytmUpiId = ''.obs;
  var paytmQrCode = ''.obs;
  var bankStatus = false.obs;
  var gpayStatus = false.obs;
  var phonepeStatus = false.obs;
  var paytmStatus = false.obs;
  var selfDepositStatus = false.obs;
  var upiIntentStatus = false.obs;

  // Contact Details
  var contactMobileNo = ''.obs;
  var contactWhatsappNo = ''.obs;
  var contactAppLink = ''.obs;
  var contactHomepageContent = ''.obs;
  var contactVideoDescription = ''.obs;

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

  // New method to fetch and update contact details
  Future<void> fetchAndUpdateContactDetails() async {
    if (accessToken.value.isEmpty) {
      log('❌ Access Token missing. Cannot fetch contact details.');
      return;
    }

    final url = Uri.parse('${Constant.apiEndpoint}contact-detail');

    try {
      final response = await http.get(
        url,
        headers: {
          'deviceId': _deviceId ?? 'qwert',
          'deviceName': _deviceName ?? 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${accessToken.value}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        log(
          '✅ Contact Details Response:\n${const JsonEncoder.withIndent('  ').convert(data)}',
        );

        final contactInfo = data['info']?['contactInfo'];
        final videosInfo = data['info']?['videosInfo'];

        if (contactInfo == null || videosInfo == null) {
          log('❌ contactInfo or videosInfo is null in response.');
          return;
        }

        // Save to GetStorage
        _storage.write('mobileNoContact', contactInfo['mobileNo'] ?? '');
        _storage.write('whatsappNo', contactInfo['whatsappNo'] ?? '');
        _storage.write('appLink', contactInfo['appLink'] ?? '');
        _storage.write('homepageContent', contactInfo['homepageContent'] ?? '');
        _storage.write('videoDescription', videosInfo['description'] ?? '');

        // Update reactive variables
        contactMobileNo.value = contactInfo['mobileNo'] ?? '';
        contactWhatsappNo.value = contactInfo['whatsappNo'] ?? '';
        contactAppLink.value = contactInfo['appLink'] ?? '';
        contactHomepageContent.value = contactInfo['homepageContent'] ?? '';
        contactVideoDescription.value = videosInfo['description'] ?? '';

        log('✅ Contact details updated and saved.');
      } else {
        log('❌ Failed to fetch contact details: ${response.statusCode}');
        log('Response body: ${response.body}');
      }
    } catch (e) {
      log('❌ Exception in fetchAndUpdateContactDetails: $e');
    }
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

  // Payment details Api
  Future<void> fetchPaymentDetails() async {
    if (mobileNo.value.isEmpty || accessToken.value.isEmpty) {
      log(
        'Mobile number or Access Token is missing. Cannot fetch payment details.',
      );
      return;
    }

    final url = Uri.parse('${Constant.apiEndpoint}payment-detail');

    try {
      final request = http.Request('GET', url);

      request.headers.addAll({
        'deviceId': _deviceId,
        'deviceName': _deviceName,
        'accessStatus': '1',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${accessToken.value}',
      });

      request.body = jsonEncode({
        'mobileNo': int.tryParse(mobileNo.value) ?? 0,
      });

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);
        log("✅ Payment Detail: $data");

        if (data['status'] == true && data['info'] != null) {
          final info = data['info'];

          // Assign values to observables
          bankName.value = info['bankName'] ?? '';
          accountHolderName.value = info['accountHolderName'] ?? '';
          accountNumber.value = info['accountNumber'] ?? '';
          ifscCode.value = info['ifscCode'] ?? '';
          accountType.value = info['acccountType'] ?? '';

          gpayUpiId.value = info['gpayUpiId'] ?? '';
          gpayQrCode.value = info['gpayQrCode'] ?? '';

          phonepeUpiId.value = info['phonepeUpiId'] ?? '';
          phonepeQrCode.value = info['phonepeQrCode'] ?? '';

          paytmUpiId.value = info['paytmUpiId'] ?? '';
          paytmQrCode.value = info['paytmQrCode'] ?? '';

          bankStatus.value = info['bankStatus'] ?? false;
          gpayStatus.value = info['gpayStatus'] ?? false;
          phonepeStatus.value = info['phonepeStatus'] ?? false;
          paytmStatus.value = info['paytmStatus'] ?? false;
          selfDepositStatus.value = info['selfDepositStatus'] ?? false;
          upiIntentStatus.value = info['upiIntentStatus'] ?? false;

          // Optional: Save to storage if needed
          _storage.write('paymentInfo', info);

          log("✅ Payment info updated successfully.");
        } else {
          log("⚠️ No info found in payment detail.");
        }
      } else {
        final errorBody = await response.stream.bytesToString();
        log("❌ Failed to fetch payment details: ${response.statusCode}");
        log("Response: $errorBody");
      }
    } catch (e) {
      log("❌ Exception in fetchPaymentDetails: $e");
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
