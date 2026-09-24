# Kyverno Admission-Control Evidence

## Objective

Validate that Kubernetes admission policy rejects selected unsafe workload configurations rather than relying only on policy configuration as evidence.

The tested controls are:

```text
require-image-digest
disallow-privileged
require-non-root
```

Test fixtures are maintained under `k8s/security-tests/`.

## Test Environment

The reproducible local validation environment used:

```text
kind:        v0.33.0
Kubernetes:  v1.36.4
Kyverno:     v1.19.1
Namespace:   supply-chain
```

Before testing, the Kyverno controllers were healthy and all three `ValidatingPolicy` resources reported `READY=true`.

The local environment was used after AWS teardown so additional security testing did not require recreating billable EKS infrastructure.

## Policy 1: Disallow Privileged Containers

**Policy:** `k8s/policies/disallow-privileged.yaml`
**Fixture:** `k8s/security-tests/bad-privileged.yaml`

The workload requests:

```yaml
securityContext:
  privileged: true
  runAsNonRoot: true
  runAsUser: 10001
```

The image is digest-qualified so the test isolates privileged-container behavior.

Test:

```bash
kubectl apply -f k8s/security-tests/bad-privileged.yaml
```

Observed result:

```text
Policy disallow-privileged failed:
Privileged containers are not allowed.
```

A subsequent lookup confirmed the rejected Pod was not created.

**Result: PASS: privileged workload rejected.**

## Policy 2: Require Non-Root Execution

**Policy:** `k8s/policies/require-non-root.yaml`
**Fixture:** `k8s/security-tests/bad-root.yaml`

The workload explicitly requests root execution:

```yaml
securityContext:
  privileged: false
  runAsNonRoot: false
  runAsUser: 0
```

Test:

```bash
kubectl apply -f k8s/security-tests/bad-root.yaml
```

Observed result:

```text
Policy require-non-root failed:
Containers must explicitly run as a non-root user.
```

**Result: PASS: root workload rejected.**

## Policy 3: Require Immutable Image Digest

**Policy:** `k8s/policies/require-image-digest.yaml`
**Fixture:** `k8s/security-tests/bad-image-tag.yaml`

The workload uses a mutable image tag while otherwise satisfying the tested non-root and non-privileged requirements.

Test:

```bash
kubectl apply -f k8s/security-tests/bad-image-tag.yaml
```

Kyverno denied the workload because the container image was not pinned by digest. A subsequent lookup confirmed the rejected Pod was not created.

**Result: PASS: mutable/tag-only image rejected.**

## Positive Control

**Fixture:** `k8s/security-tests/good-security.yaml`

The positive control uses a digest-qualified image, `privileged: false`, `runAsNonRoot: true`, and a non-zero `runAsUser`.

Test:

```bash
kubectl apply -f k8s/security-tests/good-security.yaml
```

Observed result:

```text
pod/good-security created
```

**Result: PASS: policy-compliant workload admitted.**

The test reused a Kyverno controller image as a convenient digest-qualified artifact. The container subsequently entered `CrashLoopBackOff` because the controller image was being executed as an artificial test workload with a different runtime configuration. This occurred after admission and does not change the admission-control result.

## Test Matrix

| Fixture | Digest | Non-root | Non-privileged | Expected | Observed |
| --- | --- | --- | --- | --- | --- |
| `bad-image-tag.yaml` | No | Yes | Yes | Deny | Denied |
| `bad-root.yaml` | Yes | No | Yes | Deny | Denied |
| `bad-privileged.yaml` | Yes | Yes | No | Deny | Denied |
| `good-security.yaml` | Yes | Yes | Yes | Allow | Admitted |

The fixtures intentionally violate one primary admission property at a time so denials are attributable to the control being tested.

## Live EKS Evidence

Before AWS teardown, the live EKS environment ran `require-image-digest`. The policy reported ready and rejected a tag-only workload.

```text
Digest enforcement
  Live EKS: demonstrated
  Local:    demonstrated

Privileged rejection
  Live EKS: not claimed
  Local:    demonstrated

Non-root rejection
  Live EKS: not claimed
  Local:    demonstrated
```

The privileged and non-root policies were reproduced locally after teardown instead of recreating EKS solely for additional portfolio evidence.

## Application Workload Security Context

The API workload includes:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 10001
  capabilities:
    drop:
      - ALL
```

The frontend uses the same security pattern with `runAsUser: 101`.

Admission policy and workload security context provide separate layers:

```text
Kyverno
   |
   | Can this workload enter the cluster?
   v
securityContext
   |
   | How constrained is the admitted process?
   v
runtime
```

## Signature Verification Boundary

The project implements Cosign keyless image signing. Independent verification confirmed signatures against the intended GitHub Actions signing identity.

This admission evidence does **not** claim that Kyverno verified those signatures.

```text
digest-qualified image enforcement     YES
privileged-container rejection          YES
explicit non-root enforcement           YES
cluster-side Cosign verification        NO
```

Cluster-side verification against private Amazon ECR would require additional registry authentication/IAM integration for the admission controller and is recorded as a deferred control.

## Reproduction

With the local Kyverno environment running:

```bash
kubectl apply -f k8s/security-tests/bad-privileged.yaml
kubectl apply -f k8s/security-tests/bad-root.yaml
kubectl apply -f k8s/security-tests/bad-image-tag.yaml
kubectl apply -f k8s/security-tests/good-security.yaml
```

Expected behavior:

```text
bad-privileged   -> DENIED
bad-root         -> DENIED
bad-image-tag    -> DENIED
good-security    -> ADMITTED
```

These tests provide reproducible negative and positive admission evidence for the controls referenced by the project threat model.
