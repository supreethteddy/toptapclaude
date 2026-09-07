import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/common_service.dart';
import 'package:shortzz/common/service/api/notification_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/subscription/subscription_manager.dart';
import 'package:shortzz/common/utils/profile_completion_helper.dart';
import 'package:shortzz/languages/dynamic_translations.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/user_model/user_model.dart' as user;
import 'package:shortzz/screen/dashboard_screen/dashboard_screen.dart';
import 'package:shortzz/screen/edit_profile_screen/edit_profile_screen.dart';

class AuthScreenController extends BaseController {
  TextEditingController fullNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController forgetEmailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
//  TextEditingController confirmPassController = TextEditingController();

  @override
  void onInit() {
    CommonService.instance.fetchGlobalSettings();
    FirebaseNotificationManager.instance;
    super.onInit();
  }

  Future<void> onLogin() async {
    if (emailController.text.trim().isEmpty) {
      return showSnackBar(LKey.enterEmail.tr);
    }
    if (passwordController.text.trim().isEmpty) {
      return showSnackBar(LKey.enterAPassword.tr);
    }
    if (!GetUtils.isEmail(emailController.text.trim())) {
      return showSnackBar(LKey.invalidEmail.tr);
    }
    showLoader();
    try {
      UserCredential? credential = await signInWithEmailAndPassword();
      if (credential == null) {
        return;
      }

      // Debug builds skip the e-mail verification gate so QA accounts with
      // throw-away addresses can log in. Release builds still enforce it.
      if (credential.user?.emailVerified == false && !kDebugMode) {
        showSnackBar(LKey.verifyEmailFirst.tr);
        return;
      }

      final data = await _registration(
          identity: emailController.text.trim(),
          loginMethod: LoginMethod.email,
          fullname: credential.user?.displayName ??
              emailController.text.split('@')[0]);

      _navigateScreen(data);
    } on LoginApiException catch (e) {
      Loggers.error('Backend login failed: ${e.message}');
      showSnackBar(e.message);
    } catch (e, st) {
      Loggers.error('Login failed: $e\n$st');
      showSnackBar(_unexpectedLoginMessage(e));
    } finally {
      stopLoader();
    }
  }

  Future<void> onCreateAccount() async {
    if (fullNameController.text.trim().isEmpty) {
      return showSnackBar(LKey.fullNameEmpty.tr);
    }
    if (emailController.text.trim().isEmpty) {
      return showSnackBar(LKey.enterEmail.tr);
    }
    if (passwordController.text.trim().isEmpty) {
      return showSnackBar(LKey.enterAPassword.tr);
    }
    // if (confirmPassController.text.trim().isEmpty) {
    //   return showSnackBar(LKey.confirmPasswordEmpty.tr);
    // }
    if (!GetUtils.isEmail(emailController.text.trim())) {
      return showSnackBar(LKey.invalidEmail.tr);
    }
    // if (passwordController.text.trim() != confirmPassController.text.trim()) {
    //   return showSnackBar(LKey.passwordMismatch.tr);
    // }
    showLoader();
    try {
      final credential = await createUserWithEmailAndPassword();
      if (credential == null) return;

      await _registration(
          identity: emailController.text.trim(),
          loginMethod: LoginMethod.email,
          fullname: fullNameController.text.trim());

      await credential.user?.updateDisplayName(fullNameController.text.trim());
      await credential.user?.sendEmailVerification();
      Get.back();
      Get.back();
      showSnackBar(LKey.verificationLinkSent.tr);
    } on LoginApiException catch (e) {
      Loggers.error('Backend registration failed: ${e.message}');
      showSnackBar(e.message);
    } catch (e, st) {
      Loggers.error('Account creation failed: $e\n$st');
      showSnackBar(_unexpectedLoginMessage(e));
    } finally {
      stopLoader();
    }
  }

