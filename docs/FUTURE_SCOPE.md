# Future Scope

> **Roadmap only.** None of the items below are implemented yet. This document is for contributors and maintainers tracking planned improvements — not a description of current functionality.

This project is a work in progress. The following improvements are planned to strengthen automation, quality, and developer experience:

## Infrastructure & CI/CD

- **Remote state backend**: Configure S3, GCS, or Azure Blob backend with state locking.
  - *Benefit*: Enables team collaboration — multiple operators can plan/apply without state conflicts. State locking prevents concurrent modifications that corrupt state.

- **GitHub workflows** for continuous integration, automated `terraform plan`, and security checks on pull requests.
  - *Benefit*: Catches misconfigurations before merge. Every PR shows plan diff — reviewers see exactly what will change. Blocks merges that fail policy checks.

- **Atlantis integration**: Pull request automation for Terraform plan/apply with approval workflows.
  - *Benefit*: GitOps workflow — plan runs automatically on PR, apply requires approval comment. Audit trail of who approved what. No local credentials needed for CI.

- **Checkov** policy scanning across Terraform code to catch misconfigurations early.
  - *Benefit*: 1000+ built-in policies for security and compliance. Catches issues like missing encryption, overly permissive grants, public exposure before they reach Snowflake.

- **OPA (Open Policy Agent)**: Policy-as-code for custom guardrails beyond Checkov's built-in rules.
  - *Benefit*: Enforce org-specific rules (e.g., "no warehouse larger than MEDIUM in test", "all roles must have comment"). Rego policies are version-controlled and testable.

- **TFLint (static analysis)** to enforce provider-specific best practices and naming conventions.
  - *Benefit*: Catches deprecated resource names (`snowflake_role` → `snowflake_account_role`), invalid attribute combinations, and naming violations before plan.

- **Makefile** wrapper to standardize common commands (`init`, `plan`, `apply`, linting, formatting).
  - *Benefit*: Single entry point for all operations. `make plan ENV=test STACK=roles` is easier than remembering var-file paths. Onboarding friction drops significantly.

- **Centralized state orchestration** so stack states can be managed from a single entry point.
  - *Benefit*: Run all 10 stacks with one command instead of cd-ing into each directory. Dependency ordering handled automatically. Easier CI integration.

- **Dynamic environment-aware naming** utilities that inject environment suffixes automatically.
  - *Benefit*: Define `ANALYST_ROLE` once, get `ANALYST_ROLE_TEST` in test and `ANALYST_ROLE` in prod automatically. Reduces copy-paste errors across environments.

- **Pre-commit hooks** integrating formatting, linting, and security checks before code reaches CI.
  - *Benefit*: Fail fast — catch issues on developer machine before push. Consistent formatting across team. Reduces CI feedback loop from minutes to seconds.

- **Module test coverage** using Terratest or similar frameworks to validate critical modules.
  - *Benefit*: Confidence in module changes — tests verify resources create/destroy correctly. Catch breaking changes before they hit real environments.

- **Secrets management** guidelines (e.g., Vault or GitHub Actions OIDC) to reduce reliance on local key files.
  - *Benefit*: No more `.p8` files on laptops. Short-lived credentials reduce blast radius of compromise. OIDC eliminates static secrets entirely for CI.

- **Documentation automation** for generating stack usage summaries and drift reports.
  - *Benefit*: Always-current docs — generated from actual state. Drift reports become scheduled artifacts, not ad-hoc requests.

- **Network policy stack**: Add `platform/network_policies/` to manage account-level and per-user IP allow/block lists via `snowflake_network_policy` (secadmin provider). Currently the repo manages network rules (egress) but not network policies (ingress).
  - *Benefit*: Centralized IP-based access control — restrict who can connect to the account. Per-user policies enable tighter controls for service accounts and privileged users. Terraform-managed policies prevent manual UI drift.

