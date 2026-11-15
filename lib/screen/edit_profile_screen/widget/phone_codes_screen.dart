import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/general/countries_model.dart';
import 'package:toptap/screen/edit_profile_screen/widget/base_select_sheet.dart';
import 'package:toptap/screen/edit_profile_screen/widget/phone_codes_screen_controller.dart';

class PhoneCodesScreen extends StatelessWidget {
  const PhoneCodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller =
        Get.find<PhoneCodesScreenController>();
    return Scaffold(
      body: BaseSelectSheet<Country>(
        title: LKey.phoneCode.tr,
        items: controller.filteredCodes,
        selectedItem: controller.selectedCode,
        getDisplayText: (country) => country.countryName,
        getSecondaryText: (country) => country.phoneCode,
        onSelect: (country) =>
            controller.selectCode(country),
        onSearch: controller.searchPhoneCodes,
      ),
    );
  }
}
