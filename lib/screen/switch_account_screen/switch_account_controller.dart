import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/screen/auth_screen/auth_screen_controller.dart';
import 'package:shortzz/screen/auth_screen/login_screen.dart';
import 'package:shortzz/screen/auth_screen/registration_screen.dart';

class SwitchAccountController extends BaseController {
  void addAccount() {
    Get.to(() => const LoginScreen());
  }

  void createNewAccount() {
    // RegistrationScreen expects AuthScreenController to already be
    // registered (Get.find) — normally true because LoginScreen puts it
    // during its own build before ever navigating to RegistrationScreen.
    // This entry point skips LoginScreen entirely, so without this it
    // crashes with "AuthScreenController not found".
    Get.put(AuthScreenController());
    Get.to(() => const RegistrationScreen());
  }

  void switchToAccount(String accountId) {
    // Implementation for switching between accounts
    Get.snackbar(
      'Switching Account',
      'Switching to selected account...',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
