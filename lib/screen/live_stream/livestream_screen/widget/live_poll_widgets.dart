import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/bottom_sheet_top_view.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Compact, always-visible indicator for the currently running poll (mirrors
/// [PinnedGiftGoalChip]). Tapping it (host or audience) opens [LivePollSheet]
/// to vote or, for the host, to end the poll. Hidden when no poll is active.
class LivePollBanner extends StatelessWidget {
  final LivestreamScreenController controller;

  const LivePollBanner({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final poll = controller.liveData.value.poll;
      if (poll == null) return const SizedBox.shrink();
      return InkWell(
        onTap: () => Get.bottomSheet(
          LivePollSheet(controller: controller),
          isScrollControlled: true,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blueAccent.withValues(alpha: .6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.poll_outlined, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  poll.question,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Host: create a poll when none is running, or see live results with an End
/// poll button while one is. Audience: vote once, then see live results.
class LivePollSheet extends StatelessWidget {
  final LivestreamScreenController controller;

  const LivePollSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: AppBar().preferredSize.height * 2),
      decoration: ShapeDecoration(
        color: whitePure(context),
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 30, cornerSmoothing: 1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetTopView(
              title: LKey.interact.tr, sideBtnVisibility: false),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Obx(() {
              final poll = controller.liveData.value.poll;
              if (poll == null) {
                return controller.isHost
                    ? _CreatePollForm(controller: controller)
                    : const SizedBox();
              }
              return _PollResults(controller: controller, poll: poll);
            }),
          ),
        ],
      ),
    );
  }
}

class _CreatePollForm extends StatefulWidget {
  final LivestreamScreenController controller;

  const _CreatePollForm({required this.controller});

  @override
  State<_CreatePollForm> createState() => _CreatePollFormState();
}

class _CreatePollFormState extends State<_CreatePollForm> {
  final questionController = TextEditingController();
  final optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    questionController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(LKey.pollQuestion.tr,
            style: TextStyleCustom.outFitMedium500(
                color: adaptiveTextColor(context))),
        const SizedBox(height: 8),
        TextField(
          controller: questionController,
          decoration: InputDecoration(
            isDense: true,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < optionControllers.length; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: optionControllers[i],
              decoration: InputDecoration(
                isDense: true,
                hintText: '${LKey.pollOption.tr} ${i + 1}',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
        if (optionControllers.length < 4)
          TextButton(
            onPressed: () =>
                setState(() => optionControllers.add(TextEditingController())),
            child: Text(LKey.addOption.tr),
          ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () {
            final question = questionController.text.trim();
            final options = optionControllers
                .map((c) => c.text.trim())
                .where((text) => text.isNotEmpty)
                .toList();
            if (question.isEmpty || options.length < 2) return;
            widget.controller.createPoll(question, options);
            Get.back();
          },
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: themeAccentSolid(context),
              shape: SmoothRectangleBorder(
                  borderRadius:
                      SmoothBorderRadius(cornerRadius: 10, cornerSmoothing: 1)),
            ),
            child: Text(LKey.createPoll.tr,
                style: TextStyleCustom.outFitMedium500(
                    color: whitePure(context), fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

class _PollResults extends StatelessWidget {
  final LivestreamScreenController controller;
  final LivePoll poll;

  const _PollResults({required this.controller, required this.poll});

  @override
  Widget build(BuildContext context) {
    final hasVoted = poll.voterIds.contains(controller.myUserId);
    final showResults = hasVoted || poll.isClosed || controller.isHost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(poll.question,
            style: TextStyleCustom.outFitMedium500(
                color: adaptiveTextColor(context), fontSize: 16)),
        const SizedBox(height: 12),
        for (int i = 0; i < poll.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: (!controller.isHost && !hasVoted && !poll.isClosed)
                  ? () => controller.votePoll(i)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: ShapeDecoration(
                  color: bgLightGrey(context),
                  shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                          cornerRadius: 10, cornerSmoothing: 1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(poll.options[i],
                              style: TextStyleCustom.outFitRegular400(
                                  color: adaptiveTextColor(context))),
                        ),
                        if (showResults)
                          Text(
                              '${poll.voteCounts[i]} ${LKey.votes.tr}',
                              style: TextStyleCustom.outFitLight300(
                                  color: textLightGrey(context), fontSize: 12)),
                      ],
                    ),
                    if (showResults) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: poll.totalVotes > 0
                              ? poll.voteCounts[i] / poll.totalVotes
                              : 0,
                          minHeight: 6,
                          backgroundColor:
                              whitePure(context).withValues(alpha: .3),
                          color: themeAccentSolid(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        if (controller.isHost && !poll.isClosed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InkWell(
              onTap: controller.endPoll,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: ColorRes.likeRed,
                  shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                          cornerRadius: 10, cornerSmoothing: 1)),
                ),
                child: Text(LKey.endPoll.tr,
                    style: TextStyleCustom.outFitMedium500(
                        color: Colors.white, fontSize: 14)),
              ),
            ),
          ),
      ],
    );
  }
}