- **Security governance enhancements** such as automated least-privilege reviews and ACCOUNTADMIN drift alerting.
  - *Benefit*: Proactive security posture — get alerted when someone manually grants ACCOUNTADMIN. Automated reviews flag over-privileged roles before audit.

- **Privileged credential hardening** with managed secrets, key rotation, and short-lived tokens.
  - *Benefit*: Meets enterprise security requirements. Automated rotation eliminates "key expired" surprises. Audit logs show which secret version was used.

- **SnowSQL escape hatch hardening**: Add retry logic, better error handling, and Snow CLI migration for stacks 6 and 9.
  - *Benefit*: Fewer flaky failures on transient network issues. Better error messages when SnowSQL fails. Snow CLI is actively maintained and has better UX.

- **Multi-account promotion patterns**: Document and automate dev → stage → prod workflows.
  - *Benefit*: Consistent promotion process — same change flows through all environments. Approval gates prevent accidental prod changes. Full audit trail.

## Skill Enhancements

- **coco-iac-agent-grants**: Standalone skill for privilege changes without user/role creation.
  - *Benefit*: Day-2 RBAC changes are common but don't need full user/role workflow. Faster, more focused skill for "add SELECT on X to role Y".

- **coco-iac-agent-teardown**: Controlled environment destruction with safety gates and dependency ordering.
  - *Benefit*: Safe cleanup of test environments. Reverse dependency order prevents orphaned objects. Confirmation prompts prevent accidents.

- **coco-iac-agent-import**: Import existing Snowflake objects into Terraform state.
  - *Benefit*: Adopt brownfield environments — bring manually-created objects under Terraform control without recreating them. Essential for migrations.

- **coco-iac-agent-troubleshoot**: Diagnose common Terraform/provider errors with guided resolution.
  - *Benefit*: Self-service debugging — operators fix state locks, version mismatches, and auth issues without escalation. Reduces support burden.

- **Consolidate agent/skill locations**: Move all to `.cortex/skills/` for consistency.
  - *Benefit*: Simpler mental model — one place for all CoCo customizations. Easier onboarding. Symlink setup becomes trivial.

- **Standardize frontmatter**: Add `model:` field to all skills for consistency.
  - *Benefit*: Explicit model selection per skill. Heavy skills can use opus, simple ones use haiku. Cost optimization without sacrificing quality.

- **Inline script documentation**: Document `stack-plan.sh` and `scan-forcenew.sh` in skills.
  - *Benefit*: Skills become self-contained — no need to read script source to understand behavior. Reduces context-switching during debugging.

- **Role revocation examples**: Add removal/revoke examples to coco-iac-agent-new-role-user.
  - *Benefit*: Complete lifecycle coverage — skill handles offboarding, not just onboarding. Operators don't have to figure out revocation manually.

- **Schemas-only fast path**: Skip roles/warehouses stacks when only adding schemas.
  - *Benefit*: Faster execution for common operation. Adding a schema shouldn't require planning 3 stacks when only 1 changes.

## Skill Quality & Observability

- **Skill testing framework**: Automated validation of skill behavior with mock inputs and expected outputs.
  - *Benefit*: Confidence in skill changes — regression tests catch breaking changes. CI can validate skills before merge. Reduces "it worked yesterday" debugging.

- **Skill versioning**: Pin skill versions to repo releases.
  - *Benefit*: Reproducible behavior — know exactly which skill version ran. Rollback is possible when new version breaks. Changelog shows what changed.

- **Metrics and observability**: Track invocation frequency, success rates, drift frequency, and error patterns.
  - *Benefit*: Data-driven improvement — know which skills are used, which fail often, what errors are common. Prioritize fixes based on impact.

- **Context window optimization**: Measure token usage and optimize reference file loading.
  - *Benefit*: Faster responses, lower cost. Avoid loading 500-line reference files when 50 lines would suffice. Identify bloated skills.

Contributions that help deliver these items—or propose additional enhancements—are welcome.
