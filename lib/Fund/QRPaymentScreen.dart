// The main payment screen widget
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class QRPaymentScreen extends StatefulWidget {
  final String paymentLink;
  final String amount;
  const QRPaymentScreen({
    super.key,
    required this.paymentLink,
    required this.amount,
  });

  @override
  State<QRPaymentScreen> createState() => _QRPaymentScreenState();
}

class _QRPaymentScreenState extends State<QRPaymentScreen> {
  bool _isLoading = false;
  String? _error;
  final box = GetStorage();
  late final String deviceId;
  late final String deviceName;
  late final String authToken;
  late final String registerId;

  final ScreenshotController _screenshotController = ScreenshotController();

  // Webview controller for webview_flutter
  late final WebViewController _controller;

  bool _apiCallTriggered = false;

  @override
  void initState() {
    super.initState();

    deviceId = box.read('deviceId') ?? '';
    deviceName = box.read('deviceName') ?? '';
    authToken = box.read('accessToken') ?? '';
    registerId = box.read('registerId') ?? '';

    _initializeWebView();
  }

  // Initialize the WebViewController for webview_flutter
  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            log('WebView is loading (progress : $progress%)');
            if (mounted) {
              setState(() {
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (String url) {
            log('Page started loading: $url');
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            log('Page finished loading: $url');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            log('Web resource error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            log('Navigation request to: $url');

            // UPI deep link schemes (Paytm, PhonePe, GPay, etc.)
            final upiSchemes = [
              'upi:',
              'phonepe:',
              'paytmmp:',
              'paytm:',
              'gpay:',
              'tez:',
              'amazonpay:',
            ];

            // If the intercepted URL starts with any of the UPI schemes
            if (upiSchemes.any((scheme) => url.startsWith(scheme))) {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                log("Could not launch $url");
              }
              return NavigationDecision
                  .prevent; // Prevent webview from navigating
            }

            // Check for success/failure keywords in the URL
            final lowerUrl = url.toLowerCase();

            if (lowerUrl.contains('cancel') && !_apiCallTriggered) {
              _apiCallTriggered = true;
              log('Payment cancel URL detected. Navigating back.');

              if (mounted) {
                Navigator.of(context).pop();
              }
              return NavigationDecision.prevent;
            }

            if (lowerUrl.contains('success') && !_apiCallTriggered) {
              _apiCallTriggered = true;
              log(
                'Payment success URL detected. Performing backend confirmation.',
              );

              return NavigationDecision
                  .prevent; // Prevent webview from navigating
            } else if (lowerUrl.contains('fail') && !_apiCallTriggered) {
              _apiCallTriggered = true;
              log('Payment failure URL detected.');

              return NavigationDecision
                  .prevent; // Prevent webview from navigating
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setOnJavaScriptAlertDialog((request) async {
        log('JavaScript Alert: ${request.message}');
      })
      ..setOnJavaScriptConfirmDialog((request) async {
        log('JavaScript Confirm: ${request.message}');

        if (request.message.toLowerCase().contains('cancel')) {
          if (mounted) {
            Navigator.of(context).pop();
          }

          return false;
        }

        return true;
      })
      ..loadRequest(Uri.parse(widget.paymentLink));
  }

  Future<void> saveScreen() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) {
        log("Failed to capture screenshot");
        return;
      }

      final directory = await getTemporaryDirectory();
      final imagePath =
          '${directory.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(image);

      await GallerySaver.saveImage(imageFile.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Screenshot saved to gallery")),
        );
      }
    } catch (e) {
      log("Error capturing screenshot: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save screenshot")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('QR Payment'),
        backgroundColor: Colors.grey.shade300,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Screenshot(
                    controller: _screenshotController,
                    // Use WebViewWidget with the _controller
                    child: WebViewWidget(controller: _controller),
                  ),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveScreen,
              child: const Text("Save QR to Gallery"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
