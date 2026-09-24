# Threat Model: Secure Software Supply Chain

## 1. Scope

This threat model covers the path from a developer source-code change to an application running on Amazon EKS and communicating with PostgreSQL on Amazon RDS.

The primary security objective is:

> Code reaching the Kubernetes runtime should be traceable to the expected source and CI workflow, pass defined security gates, be deployed by immutable artifact identity, and execute with constrained privileges.

This is a development/portfolio environment rather than a production reference architecture.

## 2. Methodology

Threats are categorized using STRIDE.

| Category | Security property |
| --- | --- |
| Spoofing | Authenticity |
| Tampering | Integrity |
| Repudiation | Accountability |
| Information Disclosure | Confidentiality |
| Denial of Service | Availability |
| Elevation of Privilege | Authorization |

Each threat is tied to an asset, trust boundary, attack scenario, implemented mitigation, validation/evidence, and residual risk.

## 3. Security-Critical Assets

| Asset | Security concern |
| --- | --- |
| Source code | Unauthorized or malicious modification |
| CI workflow | Pipeline bypass or malicious build behavior |
| Container image | Artifact tampering or substitution |
| Image digest | Integrity of deployed artifact identity |
| SBOM | Integrity and availability of composition evidence |
| Cosign identity | Authenticity of artifact signer |
| GitHub OIDC identity | Authentication to AWS |
| AWS IAM roles | Cloud authorization |
| Terraform execution role | Infrastructure-level privilege |
| Terraform state | Infrastructure metadata and integrity |
| GitOps manifests | Desired deployment state |
| EKS control plane | Cluster administration |
| Kyverno policies | Admission security boundary |
| Kubernetes workloads | Runtime execution |
| Database credential | RDS authentication |
| Application data | Confidentiality and integrity |

## 4. Trust Boundaries and Data Flow

The threat model treats security boundaries as changes in identity, administrative control, artifact ownership, or network reachability.

### TB-1: Developer to GitHub

A source-code change crosses from the developer environment into the repository and CI system.

Primary risks include compromised developer identity, malicious source modification, and accidental secret disclosure.

Primary controls include repository history, Gitleaks, Semgrep, dependency scanning, and CI security gates.

### TB-2: GitHub Actions to AWS

The CI system crosses into the AWS account when it publishes container artifacts.

The primary risks are CI impersonation, theft of cloud credentials, and excessive cloud permissions.

GitHub Actions uses OIDC to obtain temporary credentials for a dedicated AWS role rather than relying on stored long-lived AWS access keys. The role is scoped to the required ECR publishing path.

### TB-3: CI Artifact to Amazon ECR

A built and scanned container becomes a published registry artifact.

The primary integrity risk is artifact substitution: scanning one image and publishing a different image.

The pipeline reduces this risk by exporting the exact scanned images from the build job, transferring them as CI artifacts, loading them in the publishing job, and then pushing those images to ECR without intentionally rebuilding them.

After publication, immutable registry digests identify the resulting artifacts.

### TB-4: Git Desired State to Kubernetes

Argo CD reads the GitOps development overlay and reconciles that desired state into the EKS cluster.

The main risks are unauthorized desired-state changes, mutable image references, and unsafe workload configuration.

The demonstrated controls include digest-qualified image references and Kyverno admission policies for digest pinning, privileged containers, and non-root execution.

### TB-5: Kubernetes Admission to Runtime

A deployment request becomes an executing workload only after admission.

This boundary is used to prevent selected unsafe workload properties before Pod creation.

Kyverno was demonstrated rejecting tag-only images, privileged containers, and containers explicitly configured to run as root. A compliant positive-control workload was admitted.

### TB-6: Application to RDS

The application crosses from the Kubernetes workload environment to the private PostgreSQL data store.

The primary risks are unauthorized database access, credential disclosure, and compromise of data through a compromised application.

RDS was deployed privately with network controls and encryption. The RDS master credential was managed by AWS Secrets Manager. Application compromise remains an important residual path because the application legitimately requires database access.

## 5. STRIDE Threat Register

### T-01: Unauthorized AWS CI Identity

**STRIDE:** Spoofing
**Asset:** AWS CI role
**Boundary:** GitHub Actions -> AWS

**Scenario:** An attacker attempts to impersonate CI to obtain AWS permissions used for container publication.

**Controls:** GitHub Actions OIDC, temporary AWS credentials, dedicated CI role, scoped ECR permissions.

**Residual risk:** Compromise of the trusted GitHub workflow/repository identity remains a higher-level attack path.

### T-02: Secret Committed to Source

**STRIDE:** Information Disclosure
**Asset:** Credentials and secrets
**Boundary:** Developer -> repository

