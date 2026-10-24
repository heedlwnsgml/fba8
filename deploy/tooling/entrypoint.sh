#!/usr/bin/env bash
set -euo pipefail
cd /opt/travelplanner-deploy
case "${1:-help}" in
  bootstrap) exec ansible-playbook -i localhost, deploy/ansible/kind.yml -e tp_bundle_root=/opt/travelplanner-deploy ;;
  cluster) exec bash deploy/kubernetes/cluster.sh ;;
  deploy) exec bash deploy/kubernetes/deploy-kind.sh ;;
  verify) exec bash deploy/kubernetes/verify-kind.sh ;;
  restore) exec bash deploy/kubernetes/restore-data.sh "${2:-/import}" ;;
  backup) exec bash deploy/kubernetes/backup-data.sh "${2:?Specify a new backup directory}" ;;
  *) echo 'Commands: bootstrap | cluster | deploy | verify | restore [directory] | backup directory'; exit 0 ;;
esac
