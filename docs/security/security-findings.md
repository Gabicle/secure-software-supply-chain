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

---

## AWS-0077 — RDS backup retention period too low

**Severity:** MEDIUM
**Status:** REMEDIATED

### Finding

Trivy reported that the RDS PostgreSQL instance had a very low automated
backup retention period.

The dev environment configured the retention period to 1 day.

### Risk

A one-day recovery window may be insufficient if data corruption,
accidental deletion, or malicious activity is not detected immediately.

The available clean backup could expire before the incident is identified.

### Decision

**FIX**

Increase automated backup retention while keeping the configuration
reasonable for a development environment.

### Remediation

Changed the RDS automated backup retention period from 1 day to 7 days.

This provides a larger recovery window without adopting the longer
retention period that might be appropriate for a production environment.

### Verification

Terraform validation succeeded.

Trivy was rerun after increasing the backup retention period.

AWS-0077 was no longer reported.

Evidence: `trivy/v7-after-aws-0077.txt`

---

## AWS-0133 / AWS-0078 — RDS Database Insights monitoring and encryption

**Severity:** LOW
**Status:** REMEDIATED

### Finding

Trivy initially reported AWS-0133 because RDS Performance Insights was
disabled.

After enabling Performance Insights, Trivy identified AWS-0078 because
the Performance Insights data would use an AWS-managed KMS key rather
than a customer-managed key.

### Risk

Without database performance telemetry, visibility during performance
issues and security investigations is reduced.

Database performance telemetry may also contain sensitive operational
information. Using a customer-managed KMS key provides additional control
over encryption key policies and lifecycle.

### Decision

**FIX**

Enable database performance telemetry and protect its data using a
dedicated customer-managed KMS key.

### Remediation

Enabled RDS Performance Insights with a 7-day retention period.

Created a dedicated customer-managed KMS key for RDS Database Insights
data.

Automatic KMS key rotation was enabled.

Configured RDS Performance Insights to use the customer-managed KMS key.

The key is separate from the Terraform state encryption key so the two
security domains have independent key lifecycles and access controls.

### Verification

Terraform validation succeeded.

Trivy was rerun after enabling Performance Insights and initially
identified AWS-0078.

After configuring the dedicated customer-managed KMS key, Trivy was
rerun again.

AWS-0133 and AWS-0078 were no longer reported, and no new finding was
introduced.

Evidence: `trivy/v8-after-aws-0133-0078.txt`

---

## AWS-0176 — RDS IAM database authentication disabled

**Severity:** MEDIUM
**Status:** REMEDIATED

### Finding

Trivy reported that the RDS PostgreSQL instance did not have IAM database
authentication enabled.

### Risk

Without IAM database authentication, database access relies on traditional
database credentials. IAM authentication provides an additional authentication
mechanism using short-lived AWS authentication tokens and IAM permissions.

### Decision

**FIX**

Enable IAM database authentication support for the RDS PostgreSQL instance.

### Remediation

Enabled IAM database authentication on the RDS instance:

`iam_database_authentication_enabled = true`

This enables the capability without automatically converting existing
PostgreSQL users to IAM authentication.

### Verification

Terraform validation succeeded.

Trivy was rerun after the change.

AWS-0176 was no longer reported, and no new finding was introduced.

Evidence: `trivy/v9-after-aws-0176.txt`

---

## AWS-0177 — RDS deletion protection disabled

**Severity:** MEDIUM
**Status:** REMEDIATED

### Finding

Trivy reported that the RDS PostgreSQL instance did not have deletion
protection enabled.

### Risk

Without deletion protection, the database instance can be deleted directly,
increasing the risk of accidental or unauthorized database removal.

### Decision

**FIX**

Enable deletion protection for the dev RDS instance.

Although this environment is designed to be temporary, requiring deletion
protection to be explicitly disabled before destruction adds a deliberate
safety step.

### Remediation

Changed the dev environment configuration to:

`deletion_protection = true`

The RDS module was already parameterized to apply this setting.

### Verification

