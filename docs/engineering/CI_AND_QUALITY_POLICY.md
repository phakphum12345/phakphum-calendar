# CI and quality policy

Use PASS, FAIL, SKIPPED, BLOCKED and UNKNOWN. Only PASS is positive evidence; skipped, missing, queued, cancelled or stale checks are not PASS.

Every CI statement names exact PR head SHA. Refresh after each push/base update. Formatting, unit, integration, platform build, security/privacy, install and deployed E2E are distinct evidence layers.

Do not merge Draft PRs. Inspect diff, deletions, secrets, reviews, unresolved threads, mergeability, base SHA and required checks.