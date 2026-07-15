#!/bin/bash

USER=""
PROJECT=""
DRY_RUN=false
AUTO_APPROVE=false

function usage() {
  echo "Usage: $0 -u <user> -p <project_id> [-d <dry-run>] [-a <auto-approve>] [-h]"
  echo "  -u <user>          : Specify the user to add roles to"
  echo "  -p <project_id>    : Specify the project ID"
  echo "  -d                 : Optional dry run mode (no changes will be made)"
  echo "  -a                 : Optional auto-approve mode (automatically approve cleanup)"
  echo "  -h                 : Display this help message"
}

function arg_check() {
  if [[ -z "$USER" || -z "$PROJECT" ]]; then
    echo "Error: User and project ID are required."
    usage
    exit 1
  fi

  if [[ "$DRY_RUN" == true && "$AUTO_APPROVE" == true ]]; then
    echo "Error: Cannot use both dry run and auto-approve options together."
    usage
    exit 1
  fi
}

while getopts ":u:p:d:a:h" opt; do
  case $opt in
    u)
      USER="$OPTARG"
      ;;
    p)
      PROJECT="$OPTARG"
      ;;
    d)
      DRY_RUN=true
      ;;
    a)
      AUTO_APPROVE=true
      ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
  esac
done

arg_check

ROLES=(member k8s-member CVLT load-balancer_member)

for role in "${ROLES[@]}"; do
    openstack role add --user "$USER" --project "$PROJECT" "$role" \
    && echo "Role $role added to user $USER in project $PROJECT" \
    || echo "Failed to add role $role to user $USER in project $PROJECT"
done

# Can be ommited to speed things up the script, but it is useful to verify that the project is enabled
echo "Enable project $(openstack project show "$PROJECT" -f value -c name)"
openstack project set --enable "$PROJECT" \
&& echo "Project $PROJECT enabled" \
|| echo "Failed to enable project $PROJECT"

PROJECT_NAME=$(openstack project show "$PROJECT" -f value -c name)
PROJECT_DOMAIN_ID=$(openstack project show "$PROJECT" -f value -c domain_id)
PROJECT_DOMAIN_NAME=$(openstack domain show "$PROJECT_DOMAIN_ID" -f value -c name)
USER_DOMAIN_ID=$(openstack user show "$USER" -f value -c domain_id)
USER_DOMAIN_NAME=$(openstack domain show "$USER_DOMAIN_ID" -f value -c name)

# Normally unrun openrc.sh before running this with required ADMIN user credentials, then run this script to set the environment variables for the specified user and project.
export OS_PROJECT_NAME="$PROJECT_NAME"
#export OS_PROJECT_ID="$PROJECT"
#export OS_PROJECT_DOMAIN_ID="$PROJECT_DOMAIN_ID"
export OS_PROJECT_DOMAIN_NAME="$PROJECT_DOMAIN_NAME"
export OS_USERNAME="$USER"
export OS_USER_DOMAIN_NAME="$USER_DOMAIN_NAME"

# Clean project
if [ "$DRY_RUN" = false ]; then
  echo "Cleaning project $PROJECT_NAME..."
  if [ "$AUTO_APPROVE" = true ]; then
    openstack --os-ha-api-version 1.2 project cleanup --auth-project --auto-approve
    else
    # This will prompt for confirmation before proceeding with the cleanup
    openstack --os-ha-api-version 1.2 project cleanup --auth-project
  fi
  echo "Project $PROJECT_NAME cleaned."
else
  openstack --os-ha-api-version 1.2 project cleanup --auth-project --dry-run
  echo "Dry run mode enabled. No changes will be made."
fi

# Getting default project back
export OS_PROJECT_NAME="admin"
export OS_PROJECT_DOMAIN_NAME="admin_domain"

# Remove roles from user
for role in "${ROLES[@]}"; do
    openstack role remove --user "$USER" --project "$PROJECT" "$role" \
    && echo "Role $role removed from user $USER in project $PROJECT" \
    || echo "Failed to remove role $role from user $USER in project $PROJECT"
done

# Disable project
openstack project set --disable "$PROJECT" \
&& echo "Project $PROJECT disabled" \
|| echo "Failed to disable project $PROJECT"

# Delete project (optional, uncomment if needed)
echo "Deleting project $PROJECT... [y/N]:"
read -r response
if [ "$response" = "y" ]; then
    openstack project delete "$PROJECT"
fi

# Final message
echo "Script execution completed."
