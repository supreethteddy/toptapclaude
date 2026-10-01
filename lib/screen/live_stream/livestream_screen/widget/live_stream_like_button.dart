import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/theme_res.dart';

class LiveStreamLikeButton extends StatefulWidget {
  final Function(void Function(Offset?))? onLikeTap;

  const LiveStreamLikeButton({super.key, required this.onLikeTap});

  @override
  State<LiveStreamLikeButton> createState() => _LiveStreamLikeButtonState();
}

class _LiveStreamLikeButtonState extends State<LiveStreamLikeButton>
    with TickerProviderStateMixin {
  final List<ReactionAnimation> _reactions = [];

  @override
  void initState() {
    widget.onLikeTap?.call(_addReaction);
    super.initState();
  }

  /// [position] is where the burst should originate, in this widget's own
  /// coordinate space (it fills the whole screen, so that's effectively
  /// screen coordinates) - the exact spot the viewer tapped. Null means
  /// there's no tap to anchor to (e.g. a like arriving from Firestore that
  /// another viewer sent), so it falls back to a fixed corner.
  void _addReaction([Offset? position]) {
    final size = MediaQuery.sizeOf(context);
    final origin = position ?? Offset(size.width - 40, size.height - 160);

    final reactionController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));

    final random = Random();
    final xAxisValue = random.nextDouble() * 20 * (random.nextBool() ? 1 : -1);

    final reaction = ReactionAnimation(
      controller: reactionController,
      origin: origin,
      xAxisAnimation: reactionController.drive(TweenSequence([
        TweenSequenceItem(
            tween: Tween<double>(begin: 0.0, end: xAxisValue), weight: 20),
        TweenSequenceItem(
            tween: Tween<double>(begin: xAxisValue, end: 0.0), weight: 20),
      ])),
      opacityAnimation:
          reactionController.drive(Tween<double>(begin: 1.0, end: 0.0)),
      sizeAnimation:
          reactionController.drive(Tween<double>(begin: .8, end: 0.4)),
      reactionAnimation:
          reactionController.drive(Tween<double>(begin: 0.0, end: 1.0)),
    );

    _reactions.add(reaction);

    setState(() {});

    reactionController.forward().then((_) {
      if (mounted) {
        setState(() {
          _reactions.remove(reaction);
        });
      }
      reactionController.dispose();
    });
  }

  @override
  void dispose() {
    for (var reaction in _reactions) {
      reaction.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No static tappable icon any more - liking happens by tapping anywhere
    // on screen (see LivestreamHostScreen/LiveStreamAudienceScreen). This
    // widget fills the whole screen (see its Positioned.fill call site) so
    // each burst can be positioned at the tap that triggered it, rather than
    // always originating from one fixed spot.
    return Stack(
      children: [
        ..._reactions.map((reaction) {
          final double rotationAngle =
              (reaction.xAxisAnimation.value / 20) * pi / 6;
          return Positioned(
            left: reaction.origin.dx - 21.5,
            top: reaction.origin.dy - 21.5,
            child: AnimatedBuilder(
              animation: reaction.controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(reaction.xAxisAnimation.value,
                      -170.0 * reaction.reactionAnimation.value),
                  child: Transform.rotate(
                    angle: rotationAngle,
                    child: FadeTransition(
                      opacity: reaction.opacityAnimation,
                      child: Transform.scale(
                          scale: reaction.sizeAnimation.value, child: child),
                    ),
                  ),
                );
              },
              child: _likeWidget,
            ),
          );
        }),
      ],
    );
  }

  Widget get _likeWidget {
    return Container(
      height: 43,
      width: 43,
      decoration:
          const BoxDecoration(shape: BoxShape.circle, color: ColorRes.likeRed),
      alignment: const Alignment(0, 0.2),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Image.asset(
        AssetRes.icFillHeart,
        width: 25,
        height: 25,
        color: whitePure(context),
      ),
    );
  }
}

class ReactionAnimation {
  final AnimationController controller;
  final Offset origin;
  final Animation<double> xAxisAnimation;
  final Animation<double> opacityAnimation;
  final Animation<double> sizeAnimation;
  final Animation<double> reactionAnimation;

  ReactionAnimation({
    required this.controller,
    required this.origin,
    required this.xAxisAnimation,
    required this.opacityAnimation,
    required this.sizeAnimation,
    required this.reactionAnimation,
  });
}