Terraform validation succeeded.

Trivy was rerun after the change.

AWS-0177 was no longer reported, and no new finding was introduced.

Evidence: `trivy/v10-after-aws-0177.txt`

---

## AWS-0164 — Public subnet automatically assigns public IP addresses

**Severity:** HIGH
**Status:** REMEDIATED

### Finding

Trivy reported that resources launched into the public subnets were configured
to automatically receive public IPv4 addresses.

### Risk

Automatically assigning public IP addresses can unintentionally increase the
internet-facing attack surface of resources launched into these subnets.

A public subnet does not require every resource within it to have a public IP
address.

### Decision

**FIX**

Disable automatic public IPv4 assignment while preserving the public subnet
routing required by internet-facing infrastructure.

### Remediation

Changed the public subnet configuration to:

`map_public_ip_on_launch = false`

The public subnets retain their route to the Internet Gateway. The NAT Gateway
continues to use its explicitly allocated Elastic IP.

### Verification

Terraform validation succeeded.

Trivy was rerun after the change.

AWS-0164 was no longer reported, and no new finding was introduced.

Evidence: `trivy/v11-after-aws-0164.txt`

---

## AWS-0178 / AWS-0017 — VPC Flow Logs and log encryption

**Severity:** MEDIUM / LOW
**Status:** REMEDIATED

### Finding

Trivy reported AWS-0178 because VPC Flow Logs were not enabled.

After enabling VPC Flow Logs with CloudWatch Logs as the destination,
Trivy reported AWS-0017 because the CloudWatch log group used default
encryption rather than a customer-managed KMS key.

### Risk

Without VPC Flow Logs, network traffic metadata is unavailable for
investigation of accepted and rejected connections, unexpected traffic
patterns, and other network security events.

Using a customer-managed KMS key for security telemetry provides additional
control over encryption key policy, rotation, and lifecycle.

### Decision

**FIX**

Enable VPC Flow Logs for accepted and rejected traffic and send the logs to
CloudWatch Logs.

Protect the CloudWatch log group with a dedicated customer-managed KMS key.

### Remediation

Enabled VPC Flow Logs with `traffic_type = "ALL"`.

Created a CloudWatch log group with 30-day retention.

Created a dedicated IAM role allowing the VPC Flow Logs service to publish
to the specific CloudWatch log group.

Restricted the role trust relationship using the AWS account and Flow Log
source ARN.

Created a dedicated customer-managed KMS key with automatic rotation and
restricted CloudWatch Logs access using the log group's encryption context.

Configured the CloudWatch log group to use the customer-managed KMS key.

### Verification

Terraform validation succeeded.

Trivy was rerun after enabling VPC Flow Logs and identified AWS-0017.

After configuring customer-managed KMS encryption, Trivy was rerun again.

AWS-0178 and AWS-0017 were no longer reported, and no new finding was
introduced.

The only remaining Trivy finding is AWS-0039, which has already been reviewed
and documented as accepted for the pinned EKS version.

Evidence: `trivy/v12-after-aws-0178-0017.txt`

---

### CKV_AWS_58 — EKS secrets encryption

- **Status:** Accepted / scanner limitation
- **Resource:** `module.eks.aws_eks_cluster.main`
- **Finding:** Checkov reports that the EKS cluster does not explicitly configure secrets encryption.
- **Assessment:** The cluster is pinned to Kubernetes 1.36. Amazon EKS 1.28 and later automatically applies envelope encryption to Kubernetes API data using AWS-managed encryption by default.
- **Decision:** No Terraform change. Adding configuration solely to satisfy the scanner would not address an actual lack of encryption.
- **Related finding:** Trivy `AWS-0039`.

---

### CKV_AWS_339 — EKS supported Kubernetes version

