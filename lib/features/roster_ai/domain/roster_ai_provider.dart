import 'roster_ai_models.dart';

/// Provider boundary for an optional AI service.
///
/// Implementations may call a remote model or a local model. Do not place
/// API keys in Flutter client code. Remote implementations must be configured
/// explicitly and send only the minimum data needed for interpretation.
abstract interface class RosterAIProvider {
  Future<RosterAIProposal?> propose(RosterAIRequest request);
}

/// Deterministic rule-first resolver. Existing parsers and configuration
/// should implement this contract before any AI request is considered.
abstract interface class RosterRuleResolver {
  RosterRuleDecision resolve(RosterFieldInput input);
}
