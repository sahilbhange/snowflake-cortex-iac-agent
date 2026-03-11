## Summary
Describe the change, motivation, and context.

## Checklist
- [ ] `terraform fmt` ran cleanly
- [ ] `terraform validate` passes
- [ ] `tflint` passes
- [ ] `tfsec` or `checkov` passes
- [ ] If you ran `terraform plan`, you scanned it for ForceNew (`bash scripts/scan-forcenew.sh <plan.out>`) and called out any `# forces replacement`
- [ ] Docs updated (if applicable)

## CI guardrail (optional)
For demo/dev we only validate in CI. This repo can also add a PR guardrail that runs `terraform plan` (with Snowflake auth) and fails if `scripts/scan-forcenew.sh` detects `# forces replacement`.

## Related Issues
Fixes #