- **Status:** Accepted / scanner limitation
- **Resource:** `module.eks.aws_eks_cluster.main`
- **Finding:** Checkov reports that the configured EKS Kubernetes version is unsupported.
- **Assessment:** The dev environment is pinned to EKS Kubernetes 1.36, which is currently supported by Amazon EKS. The Checkov result does not reflect the current EKS support lifecycle.
- **Decision:** No Terraform change. Continue pinning the Kubernetes version explicitly and validate it against the AWS EKS support lifecycle during upgrades.

---

### CKV_AWS_129 — RDS log exports

- **Status:** Remediated
- **Resource:** `module.rds.aws_db_instance.main`
- **Finding:** RDS engine logs were not configured for export to CloudWatch Logs.
- **Risk:** Without centralized database logs, security investigation, troubleshooting, and operational visibility are reduced.
- **Remediation:** Enabled CloudWatch export of the `postgresql` and `upgrade` logs.
- **Validation:** Checkov changed from 116 passed / 18 failed to 117 passed / 17 failed, and `CKV_AWS_129` now passes.

---

### CKV_AWS_157 — RDS Multi-AZ

- **Status:** Accepted risk — development environment
- **Resource:** `module.rds.aws_db_instance.main`
- **Finding:** Checkov reports that the RDS instance does not have Multi-AZ enabled.
- **Risk:** A Single-AZ database does not provide the cross-AZ standby and automatic failover available with an RDS Multi-AZ deployment, reducing availability during instance or Availability Zone failures.
- **Assessment:** The RDS module supports Multi-AZ through `var.multi_az`, but the `dev` environment deliberately sets `multi_az = false`.
- **Decision:** Accept for the cost-conscious development/demo environment. Production environments should set `multi_az = true`.
- **Terraform change:** None.
- **Validation:** Checkov is correctly detecting the Single-AZ configuration; this finding is an intentional risk acceptance rather than a scanner false positive.

---

### CKV_AWS_118 — RDS Enhanced Monitoring

- **Status:** Remediated
- **Resource:** `module.rds.aws_db_instance.main`
- **Finding:** Checkov reported that RDS Enhanced Monitoring was not enabled.
- **Risk:** Without Enhanced Monitoring, OS-level database host telemetry such as CPU, memory, processes, and I/O is less visible, reducing operational and security observability.
- **Remediation:** Enabled RDS Enhanced Monitoring with a 60-second collection interval and created a dedicated IAM role trusted by the RDS monitoring service. The role uses the AWS-managed `AmazonRDSEnhancedMonitoringRole` policy, and its trust policy is constrained by source account and RDS DB ARN.
- **Validation:** `terraform validate` succeeded. Checkov rescan confirms `CKV_AWS_118` passes and reports no new failed checks for the monitoring IAM role.

---

### CKV_AWS_338 — CloudWatch Log Retention

- **Status:** Accepted risk — development environment
- **Resource:** `module.vpc.aws_cloudwatch_log_group.vpc_flow_logs`
- **Finding:** Checkov requires CloudWatch log groups to retain logs for at least one year. The VPC Flow Logs group is configured for 30 days.
- **Risk:** Security investigations occurring more than 30 days after an event will not have access to these historical VPC Flow Logs.
- **Assessment:** The log group has explicit retention configured, but the 30-day period does not meet Checkov's one-year policy threshold. This project uses a short-lived, cost-conscious development/demo environment.
- **Decision:** Retain 30 days for `dev`. Production or compliance-sensitive environments should define a longer retention period based on investigation and regulatory requirements.
- **Terraform change:** None.
- **Validation:** Checkov correctly reports `CKV_AWS_338`; this is an intentional development-environment risk acceptance.

---

### CKV_AWS_144 — Terraform State Cross-Region Replication

