#!/bin/bash

contexts=$(kubectl config get-contexts -o name)

for ctx in $contexts; do
  node_name_list=$(kubectl get nodes --context=$ctx -o name | awk -F/ '{print $2}')
  
  for node in $node_name_list; do
    kubectl label nodes $node cluster-name=$ctx --context=$ctx --overwrite
  done
done