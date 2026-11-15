import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/service/api/user_service.dart';
import 'package:toptap/common/widget/confirmation_dialog.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/user_model/user_model.dart';

class LocationService {
  LocationService._();

  static final instance = LocationService._();

  Future<Position> getCurrentLocation({
    bool isPermissionDialogShow = false,
    Function(bool enable)? returnCallback,
  }) async {
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && isPermissionDialogShow) {
      await showServiceDialog();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    }
    if (!serviceEnabled) {
      returnCallback?.call(false);
      throw Exception('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      returnCallback?.call(false);
      if (isPermissionDialogShow) {
        await showPermissionDialog();
      }
      throw Exception('Location permission is permanently denied.');
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      returnCallback?.call(false);
      throw Exception('Location permission was not granted.');
    }

    returnCallback?.call(true);
    const double locationPrecision = 0.0001; // ~11 meters

    Position position = await Geolocator.getCurrentPosition();
    User? user = SessionManager.instance.getUser();

    final double latitude = position.latitude;
    final double longitude = position.longitude;
    final double userLatitude = user?.lat?.toDouble() ?? 0;
    final double userLongitude = user?.lon?.toDouble() ?? 0;

    // Check if position has changed significantly
    bool hasLocationChanged =
        (latitude - userLatitude).abs() > locationPrecision ||
            (longitude - userLongitude).abs() > locationPrecision;

    if (hasLocationChanged) {
      await UserService.instance
          .updateUserDetails(lat: latitude, lon: longitude);
    }
    return position;
  }

  Future<void> showPermissionDialog() async {
    await Get.bottomSheet<void>(ConfirmationSheet(
      title: LKey.nearbyReelsPermissionTitle.tr,
      description: LKey.nearbyReelsPermissionDescription.tr,
      onTap: openAppSettings,
    ));
  }

  Future<void> showServiceDialog() async {
    await Get.bottomSheet<void>(ConfirmationSheet(
      title: LKey.locationServicesDisabledTitle.tr,
      description: LKey.locationServicesDisabledDescription.tr,
      onTap: Geolocator.openLocationSettings,
    ));
  }
}
