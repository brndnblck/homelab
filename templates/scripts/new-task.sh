#!/bin/sh

# Parse parameters
NAME="$1"
DESCRIPTION="$2"  
SCRIPT_NAME="$3"
DEPENDENCIES="$4"
REMAIN_ACTIVE="$5"

# Interactive prompts if not provided
if [ -z "$NAME" ]; then
    printf "Task name: "
    read -r NAME
fi

if [ -z "$NAME" ]; then
    echo "ERROR: Task name is required"
    exit 1
fi

if [ -f "services/task-$NAME.service.template" ]; then
    echo "WARNING: services/task-$NAME.service.template already exists"
    exit 1
fi

if [ -z "$DESCRIPTION" ]; then
    printf "Description (e.g., Setup Dependencies): "
    read -r DESCRIPTION
fi

if [ -z "$DESCRIPTION" ]; then
    echo "ERROR: Description is required"
    exit 1
fi

if [ -z "$SCRIPT_NAME" ]; then
    printf "Script filename (e.g., init-$NAME.sh) [$NAME.sh]: "
    read -r user_script
    SCRIPT_NAME="${user_script:-$NAME.sh}"
fi

if [ -z "$DEPENDENCIES" ]; then
    printf "Dependencies (comma-separated services, e.g., network-online.target,syslog.target) [network-online.target]: "
    read -r user_deps
    DEPENDENCIES="${user_deps:-network-online.target}"
fi

if [ -z "$REMAIN_ACTIVE" ]; then
    printf "Keep service active after completion? (y/n) [n]: "
    read -r user_remain
    case "$user_remain" in
        [Yy]*) REMAIN_ACTIVE="yes" ;;
        *) REMAIN_ACTIVE="no" ;;
    esac
fi

# Format dependencies for After/Requires
formatted_deps="$DEPENDENCIES"

# Set RemainAfterExit if requested
if [ "$REMAIN_ACTIVE" = "yes" ]; then
    remain_after_exit="RemainAfterExit=yes"
else
    remain_after_exit=""
fi

# Generate the task service file
echo "Generating task-$NAME.service.template..."

# Start with base template
sed -e "s/{{DESCRIPTION}}/$DESCRIPTION/g" \
    -e "s/{{SCRIPT_NAME}}/$SCRIPT_NAME/g" \
    -e "s/{{AFTER}}/$formatted_deps/g" \
    -e "s/{{REQUIRES}}/$formatted_deps/g" \
    -e "s/{{REMAIN_AFTER_EXIT}}/$remain_after_exit/g" \
    templates/base.task.template > "services/task-$NAME.service.template"

echo "Created services/task-$NAME.service.template"
echo ""
echo "Next steps:"
echo "  1. Create the script file:"
echo "     touch scripts/$SCRIPT_NAME"
echo "     chmod +x scripts/$SCRIPT_NAME"
echo ""
echo "  2. Enable auto-start in systemd.yaml.template:"
echo "     - name: task-$NAME.service"
echo "       enabled: true"
echo ""
echo "  3. Build and test:"
echo "     make generate && make build"
echo ""
echo "Task types:"
echo "  Init tasks:   RemainAfterExit=yes (run once, stay active)"
echo "  Job tasks:    RemainAfterExit=no (run and exit)"
echo "  Timer tasks:  Create matching timer with 'make new timer $NAME'"
