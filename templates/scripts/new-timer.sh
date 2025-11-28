#!/bin/sh

# Parse parameters
NAME="$1"
DESCRIPTION="$2"  
SCHEDULE="$3"

# Interactive prompts if not provided
if [ -z "$NAME" ]; then
    printf "Timer name: "
    read -r NAME
fi

if [ -z "$NAME" ]; then
    echo "ERROR: Timer name is required"
    exit 1
fi

if [ -f "services/task-$NAME.timer.tpl" ]; then
    echo "WARNING: services/task-$NAME.timer.tpl already exists"
    exit 1
fi

if [ -z "$DESCRIPTION" ]; then
    printf "Description (e.g., Daily backup task): "
    read -r DESCRIPTION
fi

if [ -z "$DESCRIPTION" ]; then
    echo "ERROR: Description is required"
    exit 1
fi

if [ -z "$SCHEDULE" ]; then
    printf "Schedule (systemd OnCalendar format, e.g., '*-*-* 04:00:00' for daily at 4am): "
    read -r SCHEDULE
fi

if [ -z "$SCHEDULE" ]; then
    echo "ERROR: Schedule is required"
    exit 1
fi

# Generate the timer file
echo "Generating task-$NAME.timer.tpl..."

# Start with base template
sed -e "s/{{DESCRIPTION}}/$DESCRIPTION/g" \
    -e "s/{{SCHEDULE}}/$SCHEDULE/g" \
    templates/base.timer.tpl > "services/task-$NAME.timer.tpl"

echo "Created services/task-$NAME.timer.tpl"
echo "Next steps:"
echo "  1. Review and customize services/task-$NAME.timer.tpl"
echo "  2. Create corresponding task-$NAME.service.tpl (if it doesn't exist)"
echo "  3. Add to systemd.yaml.tpl to enable the timer"  
echo "  4. Run 'make generate' to test"
echo ""
echo "Common OnCalendar examples:"
echo "  Daily at 4am:     *-*-* 04:00:00"
echo "  Every hour:       *:0:0"
echo "  Every 15 minutes: *:0/15"
echo "  Weekly on Sunday: Sun *-*-* 02:00:00"
echo "  Monthly on 1st:   *-*-01 03:00:00"