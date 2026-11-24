# Assignment calculation and monthly statement

Only confirmed assignments are eligible for actual statements. Draft, unreviewed import and forecast remain separate.

Persist assignment identity/scope/date/hours/shift/location, selected source, rule ID/version, formula inputs, rounding, currency, result state, amount, calculation version and timestamp. Reprocessing must not create duplicate payable rows.

Issued snapshots are immutable; corrections create auditable adjustment events. Monthly statements include period, mode, source policy, currency, assignment detail, treatment states, totals and reconciliation to eligible rows.