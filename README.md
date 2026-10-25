# aws-vpc-peering-intra

Two AWS VPCs in the same region, connected with **VPC peering**, built with **Terraform** and run by **HCP Terraform** using a **VCS-driven (GitOps) workflow**.

- **Frontend VPC:** `10.0.0.0/16`
- **Backend VPC:** `192.168.0.0/16`
- **Region:** `ap-southeast-1` (Singapore)
- **HCP Terraform:** org `nickcloud4t-master`, project `aws-vpc-peering-infra`

Only `private-subnet02 <-> private-subnet02` and `private-subnet03 <-> private-subnet03` can talk across the peering. Everything else is blocked by route tables and security groups.

---

## Architecture

```
            frontend-vpc 10.0.0.0/16                     backend-vpc 192.168.0.0/16
 ┌───────────────────────────────────────┐     ┌───────────────────────────────────────┐
 │ pub-subnet1  bastion/web + NAT GW     │     │ pub-subnet1  bastion/web + NAT GW     │
 │ pub-subnet2 / pub-subnet3             │     │ pub-subnet2 / pub-subnet3             │
 │                                       │     │                                       │
 │ pri-subnet1  private-instance01 ─NAT  │     │ pri-subnet1  private-instance01 ─NAT  │
 │ pri-subnet2  private-instance02 ──────┼─pcx─┼─ private-instance02  pri-subnet2      │
 │ pri-subnet3  private-instance03 ──────┼─pcx─┼─ private-instance03  pri-subnet3      │
 └───────────────────────────────────────┘     └───────────────────────────────────────┘
```

| Subnet | Frontend | Backend |
|---|---|---|
| pub-subnet1 / 2 / 3 | 10.0.1-3.0/24 | 192.168.1-3.0/24 |
| pri-subnet1 (internet via NAT) | 10.0.253.0/24 | 192.168.253.0/24 |
| pri-subnet2 (peered) | 10.0.254.0/24 | 192.168.254.0/24 |
| pri-subnet3 (peered) | 10.0.255.0/24 | 192.168.255.0/24 |

| Route table | Routes |
|---|---|
| public-rtb | local, `0.0.0.0/0 -> IGW` |
| private-rtb-01 | local, `0.0.0.0/0 -> NAT` |
| private-rtb-02 | local, other VPC's pri-subnet2 `-> pcx` |
| private-rtb-03 | local, other VPC's pri-subnet3 `-> pcx` |

| Security group | Inbound | Outbound |
|---|---|---|
| pub-sg01 | SSH, ICMP, HTTP, HTTPS | all |
| pri-sg01 | SSH + ICMP from pub-sg01 | all |
| pri-sg02 | SSH + ICMP from own pri-sg01 and other VPC's pri-sg02 | SSH + ICMP to other VPC's pri-sg02 |
| pri-sg03 | SSH + ICMP from own pri-sg01 and other VPC's pri-sg03 | SSH + ICMP to other VPC's pri-sg03 |

---

## Repository layout

One folder per HCP Terraform workspace. Workspaces share values with `terraform_remote_state`.

```
aws-vpc-peering-intra/
├── fe-network/    frontend VPC, subnets, IGW, NAT, route tables
├── be-network/    backend VPC, subnets, IGW, NAT, route tables + VPC peering + peering routes
├── fe-security/   frontend security groups
├── be-security/   backend security groups + cross-VPC SG rules (both sides)
├── fe-compute/    frontend key pair, bastion/web instance, 3 private instances
├── be-compute/    backend key pair, bastion/web instance, 3 private instances
├── .gitignore
└── README.md
```

| Folder | Workspace | Reads outputs from |
|---|---|---|
| fe-network | fe-network-ws | – |
| be-network | be-network-ws | fe-network-ws |
| fe-security | fe-security-ws | fe-network-ws |
| be-security | be-security-ws | be-network-ws, fe-security-ws |
| fe-compute | fe-compute-ws | fe-network-ws, fe-security-ws |
| be-compute | be-compute-ws | be-network-ws, be-security-ws |

Peering and the cross-VPC rules live on the backend side to avoid a circular dependency: the frontend is built first, then the backend creates the links.

---

## Branching and workflow

`main` is **production**. All 6 workspaces track `main`. Each folder has its own working branch.

```
fe-network  ─┐
be-network  ─┤
fe-security ─┤  push  ──▶  Pull request to main  ──▶  speculative plan (review)
be-security ─┤                    │
fe-compute  ─┤                  merge
be-compute  ─┘                    ▼
                                main  ──▶  HCP Terraform plan + apply (auto)  ──▶  AWS
```

