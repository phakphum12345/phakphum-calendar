import '../domain/roster_ai_models.dart';
import '../domain/roster_ai_provider.dart';

/// Hybrid pipeline: deterministic rules first, AI only for ambiguous fields.
///
/// This service produces reviewable proposals only. It does not mutate roster
/// records, save data, or sync to Google Calendar.
class HybridRosterAIAnalyzer {
  const HybridRosterAIAnalyzer({
    required this._rules,
    RosterAIProvider? aiProvider,
    this.minimumConfidence = 0.85,
  }) : _aiProvider = aiProvider;

  final RosterRuleResolver _rules;
  final RosterAIProvider? _aiProvider;
  final double minimumConfidence;

  Future<List<RosterFieldAnalysis>> analyze(
    List<RosterFieldInput> inputs,
  ) async {
    final results = <RosterFieldAnalysis>[];

    for (final input in inputs) {
      final ruleDecision = _rules.resolve(input);
      if (!ruleDecision.isAmbiguous) {
        final value = ruleDecision.value;
        if (value != null && input.allowedValues.contains(value)) {
          results.add(
            RosterFieldAnalysis(
              input: input,
              status: RosterFieldStatus.ruleResolved,
              proposedValue: value,
              reason: ruleDecision.reason,
              explanation: 'Resolved by deterministic rules.',
            ),
          );
        } else {
          results.add(
            RosterFieldAnalysis(
              input: input,
              status: RosterFieldStatus.needsReview,
              reason: 'Rule result is outside the allowed values.',
            ),
          );
        }
        continue;
      }

      final provider = _aiProvider;
      if (provider == null) {
        results.add(
          RosterFieldAnalysis(
            input: input,
            status: RosterFieldStatus.needsReview,
            reason: ruleDecision.reason,
          ),
        );
        continue;
      }

      final proposal = await provider.propose(
        RosterAIRequest(
          fieldName: input.fieldName,
          rawValue: input.rawValue,
          allowedValues: List.unmodifiable(input.allowedValues),
          reason: ruleDecision.reason,
          context: Map.unmodifiable(input.context),
        ),
      );

      if (proposal == null) {
        results.add(
          RosterFieldAnalysis(
            input: input,
            status: RosterFieldStatus.needsReview,
            reason: 'AI did not return a proposal.',
          ),
        );
        continue;
      }

      final validConfidence =
          proposal.confidence.isFinite &&
          proposal.confidence >= minimumConfidence &&
          proposal.confidence <= 1.0;
      final allowedValue = input.allowedValues.contains(proposal.value);

      if (validConfidence && allowedValue) {
        results.add(
          RosterFieldAnalysis(
            input: input,
            status: RosterFieldStatus.aiProposed,
            proposedValue: proposal.value,
            confidence: proposal.confidence,
            reason: ruleDecision.reason,
            explanation: proposal.explanation,
          ),
        );
      } else {
        results.add(
          RosterFieldAnalysis(
            input: input,
            status: RosterFieldStatus.needsReview,
            confidence: proposal.confidence,
            reason: !allowedValue
                ? 'AI proposal is outside the allowed values.'
                : 'AI confidence is below the configured threshold or invalid.',
            explanation: proposal.explanation,
          ),
        );
      }
    }

    return List.unmodifiable(results);
  }
}
