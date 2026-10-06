# Architecture Reference and Decision Record

Governing reference: **Architecture Charter Revision 2** (held outside this repository) plus the Captain decisions below.
This document is the in-repo summary. Where it differs from the Charter, the differences are listed under *Approved deviations*.

> Status: nothing is deployed. Terraform validates but is not applied. Ansible is syntax-checked but has not been run against any host.

## Hard constraints
- Target VM: GCP `e2-micro`, Debian 12, about 1 GB RAM. Every always-on service must justify its memory cost.
- No Redis, Kafka, RabbitMQ or other broker. No self-hosted video. No background workers unless approved.
- Security controls are never weakened for implementation convenience.

## Confirmed decisions
| Area | Decision |
|---|---|
| Frontend | React, Vite, Tailwind CSS, shadcn/ui, React Router, TanStack Query, react-hook-form + Zod, dnd-kit, native WebSocket, HTML5 Canvas + WebCrypto |
| Backend | Node.js **24 LTS** (major pinned everywhere) + Fastify |
| Realtime | Native WebSocket on the application runtime. No message queue. |
| Database | PostgreSQL on the same VM for the initial implementation. No managed DB or second VM without an approved architecture change. |
| Authorization | Workspace-scoped RBAC enforced in the application **and** in PostgreSQL (row-level security). |
| Encryption | Application-level encryption of protected message content and whiteboard strokes, with GCP KMS key custody. No plaintext fallback. |
| Video | External, off-VM provider behind a provider interface. |
| Ingress | **Cloudflare Tunnel** is the only application ingress. No public 443 rule. |
| Administration | **IAP** (OS Login + 2FA) is the only administrative path. No public SSH rule. |
| Public IP | Kept for outbound connectivity only. No Cloud NAT in this iteration. |
| Branch protection | `main` requires 1 approving review. No admin bypass as a normal workflow. |

## Still undecided (kept behind interfaces)
- Authentication provider and OTP/email provider (`AuthProvider`, `OtpProvider`).
- Video provider (`VideoProvider`).
- Exact encryption and key model (`KeyProvider`). No KMS consumer is created until it is approved.
- Remote Terraform state bucket and project, CI/CD scope, scaling strategy, audit retention.

## Approved deviations from Charter Rev 2
1. **`workspace_id` on workspace-owned child tables (deviates from Charter §9).** `messages`, `message_reactions`, `kanban_boards`, `kanban_cards`, `whiteboard_sessions`, `video_rooms`, `notifications` and `channels` carry `workspace_id` directly so PostgreSQL row-level security can be enforced with a single, non-joining policy. Composite foreign keys keep the child's `workspace_id` consistent with its parent.
2. **dnd-kit replaces `@hello-pangea/dnd`** (Charter §6, §7).
3. **Cloudflare Tunnel replaces the public-origin option** (Charter §19 listed it as undecided).

## Database roles and row-level security
- The table-owner role (`shellspace`) runs migrations. The API connects as `shellspace_app`, which is not the owner and has no `BYPASSRLS`, so row-level security always applies.
- Each request runs in a transaction with `app.user_id` and `app.workspace_id` set locally (`server/src/db/scope.js`). Policies check both the workspace and real membership via `SECURITY DEFINER` helpers.
- Encryption columns (`*_ciphertext`, `encryption_meta`) are provisional until the key model is approved. No plaintext content column exists.

## Charter appendix note
The Charter's infrastructure appendix (AWS, EC2/RDS, S3 and DynamoDB state, CloudWatch, Docker, Kubernetes, Grafana) is legacy reference material and is not implemented.

## Infrastructure execution gates
Not authorized without a separate Captain approval of the reviewed plan: `terraform apply`, any Ansible run against a host, SSH to the VM, `cloudflared` deployment, billable resources, a KMS consumer, and initializing remote state against an unconfirmed bucket.
Allowed: `terraform validate`, `terraform plan` without apply, `ansible-playbook --syntax-check` and `--check` against no host, static validation and tests.

## Workflow constraint
`main` requires one approving review. With a single maintainer this means a second reviewer must approve every PR. The rule is not weakened for convenience.
