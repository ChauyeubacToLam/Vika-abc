import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The single chokepoint for all PostHog product analytics.
///
/// Privacy invariants — do NOT weaken any of these:
///  • Consent defaults to OFF. Until the user accepts the S06 privacy policy
///    (or flips the Profile toggle back on), [capture] and [identify] are hard
///    no-ops and nothing leaves the device.
///  • Users are pseudonymous: the distinct_id is the Supabase UID and nothing
///    else. No name, email, avatar, or any other person property is ever sent.
///  • The PostHog instance is EU-resident and configured for explicit events
///    only — no session replay, no screen/gesture autocapture. That is set up
///    once in main() via [setup]; this service only gates and forwards events.
class AnalyticsService {
  AnalyticsService._();

  /// Process-wide singleton. Every call site goes through this instance so the
  /// consent gate is impossible to bypass.
  static final AnalyticsService instance = AnalyticsService._();

  /// SharedPreferences key holding the persisted consent flag (default false).
  static const String consentKey = 'analytics_consent';

  bool _consent = false;

  /// Whether analytics collection is currently permitted. Read by the Profile
  /// toggle to show its initial state; every [capture]/[identify] also checks
  /// it internally, so callers never have to gate themselves.
  bool get hasConsent => _consent;

  /// Reads the persisted consent flag and aligns PostHog's enabled/disabled
  /// state to it. Call ONCE from main() AFTER `Posthog().setup(...)`.
  ///
  /// PostHog is set up opted-out (config.optOut = true) so that even this
  /// alignment can only ever turn collection ON for a user who already
  /// consented on a previous launch — never the reverse-by-accident.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _consent = prefs.getBool(consentKey) ?? false;
    try {
      if (_consent) {
        await Posthog().enable();
      } else {
        await Posthog().disable();
      }
    } catch (e) {
      debugPrint('[Analytics] init enable/disable failed: $e');
    }
  }

  /// Captures an explicit product event. Hard no-op when consent is false.
  ///
  /// [props] must contain ONLY non-identifying values (ids, enums, counts) —
  /// never name, email, or any free text a user typed about themselves.
  Future<void> capture(String event, {Map<String, Object>? props}) async {
    if (!_consent) return;
    try {
      await Posthog().capture(eventName: event, properties: props);
    } catch (e) {
      debugPrint('[Analytics] capture "$event" failed: $e');
    }
  }

  /// Identifies the current user by their Supabase UID ONLY. The UID becomes
  /// the distinct_id; no person properties are attached. Hard no-op without
  /// consent.
  Future<void> identify(String uid) async {
    if (!_consent || uid.isEmpty) return;
    try {
      // userId only — deliberately no userProperties / userPropertiesSetOnce
      // so PostHog never receives name, email, or any other PII.
      await Posthog().identify(userId: uid);
    } catch (e) {
      debugPrint('[Analytics] identify failed: $e');
    }
  }

  /// Grants consent: persist the flag, enable collection. Idempotent.
  ///
  /// The in-memory flag is flipped before the awaits so an event captured on
  /// the very next frame (e.g. the onboarding step right after S06) is not
  /// dropped by a race with persistence.
  Future<void> grantConsent() async {
    _consent = true;
    try {
      await Posthog().enable();
    } catch (e) {
      debugPrint('[Analytics] grantConsent enable failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(consentKey, true);
  }

  /// Revokes consent: stop collection immediately, drop the stored distinct_id
  /// and any queued events, then persist the flag off. After this, every
  /// capture/identify is a hard no-op again until consent is re-granted.
  Future<void> revokeConsent() async {
    _consent = false;
    try {
      await Posthog().disable();
      await Posthog().reset();
    } catch (e) {
      debugPrint('[Analytics] revokeConsent failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(consentKey, false);
  }

  /// Clears the current distinct_id + queue (sign-out / account deletion) so a
  /// subsequent user on the same device never inherits the previous UID. Hard
  /// no-op without consent — there is nothing identified to clear.
  Future<void> reset() async {
    if (!_consent) return;
    try {
      await Posthog().reset();
    } catch (e) {
      debugPrint('[Analytics] reset failed: $e');
    }
  }
}
