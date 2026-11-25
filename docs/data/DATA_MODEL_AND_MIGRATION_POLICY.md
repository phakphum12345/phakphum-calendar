# Data model and migration policy

For every persistent entity document owner, tenant scope, sensitivity, retention, source of truth and deletion behavior.

Migrations should be additive/reversible where practical, preserve user data/history, test supported prior schemas and avoid silently resetting preferences or rewriting customized templates. Personal data must not depend on organization membership.

Issued pay statements and calculation snapshots are immutable evidence. Corrections create explicit adjustment records. Document backup, restore, export and data-loss limitations.