# Change delivery protocol

READ baseline → DEFINE scope → PLAN minimal change → IMPLEMENT on branch → TEST → ANALYZE diff → VERIFY exact SHA → REVIEW → MERGE only when authorized and gates pass.

Never push directly to main. Do not delete unrelated/historical files. Use expected-SHA leases for branch updates. Separate docs, domain logic, migrations, auth, AI and release work where review risks differ. No deployment or external console changes without authorization.

Completion reports list files, exact SHA, checks, skipped checks, reviews, gaps and next dependency.