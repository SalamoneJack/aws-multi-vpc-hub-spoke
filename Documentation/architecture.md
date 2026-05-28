# Architecture Diagram

Add your draw.io architecture diagram here as `architecture.png`.

## Suggested draw.io Elements

- Three VPC boxes: shared-services (hub, center), prod (left spoke), dev (right spoke)
- VPC peering arrows: shared↔prod, shared↔dev — labeled with peering connection IDs
- Explicit X or "NO PEERING" indicator between prod and dev
- Route tables shown as callouts on each VPC
- EC2 test instances in each VPC
- CIDRs labeled on each VPC (10.0.0.0/16 shared, 10.10.0.0/16 prod, 10.20.0.0/16 dev)

## Export

Export as PNG at 1200px wide, save as `docs/architecture.png`.
Update the README image reference: `![Architecture](docs/architecture.png)`
