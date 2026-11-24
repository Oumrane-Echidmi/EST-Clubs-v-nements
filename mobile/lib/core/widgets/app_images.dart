import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Bundled photos from the Stitch design (assets/images). They are used whenever
/// the backend has no image (posterUrl / logoUrl is null), so the app always looks
/// like the mockups. Real uploaded images always win.
const _dir = 'assets/images';

/// Which of the 8 design clubs a club looks like (by name, then by category).
String clubKey(String? name, String? category) {
  final n = (name ?? '').toLowerCase();
  const byName = {
    'robot': 'robotics',
    'cyber': 'science',
    'informatique': 'science',
    'enactus': 'entrepreneurs',
    'théâtre': 'arts',
    'theatre': 'arts',
    'outdoor': 'sports',
    'science': 'science',
    'entrepren': 'entrepreneurs',
    'art': 'arts',
    'sport': 'sports',
    'photo': 'photography',
    'solidar': 'solidarity',
    'music': 'music',
    'musi': 'music',
  };
  for (final e in byName.entries) {
    if (n.contains(e.key)) return e.value;
  }
  switch (category) {
    case 'TECHNOLOGY':
      return 'robotics';
    case 'SCIENCE':
      return 'science';
    case 'CULTURE':
      return 'arts';
    case 'SPORTS':
      return 'sports';
    case 'SOCIAL':
      return 'solidarity';
    case 'ENTREPRENEURSHIP':
      return 'entrepreneurs';
  }
  // Stable fallback so the same club always gets the same photo.
  const all = ['science', 'robotics', 'entrepreneurs', 'arts', 'sports', 'photography', 'solidarity', 'music'];
  return all[n.hashCode.abs() % all.length];
}

String clubBannerAsset(String? name, String? category) =>
    '$_dir/banner_${clubKey(name, category)}.jpg';

String clubLogoAsset(String? name, String? category) =>
    '$_dir/logo_${clubKey(name, category)}.jpg';

/// Event poster by category (technology alternates between two photos by id).
String eventPosterAsset(String id, String? category, {String? clubName}) {
  // Club-specific photo for cultural / sports / social / startup events.
  if (clubName != null && category != 'TECHNOLOGY' && category != 'SCIENCE') {
    return clubBannerAsset(clubName, category);
  }
  switch (category) {
    case 'SCIENCE':
      return '$_dir/event_science.jpg';
    case 'CULTURE':
      return '$_dir/banner_arts.jpg';
    case 'SPORTS':
      return '$_dir/banner_sports.jpg';
    case 'SOCIAL':
      return '$_dir/banner_solidarity.jpg';
    case 'ENTREPRENEURSHIP':
      return '$_dir/event_entrepreneurship.jpg';
    default:
      return id.hashCode.isOdd ? '$_dir/event_gaming.jpg' : '$_dir/event_technology.jpg';
  }
}

const profileAvatarAsset = '$_dir/avatar.jpg';

/// Shows [url] when present, otherwise the bundled [asset] photo.
Widget photo({
  required String? url,
  required String asset,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  if (url == null || url.isEmpty) {
    return Image.asset(asset, width: width, height: height, fit: fit);
  }
  return CachedNetworkImage(
    imageUrl: url,
    width: width,
    height: height,
    fit: fit,
    placeholder: (_, _) => Image.asset(asset, width: width, height: height, fit: fit),
    errorWidget: (_, _, _) => Image.asset(asset, width: width, height: height, fit: fit),
  );
}

/// Round image provider with the same fallback rule.
ImageProvider photoProvider({required String? url, required String asset}) =>
    (url == null || url.isEmpty)
        ? AssetImage(asset)
        : CachedNetworkImageProvider(url) as ImageProvider;
