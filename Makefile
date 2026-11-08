NAME   := homelab-config
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
CYAN   := $(shell tput -Txterm setaf 6)
WHITE  := $(shell tput -Txterm setaf 7)
RED    := $(shell tput -Txterm setaf 1)
RESET  := $(shell tput -Txterm sgr0)

.DEFAULT_GOAL := all
.SHELLFLAGS := -eu -c

.PHONY: all build serve clean generate help lint lint-yaml lint-shell lint-python validate-butane validate-systemd validate-templates test
.ONESHELL: all build serve clean generate help lint lint-yaml lint-shell validate-butane validate-systemd validate-templates

print-header:
	@echo "\n:::    :::  ::::::::  ::::    ::::  :::::::::: :::            :::     :::::::::  "
	@echo ":+:    :+: :+:    :+: +:+:+: :+:+:+ :+:        :+:          :+: :+:   :+:    :+: "
	@echo "+:+    +:+ +:+    +:+ +:+ +:+:+ +:+ +:+        +:+         +:+   +:+  +:+    +:+ "
	@echo "+#++:++#++ +#+    +:+ +#+  +:+  +#+ +#++:++#   +#+        +#++:++#++: +#++:++#+  "
	@echo "+#+    +#+ +#+    +#+ +#+       +#+ +#+        +#+        +#+     +#+ +#+    +#+ "
	@echo "#+#    #+# #+#    #+# #+#       #+# #+#        #+#        #+#     #+# #+#    #+# "
	@echo "###    ###  ########  ###       ### ########## ########## ###     ### #########  "
	@printf "                                                                "
	@echo "${YELLOW}Version: $$(git rev-parse --short HEAD)${RESET}"

all: print-header help

help: print-header ## Show this help.
	@echo ''
	@echo 'Usage:\n'
	@echo '  ${WHITE}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:\n'
	@awk 'BEGIN {FS = ":.*?## "} { \
		if (/^[a-zA-Z_-]+:.*?##.*$$/) {printf "  ${GREEN}%-20s${WHITE}%s${RESET}\n", $$1, $$2} \
		else if (/^## .*$$/) {printf "\n${WHITE}%s:${RESET}\n\n", substr($$1,4)} \
		}' $(MAKEFILE_LIST)

clean: ## Cleanup all temporary files and build artifacts.
	@printf "\n${WHITE}[BUILD]${RESET} Cleaning up... "
	@rm -rf build/
	@printf "${GREEN}[DONE]${RESET}\n"

generate: ## Generates templates for build process.
	@printf "${WHITE}[BUILD]${RESET} Generating templates... "
	@uv run --locked tools/config.py build
	@printf "${GREEN}[DONE]${RESET}\n"

build: validate-templates ## Primary build task. Validates and generates ignition file
	@printf "${WHITE}[BUILD]${RESET} Building and validating... "
	@$(MAKE) clean
	@$(MAKE) generate
	@version=$$(date +%Y%m%dT%H%M%S); \
	 butane --strict -d build --pretty -o build/ignition_$${version}.json build/merged.yaml; \
	 ln -sf ignition_$${version}.json build/latest
	@printf "${GREEN}[DONE]${RESET}\n"

serve: build ## Builds and serves the latest ignition file for local consumption.
	@ip_address=$$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $$2}')
	@echo "\nServing on http://$${ip_address}:8080/latest..."
	@stty -echoctl
	@trap 'echo "\n${YELLOW}Termination signal received...${RESET}\n"; kill $$(jobs -p); make clean; exit 0' INT TERM
	@python3 -m http.server 8080 --directory build & wait
	@stty echoctl

## Development Commands

new: ## Create new resources: 'make new [service,timer,task]'
	@if [ "$(filter service,$(MAKECMDGOALS))" ]; then \
		./templates/scripts/new-service.sh "$(NAME)" "$(IMAGE)" "$(PORTS)" "$(VOLUMES)" "$(HEALTH_PORT)"; \
	elif [ "$(filter timer,$(MAKECMDGOALS))" ]; then \
		./templates/scripts/new-timer.sh "$(NAME)" "$(DESCRIPTION)" "$(SCHEDULE)"; \
	elif [ "$(filter task,$(MAKECMDGOALS))" ]; then \
		./templates/scripts/new-task.sh "$(NAME)" "$(DESCRIPTION)" "$(SCRIPT)" "$(AFTER)" "$(REMAIN_ACTIVE)"; \
	else \
		echo "\n${WHITE}Usage:${RESET}\n"; \
		echo "  ${GREEN}make new service${RESET} NAME=jellyfin IMAGE=jellyfin/jellyfin:latest PORTS=8096:8096"; \
		echo "  ${GREEN}make new timer${RESET} NAME=backup DESCRIPTION=\"Daily backup\" SCHEDULE=\"*-*-* 02:00:00\""; \
		echo "  ${GREEN}make new task${RESET} NAME=deps SCRIPT=init-deps.sh REMAIN_ACTIVE=yes"; \
		echo "\n${WHITE}Interactive Mode:${RESET}"; \
		echo "  ${GREEN}make new service${RESET} | ${GREEN}make new timer${RESET} | ${GREEN}make new task${RESET}"; \
	fi

service:
	@: 

timer:
	@:

task:
	@:

lint: lint-yaml lint-shell lint-python validate-butane validate-systemd validate-templates test ## Run all local linting and validation checks.

lint-yaml: ## Lint YAML files with yamllint.
	@uv run --locked yamllint -c .yamllint.yml *.yaml.template .github/workflows/

lint-shell: ## Lint shell scripts with shellcheck.
	@shellcheck -x -P scripts scripts/*.sh

lint-python: ## Check Python scripts, tools, and tests with Ruff.
	@uv run --locked ruff check scripts/*.py tools tests
	@uv run --locked ruff format --check scripts/*.py tools tests

validate-butane: ## Validate Butane configuration files.
	@uv run --locked tools/validate.py --butane

validate-systemd: ## Validate SystemD service files.
	@uv run --locked tools/validate.py --systemd

validate-templates: ## Validate that referenced services have corresponding template files.
	@uv run --locked tools/validate.py

test: ## Test configuration, storage safeguards, and backup failure handling.
	@uv run --locked python -m unittest discover -s tests -v
