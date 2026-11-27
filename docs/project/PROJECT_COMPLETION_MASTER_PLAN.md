# Phakphum Calendar — Project Completion Master Plan

**Audit date:** 2026-11-27 (UTC)  
**Repository:** https://github.com/phakphum12345/phakphum-calendar  
**Default branch:** `main`  
**Audited main baseline:** `68ef85361c2d08e2970160a36475592010d908f7`  
**Status:** INCOMPLETE — active engineering and external acceptance required

## 1. Mission and operating rules

Complete the existing application by reconciling the current implementation, tests, documentation and open pull requests. Reuse existing domain services and persistence boundaries. Do not create parallel systems merely to satisfy a checklist.

No PR is approved for merge by this audit. All listed PRs were Draft at the time of inspection. A green workflow is not equivalent to independent review, product acceptance, operational acceptance or deployment.

Safety rules:
- Preserve existing schedules, employee records, transaction history, user overrides and local data.
- No destructive database reset, force push, unreviewed schema rewrite or production Calendar mutation.
- No retry against a newly read revision after a CAS conflict.
- Never infer an employee, shift, employment classification or date when evidence is ambiguous.
- Skipped, cancelled, missing, pending and unknown checks are not PASS.
- Validate every change against its exact head SHA and verify main after any authorized merge.

## 2. Repository baseline

| Item | Observed value |
|---|---|
| Repository | `phakphum12345/phakphum-calendar` |
| Visibility | Public |
| Archived | No |
| Default branch | `main` |
| Main SHA | `68ef85361c2d08e2970160a36475592010d908f7` |
| Connected account permissions | admin, maintain, push, pull |
| Local working tree | UNKNOWN — no local checkout was inspected |
| Branch protection / rulesets | UNKNOWN — not exposed by the repository connector audit |
| Open PRs in active completion scope | 11 |
| Deployment SHA / runtime | UNKNOWN — not verified by this audit |

The main SHA above is the latest commit returned by the repository commit listing and was also confirmed as the base SHA of main-targeting PRs during this audit. Refresh it before each subsequent delivery decision.

## 3. Live pull-request inventory

See [PR Dependency Map](PR_DEPENDENCY_MAP.md) and [Work Package Status](WORK_PACKAGE_STATUS.md) for details.

| PR | Head SHA at audit | Base | Exact-head CI observation | Disposition |
|---|---|---|---|---|
| #192 Grid import + persistence | `87181d550917625659e715b46014ae05fdfab3f3` | main | New exact-head matrix queued/in progress after documentation reconciliation; parent `fb670c84...` had 13 successful workflows and a separate failed/cancelled spike job | Draft; wait for new exact-head matrix, reconcile spike and product acceptance |
| #205 reviewer orientation | `1cfceeeabd3af3f36421f9b06bd286966863b70b` | #192 feature branch | 12/12 listed workflows successful | Draft; rebase/reconcile and real workbook review |
| #207 merged vertical headers | `7f6df4380ed60edf436402ca01264eb93dbd416b` | #192 feature branch | 12/12 listed workflows successful | Draft; GitHub reported mergeable=false at inspection; reconcile base |
| #206 Schedule read-back | `997c249394bd02c4fd868f4532829e20df9f58fe` | #192 feature branch | 12/12 listed workflows successful | Draft; reconcile base and review writer coverage |
| #208 employee aliases | `b98a4e7f7911abe7b97d661bf62c121b1e66d716` after audit fix commit | #192 feature branch | New-head workflows were queued/in progress; prior head failed Cross-platform Runtime, Auto Detect, PR Gate and Windows tests | Draft; await new exact-head CI |
| #204 Drive history restore | `3fa4b22b74aabaa7d57b391f487d15657f85e2ae` | #192 feature branch | 12/12 listed workflows successful | Draft; reconcile base and test real Drive revision fixture |
| #202 generation approval | `ca6ebd095ef6566fcce00e9bc49e9c820470b80d` | #192 feature branch | 12/12 listed workflows successful | Draft; reconcile base and prove approval workflow |
| #196 Calendar ETag concurrency | `ca0bf5a661c6f6e63d8356a5b198d955635e26c4` | main | 13/13 listed workflows successful, including Laravel Backend CI | Draft; no live provider/backend operational acceptance |
| #191 notification outbox | `cf7eaa22eaf81e04b0b444acfc3aee2a8ca51e5e` | main | 13/13 listed workflows successful, including Laravel Backend CI | Draft; real browser delivery/operations acceptance open |
| #201 Shift Pay rule conflicts | `d3f228dcdaea4f1a3771c271421226ab71ab00b5` | main | 12/12 listed workflows successful | Draft; product/payroll acceptance and #203 dependency |
| #203 monthly statement core | `9ddcca51de57b71c721f60665f3c9f8cf0e7bbcb` | #201 feature branch | 11/11 listed workflows successful | Draft; persistence/API/UI and assignment lifecycle open |

Workflow counts above describe the runs returned for the exact SHA at audit time, not a claim that every workflow is a required branch-protection check. Confirm required-check policy independently before merge.

## 4. Critical path

1. Finish and verify the #208 exact-head test correction; inspect any remaining failures from logs.
2. Review #192 implementation and all Schedule writers; determine whether the isolated SQLite CAS spike is advisory or required and record its disposition.
3. Reconcile #205, #207, #206, #208, #204 and #202 against the current #192 head. Preserve all unique changes and rerun CI after any rebase/update.
4. Integrate Grid parser and persistence only after independent review, no blocking threads, required checks green and product acceptance evidence for real workbooks.
5. Validate #196 server lease/ETag/ledger design, then controlled Google test-calendar behavior and backend deployment prerequisites.
6. Validate #191 outbox and real browser push behavior; do not claim native iOS/Android push.
7. Integrate #201 before #203; complete persisted monthly statements, UI/API, authorization and payroll acceptance.
8. Reconcile all Markdown to the resulting main SHA; complete cross-platform, security, recovery and operational acceptance.
9. Verify post-merge main SHA and deployment SHA, if deployment is performed.

## 5. External acceptance blockers

- Original operational workbooks for X-OPD November 2569, 16 Nov–15 Dec 2569 and US Clinic ภปร.4 were not available in the prior PR execution evidence.
- Real Google test-calendar credentials/account and a controlled calendar are needed for provider insert/update/delete and ambiguous-outcome tests.
- Backend production endpoint, HTTPS/auth configuration, durable database/locking and APP_KEY backup/restore evidence are not established by CI.
- Real browser/device push acceptance is outstanding.
- Contractor-specific employment/payment classification semantics are not defined by the available requirements; do not invent a third classification.
- Deployment/runtime SHA has not been verified.

## 6. Completion evidence

The project is complete only when every row in [Acceptance Matrix](ACCEPTANCE_MATRIX.md) has evidence and the remaining external constraints are either accepted or explicitly recorded as limitations. Keep this plan current after every main merge; do not rewrite historical snapshots as if they were current.
