[Unit]
Description={{DESCRIPTION}}
After={{AFTER}}
Requires={{REQUIRES}}

[Service]
Type=oneshot
ExecStart=/usr/bin/sh /var/scripts/{{SCRIPT_NAME}}
User=root
StandardOutput=journal
StandardError=journal
{{REMAIN_AFTER_EXIT}}

[Install]
WantedBy=multi-user.target