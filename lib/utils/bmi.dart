// Single source of truth for BMI banding across the app.
//
// Both the onboarding body-info step and the Profile body card/editor read
// their BMI label + zone from [bmiCategory] so the two can never drift. The
// helper takes BMI ONLY — categories are UNISEX by the Vietnamese standard
// (IDI&WPRO / Viện Dinh dưỡng), so there is intentionally no gender parameter.
//
// Cutoffs (do NOT split obese I/II — the four soft labels are deliberate):
//   < 18.5      Hơi gầy   (low)
//   18.5–22.9   Cân đối   (good)
//   23–24.9     Hơi tròn  (warn)
//   >= 25       Cần chú ý (high)
//
// The BMI formula itself (weight / height²) is universal and lives at each
// readout. Show [bmiCaveat] near every BMI value: BMI is a rough estimate and
// cannot tell muscle from fat.

/// Abstract band, independent of any design register. Each call site maps the
/// zone to its own colors (V5 in onboarding, VikaColors in the main app).
enum BmiZone { low, good, warn, high }

/// (label, zone) for a BMI value. Label is the canonical Vietnamese band name.
typedef BmiBand = ({String label, BmiZone zone});

BmiBand bmiCategory(double bmi) {
  if (bmi < 18.5) return (label: 'Hơi gầy', zone: BmiZone.low);
  if (bmi < 23) return (label: 'Cân đối', zone: BmiZone.good);
  if (bmi < 25) return (label: 'Hơi tròn', zone: BmiZone.warn);
  return (label: 'Cần chú ý', zone: BmiZone.high);
}

/// Encouraging footnote shown beside BMI readouts. Not an alert.
const String bmiCaveat = 'BMI chỉ là ước tính, không phân biệt cơ và mỡ.';