| Event | What HCP Terraform does |
|---|---|
| Push to a working branch | nothing |
| Pull request opened / updated (into `main`) | **speculative plan** for the workspace whose folder changed, shown on the PR |
| PR merged into `main` | **plan + auto-apply** in that workspace |
| A workspace finishes applying | **run triggers** start the downstream workspaces |

Rules:

- `main` is protected: no direct pushes, no force pushes, changes only through a pull request with a passing Terraform check.
- Only edit **your branch's own folder** in that branch.
- Always update your branch from `main` before starting work.

### Make a change

```bash
git checkout fe-security
git pull origin main                 # start from production
# edit files in fe-security/ only
git add fe-security/
git commit -m "fe-security: describe the change"
git push
```

1. On GitHub, open a pull request: **base `main` ← compare `fe-security`**.
2. Wait for `Terraform Cloud/nickcloud4t-master/fe-security-ws` to pass, and read the plan (**Details**).
3. **Merge.** fe-security-ws plans and applies automatically; run triggers update the downstream workspaces.

---

## HCP Terraform setup

**Variable set** `vpc-peering-variables` (scope: entire project):

| Key | Category | Sensitive |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | env | yes |
| `AWS_SECRET_ACCESS_KEY` | env | yes |

**Each workspace** (`fe-network-ws` ... `be-compute-ws`):

| Setting | Value |
|---|---|
| Workflow | Version control (GitHub App), repo `sispaing/aws-vpc-peering-intra` |
| Terraform working directory | the folder name, e.g. `fe-network` |
| VCS branch | `main` |
| Automatic run triggering | only when files change, pattern `<folder>/**/*` |
| Automatic speculative plans | on |
| Auto-apply (VCS runs and run triggers) | on |
| Remote state sharing | share with all workspaces in the organization |

**Run triggers:**

| Workspace | Source workspaces |
|---|---|
| be-network-ws | fe-network-ws |
| fe-security-ws | fe-network-ws |
| be-security-ws | be-network-ws, fe-security-ws |
| fe-compute-ws | fe-network-ws, fe-security-ws |
| be-compute-ws | be-network-ws, be-security-ws |

A new VCS workspace must have **one run started manually** before GitHub events trigger it.

---

## Build and destroy order

**Build:** fe-network → be-network → fe-security → be-security → fe-compute → be-compute

**Destroy** (each workspace: Settings → Destruction and Deletion → Queue destroy plan):
be-compute → fe-compute → be-security → fe-security → be-network → fe-network

---

## Access and testing

Get the SSH keys (stored in HCP Terraform state, never in Git):

```bash
cd fe-compute && terraform init
terraform output -raw fe_instances_private_key > ~/.ssh/fe-sshkey.pem
cd ../be-compute && terraform init
terraform output -raw be_instances_private_key > ~/.ssh/be-sshkey.pem
chmod 400 ~/.ssh/*-sshkey.pem
```

Web page on each bastion:

```bash
curl http://<frontend_public_instance_public_ip>
curl http://<backend_public_instance_public_ip>
```

SSH path (each hop is only allowed from the one before it):

```bash
ssh-add --apple-use-keychain ~/.ssh/fe-sshkey.pem ~/.ssh/be-sshkey.pem
ssh -A ec2-user@<fe-public-ip>        # bastion
ssh -A ubuntu@<fe-private-01-ip>       # 10.0.253.x
ssh -A ubuntu@<fe-private-02-ip>       # 10.0.254.x
ssh ubuntu@<be-private-02-ip>          # 192.168.254.x over peering
```

Expected results from frontend-private-instance02:

| Test | Result |
|---|---|
| ping / SSH backend-private-instance02 | OK (peering) |
| ping backend-private-instance03 | blocked (02 only talks to 02) |
| ping 8.8.8.8 | blocked (no NAT route on rtb-02) |

---

## Security notes

- Never commit `*.pem`, `*.tfstate`, `.terraform/` or `*.tfvars` (see `.gitignore`).
- AWS keys live only in the HCP Terraform variable set.
- `pub-sg01` allows SSH from `0.0.0.0/0` for the lab; tighten it to your own IP/32.
- NAT gateways and Elastic IPs cost money every hour: destroy the lab when not in use.

---

Based on the `aws-vpc-peering-intra` lab by Sai Linn Thu (GitLab `sailinnthu/terraform-aws-bastion-host`), split into 6 HCP Terraform workspaces.
