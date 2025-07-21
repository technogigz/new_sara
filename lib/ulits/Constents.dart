import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_workers/utils/debouncer.dart';

import 'ColorsR.dart';

final GlobalKey<ScaffoldState> globalKey = GlobalKey<ScaffoldState>();
showErrorDialog(String mgs, String type) {
  Get.snackbar(
    type,
    mgs,
    colorText: Colors.white,
    backgroundColor: ColorsR.appColor,
    snackPosition: SnackPosition.BOTTOM,
  );
}

class Widgets {
  static String getAssetsPath(int folder, String filename) {
    //0-image,1-svg,2-language,3-animation

    String path = "";
    switch (folder) {
      case 0:
        path = "assets/images/$filename";
        break;
      case 1:
        path = "assets/svg/$filename.svg";
        break;
      case 2:
        path = "assets/language/$filename.json";
        break;
      case 3:
        path = "assets/animation/$filename.json";
        break;
    }

    return path;
  }

  static Widget defaultImg({
    double? height,
    double? width,
    required String image,
    Color? iconColor,
    BoxFit? boxFit,
    EdgeInsetsDirectional? padding,
  }) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(0),
      child: iconColor != null
          ? SvgPicture.asset(
              Constant.getAssetsPath(1, image),
              width: width,
              height: height,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              fit: boxFit ?? BoxFit.contain,
              matchTextDirection: true,
            )
          : SvgPicture.asset(
              Constant.getAssetsPath(1, image),
              width: width,
              height: height,
              fit: boxFit ?? BoxFit.contain,
              matchTextDirection: true,
            ),
    );
  }

  static getSizedBox({double? height, double? width}) {
    return SizedBox(height: height ?? 0, width: width ?? 0);
  }

  static Widget setNetworkImg({
    double? height,
    double? width,
    String image = "placeholder",
    Color? iconColor,
    BoxFit? boxFit,
  }) {
    return image.trim().isEmpty
        ? defaultImg(
            image: "placeholder",
            height: height,
            width: width,
            boxFit: boxFit,
          )
        : FadeInImage.assetNetwork(
            image: image,
            width: width,
            height: height,
            fit: boxFit,
            placeholderFit: BoxFit.cover,
            placeholder: Constant.getAssetsPath(0, "placeholder.png"),
            imageErrorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) {
                  return defaultImg(
                    image: "placeholder",
                    width: width,
                    height: height,
                    boxFit: boxFit,
                  );
                },
          );
  }
}

class Constant {
  //Add your admin panel url here with postfix slash eg. https://www.admin.panel/
  // static String apiUrl = "https://games.parkensolution.in/";
  static String apiUrl = "https://app.sara777.co.in/";

  //authenticationScreen with phone constants
  static int otpTimeOutSecond = 60; //otp time out
  static int otpResendSecond = 60; // resend otp timer
  static int messageDisplayDuration = 3500; // resend otp timer

  static int searchHistoryListLimit = 20; // resend otp timer

  static int discountCouponDialogVisibilityTimeInMilliseconds = 3000;

  static String initialCountryCode =
      "IN"; // initial country code, change as per your requirement

  // Theme list, This system default names please do not change at all
  static List<String> themeList = ["System default", "Light", "Dark"];

  static GlobalKey<NavigatorState> navigatorKay = GlobalKey<NavigatorState>();

  //google api keys
  static String googleApiKey = "AIzaSyAlSRLUTHpw59Qn36HI1SMaTULefFQ476k";

  //Set here 0 if you want to show all categories at home
  static int homeCategoryMaxLength = 6;

  static int defaultDataLoadLimitAtOnce = 20;

  static String selectedCoupon = "";
  static double discountedAmount = 0.0;
  static double discount = 0.0;
  static bool isPromoCodeApplied = false;
  static String selectedPromoCodeId = "0";

  static BorderRadius borderRadius5 = BorderRadius.circular(5);
  static BorderRadius borderRadius7 = BorderRadius.circular(7);
  static BorderRadius borderRadius10 = BorderRadius.circular(10);
  static BorderRadius borderRadius13 = BorderRadius.circular(13);
  static BorderRadius borderRadius15 = BorderRadius.circular(15);

  //  static late SessionManager session;
  static List<String> searchedItemsHistoryList = [];
  static final debouncer = Debouncer(delay: const Duration(milliseconds: 1000));

  //Order statues codes
  static List<String> orderStatusCode = [
    "1", //Awaiting Payment
    "2", //Received
    "3", //Processed
    "4", //Shipped
    "5", //Out For Delivery
    "6", //Delivered
    "7", //Cancelled
    "8", //Returned
  ];

