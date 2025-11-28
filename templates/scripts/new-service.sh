#!/bin/sh

# Parse parameters
NAME="$1"
IMAGE="$2"  
PORTS="$3"
VOLUMES="$4"
HEALTH_PORT="${5:-8080}"

# Interactive prompts if not provided
if [ -z "$NAME" ]; then
    printf "Service name: "
    read -r NAME
fi

if [ -z "$NAME" ]; then
    echo "ERROR: Service name is required"
    exit 1
fi

if [ -f "services/container-$NAME.service.tpl" ]; then
    echo "WARNING: services/container-$NAME.service.tpl already exists"
    exit 1
fi

if [ -z "$IMAGE" ]; then
    printf "Docker image (e.g., repo/image:tag): "
    read -r IMAGE
fi

if [ -z "$IMAGE" ]; then
    echo "ERROR: Docker image is required"
    exit 1
fi

if [ -z "$PORTS" ]; then
    printf "Ports (comma-separated, e.g., 8080:8080,9090:9090) [optional]: "
    read -r PORTS
fi

if [ -z "$VOLUMES" ]; then
    printf "Volumes (comma-separated, e.g., /host:/container,/data:/app) [optional]: "
    read -r VOLUMES  
fi

if [ -z "$HEALTH_PORT" ] || [ "$HEALTH_PORT" = "8080" ]; then
    printf "Health check port [8080]: "
    read -r user_health_port
    HEALTH_PORT="${user_health_port:-8080}"
fi

# Generate the service file
echo "Generating container-$NAME.service.tpl..."

# Start with base template
sed -e "s/{{CONTAINER_NAME}}/$NAME/g" \
    -e "s|{{IMAGE_URL}}|$IMAGE|g" \
    -e "s/{{HEALTH_PORT}}/$HEALTH_PORT/g" \
    templates/base.service.tpl > "services/container-$NAME.service.tpl"

# Process ports and volumes
temp_file=$(mktemp)
while IFS= read -r line; do
    if echo "$line" | grep -q "{{PORTS}}"; then
        if [ -n "$PORTS" ]; then
            echo "$PORTS" | tr ',' '\n' | while IFS= read -r port; do
                echo "  -p $port \\"
            done | sed '$s/ \\$//'
        fi
    elif echo "$line" | grep -q "{{VOLUMES}}"; then
        if [ -n "$VOLUMES" ]; then
            echo "$VOLUMES" | tr ',' '\n' | while IFS= read -r volume; do
                echo "  -v $volume:z \\"
            done | sed '$s/ \\$//'
        fi
    else
        echo "$line"
    fi
done < "services/container-$NAME.service.tpl" > "$temp_file"

mv "$temp_file" "services/container-$NAME.service.tpl"

echo "Created services/container-$NAME.service.tpl"
echo ""
echo "Next steps:"
echo "  1. Review the service file:"
echo "     cat services/container-$NAME.service.tpl"
echo ""
echo "  2. Enable auto-start by adding to systemd.yaml.tpl:"
echo "     - name: container-$NAME.service"
echo "       enabled: true"
echo ""
echo "  3. Build and test:"
echo "     make generate && make build"
echo ""
echo "  4. Deploy:"
echo "     make serve  # Then install via CoreOS"
