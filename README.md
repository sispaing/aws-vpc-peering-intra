# aws-vpc-peering-intra on HCP Terraform (6 workspaces)

Frontend VPC (10.0.0.0/16) and backend VPC (192.168.0.0/16) in the same region,
joined by VPC peering. Same code as the GitLab branch, split into 6 workspaces.

| Folder        | Workspace       | What it builds                                             | Reads from              |
|---------------|-----------------|------------------------------------------------------------|-------------------------|
| fe-network    | fe-network-ws   | frontend VPC, subnets, IGW, NAT, route tables              | -                       |
| be-network    | be-network-ws   | backend VPC, subnets, IGW, NAT, route tables + **peering** | fe-network-ws           |
| fe-security   | fe-security-ws  | frontend public SG + private SG01/02/03                    | fe-network-ws           |
| be-security   | be-security-ws  | backend SGs + **cross-VPC SG rules (both sides)**          | be-network-ws, fe-security-ws |
| fe-compute    | fe-compute-ws   | key pair, public (bastion/web) + 3 private instances       | fe-network-ws, fe-security-ws |
| be-compute    | be-compute-ws   | key pair, public (bastion/web) + 3 private instances       | be-network-ws, be-security-ws |

Why peering is in be-network and cross rules are in be-security:
fe and be reference each other, so one side must be created first.
Frontend goes first, backend adds the links. This avoids a circular dependency.

## 1. Setup (once)

1. Replace `nickcloud4t-master` in every `versions.tf` and `variables.tf`.
   Mac: `grep -rl nickcloud4t-master . | xargs sed -i '' 's/nickcloud4t-master/<YOUR-ORG>/g'`
2. Project `aws-vpc-peering-intra` must exist (it does in your org).
3. AWS credentials: a Variable Set on the project with env vars
   `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` (mark sensitive).
4. Remote state sharing. Easiest for a lab: each workspace >
   Settings > General > Remote state sharing > "Share with all workspaces in this organization".
   Or share exactly:
   - fe-network-ws  -> be-network-ws, fe-security-ws, fe-compute-ws
   - be-network-ws  -> be-security-ws, be-compute-ws
   - fe-security-ws -> be-security-ws, fe-compute-ws
   - be-security-ws -> be-compute-ws

## 2. Apply (in this order)

```bash
terraform login

cd fe-network  && terraform init && terraform apply
cd ../be-network  && terraform init && terraform apply
cd ../fe-security && terraform init && terraform apply
cd ../be-security && terraform init && terraform apply
cd ../fe-compute  && terraform init && terraform apply
cd ../be-compute  && terraform init && terraform apply
```

`terraform init` creates the workspace in HCP Terraform automatically if it does not exist.

## 3. Destroy (reverse order)

be-compute -> fe-compute -> be-security -> fe-security -> be-network -> fe-network

## 4. Test

```bash
cd fe-compute
terraform output -raw fe_instances_private_key > fe-sshkey.pem && chmod 400 fe-sshkey.pem
terraform output

# web page
curl http://<frontend_public_instance_public_ip>

# bastion -> fe private-instance02
ssh -i fe-sshkey.pem -J ec2-user@<frontend_public_ip> ubuntu@<frontend_private_instance02_private_ip>
```

From fe private-instance02 you can ping be private-instance02 (and 03 <-> 03) over peering.
To jump there with SSH you need the be key on the fe instance (copy be-sshkey.pem over first).

## Changes from the original repo

- Public instances use Amazon Linux 2023 (Amazon Linux 2 support ended 2026-06-30).
  cowsay is not in AL2023 repos, so that step can no longer fail the run.
- `aws_eip` uses `domain = "vpc"`. NAT route uses `nat_gateway_id`.
- Public IP outputs read the Elastic IP (the instance itself has no public IP).
- Ubuntu cowsay path fixed to `/usr/games/cowsay`.
