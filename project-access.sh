#!/bin/bash

ACTION=""
USER=""
PROJECT=""
ROLES=(load-balancer_member
        creator
        member
        key-manager:operator)

function show_help() {
  echo "Usage: $0 [-a | -r | -d] -u <user> -p <project_id>"
  echo "  -a                : Add access"
  echo "  -r or -d          : Remove access"
  echo "  -u <user>         : User to add/remove roles for"
  echo "  -p <project_id>   : Project ID"
  echo "  -h                : Show this help message and exit"
}

# Check for help before getopts so commands such as `-p -h` still show help.
for arg in "$@"; do
  if [[ "$arg" == "-h" ]]; then
    show_help
    exit 0
  fi
done

while getopts ":ardu:p:h" opt; do
  case $opt in
    a)
      ACTION="add"
      ;;
    r|d)
      ACTION="remove"
      ;;
    u)
      USER="$OPTARG"
      ;;
    p)
      PROJECT="$OPTARG"
      ;;
    h)
      show_help
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

for ROLE in "${ROLES[@]}"; do
  if [[ "$ACTION" == "add" ]]; then
    echo "Adding role '$ROLE' to user '$USER' in project '$PROJECT'"
    openstack role add --user "$USER" --project "$PROJECT" "$ROLE" \
      || { echo "Failed to add role '$ROLE' to user '$USER' in project '$PROJECT'"; exit 1; }
  elif [[ "$ACTION" == "remove" ]]; then
    echo "Removing role '$ROLE' from user '$USER' in project '$PROJECT'"
    openstack role remove --user "$USER" --project "$PROJECT" "$ROLE" \
      || { echo "Failed to remove role '$ROLE' from user '$USER' in project '$PROJECT'"; exit 1; }
  else
    echo "No action specified. Use -a to add or -r/-d to remove."
    exit 1
  fi
done