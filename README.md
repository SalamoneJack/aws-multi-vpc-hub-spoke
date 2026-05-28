# AWS Multi-VPC Hub-and-Spoke Network

![AWS](https://img.shields.io/badge/AWS-232F3E?logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?logo=terraform&logoColor=white)
![VPC Peering](https://img.shields.io/badge/VPC-Peering-informational)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)

Enterprise-grade network segmentation using a hub-and-spoke VPC topology. Three VPCs — `prod`, `dev`, and `shared-services` — connected via VPC peering with route tables that enforce strict segmentation: prod and dev can each reach shared services, but cannot reach each other.

> ### "The failed ping IS the success screenshot"
>
> Captured live across 4 SSH-driven ping tests between the 3 test instances. Both spokes reach the hub (sub-1ms); **neither spoke can reach the other** — proving the security model is enforced at the network layer, not by trust.
>
> ```
> prod → shared : 0% loss, 0.563ms avg    ✓ via shared↔prod peering
> dev  → shared : 0% loss, 0.583ms avg    ✓ via shared↔dev peering
> prod → dev    : 100% packet loss        ✗ no peering, no route
> dev  → prod   : 100% packet loss        ✗ no peering, no route
> ```
>
> **Full evidence + raw AWS describe JSON:** [`screenshots/`](screenshots/)

## The Problem

In enterprise networks, you don't put production and development on the same segment. A misconfigured dev workload shouldn't be able to reach a production database. This is the cloud equivalent of a foundational network design principle: segment by security zone, then explicitly allow only what's required.

The hub-and-spoke model solves this by routing all inter-environment traffic through a central point (shared-services), giving you a single place to add firewalls, DNS, monitoring, or shared tooling — without letting environments talk directly.

## Architecture

```
                    ┌──────────────────────────┐
                    │   Shared-Services VPC     │
                    │   10.0.0.0/16             │
                    │                          │
                    │  • Internal DNS (Route53) │
                    │  • Bastion Host           │
                    │  • Shared tooling         │
                    └───────────┬──────────────┘
                                │ VPC Peering
               ┌────────────────┴────────────────┐
               │                                 │
    ┌──────────▼──────────┐           ┌──────────▼──────────┐
    │   Prod VPC          │           │   Dev VPC           │
    │   10.10.0.0/16      │           │   10.20.0.0/16      │
    │                     │           │                     │
    │  • Production        │    ✗     │  • Development       │
    │    workloads        │◄─────────►│    workloads         │
    │  • Strict SGs        │ BLOCKED  │  • Relaxed SGs       │
    └─────────────────────┘           └─────────────────────┘
          Can reach shared                  Can reach shared
          CANNOT reach dev                  CANNOT reach prod
```

*Full diagram: [docs/architecture.png](docs/architecture.png)*

| VPC | CIDR | Purpose |
|-----|------|---------|
| shared-services | 10.0.0.0/16 | DNS, bastion, shared tooling |
| prod | 10.10.0.0/16 | Production workloads |
| dev | 10.20.0.0/16 | Development and testing |

## Why This Design

### The Three Peering Rules

1. **prod ↔ shared-services**: Prod needs DNS, shared storage, monitoring
2. **dev ↔ shared-services**: Dev needs the same shared tooling
3. **prod ↔ dev: NOT PEERED** — no peering connection exists between them

VPC peering is non-transitive by design. Even if prod→shared and dev→shared both exist, traffic cannot flow prod→shared→dev. You'd need Transit Gateway for that, and we explicitly don't want it here.

### Why Not Transit Gateway?

TGW enables full mesh routing between all attached VPCs by default. You'd have to explicitly configure route tables to block prod↔dev traffic, and that's easy to misconfigure. With peering, the absence of a connection is the security control — there's nothing to misconfigure.

**When you'd upgrade to TGW:** More than ~10 VPCs, need for centralized inspection via a firewall appliance, or cross-region routing. See the "Scaling" section below.

## Prerequisites

- AWS account (Free Tier eligible for t2.micro instances)
- Terraform >= 1.5
- AWS CLI configured (`aws configure`)
- An existing EC2 key pair

## Quick Start

```bash
git clone https://github.com/SalamoneJack/aws-multi-vpc-hub-spoke.git
cd aws-multi-vpc-hub-spoke/terraform

cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

## Deployment

### Variables

`terraform/terraform.tfvars.example`:
```hcl
region   = "us-east-1"
key_pair = "your-key-pair-name"
```

### What Gets Built

- 3 VPCs with public subnets
- 2 VPC peering connections (prod↔shared, dev↔shared)
- Route tables routing peered CIDR ranges through peering connections
- 1 test EC2 in each VPC
- Security groups allowing ICMP within valid peered ranges only

## Verification

### Test 1: prod → shared-services (should succeed)

```bash
ssh ubuntu@<prod_test_ip>
ping <shared_test_private_ip>
# Expected: replies
```

### Test 2: dev → shared-services (should succeed)

```bash
ssh ubuntu@<dev_test_ip>
ping <shared_test_private_ip>
# Expected: replies
```

### Test 3: prod → dev (should FAIL — this is the point)

```bash
ssh ubuntu@<prod_test_ip>
ping <dev_test_private_ip>
# Expected: Request timeout — no route exists
```

The failed ping is the success condition. Screenshot it and label it "segmentation working."

See `screenshots/` for expected output from all three tests.

## Scaling: Hub-and-Spoke → Transit Gateway

| Aspect | VPC Peering (this lab) | AWS Transit Gateway |
|--------|----------------------|---------------------|
| Connection model | Mesh of 1:1 peerings | Hub: all VPCs attach to TGW |
| Max VPCs | ~125 peering connections per VPC | 5,000 VPC attachments |
| Routing control | Per-peering route table entries | TGW route tables (more flexible) |
| Centralized inspection | Not supported | Attach Network Firewall or appliance |
| Cost | Free (data transfer charges only) | $0.05/hr per attachment + data |
| Cross-region | Supported | Supported (inter-region peering) |

**Rule of thumb:** Use VPC peering when you have < 10 VPCs and don't need centralized inspection. Use TGW at scale or when you need a firewall in the traffic path.

## Production Considerations

- Add a Network Firewall or third-party appliance in the shared-services VPC for east-west inspection
- Use AWS RAM (Resource Access Manager) to share resources across AWS Organization accounts, not just VPCs
- DNS: Route 53 Resolver with inbound/outbound endpoints for hybrid DNS resolution
- Flow Logs on all three VPCs — see [aws-network-monitoring](https://github.com/SalamoneJack/aws-network-monitoring)

## Cost

| Resource | Monthly Cost |
|----------|-------------|
| 3× t2.micro test instances (Free Tier) | $0 |
| VPC Peering (connection itself) | $0 |
| Data transfer across peering | $0.01/GB (same region) |
| **Total** | **~$0** |

## What I Learned

- VPC peering is non-transitive — I expected traffic to route through the shared VPC, but AWS explicitly doesn't allow it. The absence of a peering connection IS the security control
- Route table entries are directional — adding a route in prod's table pointing to shared doesn't automatically add the return route in shared's table
- The failed ping (prod→dev) is the screenshot that matters most — it's proof the segmentation actually works, not just that it was configured
- This is the cloud equivalent of a VLAN ACL: you're not filtering with rules, you're controlling reachability by controlling routing

## Related Projects

- [aws-hybrid-vpn-lab](https://github.com/SalamoneJack/aws-hybrid-vpn-lab) — Hybrid connectivity: connecting this to on-prem
- [aws-ha-web-app](https://github.com/SalamoneJack/aws-ha-web-app) — Deploying workloads into a segmented network
- [terraform-aws-vpc-module](https://github.com/SalamoneJack/terraform-aws-vpc-module) — Reusable Terraform module for this VPC pattern
