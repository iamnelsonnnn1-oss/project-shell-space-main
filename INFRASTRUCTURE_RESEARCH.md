# Infrastructure Decision: GCP Free Tier + Cloudflare

**Decision:** GCP replaces AWS. OCI was considered but is not used. Cloudflare (free) fronts the app for DNS/CDN.
**Status:** Waiting on GCP account activation (prepayment). Nothing is applied until then.

## Free tier limits (verify at https://cloud.google.com/free)
- 1x `e2-micro` in us-west1 / us-central1 / us-east1, 30 GB standard disk
- ~1 GB/month egress free: bandwidth is NOT unlimited on GCP
- $300 trial credit expires after 90 days
- Cloud KMS is not free (cents/month)
- No managed SQL on free tier: run Postgres on the VM, or use Firestore

## Cloudflare role
Free DNS, CDN and proxy in front of the VM. Cached/proxied traffic is where the "unlimited bandwidth" comes from.

## Terraform
- `providers.tf`: `hashicorp/google ~> 5.0` (Cloudflare provider commented, enable later)
- `variables.tf` / `main.tf` / `outputs.tf` / `terraform.tfvars`: VPC, subnet, KMS, firewall (443), e2-micro VM

## AWS -> GCP mapping
| AWS | GCP |
|---|---|
| aws_vpc | google_compute_network + subnetwork |
| aws_security_group | google_compute_firewall |
| aws_kms_key | google_kms_key_ring + crypto_key |
| EC2 | google_compute_instance (e2-micro) |
| RDS | Postgres on VM / Firestore |

## Before first apply
1. Activate GCP, create project, set `project_id` in `terraform.tfvars`
2. Create a billing budget + alerts
3. Restrict `allowed_cidr_blocks` to Cloudflare IP ranges
4. Configure the GCS state backend
