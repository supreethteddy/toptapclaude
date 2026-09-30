import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/utilities/asset_res.dart';

final DeepARFilters deepArNoneEffect = DeepARFilters(
  id: -1,
  title: 'None',
  image: AssetRes.icNoFilter,
  filterFile: 'none',
);

final List<DeepARFilters> localDeepArBeautyFilters = [
  deepArNoneEffect,
  DeepARFilters(
    id: -2,
    title: 'Natural Glow',
    image: '${AssetRes.deepAr}thumbnails/natural_glow.png',
    filterFile: '${AssetRes.deepAr}beauty/base_beauty.deepar',
  ),
  DeepARFilters(
    id: -3,
    title: 'Rose Blush',
    image: '${AssetRes.deepAr}thumbnails/rose_blush.png',
    filterFile: '${AssetRes.deepAr}beauty/look1.deepar',
  ),
  DeepARFilters(
    id: -4,
    title: 'Evening Glam',
    image: '${AssetRes.deepAr}thumbnails/evening_glam.png',
    filterFile: '${AssetRes.deepAr}beauty/look2.deepar',
  ),
  DeepARFilters(
    id: -5,
    title: 'Vendetta',
    image: '${AssetRes.deepAr}thumbnails/vendetta.png',
    filterFile: '${AssetRes.deepAr}beauty/vendetta.deepar',
  ),
];
