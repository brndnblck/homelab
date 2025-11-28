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

if [ -f "services/task-$NAME.service.tpl" ]; then
    echo "WARNING: services/task-$NAME.service.tpl already exists"
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
echo "Generating task-$NAME.service.tpl..."

# Start with base template
sed -e "s/{{DESCRIPTION}}/$DESCRIPTION/g" \
    -e "s/{{SCRIPT_NAME}}/$SCRIPT_NAME/g" \
    -e "s/{{AFTER}}/$formatted_deps/g" \
    -e "s/{{REQUIRES}}/$formatted_deps/g" \
    -e "s/{{REMAIN_AFTER_EXIT}}/$remain_after_exit/g" \
    templates/base.task.tpl > "services/task-$NAME.service.tpl"

echo "Created services/task-$NAME.service.tpl"
echo "Next steps:"
echo "  1. Create the script: scripts/$SCRIPT_NAME"
echo "  2. Make it executable: chmod +x scripts/$SCRIPT_NAME" 
echo "  3. Review and customize services/task-$NAME.service.tpl"
echo "  4. Add to systemd.yaml.tpl if auto-start desired"
echo "  5. Run 'make generate' to test"
echo ""
echo "Task types:"
echo "  Init tasks:   RemainAfterExit=yes (run once, stay active)"
echo "  Job tasks:    RemainAfterExit=no (run and exit)"
echo "  Timer tasks:  Create matching .timer.tpl with 'make new timer $NAME'"