**Scenario:** A developer commits an API key, password, token, or cloud credential.

**Control:** Gitleaks executes as a dedicated CI secret-scanning job.

**Residual risk:** Pattern-based detection cannot guarantee identification of every sensitive value.

### T-03: Vulnerable Dependency Enters Build

**STRIDE:** Tampering / Elevation of Privilege
**Asset:** Application artifact

**Controls:** Trivy filesystem/dependency scanning and hash-locked dependencies.

**Residual risk:** Unknown vulnerabilities and vulnerabilities outside configured scanner policy remain possible.

### T-04: Vulnerable Container Image Published

**STRIDE:** Tampering / Elevation of Privilege
**Asset:** Container image

**Control:** Trivy scans built backend and frontend images before publication.

**Residual risk:** Vulnerability intelligence cannot identify every exploitable condition.

### T-05: Artifact Substitution After Scanning

**STRIDE:** Tampering
**Asset:** Container image
**Boundary:** CI build job -> publication job

**Scenario:** Image A passes scanning, but image B is rebuilt or substituted before publication.

**Controls:**

```text
build exact image
      |
      v
scan exact image
      |
      v
export scanned image
      |
      v
CI artifact transfer
      |
      v
load same image
      |
      v
publish
```

The publishing job does not intentionally rebuild the application image.

**Evidence:** `.github/workflows/ci.yml` and `docs/security/container-signing-evidence.md`.

**Residual risk:** A compromise of the trusted CI workflow or runner could attack the pipeline at a higher level.

### T-06: Artifact Composition Is Unknown

**STRIDE:** Repudiation / Information Disclosure
**Asset:** Software composition evidence

**Control:** Syft generates CycloneDX JSON SBOMs for backend and frontend images and uploads them as CI artifacts.

### T-07: Published Artifact Identity Is Ambiguous

**STRIDE:** Tampering
**Asset:** Published image
**Boundary:** ECR -> deployment

**Scenario:** A mutable tag is updated after approval.

**Controls:** ECR digest resolution, digest-qualified GitOps manifests, and Kyverno `require-image-digest`.

**Validation:** A tag-only workload was rejected.

**Residual risk:** Digest pinning proves artifact identity, not artifact safety.

### T-08: Unexpected Identity Signs an Image

**STRIDE:** Spoofing / Tampering
**Asset:** Container signature

**Controls:** Cosign keyless signing, GitHub Actions OIDC/Sigstore identity, independent verification against the expected workflow identity.

**Evidence:** `docs/security/container-signing-evidence.md`.

**Residual risk:** The cluster did not perform Cosign signature verification during admission.

### T-09: Privileged Kubernetes Workload

**STRIDE:** Elevation of Privilege
**Asset:** Kubernetes node/runtime
**Boundary:** Deployment request -> admission

**Scenario:** A workload requests `privileged: true`.

**Control:** Kyverno `disallow-privileged`.

**Validation:** The privileged negative test was denied during admission.

### T-10: Container Executes as Root

**STRIDE:** Elevation of Privilege
**Asset:** Application runtime

**Controls:** Kyverno explicit non-root policy and non-zero application UIDs.

**Validation:** The root-container negative test was denied.

### T-11: Runtime Privilege Escalation

**STRIDE:** Elevation of Privilege
**Asset:** Application runtime

**Controls:**

```yaml
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
capabilities:
  drop:
    - ALL
```

**Residual risk:** These controls reduce runtime capability but do not make application compromise harmless.

### T-12: Excessive Terraform Privilege

**STRIDE:** Elevation of Privilege
**Asset:** AWS account

**Controls:** Dedicated Terraform execution role, custom execution policies, permissions boundaries, constrained role management and `iam:PassRole`, and specific lifecycle permissions.

**Security decision:** Missing permissions were fixed by identifying required AWS operations rather than granting general administrator access.

### T-13: Excessive Human Kubernetes Administration Path

**STRIDE:** Elevation of Privilege / Spoofing
**Asset:** EKS control plane

**Controls:**

```text
IAM Identity Center + MFA
        |
        v
Dedicated EKS Platform Admin Role
        |
        v
EKS Access Entry
        |
        v
Kubernetes administration
```

**Evidence:** `docs/security/eks-platform-access-evidence.md`.

### T-14: Public Kubernetes API Exposure

**STRIDE:** Spoofing / Denial of Service / Elevation of Privilege
**Asset:** EKS API server

**Control:** Private EKS API endpoint.

### T-15: Direct Database Exposure

**STRIDE:** Information Disclosure / Tampering
**Asset:** Application data

**Controls:** Private RDS networking, security-group controls, encrypted storage, and application-mediated database access.

