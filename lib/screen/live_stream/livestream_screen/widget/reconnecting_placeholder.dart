import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/utilities/text_style_custom.dart';

/// A seated participant (co-host, guest, or PK team member) whose stream
/// has dropped — same slot, same position, not collapsed out of the
/// layout, so the rest of the grid never silently reflows around them.
/// Shared by the PK arena (battle_view.dart) and the general multi-guest
/// grid (livestream_view.dart).
class ReconnectingPlaceholder extends StatelessWidget {
  final AppUser user;

  const ReconnectingPlaceholder({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 26,
            width: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(LKey.reconnectingCreator.tr,
              style: TextStyleCustom.outFitSemiBold600(
                  color: Colors.white, fontSize: 13)),
          const SizedBox(height: 2),
          Text(LKey.creatorWillBeBackSoon.tr,
              style: TextStyleCustom.outFitRegular400(
                  color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
