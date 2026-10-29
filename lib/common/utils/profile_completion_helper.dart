import 'package:shortzz/model/user_model/user_model.dart';

class ProfileCompletionHelper {
  ProfileCompletionHelper._();

  // Client spec: only full name blocks initial registration. Username,
  // bio, email (beyond the identity already captured at login), phone
  // number and profile picture are all optional and completable later
  // from Profile/Edit Profile -- never gate app entry.
  static bool isProfileComplete(User? user) {
    return missingFields(user).isEmpty;
  }

  static List<String> missingFields(User? user) {
    if (user == null) {
      return const <String>['full name'];
    }

    final missing = <String>[];
    final fullName = user.fullname?.trim() ?? '';

    if (fullName.isEmpty) {
      missing.add('full name');
    }

    return missing;
  }
}