**Residual risk:** Application compromise can provide an indirect path to data available to the application's database identity.

### T-16: Database Credential Exposure

**STRIDE:** Information Disclosure / Spoofing
**Asset:** RDS credential

**Controls:** RDS master credential managed by AWS Secrets Manager; secrets not committed to Git.

**Residual risk:** External Secrets Operator integration was not completed. The live application used a Kubernetes Secret created operationally and not stored in the repository.

### T-17: Infrastructure State Disclosure or Tampering

**STRIDE:** Information Disclosure / Tampering
**Asset:** Terraform state

**Controls:** S3 public-access blocking, versioning, KMS encryption, access logging, and native Terraform state locking.

### T-18: Accidental Destructive Database Operation

**STRIDE:** Denial of Service
**Asset:** Database availability

**Control:** RDS deletion protection during normal operation. It was deliberately disabled only for controlled final teardown.

## 6. Attack Paths

### A: Compromise the Software Supply Chain

```text
Compromise source/workflow
        |
        v
introduce malicious code
        |
        v
attempt to pass CI gates
        |
        v
produce malicious artifact
        |
        v
publish artifact
        |
        v
change GitOps desired state
        |
        v
reach Kubernetes
```

Controls include Gitleaks, Semgrep, Trivy, build-once artifact handling, SBOM generation, digest identity, Cosign signing, GitOps, and Kyverno.

### B: Replace a Validated Artifact

```text
valid image
    |
    v
security scan
    |
    X  substitution attempt
    |
    v
publication
```

The pipeline transfers the exact scanned images to the publishing job. Deployment state then uses immutable digest references.

### C: Gain Runtime Privilege

```text
malicious deployment
      |
      +--> privileged: true --------X
      |
      +--> UID 0 -------------------X
      |
      +--> mutable image tag -------X
      |
      v
 compliant workload
```

All three rejection paths have reproducible test fixtures.

### D: Reach the Database

```text
Internet
   |
   X
Private RDS

Compromised application
   |
   v
Application DB access
   |
   v
RDS
```

Private networking prevents a direct public database path. Application compromise remains an important residual path.

## 7. Mitigation Validation

The project distinguishes:

```text
configured control != demonstrated control
```

| Control | Validation |
| --- | --- |
| Gitleaks | CI secret-scanning job |
| Trivy | CI scanner execution and remediation evidence |
| Build-once artifact flow | Workflow exports and reloads exact scanned images |
| SBOM | CycloneDX artifacts generated by Syft |
| GitHub OIDC | AWS credential configuration uses federated role |
| Cosign | Independent signature verification |
| Digest pinning | Final GitOps overlay contains SHA-256 digests |
| Argo CD | Live application observed Synced/Healthy |
| Kyverno digest policy | Tag-only workload rejected |
| Kyverno privileged policy | Privileged workload rejected |
| Kyverno non-root policy | UID 0 workload rejected |
| Positive admission | Compliant workload admitted |
| Application path | Record written/read through frontend -> API -> RDS |
| EKS human access | Dedicated platform role successfully used |
| Terraform security | Scanner findings and IAM changes documented |

## 8. Residual Risk

- **R-01: No cluster-side signature verification:** Cosign signing and independent verification were implemented, but Kyverno did not verify signatures against private ECR during admission. Deferred.
- **R-02: External Secrets integration incomplete:** Secrets Manager and IAM groundwork exist, but ESO integration was not completed. Deferred.
- **R-03: Runtime detection outside scope:** No completed Falco/SIEM/runtime-detection stack.
- **R-04: Development availability tradeoff:** RDS was Single-AZ. Accepted development-environment risk.
- **R-05: Scanner coverage is not proof of safety:** scanners cannot prove absence of unknown vulnerabilities or business-logic flaws.
- **R-06: Trusted CI compromise:** sufficiently privileged compromise of the trusted CI workflow or execution environment remains a supply-chain risk.

## 9. Security Assumptions

This model assumes GitHub provides the expected repository and Actions identity mechanisms, AWS correctly enforces IAM/OIDC authorization, cryptographic digest/signing primitives operate as intended, Kubernetes admission executes before workload creation, security tooling itself has not been maliciously compromised, and administrative identities are protected outside the repository.

## 10. Environment Lifecycle

The AWS environment was intentionally temporary. After security and end-to-end evidence was captured, billable runtime resources were destroyed.

The threat model describes the demonstrated architecture and its reproducible Terraform/GitOps configuration rather than claiming that a live public environment remains available.

## 11. Supporting Evidence

```text
docs/security/container-signing-evidence.md
docs/security/eks-platform-access-evidence.md
docs/security/kyverno-admission-evidence.md
docs/security/security-findings.md
```
