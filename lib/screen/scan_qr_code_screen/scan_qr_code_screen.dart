import 'dart:async';
import 'dart:io';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as qr;
import 'package:image_picker/image_picker.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:toptap/common/functions/media_picker_helper.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/common/service/api/user_service.dart';
import 'package:toptap/common/service/navigation/navigate_with_controller.dart';
import 'package:toptap/common/widget/custom_app_bar.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/user_model/user_model.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class ScanQrCodeScreen extends StatefulWidget {
  const ScanQrCodeScreen({super.key});

  @override
  State<ScanQrCodeScreen> createState() => _ScanQrCodeScreenState();
}

class _ScanQrCodeScreenState extends State<ScanQrCodeScreen> {
  GlobalKey qrKey = GlobalKey();
  Barcode? result;
  QRViewController? controller;
  StreamSubscription? _scanSubscription;

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(
            title: LKey.scanQrCode.tr,
            widget: Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Text(LKey.scanQrProfileSearch.tr,
                  style: TextStyleCustom.outFitLight300(
                      color: textLightGrey(context), fontSize: 14)),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                SizedBox(
                    height: Get.height,
                    child:
                        QRView(key: qrKey, onQRViewCreated: _onQRViewCreated)),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    color: whitePure(context),
                    alignment: Alignment.center,
                    child: InkWell(
                      onTap: onUploadFromGallery,
                      child: Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: ShapeDecoration(
                          shape: SmoothRectangleBorder(
                              borderRadius: SmoothBorderRadius(
                                  cornerRadius: 10, cornerSmoothing: 1)),
                          color: bgMediumGrey(context),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 12,
                          children: [
                            Image.asset(AssetRes.icUploadGallery,
                                width: 28, height: 28),
                            Text(
                              LKey.uploadFromGallery.tr,
                              style: TextStyleCustom.outFitMedium500(
                                  color: textLightGrey(context), fontSize: 16),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    _scanSubscription = controller.scannedDataStream.listen((scanData) async {
      if (result != null) return; // Prevent multiple scans

      setState(() {
        result = scanData;
      });

      if (result?.code != null) {
        int userId = int.parse(result?.code ?? '');
        _navigateToProfileScreen(userId);
      }

      // Cancel the stream to stop listening
      _scanSubscription?.cancel();
    });
  }

  void _navigateToProfileScreen(int userId) async {
    User? user = await UserService.instance.fetchUserDetails(userId: userId);
    if (user != null) {
      Get.back();
      NavigationService.shared.openProfileScreen(user);
    }
  }

  void onUploadFromGallery() async {
    XFile? image =
        await MediaPickerHelper.shared.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final inputImage = qr.InputImage.fromFile(File(image.path));
    final barcodeScanner = qr.BarcodeScanner();

    try {
      final List<qr.Barcode> barcodes =
          await barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        setState(() {
          String scannedData = barcodes.first.rawValue ?? "";
          if (scannedData.isNotEmpty) {
            _navigateToProfileScreen(int.parse(scannedData));
          }
        });
      } else {
        Loggers.error("No QR code detected.");
      }
    } catch (e) {
      Loggers.error("Error scanning image: $e");
    } finally {
      barcodeScanner.close();
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}
