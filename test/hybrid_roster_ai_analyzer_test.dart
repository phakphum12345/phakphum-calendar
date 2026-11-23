import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/features/roster_ai/application/hybrid_roster_ai_analyzer.dart';
import 'package:phakphum_calendar/features/roster_ai/domain/roster_ai_models.dart';
import 'package:phakphum_calendar/features/roster_ai/domain/roster_ai_provider.dart';

void main() {
  const input = RosterFieldInput(
    fieldName: 'shiftCode',
    rawValue: 'ช?',
    allowedValues: ['ช', 'บ', 'ด'],
    sourceReference: 'Sheet1!B12',
  );

  test('resolved rule bypasses AI provider', () async {
    final provider = _FakeAIProvider();
    final analyzer = HybridRosterAIAnalyzer(
      rules: _FakeRules(RosterRuleDecision.resolved('ช')),
      aiProvider: provider,
    );

    final result = await analyzer.analyze([input]);

    expect(provider.calls, 0);
    expect(result.single.status, RosterFieldStatus.ruleResolved);
    expect(result.single.proposedValue, 'ช');
    expect(result.single.requiresUserConfirmation, isTrue);
  });

  test('ambiguous field alone is sent to AI and remains a proposal', () async {
    final provider = _FakeAIProvider(
      proposal: const RosterAIProposal(
        value: 'บ',
        confidence: 0.92,
        explanation: 'Possible match from allowed shift codes.',
      ),
    );
    final analyzer = HybridRosterAIAnalyzer(
      rules: _FakeRules(
        const RosterRuleDecision.ambiguous(reason: 'Code is unclear'),
      ),
      aiProvider: provider,
    );

    final result = await analyzer.analyze([input]);

    expect(provider.calls, 1);
    expect(provider.lastRequest?.allowedValues, ['ช', 'บ', 'ด']);
    expect(result.single.status, RosterFieldStatus.aiProposed);
    expect(result.single.proposedValue, 'บ');
    expect(result.single.requiresUserConfirmation, isTrue);
  });

  test('AI cannot introduce a value outside the allowlist', () async {
    final analyzer = HybridRosterAIAnalyzer(
      rules: _FakeRules(
        const RosterRuleDecision.ambiguous(reason: 'Unclear code'),
      ),
      aiProvider: _FakeAIProvider(
        proposal: const RosterAIProposal(
          value: 'DELETE_ALL',
          confidence: 0.99,
          explanation: 'Untrusted model output.',
        ),
      ),
    );

    final result = await analyzer.analyze([input]);

    expect(result.single.status, RosterFieldStatus.needsReview);
    expect(result.single.proposedValue, isNull);
  });

  test('low or non-finite confidence remains for review', () async {
    final analyzer = HybridRosterAIAnalyzer(
      rules: _FakeRules(
        const RosterRuleDecision.ambiguous(reason: 'Unclear code'),
      ),
      aiProvider: _FakeAIProvider(
        proposal: const RosterAIProposal(
          value: 'บ',
          confidence: 0.2,
          explanation: 'Low confidence.',
        ),
      ),
    );

    final result = await analyzer.analyze([input]);

    expect(result.single.status, RosterFieldStatus.needsReview);
    expect(result.single.proposedValue, isNull);
  });

  test('without provider ambiguous fields remain reviewable', () async {
    final analyzer = HybridRosterAIAnalyzer(
      rules: _FakeRules(
        const RosterRuleDecision.ambiguous(reason: 'No deterministic match'),
      ),
    );

    final result = await analyzer.analyze([input]);

    expect(result.single.status, RosterFieldStatus.needsReview);
    expect(result.single.proposedValue, isNull);
  });
}

class _FakeRules implements RosterRuleResolver {
  const _FakeRules(this.decision);

  final RosterRuleDecision decision;

  @override
  RosterRuleDecision resolve(RosterFieldInput input) => decision;
}

class _FakeAIProvider implements RosterAIProvider {
  _FakeAIProvider({this.proposal});

  final RosterAIProposal? proposal;
  int calls = 0;
  RosterAIRequest? lastRequest;

  @override
  Future<RosterAIProposal?> propose(RosterAIRequest request) async {
    calls++;
    lastRequest = request;
    return proposal;
  }
}
