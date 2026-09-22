# Trivy Infrastructure Security Findings

This document tracks the investigation and remediation of infrastructure
security findings identified by Trivy.

Baseline scan evidence: `trivy/baseline.txt`

---

## AWS-0089 — Terraform state bucket logging disabled

**Severity:** LOW  
**Status:** OPEN

### Finding

The S3 bucket containing Terraform state does not have S3 server access
logging enabled.

### Risk

Reduced request-level audit visibility for access to the Terraform state
bucket.

### Decision

**FIX**

Enable S3 server access logging using a dedicated secured logging bucket.

### Remediation

Pending.

### Verification

Pending.
