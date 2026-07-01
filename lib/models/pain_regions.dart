enum BodyGender { male, female }

/// Free-text 'other' region id. It is reported with notes rather than a body
/// tap point.
const String kOtherPainRegion = 'other';

class PainRegion {
  const PainRegion({
    required this.id,
    required this.vnLabel,
    required this.fx,
    required this.fy,
  });

  final String id; // body_region enum value
  final String vnLabel;
  final double fx; // 0..1 across figure width
  final double fy; // 0..1 down figure height
}

/// Canonical body_region capture vocabulary shared by onboarding and Progress.
///
/// Anatomical tap points are fractions of the aspect-correct figure box.
/// Ordered top-to-bottom so callout numbers and ledgers read down the body.
const List<PainRegion> painRegions = [
  PainRegion(id: 'shoulder_neck', vnLabel: 'Cổ / vai', fx: 0.50, fy: 0.15),
  PainRegion(id: 'back', vnLabel: 'Lưng trên', fx: 0.50, fy: 0.28),
  PainRegion(id: 'lower_back', vnLabel: 'Lưng dưới', fx: 0.50, fy: 0.41),
  PainRegion(id: 'hip', vnLabel: 'Hông', fx: 0.50, fy: 0.50),
  PainRegion(id: 'wrist', vnLabel: 'Cổ tay', fx: 0.16, fy: 0.55),
  PainRegion(id: 'knee', vnLabel: 'Đầu gối', fx: 0.41, fy: 0.73),
  PainRegion(id: 'ankle', vnLabel: 'Cổ chân', fx: 0.41, fy: 0.95),
];

const Set<String> _canonicalPainRegionIds = {
  'shoulder_neck',
  'back',
  'lower_back',
  'hip',
  'wrist',
  'knee',
  'ankle',
  kOtherPainRegion,
};

/// Normalizes every `user_pain_areas.body_region` writer to the shared
/// vocabulary. Unknown, empty, or non-pain conditioning signals return null
/// and must be skipped by callers.
String? canonicalPainRegion(String raw) {
  final key = raw.trim();
  if (_canonicalPainRegionIds.contains(key)) return key;

  return switch (key) {
    'shoulder' || 'neck' || 'chest' => 'shoulder_neck',
    _ => null,
  };
}

/// Human label for any region id (body + 'other').
String painRegionLabel(String region) {
  if (region == kOtherPainRegion) return 'Khác';
  for (final r in painRegions) {
    if (r.id == region) return r.vnLabel;
  }
  return region;
}