- **Status:** Accepted risk — development environment
- **Resource:** `aws_s3_bucket.terraform_state`
- **Finding:** Checkov reports that the Terraform state bucket does not have S3 Cross-Region Replication enabled.
- **Risk:** The project does not maintain an automatically replicated Terraform state copy in a second AWS Region, reducing resilience to a Region-level disruption.
- **Existing Controls:** The state bucket uses S3 Versioning, encryption at rest, public-access blocking, and Terraform `prevent_destroy`.
- **Assessment:** Cross-Region Replication would provide additional regional disaster-recovery capability but requires a destination bucket, replication IAM permissions, and additional storage/transfer resources. The current project environment is a short-lived development/demo environment and does not have a multi-region recovery requirement.
- **Decision:** Accept for `dev`. Production environments should evaluate Cross-Region Replication according to defined RPO, RTO, compliance, and regional disaster-recovery requirements.
- **Terraform change:** None.
- **Validation:** Checkov correctly reports `CKV_AWS_144`; this is an intentional development-environment risk acceptance.

---

### CKV_AWS_144 — Terraform State Access-Log Cross-Region Replication

- **Status:** Accepted risk — development environment
- **Resource:** `aws_s3_bucket.logging`
- **Finding:** Checkov reports that the Terraform state access-log bucket does not have S3 Cross-Region Replication enabled.
- **Risk:** Access logs are not automatically replicated to a second AWS Region, reducing their availability during a Region-level disruption.
- **Existing Controls:** The access-log bucket has versioning, encryption at rest, public-access blocking, and Terraform `prevent_destroy`.
- **Assessment:** Cross-Region Replication would provide additional regional resilience but would require a destination bucket, replication IAM permissions, and additional storage/transfer resources. The development environment has no defined multi-region audit or disaster-recovery requirement.
- **Decision:** Accept for `dev`. Production or compliance-sensitive environments should evaluate replication according to log-retention, audit, RPO/RTO, and regional disaster-recovery requirements.
- **Terraform change:** None.
- **Validation:** Checkov correctly reports `CKV_AWS_144`; this is an intentional development-environment risk acceptance.

---

### CKV2_AWS_60 — RDS Copy Tags to Snapshots

- **Status:** Remediated
- **Resource:** `module.rds.aws_db_instance.main`
- **Finding:** Checkov reported that RDS was not configured to copy database instance tags to snapshots.
- **Risk:** Snapshots created without the database's tags can lose ownership, environment, project, and governance metadata, making asset inventory, cost attribution, and operational investigation more difficult.
- **Remediation:** Enabled `copy_tags_to_snapshot = true` on the RDS instance.
- **Validation:** `terraform validate` succeeded. Checkov rescan confirms `CKV2_AWS_60` passes and the failed-check count decreased from 16 to 15.

---

### CKV2_AWS_12 — Default VPC Security Group

- **Status:** Remediated
- **Resource:** `module.vpc.aws_vpc.main`
- **Finding:** Checkov reported that the VPC's default security group was not explicitly configured to restrict all traffic.
- **Risk:** Resources accidentally associated with the default security group could inherit unintended network connectivity instead of using purpose-specific security groups.
- **Remediation:** Added an `aws_default_security_group` resource that manages the VPC's default security group with no ingress or egress rules, implementing a default-deny posture.
- **Validation:** `terraform validate` succeeded. Checkov rescan confirms `CKV2_AWS_12` passes and the failed-check count decreased from 15 to 14.

---

### CKV2_AWS_30 — PostgreSQL Query Logging

- **Status:** Accepted / Compensating Controls
- **Resource:** `module.rds.aws_db_instance.main`
- **Finding:** Checkov recommends enabling PostgreSQL query logging through a custom RDS parameter group.
- **Risk:** Insufficient database query logging can reduce visibility during troubleshooting and security investigations.
- **Security Decision:** Broad PostgreSQL statement logging is not enabled solely to satisfy the scanner. AWS warns that statement logging can expose sensitive information, including credentials and application data, in database logs.
- **Compensating Controls:** PostgreSQL and upgrade logs are exported to CloudWatch, RDS Enhanced Monitoring is enabled, Performance Insights is enabled with KMS encryption, and IAM database authentication is enabled.
- **Future Hardening:** If database-level audit requirements are introduced, evaluate targeted logging such as `log_min_duration_statement` or pgAudit with appropriate log-access controls and sensitive-data protections.
- **Validation:** Finding reviewed against current AWS RDS for PostgreSQL logging guidance. No Terraform change made.

