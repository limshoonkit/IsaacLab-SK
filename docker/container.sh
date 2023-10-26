#!/bin/bash

#==
# Configurations
#==

# Exits if error occurs
set -e

# Set tab-spaces
tabs 4

# get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

#==
# Functions
#==

# print the usage description
print_help () {
    echo -e "\nusage: $(basename "$0") [-h] [run] [start] [stop] -- Utility for handling docker in Orbit."
    echo -e "\noptional arguments:"
    echo -e "\t-h, --help         Display the help content."
    echo -e "\tstart              Build the docker image and create the container in detached mode."
    echo -e "\tenter              Begin a new bash process within an existing orbit container."
    echo -e "\tcopy               Copy build and logs artifacts from the container to the host machine."
    echo -e "\tstop               Stop the docker container and remove it."
    echo -e "\n" >&2
}

#==
# Main
#==

# check argument provided
if [ -z "$*" ]; then
    echo "[Error] No arguments provided." >&2;
    print_help
    exit 1
fi

# check if docker is installed
if ! command -v docker &> /dev/null; then
    echo "[Error] Docker is not installed! Please check the 'Docker Guide' for instruction." >&2;
    exit 1
fi

# parse arguments
mode="$1"
# resolve mode
case $mode in
    start)
        echo "[INFO] Building the docker image and starting the container in the background..."
        pushd ${SCRIPT_DIR} > /dev/null 2>&1
        docker compose --file docker-compose.yaml up --detach --build --remove-orphans
        popd > /dev/null 2>&1
        ;;
    enter)
        echo "[INFO] Entering the existing 'orbit' container in a bash session..."
        pushd ${SCRIPT_DIR} > /dev/null 2>&1
        docker exec --interactive --tty orbit bash
        popd > /dev/null 2>&1
        ;;
    copy)
        # check if the container is running
        if [ "$( docker container inspect -f '{{.State.Status}}' orbit 2> /dev/null)" != "running" ]; then
            echo "[Error] The 'orbit' container is not running! It must be running to copy files from it." >&2;
            exit 1
        fi
        echo "[INFO] Copying artifacts from the 'orbit' container..."
        echo -e "\t - /workspace/orbit/logs -> ${SCRIPT_DIR}/artifacts/logs"
        echo -e "\t - /workspace/orbit/docs/_build -> ${SCRIPT_DIR}/artifacts/docs/_build"
        echo -e "\t - /workspace/orbit/data_storage -> ${SCRIPT_DIR}/artifacts/data_storage"
        # enter the script directory
        pushd ${SCRIPT_DIR} > /dev/null 2>&1
        # We have to remove before copying because repeated copying without deletion
        # causes strange errors such as nested _build directories
        # warn the user
        echo -e "[WARN] Removing the existing artifacts...\n"
        rm -rf ./artifacts/logs ./artifacts/docs/_build ./artifacts/data_storage

        # create the directories
        mkdir -p ./artifacts/docs

        # copy the artifacts
        docker cp orbit:/workspace/orbit/logs ./artifacts/logs
        docker cp orbit:/workspace/orbit/docs/_build ./artifacts/docs/_build
        docker cp orbit:/workspace/orbit/data_storage ./artifacts/data_storage
        echo -e "\n[INFO] Finished copying the artifacts from the container."
        popd > /dev/null 2>&1
        ;;
    stop)
        echo "[INFO] Stopping the launched docker container..."
        pushd ${SCRIPT_DIR} > /dev/null 2>&1
        docker compose --file docker-compose.yaml down
        popd > /dev/null 2>&1
        ;;
    *)
        echo "[Error] Invalid argument provided: $1"
        print_help
        exit 1
        ;;
esac