  Future<void> onGoogleTap() async {
    showLoader();
    try {
      final credential = await signInWithGoogle();
      if (credential?.user == null) return;

      final data = await _registration(
          identity: credential!.user?.email ?? '',
          loginMethod: LoginMethod.google,
          fullname: credential.user?.displayName ??
              credential.user?.email?.split('@')[0]);

      _navigateScreen(data);
    } on FirebaseAuthException catch (e, st) {
      Loggers.error('Google Firebase login failed: ${e.code}\n$st');
      showSnackBar(_firebaseAuthMessage(e));
    } on PlatformException catch (e, st) {
      Loggers.error('Google platform login failed: ${e.code}\n$st');
      showSnackBar(_googlePlatformMessage(e));
    } on LoginApiException catch (e) {
      Loggers.error('Google backend login failed: ${e.message}');
      showSnackBar(e.message);
    } catch (e, st) {
      Loggers.error('Google login failed: $e\n$st');
      showSnackBar(_unexpectedLoginMessage(e));
    } finally {
      stopLoader();
    }
  }

  Future<void> onAppleTap() async {
    showLoader();
    try {
      final credential = await signInWithApple();
      if (credential.user == null) return;

      final data = await _registration(
          identity: credential.user?.email ?? '',
          loginMethod: LoginMethod.apple,
          fullname: credential.user?.displayName ??
              credential.user?.email?.split('@')[0]);

      _navigateScreen(data);
    } on FirebaseAuthException catch (e, st) {
      Loggers.error('Apple Firebase login failed: ${e.code}\n$st');
      showSnackBar(_firebaseAuthMessage(e));
    } on LoginApiException catch (e) {
      Loggers.error('Apple backend login failed: ${e.message}');
      showSnackBar(e.message);
    } catch (e, st) {
      Loggers.error('Apple login failed: $e\n$st');
      showSnackBar(_unexpectedLoginMessage(e));
    } finally {
      stopLoader();
    }
  }

  Future<user.User> _registration(
      {required String identity,
      required LoginMethod loginMethod,
      String? fullname}) async {
    final deviceToken =
        await FirebaseNotificationManager.instance.getNotificationToken();
    if (deviceToken == null || deviceToken.isEmpty) {
      Loggers.warning(
          'Device token is unavailable. Continuing login without notifications.');
    }

    final userData = await UserService.instance.logInUser(
        identity: identity,
        loginMethod: loginMethod,
        deviceToken: deviceToken ?? '',
        fullName: fullname);

    Setting? setting = SessionManager.instance.getSettings();
    if (userData.newRegister == true && setting?.registrationBonusStatus == 1) {
      final translations = Get.find<DynamicTranslations>();
      final languageData = translations.keys[userData.appLanguage] ?? {};

      // Log registration bonus notification attempt
      Loggers.info(
          '📢 Sending registration bonus notification to user: ${userData.id}');

      try {
        await NotificationService.instance.pushNotification(
            title: languageData[LKey.registrationBonusTitle] ??
                LKey.registrationBonusTitle.tr,
            body: languageData[LKey.registrationBonusDescription] ??
                LKey.registrationBonusDescription.tr,
            type: NotificationType.other,
            deviceType: userData.device,
            token: userData.deviceToken,
            authorizationToken: userData.token?.authToken);
      } catch (e) {
        Loggers.warning(
            'Registration bonus notification failed after login: $e');
      }
    }

    // RevenueCat is optional. Missing purchase configuration must not prevent
    // users from entering the app.
    if (isPurchaseConfig) {
      try {
        await SubscriptionManager.shared.login('${userData.id}');
      } catch (e) {
        Loggers.warning('RevenueCat login failed after app login: $e');
      }
    }

    // Notification setup is best-effort and must never block a valid login.
    if (deviceToken?.isNotEmpty == true) {
      for (int id in (userData.followingIds ?? [])) {
        await Future.delayed(const Duration(milliseconds: 10));
        try {
          await FirebaseNotificationManager.instance
              .subscribeToTopic(topic: '$id');
        } catch (e) {
          Loggers.warning('Unable to subscribe to notification topic $id: $e');
        }
      }
    }
    return userData;
  }