---

### CKV2_AWS_62 — S3 Event Notifications

- **Status:** Accepted / Deferred Detection Control
- **Resources:** Terraform state bucket and S3 access-log bucket
- **Finding:** Checkov recommends enabling S3 event notifications.
- **Risk:** Security-relevant object operations may not generate an immediate alert.
- **Security Decision:** Generic S3 notifications are not enabled solely to satisfy the scanner. Notifications without a defined security consumer or response workflow would add infrastructure and noise without providing a meaningful detection capability.
- **Terraform State Bucket:** Object-level state modification and deletion events are security relevant. A production implementation should evaluate targeted CloudTrail S3 data events and EventBridge rules for state-object operations.
- **Access-Log Bucket:** Object creation is expected high-volume behavior, so alerting on every object creation would create unnecessary noise. Detection should focus on abnormal deletion, policy/configuration changes, or other explicitly defined security events.
- **Compensating Controls:** State bucket versioning, KMS encryption, public-access blocking, access logging, lifecycle management, and `prevent_destroy` are enabled.
- **Future Hardening:** Implement targeted S3 data-event monitoring and alerting with a defined destination and incident-response workflow.
- **Validation:** Reviewed against AWS S3, CloudTrail, and EventBridge event-monitoring capabilities. No Terraform change made.

---

### CKV_AWS_145 — S3 Access-Log Bucket Does Not Use KMS Encryption

- **Status:** Accepted / Service Compatibility
- **Resource:** S3 server access logging destination bucket
- **Finding:** Checkov recommends encrypting the S3 bucket with AWS KMS rather than SSE-S3.
- **Risk:** SSE-S3 provides encryption at rest but does not provide the additional key-level access control, auditing, and lifecycle management available with a customer-managed KMS key.
- **Security Decision:** The access-log destination intentionally uses SSE-S3 (`AES256`). AWS documentation for S3 server access logging states that the destination bucket should use SSE-S3. Changing the bucket to default SSE-KMS solely to satisfy the scanner could interfere with reliable access to delivered server access logs.
- **Compensating Controls:** The logging bucket has S3 Block Public Access enabled, versioning enabled, a restricted bucket policy allowing the S3 logging service to write only to the expected prefix, source-account and source-bucket restrictions, and lifecycle management. The Terraform state bucket itself is separately protected with a customer-managed KMS key.
- **Future Hardening:** Re-evaluate the logging architecture if stronger customer-managed key control is required, using an AWS-supported logging destination and encryption design.
- **Validation:** Reviewed against current AWS S3 server access logging encryption requirements. No Terraform change made.

---

### CKV2_AWS_64 — Terraform State KMS Key Policy

- **Status:** Accepted / Deferred Least-Privilege Hardening
- **Resource:** Terraform state customer-managed KMS key
- **Finding:** Checkov recommends defining an explicit KMS key policy in Terraform.
- **Risk:** Relying on the AWS KMS default key policy makes the key's authorization model less explicit in Infrastructure as Code and delegates access control through IAM.
- **Security Decision:** An explicit default-style key policy was evaluated but not retained. Although it satisfied CKV2_AWS_64, the broad `kms:*` and `Resource = "*"` permissions introduced additional least-privilege findings. Replacing the existing authorization model solely to satisfy the scanner would therefore not represent a security improvement.
- **Compensating Controls:** The Terraform state bucket uses a dedicated customer-managed KMS key with automatic key rotation enabled. The state bucket also has public-access blocking, versioning, access logging, lifecycle protection, and `prevent_destroy`.
- **Future Hardening:** Define separate KMS key-administrator and key-user principals after the final Terraform execution and CI/CD identities are established, then implement and test a least-privilege explicit key policy without risking loss of state access.
- **Validation:** A candidate explicit policy was tested with Checkov and rejected because it introduced broader IAM least-privilege findings. No explicit key policy is retained at this stage.

---

### CKV2_AWS_64 — RDS Performance Insights KMS Key Policy

