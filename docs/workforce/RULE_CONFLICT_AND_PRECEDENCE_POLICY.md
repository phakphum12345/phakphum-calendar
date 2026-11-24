# Rule conflict and precedence policy

Resolve by selected source, effective interval, active state, employment type, day category, shift type, assignment purpose, location, department and work point. Apply a documented specificity order.

Equal-ranked overlapping rules are a configuration conflict. Never choose arbitrarily based on list/creation order. Return a typed ambiguous-rule result with candidate IDs and diagnostics; do not calculate until resolved.

Hybrid selects one source using organization-first, personal-first or require-selection. Fallback must follow configured policy. Never combine both sources silently.

Tests cover equal specificity, duplicate rules, differing amounts, disjoint periods, wildcard/specific overlap, inactive rules, fallback and require-selection.