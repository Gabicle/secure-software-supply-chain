# EKS Platform Access Evidence

## Scope

Environment: `dev`

Cluster:

`secure-software-supply-chain-dev`

Region:

`eu-west-3`

## Access Model

Human administrative access uses AWS IAM Identity Center with MFA.

The AWS Identity Center Administrator role is not registered directly as the
EKS cluster administrator.

Instead, the human administrator assumes:

`arn:aws:iam::542489916995:role/SecureSupplyChainEksPlatformAdminRole`

The role has a maximum session duration of one hour and uses the custom
permissions boundary:

`arn:aws:iam::542489916995:policy/SecureSupplyChainEksPlatformAdminRoleBoundary`

The boundary intentionally provides no useful general AWS service permissions.
Kubernetes authorization is granted separately through the EKS access-entry
mechanism.

## EKS Authorization

The dedicated platform role is registered using an EKS `STANDARD` access entry.

It is associated with:

`arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy`

Access scope:

`cluster`

Cluster-wide Kubernetes administration is intentionally reserved for the
dedicated human platform-administration role because platform bootstrap and
management require cluster-scoped operations, including installation and
management of components such as Argo CD and Kyverno.

Application and automation identities must not inherit this human
cluster-administrator access by default.

## Verification

The EKS API independently confirmed that the access entry principal is:

`arn:aws:iam::542489916995:role/SecureSupplyChainEksPlatformAdminRole`

The associated access policy was confirmed as
`AmazonEKSClusterAdminPolicy` with cluster scope.

The Identity Center administrator successfully assumed the dedicated platform
role.

Using that role for EKS authentication, `kubectl get nodes -o wide` succeeded.

Two EKS worker nodes reported `Ready`. Both use private RFC1918 addresses and
reported no external IP address.

A final Terraform plan reported no changes after deployment.
