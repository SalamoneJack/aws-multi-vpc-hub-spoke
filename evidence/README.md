# Deployment Evidence — aws-multi-vpc-hub-spoke

**Status:** LIVE in AWS at capture time (destroyed after this screenshot session)
**Captured:** 2026-05-28
**Region:** us-east-1
**Account:** 904474958504

## What This Lab Demonstrates
Hub-and-spoke VPC topology with shared services in the hub and isolated workload spokes — the same security boundary pattern used in multi-account AWS landing zones. Two VPC peerings (hub↔prod, hub↔dev) but **no peering between spokes**. Spokes must route through the hub or not at all.

## The "Failed Ping IS The Success Screenshot"

This is the lab's signature artifact. Captured by SSH-ing into each test instance and pinging the others. The pattern proves the security model is enforced at the network layer, not by trust:

```
== prod-test (10.10.1.26) -> shared-test (10.0.1.211) — should SUCCEED ==
PING 10.0.1.211 (10.0.1.211) 56(84) bytes of data.
64 bytes from 10.0.1.211: icmp_seq=1 ttl=64 time=0.799 ms
64 bytes from 10.0.1.211: icmp_seq=2 ttl=64 time=0.452 ms
64 bytes from 10.0.1.211: icmp_seq=3 ttl=64 time=0.439 ms
3 packets transmitted, 3 received, 0% packet loss
rtt min/avg/max/mdev = 0.439/0.563/0.799/0.166 ms

== dev-test (10.20.1.76) -> shared-test (10.0.1.211) — should SUCCEED ==
PING 10.0.1.211 (10.0.1.211) 56(84) bytes of data.
64 bytes from 10.0.1.211: icmp_seq=1 ttl=64 time=0.851 ms
64 bytes from 10.0.1.211: icmp_seq=2 ttl=64 time=0.408 ms
64 bytes from 10.0.1.211: icmp_seq=3 ttl=64 time=0.492 ms
3 packets transmitted, 3 received, 0% packet loss

== prod-test (10.10.1.26) -> dev-test (10.20.1.76) — should FAIL ==
PING 10.20.1.76 (10.20.1.76) 56(84) bytes of data.
3 packets transmitted, 0 received, 100% packet loss

== dev-test (10.20.1.76) -> prod-test (10.10.1.26) — should FAIL ==
PING 10.10.1.26 (10.10.1.26) 56(84) bytes of data.
3 packets transmitted, 0 received, 100% packet loss
```

**Both spokes can reach the hub. Neither spoke can reach the other.** The two failed pings prove there's no route between prod and dev — no peering, no transit gateway, no NAT bypass. This is the security model.

## Architecture in Numbers

| VPC | CIDR | Role | Test EC2 Private IP |
|---|---|---|---|
| `shared` | 10.0.0.0/16 | hub (shared services) | 10.0.1.211 |
| `prod` | 10.10.0.0/16 | spoke (production workload) | 10.10.1.26 |
| `dev` | 10.20.0.0/16 | spoke (dev workload) | 10.20.1.76 |

| Peering | ID | State |
|---|---|---|
| `shared ↔ prod` | `pcx-09e7b62a7d14e7198` | active |
| `shared ↔ dev` | `pcx-04638f0c11007c731` | active |
| `prod ↔ dev` | **not created** — security boundary | n/a |

## Live AWS Console Links (click to view + screenshot)

- **VPC peerings (both active):** https://us-east-1.console.aws.amazon.com/vpcconsole/home?region=us-east-1#PeeringConnections:
- **All hub-spoke VPCs:** https://us-east-1.console.aws.amazon.com/vpcconsole/home?region=us-east-1#vpcs:search=hub-spoke
- **All 3 test EC2s:** https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#Instances:search=hub-spoke

## Real-World Connection
This is the foundation of AWS's [Centralized Network Inspection](https://aws.amazon.com/blogs/networking-and-content-delivery/centralized-inspection-architecture-with-aws-gateway-load-balancer/) and the topology behind AWS Control Tower's network account. In production, the hub becomes a Transit Gateway and the spokes become application VPCs; the security model — workload isolation enforced by routing — is identical.

## Raw Evidence (this folder)
- `terminal-ping-tests.txt` — the 4 ping tests above (raw)
- `peerings.json` — `aws ec2 describe-vpc-peering-connections` for both
- `vpcs.json` — all 3 VPCs
- `instances.json` — all 3 test EC2s
- `route-tables.json` — route tables showing peering routes
- `terraform-outputs.txt` — `terraform output`

## Cost
~$25/month if left running (3× t2.micro + VPC peering bandwidth). **Designed to deploy → screenshot → destroy.**