  static Map cityAddressMap = {};

  // App Settings
  static List<int> favorits = [];
  static String currency = "";
  static String maxAllowItemsInCart = "";
  static String minimumOrderAmount = "";
  static String minimumReferEarnOrderAmount = "";
  static String referEarnBonus = "";
  static String maximumReferEarnAmount = "";
  static String minimumWithdrawalAmount = "";
  static String maximumProductReturnDays = "";
  static String userWalletRefillLimit = "";
  static String isReferEarnOn = "";
  static String referEarnMethod = "";
  static String privacyPolicy = "";
  static String termsConditions = "";
  static String aboutUs = "";
  static String contactUs = "";
  static String returnAndExchangesPolicy = "";
  static String cancellationPolicy = "";
  static String shippingPolicy = "";
  static String currencyCode = "";
  static String decimalPoints = "";

  static String appMaintenanceMode = "";
  static String appMaintenanceModeRemark = "";

  static bool popupBannerEnabled = false;
  static bool showAlwaysPopupBannerAtHomeScreen = false;
  static String popupBannerType = "";
  static String popupBannerTypeId = "";
  static String popupBannerUrl = "";
  static String popupBannerImageUrl = "";

  static String currentRequiredAppVersion = "";
  static String requiredForceUpdate = "";
  static String isVersionSystemOn = "";

  static String currentRequiredIosAppVersion = "";
  static String requiredIosForceUpdate = "";
  static String isIosVersionSystemOn = "";

  static String getAssetsPath(int folder, String filename) {
    //0-image,1-svg,2-language,3-animation

    String path = "";
    switch (folder) {
      case 0:
        path = "assets/images/$filename";
        break;
      case 1:
        path = "assets/svg/$filename.svg";
        break;
      case 2:
        path = "assets/language/$filename.json";
        break;
      case 3:
        path = "assets/animation/$filename.json";
        break;
    }

    return path;
  }

  static double size2 = 2.00;
  static double size3 = 3.00;
  static double size5 = 5.00;
  static double size7 = 7.00;
  static double size8 = 8.00;
  static double size10 = 10.00;
  static double size12 = 12.00;
  static double size14 = 14.00;
  static double size15 = 15.00;
  static double size16 = 16.00;
  static double size18 = 18.00;
  static double size20 = 20.00;
  static double size25 = 25.00;
  static double size30 = 30.00;
  static double size35 = 35.00;
  static double size40 = 40.00;
  static double size50 = 50.00;
  static double size60 = 60.00;
  static double size65 = 65.00;
  static double size70 = 70.00;
  static double size75 = 75.00;
  static double size80 = 80.00;
  static Future<String> getGetMethodUrlWithParams(
    String mainUrl,
    Map params,
  ) async {
    if (params.isNotEmpty) {
      mainUrl = "$mainUrl?";
      for (int i = 0; i < params.length; i++) {
        mainUrl =
            "$mainUrl${i == 0 ? "" : "&"}${params.keys.toList()[i]}=${params.values.toList()[i]}";
      }
    }

    return mainUrl;
  }

  static List<String> selectedBrands = [];
  static List<String> selectedSizes = [];
  static RangeValues currentRangeValues = const RangeValues(0, 0);

  static getOrderActiveStatusLabelFromCode(String value) {
    if (value.isEmpty) {
      return value;
    }

    switch (value) {
      case "01":
        print("Payment pending");
      case "02":
        print("Payment Received");
      case "03":
        print("Processed");
      case "04":
        print("Shipped");
      case "05":
        print("Out For Delivery");
      case "06":
        print("Delivered");
      case "07":
        print("july");
      case "08":
        print("August");

      case "09":
        print("September");

      case "10":
        print("October");

      case "11":
        print("November");

      case "12":
        print("December");

      default:
        return "Returned";
    }
  }

  static resetTempFilters() {
    selectedBrands = [];
    selectedSizes = [];
    currentRangeValues = const RangeValues(0, 0);
  }

  static String apiGeoCode =
      "https://maps.googleapis.com/maps/api/geocode/json?key=$googleApiKey&latlng=";

  static String noInternetConnection = "no_internet_connection";
  static String somethingWentWrong = "something_went_wrong";
  static String apiEndpoint = "https://sara777.win/api/v1/";
  static String normalGamePlaceBidEndpoint =
      '${apiEndpoint}place-bid'; // Example path
  static String starlinePlaceBidEndpoint =
      '${apiEndpoint}place-starline-bid'; // Example path
  static String jackpotPlaceBidEndpoint =
      '${apiEndpoint}place-jackpot-bid'; // Example path
}
