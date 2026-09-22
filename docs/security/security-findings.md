# Trivy Infrastructure Security Findings

This document tracks the investigation and remediation of infrastructure
security findings identified by Trivy.

Baseline scan evidence: `trivy/v1-baseline.txt`

---

## AWS-0089 — Terraform state bucket logging disabled

**Severity:** LOW  
**Status:** REMEDIATED

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

Created a dedicated S3 bucket for server access logs.

The logging destination bucket:

- Blocks public access.
- Uses SSE-S3 (`AES256`) encryption.
- Allows the Amazon S3 logging service to write objects only under the
  `state-access/` prefix.
- Restricts log delivery to the Terraform state bucket and the current
  AWS account.

Server access logging was then enabled on the Terraform state bucket with
the dedicated logging bucket as its destination.

### Verification

Trivy was rerun after the remediation.

`AWS-0089` was no longer reported.

Evidence: `trivy/v2-after-aws-0089.txt`

The follow-up scan identified a new finding, `AWS-0090`, because the newly
created logging destination bucket does not have versioning enabled. This
finding will be investigated separately.

---

## AWS-0090 — Logging bucket versioning disabled

**Severity:** MEDIUM  
**Status:** REMEDIATED

### Finding

The S3 bucket created to receive Terraform state server access logs did
not have versioning enabled.

This finding was introduced during the remediation of AWS-0089 and was
identified by the subsequent Trivy scan.

### Risk

Without versioning, recovery from accidental deletion or overwriting of
objects in the logging bucket is more limited.

For security logs, this reduces the ability to recover historical log
objects following unintended changes.

### Decision

**FIX**

Enable S3 Versioning on the Terraform state access logging bucket.

### Remediation

Enabled versioning on the dedicated S3 server access logging destination
bucket using `aws_s3_bucket_versioning`.

### Verification

Trivy was rerun after the remediation.

`AWS-0090` was no longer reported, and no new finding was introduced by
this change.

Evidence: `trivy/v3-after-aws-0090.txt`

---

## AWS-0132 — Terraform state bucket not encrypted with a customer-managed KMS key

**Severity:** HIGH  
**Status:** REMEDIATED

### Finding

The Terraform state S3 bucket used SSE-S3 (`AES256`) encryption rather
than a customer-managed AWS KMS key.

### Risk

SSE-S3 provides encryption at rest, but a customer-managed KMS key provides
additional control over key lifecycle, rotation, access policies, and
auditing.

Terraform state can contain sensitive infrastructure information, making
strong control over its encryption key appropriate.

### Decision

**FIX**

Encrypt the Terraform state bucket using SSE-KMS with a dedicated
customer-managed KMS key.

The separate S3 server access logging destination remains encrypted with
SSE-S3 because S3 server access log destination buckets do not support
SSE-KMS.

### Remediation

Created a dedicated customer-managed AWS KMS key for Terraform state
encryption.

Automatic KMS key rotation was enabled.

Changed the Terraform state bucket's default encryption from SSE-S3
(`AES256`) to SSE-KMS (`aws:kms`) using the customer-managed key.

S3 Bucket Keys were also enabled for the state bucket.

### Verification

Terraform configuration validation succeeded.

Trivy was rerun after the remediation.

`AWS-0132` was no longer reported, and the bootstrap configuration reported
zero security findings.

Evidence: `trivy/v4-after-aws-0132.txt`
