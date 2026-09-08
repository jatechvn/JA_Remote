/// Multi-term search matcher mimicking Voidtools Everything syntax:
/// - Space-separated terms act as logical AND (all positive terms must match).
/// - Pipe symbol '|' acts as logical OR between query branches.
/// - Prefix '-' or '!' negates a term (must NOT match).
/// - Double quotes "phrase with spaces" preserve spaces inside terms.
/// - Case-insensitive matching across all target fields.
class EverythingSearchMatcher {
  /// Evaluates whether [targets] match the [query].
  static bool matches({required String query, required List<String?> targets}) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return true;

    // Combine all non-null target values into a single normalized search string
    final combined = targets
        .where((t) => t != null && t.isNotEmpty)
        .map((t) => t!.toLowerCase())
        .join(' ');

    if (combined.isEmpty) return false;

    // If query has OR branches ('|')
    if (trimmedQuery.contains('|')) {
      final orBranches = trimmedQuery.split('|');
      for (final branch in orBranches) {
        if (_matchAndBranch(branch.trim(), combined)) {
          return true;
        }
      }
      return false;
    }

    return _matchAndBranch(trimmedQuery, combined);
  }

  /// Matches a single branch where space-separated tokens are AND-ed.
  static bool _matchAndBranch(String branchQuery, String combinedTarget) {
    if (branchQuery.isEmpty) return true;

    final tokens = _tokenize(branchQuery);
    if (tokens.isEmpty) return true;

    for (final token in tokens) {
      if (token.isEmpty) continue;

      // Negative term (e.g. -soz or !soz)
      if (token.startsWith('-') || token.startsWith('!')) {
        if (token.length > 1) {
          final negTerm = token.substring(1).toLowerCase();
          if (negTerm.isNotEmpty && combinedTarget.contains(negTerm)) {
            return false;
          }
        }
        continue;
      }

      // Positive term
      final term = token.toLowerCase();
      if (!combinedTarget.contains(term)) {
        return false;
      }
    }

    return true;
  }

  /// Splits input into tokens respecting quoted phrases like "hello world".
  static List<String> _tokenize(String input) {
    final tokens = <String>[];
    final regex = RegExp(r'(-|!)?"([^"]+)"|(\S+)');
    final matches = regex.allMatches(input);

    for (final m in matches) {
      if (m.group(2) != null) {
        final prefix = m.group(1) ?? '';
        tokens.add('$prefix${m.group(2)}');
      } else if (m.group(3) != null) {
        tokens.add(m.group(3)!);
      }
    }

    return tokens;
  }
}
