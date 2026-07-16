# Zero Trust Hub & Spoke — AWS (Terraform)

Fully private hub-and-spoke on AWS Transit Gateway. No internet gateways on the
spokes, no public IPs, no SSH. Access to instances is via **SSM Session Manager**
only. Built for **AWS Academy Learner Lab**.

## What this builds

- **4 VPCs**: hub (`10.0.0.0/16`), frontend (`10.1.0.0/16`), app (`10.2.0.0/16`),
  database (`10.3.0.0/16`)
- **1 Transit Gateway** with all four attached
- **SSM interface endpoints** (`ssm`, `ssmmessages`, `ec2messages`) in every VPC
  so Session Manager reaches the fully private instances
- **1 t3.micro test instance per VPC** (no public IP, no key pair, ICMP open)

## Connectivity model (zero-trust segmentation)

Enforced by *which* Transit Gateway routes exist per VPC:

| From \ To  | hub | frontend | app | database |
|------------|:---:|:--------:|:---:|:--------:|
| hub        |  —  |   yes    | yes |   yes    |
| frontend   | yes |    —     | yes |  **no**  |
| app        | yes |   yes    |  —  |   yes    |
| database   | yes |  **no**  | yes |    —     |

frontend and database deliberately cannot reach each other — the web tier has no
path to the data tier.

## Deploy

Stacks are layered; each reads the networking layer's local state — no IDs to
copy-paste anywhere. Apply in this order:

| Order | Stack                 | What it adds                                              |
|-------|-----------------------|-----------------------------------------------------------|
| 1     | `usecase/networking`  | 4 VPCs, TGW, SSM endpoints (the foundation)               |
| 2     | `usecase/compute`     | *(optional)* 1 test instance per VPC for ping/segmentation tests |
| 3     | `usecase/storage`     | Private S3 bucket in the Hub + S3 gateway endpoint        |
| 4     | `usecase/database`    | 7 DynamoDB tables + gateway endpoint (Database spoke)     |
| 5     | `usecase/app`         | Cognito, 5 Lambdas, SNS topic, DynamoDB/SNS endpoints (App spoke). Run `bash infra/lambda/build.sh` first. |
| 6     | `usecase/frontend`    | Elastic Beanstalk (internal only) + the endpoints EB needs to bootstrap privately |

```bash
cd infra/usecase/networking

# 1. CHECK THE REGION in terraform.tfvars first.
#    Learner Lab is often us-east-1; this file defaults to eu-west-1.
#    See the banner at the top of terraform.tfvars.

terraform init
terraform plan      # review: ~40 resources
terraform apply

# then repeat init/plan/apply in each stack directory, in the order above
```

After apply:

```bash
terraform output instance_private_ips   # your ping targets
terraform output instance_ids           # for aws ssm start-session
```

## Test it

1. EC2 console -> pick the hub instance -> **Connect -> Session Manager**.
   (Allow 2-3 min after apply for the SSM agent to register.)
2. In the shell, ping the targets from `terraform output`:

```bash
ping -c 4 10.1.1.x   # hub -> frontend   (works)
ping -c 4 10.2.1.x   # hub -> app        (works)
ping -c 4 10.3.1.x   # hub -> database   (works)
```

3. Prove segmentation — connect to the **frontend** instance and try the database:

```bash
ping -c 4 10.3.1.x   # frontend -> database  (100% loss, BY DESIGN)
```

That deliberate failure is the zero-trust demo: no route, no reach.

## If Session Manager won't connect

Same order as the manual build:
1. Instance booted before endpoints were ready -> reboot it.
2. Confirm the instance profile is `LabInstanceProfile` (set in tfvars).
3. Endpoints must be `Available` (VPC -> Endpoints).
4. VPC DNS resolution + hostnames must be on (the VPC module sets both).

## Cost (Learner Lab budget is $50, no refill)

| Resource                        | Approx /hour |
|---------------------------------|-------------:|
| TGW attachments x4              |        $0.20 |
| Interface endpoints x12 (3x4)   |        $0.12 |
| t3.micro x4                     |        $0.04 |
| **Total**                       |    **~$0.36** |

~$8.50/day if left running. **Tear down when done.**

## Cleanup

```bash
cd infra/usecase/networking
terraform destroy
```

One command removes everything in dependency order. If destroy ever stalls on an
endpoint or attachment, re-run it — eventual-consistency retries clear it.

## Notes / future hardening

- **Centralized endpoints**: 12 endpoints is the simple, reliable option. The
  production pattern puts endpoints only in the hub and shares them to spokes via
  a Route 53 private hosted zone + TGW. Cheaper at scale, more moving parts.
- **True TGW route-table segmentation**: this version segments at the VPC route
  table layer. The enterprise approach uses separate TGW route tables per tier.
- IMDSv2 is enforced on the instances (`http_tokens = required`).

## CI/CD (GitHub Actions)

The repo ships two workflows in `.github/workflows/`:

- **terraform-deploy** — PRs touching `infra/` get lambda builds + `validate`
  + a networking `plan`. Pushes to `main` apply every stack in dependency
  order (networking → storage → database → app → frontend). The optional
  `compute` ping-test layer deploys via *Run workflow* with the checkbox.
- **terraform-destroy** — manual teardown in reverse order (type `destroy`
  to confirm). Optionally keeps the networking layer for faster redeploys.

### One-time setup

1. **State bucket** (state is shared between your laptop and CI via S3):

   ```bash
   aws s3 mb s3://easycart-tfstate-<something-unique> --region us-east-1
   aws s3api put-bucket-versioning --bucket easycart-tfstate-<something-unique> \
     --versioning-configuration Status=Enabled
   grep -rl "easycart-tfstate-mel4821" . | xargs sed -i 's/easycart-tfstate-mel4821/easycart-tfstate-<something-unique>/'
   ```

2. **Repo secrets** (Settings → Secrets and variables → Actions):
   `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`.
   Learner Lab credentials expire with the session — re-paste all three
   from **AWS Details** whenever you start a new lab session, or the
   pipeline fails with `ExpiredToken`.

3. Push to `main`. Done.

### Local runs still work

Same state, same commands — just point init at the shared backend config:

```bash
cd infra/usecase/networking
terraform init -backend-config=../../backend.hcl
terraform apply
```

Lambda zips are gitignored build artifacts; run `bash infra/lambda/build.sh`
before working on the app stack locally (CI builds them automatically).
