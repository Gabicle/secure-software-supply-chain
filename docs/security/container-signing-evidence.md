# Container Signing Evidence

This document records the implementation and independent verification of
keyless container image signing for the secure software supply chain.

## Control

Container images are built once in CI and scanned before publication.

The exact scanned images are transferred to the publishing job rather than
rebuilt. After publication to Amazon ECR, the digest-qualified images are
signed with Cosign using GitHub Actions OIDC and Sigstore keyless signing.

This prevents a separate, unscanned rebuild from being substituted during
the publishing stage and provides a cryptographic identity for the workflow
that published the artifacts.

## Trusted Signing Identity

The signatures were independently verified against the following certificate
constraints:

- OIDC issuer: `https://token.actions.githubusercontent.com`
- Certificate identity:
  `https://github.com/Gabicle/secure-software-supply-chain/.github/workflows/ci.yml@refs/heads/main`
- GitHub repository: `Gabicle/secure-software-supply-chain`
- Git ref: `refs/heads/main`

The verification does not rely on a wildcard certificate identity.

## Verified Artifacts

### Backend

Image digest:

`sha256:f3c6ac33dc09df37da7f15118b43222fc09206097f84f67e5405fd97a2792e0a`

Repository:

`542489916995.dkr.ecr.eu-west-3.amazonaws.com/secure-software-supply-chain-dev-backend`

### Frontend

Image digest:

`sha256:2f4b17bc424cee6d163eedcf7d45e7477e0c5f7393dd101ded103521eada921f`

Repository:

`542489916995.dkr.ecr.eu-west-3.amazonaws.com/secure-software-supply-chain-dev-frontend`

## Verification Result

Both digest-qualified images successfully passed independent Cosign
verification.

Verification confirmed that:

- the Cosign claims were valid;
- the signatures corresponded to the expected image digests;
- the signing certificates chained to trusted certificate authority
  certificates;
- transparency-log inclusion was verified; and
- the certificates satisfied the expected GitHub Actions OIDC issuer,
  repository, branch, and exact workflow identity constraints.

## Admission-Control Trust Basis

The verified signing identity above is the trust identity intended for the
Kubernetes admission-control policy.

The admission policy must not accept arbitrary Sigstore signatures or use an
unrestricted certificate identity such as `.*`.

The intended trust boundary is images signed through the repository's
`.github/workflows/ci.yml` workflow on `refs/heads/main`.
