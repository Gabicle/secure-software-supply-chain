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

---

## AWS-0039 — EKS cluster secret encryption

**Severity:** HIGH
**Status:** ACCEPTED — scanner rule not applicable to pinned EKS version

### Finding

Trivy reports that the EKS cluster does not define an
`encryption_config` block for Kubernetes Secrets.

### Risk

Kubernetes Secrets and other Kubernetes API data can contain sensitive
information and must be encrypted at rest.

### Investigation

The EKS Kubernetes version was made explicit and pinned to version 1.36.

AWS EKS automatically enables envelope encryption for Kubernetes API data,
including Secrets, on EKS clusters running Kubernetes 1.28 or later.

Therefore, the absence of a Terraform `encryption_config` block does not
mean that Secrets are unencrypted for this EKS 1.36 cluster.

Trivy's AWS-0039 rule statically checks for the Terraform
`encryption_config` configuration and continues to report the finding.

### Decision

**ACCEPT**

Do not introduce a customer-managed KMS key solely to satisfy the scanner.

The cluster uses the encryption provided automatically by EKS 1.36.

Using a customer-managed KMS key remains an architectural option if
customer-controlled key policies and lifecycle management become a
requirement.

### Remediation / Hardening

The EKS Kubernetes version is now explicitly configured and pinned to 1.36
instead of relying on an implicit service default.

This makes the encryption assumption explicit and reviewable.

### Verification

Terraform validation succeeded.

Trivy was rerun after pinning EKS 1.36.

AWS-0039 remains because the scanner expects an explicit
`encryption_config` block.

The finding is intentionally accepted based on the encryption behavior of
EKS 1.36.

Evidence: `trivy/v5-after-aws-0039-review.txt`

---

## AWS-0040 / AWS-0041 — Public EKS API endpoint exposure

**Severity:** CRITICAL
**Status:** REMEDIATED

### Finding

Trivy reported two related findings:

- AWS-0040: The EKS Kubernetes API endpoint had public access enabled.
- AWS-0041: The public endpoint allowed access from the default
  `0.0.0.0/0` CIDR.

### Risk

A public Kubernetes API endpoint increases the cluster's external attack
surface.

Authentication and authorization are still required to access the cluster,
but an internet-reachable API endpoint can receive connection and
authentication attempts from untrusted networks.

### Decision

**FIX**

The EKS Kubernetes API does not need to be directly reachable from the
public internet for this architecture.

Use the EKS private API endpoint instead.

### Remediation

Changed the EKS VPC configuration to:

`endpoint_private_access = true`

`endpoint_public_access = false`

The Kubernetes API is therefore reachable through the VPC's private
connectivity rather than through the public EKS endpoint.

Disabling the public endpoint also removes the `0.0.0.0/0` public endpoint
exposure reported by AWS-0041.

Administrative access to the private cluster must originate from the VPC
or an appropriately connected network/environment.

### Verification

Terraform validation succeeded.

Trivy was rerun after disabling public endpoint access.

AWS-0040 and AWS-0041 were no longer reported.

The EKS module now reports only AWS-0039, which was separately reviewed and
accepted based on the encryption behavior of the pinned EKS version.

Evidence: `trivy/v6-after-aws-0040-0041.txt`