  Future<UserCredential?> createUserWithEmailAndPassword() async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim());
      SessionManager.instance.setPassword(passwordController.text.trim());
      return credential;
    } on FirebaseAuthException catch (e) {
      stopLoader();
      Loggers.error(e.message);
      if (e.code == 'weak-password') {
        showSnackBar(LKey.weakPassword.tr);
      } else if (e.code == 'email-already-in-use') {
        showSnackBar(LKey.accountExists.tr);
      } else {
        showSnackBar(e.message);
      }
      return null;
    }
  }

  Future<UserCredential?> signInWithEmailAndPassword() async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim());
      return credential;
    } on FirebaseAuthException catch (e) {
      Loggers.error('Email login failed: ${e.code} - ${e.message}');
      showSnackBar(_firebaseAuthMessage(e));
      return null;
    } catch (e, st) {
      Loggers.error('Email login failed unexpectedly: $e\n$st');
      showSnackBar(_unexpectedLoginMessage(e));
      return null;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    // Obtain the auth details from the request
    final googleAuth = await googleUser.authentication;

    if (googleAuth.idToken == null) {
      throw FirebaseAuthException(
          code: 'google-token-missing',
          message: 'Google did not return a valid sign-in token.');
    }

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Once signed in, return the UserCredential
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  String _firebaseAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-login-credentials':
        return 'The email or password is incorrect.';
      case 'invalid-email':
        return LKey.invalidEmail.tr;
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'email-not-verified':
        return LKey.verifyEmailFirst.tr;
      case 'network-request-failed':
        return 'Unable to connect. Check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'operation-not-allowed':
        return 'This login method is not enabled. Please contact support.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using another login method.';
      case 'google-token-missing':
        return error.message ?? 'Google login could not be completed.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Login could not be completed. Please try again.';
    }
  }

  String _googlePlatformMessage(PlatformException error) {
    if (error.code == 'sign_in_canceled') {
      return 'Google login was cancelled.';
    }
    if (error.code == 'network_error') {
      return 'Unable to connect to Google. Check your internet connection.';
    }
    if (error.code == 'sign_in_failed' || error.code == '10') {
      return 'Google login is not configured for this app build.';
    }
    return error.message?.trim().isNotEmpty == true
        ? error.message!.trim()
        : 'Google login could not be completed. Please try again.';
  }

  String _unexpectedLoginMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isNotEmpty && message != 'null'
        ? message
        : LKey.somethingWentWrong.tr;
  }

  Future<UserCredential> signInWithApple() async {
    final appleProvider = AppleAuthProvider();
    return await FirebaseAuth.instance.signInWithProvider(appleProvider);
  }

  void forgetPassword() async {
    final email = forgetEmailController.text.trim();
    if (email.isEmpty) {
      showSnackBar(LKey.enterEmail.tr);
      return;
    }
    showLoader();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      stopLoader();
      Get.back(); // Close the BottomSheet
      showSnackBar(LKey.resetPasswordLinkSent.tr);
    } on FirebaseAuthException catch (e) {
      stopLoader();
      showSnackBar(e.message ?? "An error occurred. Please try again.");
    }
  }

  void _navigateScreen(user.User? user) {
    final lockedEmail = _resolveLockedEmail(user);
    if (lockedEmail.isNotEmpty && (user?.userEmail?.trim().isEmpty ?? true)) {
      user = user?.copyWith(userEmail: lockedEmail);
    }

    SessionManager.instance.setLogin(true);
    SessionManager.instance.setUser(user);
    if (ProfileCompletionHelper.isProfileComplete(user)) {
      Get.offAll(() => DashboardScreen(myUser: user));
      return;
    }

    final missingFields = ProfileCompletionHelper.missingFields(user);
    if (missingFields.isNotEmpty) {
      showSnackBar(
          'Complete your profile to continue: ${missingFields.join(', ')}.');
    }

    Get.offAll(() => EditProfileScreen(
          isProfileCompletionRequired: true,
          lockedEmail: lockedEmail,
          onUpdateUser: (updatedUser) {
            if (!ProfileCompletionHelper.isProfileComplete(updatedUser)) {
              final missing =
                  ProfileCompletionHelper.missingFields(updatedUser);
              showSnackBar(
                  'Complete your profile to continue: ${missing.join(', ')}.');
              return;
            }
            Get.offAll(() => DashboardScreen(myUser: updatedUser));
          },
        ));
  }

  String _resolveLockedEmail(user.User? userData) {
    final profileEmail = userData?.userEmail?.trim() ?? '';
    if (GetUtils.isEmail(profileEmail)) return profileEmail;

    final identity = userData?.identity?.trim() ?? '';
    if (GetUtils.isEmail(identity)) return identity;

    final typedEmail = emailController.text.trim();
    if (GetUtils.isEmail(typedEmail)) return typedEmail;

    final firebaseEmail =
        FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
    if (GetUtils.isEmail(firebaseEmail)) return firebaseEmail;

    return '';
  }
}
