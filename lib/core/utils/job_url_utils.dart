/// Optional job listing / application URLs: normalize user input and validate http(s).
class JobUrlUtils {
  JobUrlUtils._();

  static String trimInput(String raw) => raw.trim();

  /// Prepends https when the user omitted a scheme (e.g. `example.com/job`).
  static String normalizeCandidate(String trimmed) {
    if (trimmed.isEmpty) return '';
    final hasScheme = RegExp(r'^[a-zA-Z][\w+\-.]*:').hasMatch(trimmed);
    return hasScheme ? trimmed : 'https://$trimmed';
  }

  /// True if the field is blank or contains a valid http(s) URL.
  static bool isValidOptional(String raw) {
    if (raw.trim().isEmpty) return true;
    return forFirestore(raw) != null;
  }

  /// Blank input → `null` (no URL stored). Non-blank must parse as http(s) with a host.
  static String? forFirestore(String raw) {
    final trimmed = trimInput(raw);
    if (trimmed.isEmpty) return null;
    final normalized = normalizeCandidate(trimmed);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    return uri.toString();
  }

  /// Reads optional job listing URL from a Firestore job document map.
  static String? readFromJobMap(Map<String, dynamic> job) {
    final v = job['jobUrl'];
    if (v == null) return null;
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }
}