- **Status:** Accepted / Deferred Least-Privilege Hardening
- **Resource:** RDS Performance Insights customer-managed KMS key
- **Finding:** Checkov recommends defining an explicit KMS key policy in Terraform.
- **Risk:** Without an explicit key policy in Infrastructure as Code, authorization for the KMS key is less visible and relies on the AWS KMS default authorization model together with IAM.
- **Security Decision:** An explicit policy is intentionally deferred until the operational principals that require access to Performance Insights data are finalized. Creating a broad placeholder policy solely to satisfy the scanner would weaken the least-privilege design.
- **Compensating Controls:** Performance Insights is enabled and encrypted using a dedicated customer-managed KMS key with automatic key rotation enabled.
- **Future Hardening:** Define explicit key-administrator and key-user permissions. Restrict Performance Insights key usage to the required principals and RDS service path using conditions such as `kms:ViaService` and appropriate encryption-context restrictions.
- **Validation:** Reviewed against current AWS RDS Performance Insights and AWS KMS authorization guidance. No Terraform change made.

---

### TOOL-SC-001 — Checkov Container Tag and Runtime Version Mismatch

- **Status:** Documented / Supply-Chain Observation
- **Component:** Checkov container image
- **Finding:** The scanner image selected as `bridgecrew/checkov:3.3.10` was pinned and executed by immutable digest, but the Checkov process inside the image reports version `3.3.9`.
- **Risk:** Container tags are mutable metadata and do not by themselves prove which software version is contained in an image. A mismatch between the advertised tag and the embedded tool version can undermine assumptions about scanner capabilities, vulnerability fixes, and policy behavior.
- **Security Decision:** Scanner execution is pinned to the verified image digest for reproducibility. The runtime-reported version is treated as the authoritative version of Checkov actually executed rather than assuming the container tag accurately represents its contents.
- **Evidence:** Checkov scan output records `version: 3.3.9` while the project invocation uses the digest obtained from the `3.3.10` image.
- **Future Hardening:** CI/CD scanner upgrades should verify both the image digest and the scanner's runtime-reported version before adopting a new release. Where available, verify upstream image provenance/signatures or attestations in addition to digest pinning.
- **Validation:** The mismatch was reproduced directly from the pinned container and reviewed against upstream release information.

---

### SEC-IAM-001 — Incorrect permissions boundary required for EKS cluster role

**Status:** Remediated

The Terraform execution-role policy required the EKS cluster role to be created with the node-role permissions boundary rather than the dedicated cluster-role boundary.

**Risk:** The incorrect boundary could prevent deployment or apply an inappropriate maximum-permissions policy to the EKS cluster role.

**Remediation:** Updated `CreateEksClusterRole` to require `SecureSupplyChainEksClusterRoleBoundary`.

---

### SEC-IAM-002 — Terraform execution role could modify or remove EKS permissions boundaries

**Status:** Remediated

The Terraform execution role allowed `iam:PutRolePermissionsBoundary` and `iam:DeleteRolePermissionsBoundary` against the project EKS roles.

**Risk:** A compromised or misused Terraform execution role could weaken the permissions-boundary guardrail after role creation.

**Remediation:** Removed permissions-boundary mutation permissions. EKS roles must be created with their approved boundary, while subsequent boundary changes require a separate privileged administrative operation.

---

### SEC-IAM-003 — Terraform execution policy did not cover newly introduced infrastructure securely

**Status:** Remediated

The execution-role policy predated VPC Flow Logs, its CloudWatch Logs/KMS resources, RDS Enhanced Monitoring, and the Performance Insights KMS key.

**Risk:** Terraform deployments would fail due to missing permissions. Broadly granting IAM, CloudWatch Logs, or KMS administration to solve the problem would unnecessarily increase the Terraform execution role's privilege.

**Remediation:** Added narrowly scoped lifecycle permissions. VPC Flow Logs and RDS monitoring roles are restricted to exact role ARNs, service-specific `iam:PassRole` conditions, and mandatory permissions boundaries. KMS key creation is constrained to symmetric AWS KMS encryption keys; subsequent KMS administration is limited to keys in the project account and region.

