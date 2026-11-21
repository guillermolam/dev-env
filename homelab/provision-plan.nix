{ lib }:
let
  plan = builtins.fromJSON (builtins.readFile ./provision-plan.json);
  ids = map (row: row.id) plan;
  whens = [
    "nix_built"
    "runtime_up"
    "cluster_ready"
    "linux_node"
    "cloud_account"
  ];
in
assert lib.unique ids == ids;
assert builtins.length plan == 14;
assert builtins.all (row: builtins.elem row.when whens) plan;
plan
