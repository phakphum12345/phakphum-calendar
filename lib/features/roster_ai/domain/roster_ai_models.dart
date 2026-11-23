/// Data contracts for AI-assisted roster interpretation.
///
/// This layer contains proposals only. It must never persist shifts or sync
/// events to an external calendar.
enum RosterFieldStatus { ruleResolved, aiProposed, needsReview }

class RosterFieldInput {
  const RosterFieldInput({
    required this.fieldName,
    required this.rawValue,
    required this.allowedValues,
    required this.sourceReference,
    this.context = const {},
  });

  final String fieldName;
  final String rawValue;
  final List<String> allowedValues;

  /// A local cell/row reference, not a URL or credential.
  final String sourceReference;

  /// Optional minimal context needed to interpret this field.
  final Map<String, String> context;
}

class RosterRuleDecision {
  const RosterRuleDecision.resolved(this.value, {this.reason = 'Rule match'})
    : isAmbiguous = false;

  const RosterRuleDecision.ambiguous({required this.reason})
    : value = null,
      isAmbiguous = true;

  final String? value;
  final bool isAmbiguous;
  final String reason;
}

class RosterAIRequest {
  const RosterAIRequest({
    required this.fieldName,
    required this.rawValue,
    required this.allowedValues,
    required this.reason,
    this.context = const {},
  });

  final String fieldName;
  final String rawValue;
  final List<String> allowedValues;
  final String reason;
  final Map<String, String> context;
}

class RosterAIProposal {
  const RosterAIProposal({
    required this.value,
    required this.confidence,
    required this.explanation,
  });

  final String value;
  final double confidence;
  final String explanation;
}

class RosterFieldAnalysis {
  const RosterFieldAnalysis({
    required this.input,
    required this.status,
    required this.reason,
    this.proposedValue,
    this.confidence,
    this.explanation,
  });

  final RosterFieldInput input;
  final RosterFieldStatus status;
  final String reason;
  final String? proposedValue;
  final double? confidence;
  final String? explanation;

  /// Intentionally false: every interpretation requires explicit review.
  bool get requiresUserConfirmation => true;
}
