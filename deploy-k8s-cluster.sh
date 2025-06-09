#!/bin/bash

set -e

# Function to display usage
usage() {
    echo "Usage: $0 [deploy|cleanup] [options]"
    echo ""
    echo "Commands:"
    echo "  deploy              Deploy a new K8s cluster on AWS GPU instance"
    echo "  cleanup             Cleanup AWS instances found in inventory files"
    exit 1
}

# Function to deploy cluster
deploy_cluster() {
    echo "=== Deploying K8s Cluster on AWS GPU Instance ==="

    echo "Launching AWS GPU instance..."
    ansible-playbook launch-instance.yaml

    echo "Finding generated inventory file..."
    INVENTORY_FILE=$(ls -rt gpu-inventory-*.ini | tail -1)

    if [ -z "$INVENTORY_FILE" ]; then
        echo "Error: No inventory file found!"
        exit 1
    fi

    echo "Using inventory file: $INVENTORY_FILE"

    echo "Configuring Kubernetes cluster..."
    ansible-playbook -i "$INVENTORY_FILE" kubernetes-single-node.yaml

    echo "Deployment complete!"
    echo "Check the instance details file for SSH access information." 

    echo "Deploying LLM-D..."
    ansible-playbook -i "$INVENTORY_FILE" llm-d-deploy.yaml

    echo "Testing LLM-D..."
    ansible-playbook -i "$INVENTORY_FILE" llm-d-test.yaml
}

cleanup_instances() {
    echo "=== Cleaning up AWS GPU instances ==="

    # Check if there are any inventory files
    if ! ls gpu-inventory-*.ini 1> /dev/null 2>&1; then
        echo "No inventory files found. Nothing to cleanup."
        exit 0
    fi

    echo "Found inventory files. Running cleanup playbook..."
    ansible-playbook cleanup-instance.yaml

    echo "Cleanup complete!"
}

# Main script logic
case "${1:-}" in
    deploy)
        shift
        if [ $# -ne 0 ]; then
            echo "Deploy command doesn't accept additional arguments"
            usage
        fi
        deploy_cluster
        ;;
    cleanup)
        shift
        cleanup_instances "$@"
        ;;
    -h|--help|help)
        usage
        ;;
    "")
        # Default behavior - deploy
        deploy_cluster
        ;;
    *)
        echo "Unknown command: $1"
        usage
        ;;
esac 