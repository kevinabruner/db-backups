#!/bin/bash
app_name="db-backups"

echo "--- Searching NetBox for $app_name ---"

# 1. Fetch both the inventory hostname and VMID using a single jq call
read -r INVENTORY_HOSTNAME VMID < <(ansible-inventory --list | jq -r --arg app "$app_name" '
  ._meta.hostvars as $hv |
  .role_vm_template.hosts[]? as $host_name |
  $hv[$host_name] | 
  select((.custom_fields.repos.value // .custom_fields.repos) == $app) | 
  [$host_name, .custom_fields.vmid] | @tsv
')

echo "--- Found Target ---"
echo "Host:     $INVENTORY_HOSTNAME"
echo "VMID:     $VMID"

echo "--- Running Pre-flight Checklist ---"
ansible-playbook _packer-preflight.yaml -K -e "vmid=$VMID"

# 4. Build the actual image now with the vars
echo "--- Building $INVENTORY_HOSTNAME (VM $VMID) ---"

time packer build \
    -var "proxmox_vmid=$VMID" \
    -var "inventory_hostname=$INVENTORY_HOSTNAME" \
    -var-file="packer/variables.pkrvars.hcl" \
    -var-file="packer/secret.pkrvars.hcl" \
    packer/golden-image.pkr.hcl