#!/bin/bash

PROJECT_ID=""
SUSPEND=true

function usage() {
  echo "Usage: $0 -p <project_id> [-s <true|false>] [-h]"
  echo "  -p <project_id>   : Specify the project ID to suspend or unsuspend"
  echo "  -s <true|false>   : Optional flag to specify whether to suspend (true) or unsuspend (false) the project. Default is true."
  echo "  -h                : Display this help message"
}

while getopts ":p:s:h" opt; do
  case $opt in
    p)
      PROJECT_ID="$OPTARG"
      ;;
    s)
      SUSPEND="$OPTARG"
      ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: Project ID is required."
  usage
  exit 1
fi

if [[ "$SUSPEND" == "true" ]]; then
  
  echo "Disabling Routers for project with ID: $PROJECT_ID"
  for ROUTER in $(openstack router list --project "$PROJECT_ID" -f value -c ID); do
    echo "Disabling router with ID: $ROUTER"
    openstack router set --disable "$ROUTER" \
      || { echo "Failed to disable router with ID: $ROUTER"; exit 1; }
  done
  
  echo "Shelving VMs for project with ID: $PROJECT_ID"
    for SERVER in $(openstack server list --project "$PROJECT_ID" -f value -c ID); do
    echo "Shelving server with ID: $SERVER"
    openstack server shelve "$SERVER" \
      || { echo "Failed to shelve server with ID: $SERVER"; exit 1; }
  done

  echo "Suspending project with ID: $PROJECT_ID"
  openstack project set --disable "$PROJECT_ID" \
    || { echo "Failed to suspend project with ID: $PROJECT_ID"; exit 1; }

elif [[ "$SUSPEND" == "false" ]]; then

  echo "Unsuspending project with ID: $PROJECT_ID"
  openstack project set --enable "$PROJECT_ID" \
    || { echo "Failed to unsuspend project with ID: $PROJECT_ID"; exit 1; }

  echo "Enabling Routers for project with ID: $PROJECT_ID"
  for ROUTER in $(openstack router list --project "$PROJECT_ID" -f value -c ID); do
    echo "Enabling router with ID: $ROUTER"
    openstack router set --enable "$ROUTER" \
      || { echo "Failed to enable router with ID: $ROUTER"; exit 1; }
  done

  echo "Unshelving VMs for project with ID: $PROJECT_ID"
  for SERVER in $(openstack server list --project "$PROJECT_ID" -f value -c ID); do
    echo "Unshelving server with ID: $SERVER"
    openstack server unshelve "$SERVER" \
      || { echo "Failed to unshelve server with ID: $SERVER"; exit 1; }
  done

else
  echo "Error: Invalid value for -s option. Use 'true' to suspend or 'false' to unsuspend."
  usage
  exit 1
fi

# final message indicating the operation was successful
if [[ "$SUSPEND" == "true" ]]; then
  echo "Project with ID: $PROJECT_ID has been successfully suspended."
else
  echo "Project with ID: $PROJECT_ID has been successfully unsuspended."
fi