**Residual risk:** KMS key ARNs are not known before creation, so `kms:CreateKey` requires `Resource: "*"`. Post-creation KMS lifecycle permissions currently use the account/region `key/*` scope. This bootstrap privilege should remain limited to the dedicated Terraform execution role and can be further isolated if the project later introduces unrelated customer-managed KMS keys.

---

### SEC-IAM-004 — EKS node permissions boundary blocked VPC CNI permissions

**Status:** Remediated / Temporary Bootstrap Design

The EKS managed node role had the AWS-managed `AmazonEKS_CNI_Policy` attached, but the custom node-role permissions boundary did not permit all EC2 actions required by the VPC CNI. Because a permissions boundary limits the maximum permissions available to the role, permissions granted by the AWS-managed policy were ineffective when they were outside the boundary.

**Impact:** EC2 instances launched successfully and kubelet reached the private EKS API, authenticated, registered nodes, and sent heartbeats. However, the `aws-node` VPC CNI entered `CrashLoopBackOff`, causing the managed node group to fail with `NodeCreationFailure: Unhealthy nodes in kubernetes cluster`. CoreDNS health failures were a downstream symptom rather than the root cause.

**Evidence:** EKS audit logs reported `MissingIAMPermissions` for VPC CNI EC2 operations. IAM policy simulation confirmed that the node permissions boundary was the limiting authorization layer.

**Remediation:** Added only the required VPC CNI EC2 actions to the node-role permissions boundary, including network-interface lifecycle operations, private-IP assignment, interface modification, and tagging. The AWS-managed `AmazonEKS_CNI_Policy` remains attached to the node role as a temporary bootstrap mechanism.

**Validation:** IAM simulation confirmed the required CNI actions were allowed by both the role permissions and permissions boundary. Fresh EKS audit logs showed no further `MissingIAMPermissions`, and replacement of the managed node group completed successfully.

**Future Hardening:** Move VPC CNI permissions from the node role to EKS Pod Identity, then remove `AmazonEKS_CNI_Policy` and the CNI-specific permissions from the node-role boundary.

---

### SEC-IAM-005 — RDS Performance Insights required a constrained KMS grant

**Status:** Remediated

RDS creation initially failed because the Terraform execution role could describe the customer-managed Performance Insights KMS key but could not create the AWS-resource grant required for RDS to use it.

**Risk:** Granting broad KMS cryptographic permissions such as unrestricted `kms:Encrypt`, `kms:Decrypt`, or `kms:GenerateDataKey` to the Terraform execution role would exceed the permissions required to provision the service.

**Remediation:** Granted only `kms:CreateGrant` against customer-managed KMS keys in the project account and region, constrained by `kms:ViaService = rds.eu-west-3.amazonaws.com` and `kms:GrantIsForAWSResource = true`.

**Validation:** IAM simulation with the required RDS context confirmed `kms:CreateGrant` was allowed. A negative simulation without the RDS service context remained denied. No broad cryptographic permissions were added to the Terraform execution role.

---

### SEC-IAM-006 — RDS managed master password required scoped Secrets Manager creation

**Status:** Remediated

After resolving KMS authorization, RDS creation exposed a second least-privilege gap: the Terraform execution role could not create or tag the Secrets Manager secret used by the RDS managed master-password feature.

**Risk:** Broad Secrets Manager permissions would allow the Terraform execution role to create or modify unrelated application secrets.

**Remediation:** Added only `secretsmanager:CreateSecret` and `secretsmanager:TagResource`, scoped to the AWS RDS managed-secret naming pattern `arn:aws:secretsmanager:eu-west-3:542489916995:secret:rds!*`. No permission to retrieve secret values was added.

**Validation:** IAM simulation confirmed the two required operations were allowed. Terraform subsequently created the RDS instance successfully, including its AWS-managed master-user secret, and the final Terraform plan reported no changes.
