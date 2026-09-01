# Topology Visuals (Simulation Package)

This folder provides stakeholder-friendly topology visuals based on the current Project Shell Space foundation.

## Files
- `current-state.mmd` — Static current architecture view
- `simulated-flow.mmd` — Step-flow simulation:
  Terraform provisions → outputs → Ansible configures → monitoring observes

## Purpose
Non-technical communication artifact showing:
1. What is already built
2. How components are intended to interact
3. What is deferred for later configuration

## Regeneration Workflow
Update `.mmd` files as project state changes, then export to PNG/SVG using your preferred Mermaid renderer.
