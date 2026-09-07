import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/support_chat_service.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterController extends BaseController {
  Setting? get setting => SessionManager.instance.getSettings();

  /// Support email comes from admin > settings (help_mail).
  String get supportEmail {
    final mail = (setting?.helpMail ?? '').trim();
    return mail.isNotEmpty ? mail : AppRes.supportEmail;
  }

  /// Support phone comes from admin > settings (help_phone). Empty = hidden.
  String get supportPhone => (setting?.helpPhone ?? '').trim();

  bool get hasPhoneSupport => supportPhone.isNotEmpty;

  /// Community URL comes from admin > settings (community_url). Empty = hidden.
  String get communityUrl => (setting?.communityUrl ?? '').trim();

  bool get hasCommunity => communityUrl.startsWith('http');

  // ---------------------------------------------------------------- topics
  static const List<HelpTopic> topics = [
    HelpTopic('Getting Started',
        'Create your first video from the + tab, set up your profile from Settings > Edit Profile, and discover creators on the Explore tab.'),
    HelpTopic('Account & Profile',
        'Manage your account, edit your profile, request verification, switch accounts and control who can see your content from Settings.'),
    HelpTopic('Creating Content',
        'Record in HD, add music, filters, text and stickers, then post as a Reel, a feed video or a Story. Mention friends with @ in the caption.'),
    HelpTopic('Privacy & Safety',
        'Block or report users from their profile, restrict comments per post, and review blocked users under Settings > Privacy.'),
    HelpTopic('Earnings & Payments',
        'Receive gifts on posts and LIVEs, track coins in your wallet and request a withdrawal once you reach the minimum balance.'),
    HelpTopic('Live Streaming',
        'Go LIVE from the + tab. Accept guest requests, invite viewers, start a PK battle with a co-host and set a LIVE goal for your audience.'),
    HelpTopic('Comments & Chat',
        'Reply, like and pin comments on your posts. Message other creators from their profile; requests from people you do not follow land in Requests.'),
    HelpTopic('Following & Followers',
        'Follow creators to see them in your Following feed. Your followers are notified when you go LIVE.'),
    HelpTopic('Hashtags & Discovery',
        'Add #hashtags to captions to reach new viewers and browse trending tags on the Explore tab.'),
    HelpTopic('Connection Issues',
        'Check your internet connection, switch between Wi-Fi and mobile data, and lower the playback quality under Settings > Playback if videos buffer.'),
    HelpTopic('Video Upload Problems',
        'Keep videos under the maximum duration, make sure you have free storage, and retry on a stable connection. Very large files are compressed automatically.'),
    HelpTopic('Notification Issues',
        'Enable notifications for TopTap in your phone settings and check Settings > Notifications inside the app.'),
    HelpTopic('Audio Problems',
        'Make sure the device is not on silent, the volume is up and no other app is using the microphone during a LIVE.'),
  ];

  void openTopic(HelpTopic topic) => _showHelpDialog(topic.title, topic.body);

  void openGettingStarted() => openTopic(topics[0]);
  void openAccountHelp() => openTopic(topics[1]);
  void openContentHelp() => openTopic(topics[2]);
  void openPrivacyHelp() => openTopic(topics[3]);
  void openEarningsHelp() => openTopic(topics[4]);
  void openLiveStreamHelp() => openTopic(topics[5]);
  void openCommentsHelp() => openTopic(topics[6]);
  void openFollowHelp() => openTopic(topics[7]);
  void openHashtagHelp() => openTopic(topics[8]);
  void openConnectionHelp() => openTopic(topics[9]);
  void openUploadHelp() => openTopic(topics[10]);
  void openNotificationHelp() => openTopic(topics[11]);
  void openAudioHelp() => openTopic(topics[12]);

  // --------------------------------------------------------------- support
  /// Live chat = in-app conversation with the support account.
  Future<void> openLiveChat() async {
    showLoader();
    bool opened = false;
    try {
      opened = await SupportChatService.instance.openSupportChat();
    } finally {
      stopLoader();
    }
    if (!opened) {
      Get.dialog(
        AlertDialog(
          title: Text(LKey.liveChatSupport.tr),
          content: Text(LKey.supportChatUnavailable.tr),
          actions: [
            TextButton(onPressed: Get.back, child: Text(LKey.cancel.tr)),
            TextButton(
              onPressed: () {
                Get.back();
                sendEmail();
              },
              child: Text(LKey.sendEmail.tr),
            ),
          ],
        ),
      );
    }
  }

  Future<void> sendEmail() async {
    final me = SessionManager.instance.getUser();
    final body = 'Please describe your issue:\n\n\n---\n'
        'Username: @${me?.username ?? '-'}\n'
        'User ID: ${me?.id ?? '-'}';
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: _encodeQuery({
        'subject': 'TopTap support request',
        'body': body,
      }),
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) await _copySupportEmail();
    } catch (e) {
      Loggers.error('mailto failed: $e');
      await _copySupportEmail();
    }
  }

  Future<void> _copySupportEmail() async {
    await Clipboard.setData(ClipboardData(text: supportEmail));
    showSnackBar('${LKey.noEmailAppFound.tr} ($supportEmail)');
  }

  Future<void> callSupport() async {
    if (!hasPhoneSupport) {
      showSnackBar(LKey.phoneSupportUnavailable.tr);
      return;
    }
    final uri = Uri(scheme: 'tel', path: supportPhone);
    try {
      final opened = await launchUrl(uri);
      if (!opened) await _copyPhone();
    } catch (e) {
      Loggers.error('tel failed: $e');
      await _copyPhone();
    }
  }

  Future<void> _copyPhone() async {
    await Clipboard.setData(ClipboardData(text: supportPhone));
    showSnackBar('Could not open the dialer. Number copied: $supportPhone');
  }

  void openForum() {
    if (!hasCommunity) return;
    _launchURL(communityUrl);
  }

  void openFAQ() {
    Get.bottomSheet(
      const _FaqSheet(),
      isScrollControlled: true,
    );
  }

  // --------------------------------------------------------------- helpers
  String _encodeQuery(Map<String, String> params) => params.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');

  void _showHelpDialog(String title, String content) {
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(onPressed: Get.back, child: Text(LKey.close.tr)),
          TextButton(
            onPressed: () {
              Get.back();
              sendEmail();
            },
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) showSnackBar('Could not open $url');
    } catch (e) {
      showSnackBar('Could not open $url');
    }
  }
}

class HelpTopic {
  final String title;
  final String body;

  const HelpTopic(this.title, this.body);
}

class _FaqSheet extends StatelessWidget {
  const _FaqSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(top: AppBar().preferredSize.height * 2),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('FAQ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: HelpCenterController.topics.length,
              itemBuilder: (context, index) {
                final topic = HelpCenterController.topics[index];
                return ExpansionTile(
                  title: Text(topic.title),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(topic.body),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
