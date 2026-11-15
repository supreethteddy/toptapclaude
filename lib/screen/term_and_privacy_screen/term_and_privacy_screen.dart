import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:get/get.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/widget/custom_app_bar.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/general/settings_model.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

enum TermAndPrivacyType {
  privacyPolicy,
  termAndCondition;

  String get title {
    switch (this) {
      case TermAndPrivacyType.privacyPolicy:
        return LKey.privacyPolicy;
      case TermAndPrivacyType.termAndCondition:
        return LKey.termsOfUse;
    }
  }
}

class TermAndPrivacyScreen extends StatefulWidget {
  final TermAndPrivacyType type;

  const TermAndPrivacyScreen(
      {super.key, required this.type});

  @override
  State<TermAndPrivacyScreen> createState() =>
      _TermAndPrivacyScreenState();
}

class _TermAndPrivacyScreenState
    extends State<TermAndPrivacyScreen> {
  late final Setting? settings;

  @override
  void initState() {
    super.initState();
    settings = SessionManager.instance.getSettings();
  }

  @override
  Widget build(BuildContext context) {
    final content = _resolveContent();

    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(title: widget.type.title.tr),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: HtmlWidget(
                  content,
                  textStyle: TextStyleCustom.outFitRegular400(
                      fontSize: 15,
                      color: textDarkGrey(context)),
                  renderMode: RenderMode.listView,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  String _resolveContent() {
    final backendContent =
        widget.type == TermAndPrivacyType.privacyPolicy
            ? settings?.privacyPolicy
            : settings?.termsOfUses;

    if (backendContent != null &&
        backendContent.trim().isNotEmpty &&
        backendContent.trim().toLowerCase() != 'null') {
      return backendContent;
    }

    return widget.type == TermAndPrivacyType.privacyPolicy
        ? _privacyPolicyFallbackHtml
        : _termsFallbackHtml;
  }

  static const String _privacyPolicyFallbackHtml = '''
<h2>Privacy Policy (Toptap)</h2>
<p><strong>Effective Date:</strong> 21 January 2026</p>
<p><strong>Introduction:</strong> Welcome to Toptap. Your privacy matters, so we explain how we collect, use, share, and protect your information below.</p>

<h3>1. Information We Collect</h3>
<p><strong>Personal Information:</strong> name, email, phone (if voluntarily provided).</p>
<p><strong>Usage Data:</strong> device metadata, IP address, app activity, preferences, crash logs, and analytics.</p>
<p><strong>Cookies and Similar Tech:</strong> session data, tokens, and identifiers to keep the app working smoothly and personalize experience.</p>

<h3>2. How We Use Your Information</h3>
<p>Operate and improve Toptap features (performance monitoring, updates, bug fixes).</p>
<p>Personalize content, recommendations, and in-app messaging.</p>
<p>Communicate account notices, security alerts, marketing (if you opt-in), and respond to support inquiries.</p>

<h3>3. Sharing of Information</h3>
<p>We do not sell or rent personal data.</p>
<p>We share data with trusted service providers (cloud hosting, analytics, push notifications) and with law enforcement when legally required or to protect rights.</p>

<h3>4. Your Rights</h3>
<p>Access, update, correct, or delete your personal data stored in Toptap.</p>
<p>Opt out of marketing communications and disable specific tracking features (via app settings or by contacting us).</p>

<h3>5. Data Security</h3>
<p>We apply industry-standard safeguards (encryption, access control).</p>
<p>No system is fully invulnerable; we encourage you to protect your credentials and report issues.</p>

<h3>6. Changes to this Privacy Policy</h3>
<p>We may revise this policy; the app will notify you of significant changes and post the updated date.</p>

<h3>7. Contact Us</h3>
<p>Questions or privacy requests: support@toptap.com</p>
''';

  static const String _termsFallbackHtml = '''
<h2>Terms and Conditions (Toptap)</h2>
<p><strong>Effective Date:</strong> 21 January 2026</p>
<p><strong>Introduction:</strong> By using Toptap you agree to these terms. If you disagree with any part, please stop using the app.</p>

<h3>1. Use of the App</h3>
<p>You must be at least 18 years old or have parental permission.</p>
<p>Use Toptap lawfully and in accordance with community standards.</p>

<h3>2. User Content</h3>
<p>You retain ownership of what you upload.</p>
<p>You grant Toptap a non-exclusive, royalty-free license to use, display, and distribute your content for app functionality and promotion.</p>

<h3>3. Prohibited Activities</h3>
<p>No uploading offensive, infringing, illegal, or harmful material.</p>
<p>Do not tamper with the app, attempt hacks, or disrupt services.</p>

<h3>4. Limitation of Liability</h3>
<p>Toptap is provided "as is." We are not liable for indirect, incidental, or consequential damages arising from your use.</p>

<h3>5. Changes to the Terms</h3>
<p>We can revise these Terms at any time; continuing to use Toptap after updates means you accept them.</p>

<h3>6. Contact Us</h3>
<p>Questions or concerns: support@toptap.com</p>
''';
}
