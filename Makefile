NAME   := homelab-config
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
CYAN   := $(shell tput -Txterm setaf 6)
WHITE  := $(shell tput -Txterm setaf 7)
RED    := $(shell tput -Txterm setaf 1)
RESET  := $(shell tput -Txterm sgr0)

.DEFAULT_GOAL := all

.PHONY: all build serve clean generate help lint lint-yaml lint-shell validate-butane validate-systemd validate-templates
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

service:
	@: 

timer:
	@:

task:
	@:

clean: ## Cleanup all temporary files and build artifacts.
	@printf "\n${WHITE}[BUILD]${RESET} Cleaning up... "
	@rm -rf build/
	@printf "${GREEN}[DONE]${RESET}\n"

generate: ## Generates templates for build process.
	@printf "${WHITE}[BUILD]${RESET} Generating templates... "
	@mkdir -p build/scripts build/profile build/security build/services

	# copy static files to build directory
	@cp scripts/* build/scripts/
	@cp profile/* build/profile/ 2>/dev/null || true
	@cp profile/.[^.]* build/profile/ 2>/dev/null || true

	# resolve all 1Password references from default.env first
	@eval $$(grep -v '^#' default.env | grep -v '^$$' | while IFS='=' read -r key value; do \
	   if echo "$$value" | grep -q '^op://'; then \
	     resolved_value=$$(op read "$$value"); \
	     if [ "$$key" = "CORE_PASSWORD" ]; then \
	       hashed_value=$$(openssl passwd -6 "$$resolved_value"); \
	       echo "export $$key=\"$$hashed_value\""; \
	     else \
	       echo "export $$key=\"$$resolved_value\""; \
	     fi; \
	   else \
	     echo "export $$key=\"$$value\""; \
	   fi; \
	 done); \
	 \
	 find . -name "*.template" -type f -not -path "./build/*" | while read -r template; do \
	   relative_path=$${template#./}; \
	   output_dir="build/$$(dirname "$$relative_path")"; \
	   output_file="$$output_dir/$$(basename "$$relative_path" .template)"; \
	   mkdir -p "$$(dirname "$$output_file")"; \
	   envsubst < "$$template" > "$$output_file"; \
	 done

	@printf "${GREEN}[DONE]${RESET}\n"

build: clean generate validate-templates ## Primary build task. Validates and generates ignition file
	@printf "${WHITE}[BUILD]${RESET} Building and validating... "
	@version=$$(date +%Y%m%dT%H%M%S); \
	 cat build/users.yaml build/storage.yaml build/systemd.yaml > build/merged_$${version}.yaml; \
	 butane -d build --pretty -o build/ignition_$${version}.json build/merged_$${version}.yaml; \
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

lint: lint-yaml lint-shell validate-butane validate-systemd validate-templates ## Run all local linting and validation checks.

lint-yaml: ## Lint YAML files with yamllint.
	@printf "\n${WHITE}[LINT]${RESET} Checking YAML files... "
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint -c .yamllint.yml *.yaml.template services/ && printf "${GREEN}[PASS]${RESET}\n" || printf "${RED}[FAIL]${RESET}\n"; \
	elif [ -f "$$HOME/.local/bin/yamllint" ]; then \
		$$HOME/.local/bin/yamllint -c .yamllint.yml *.yaml.template services/ && printf "${GREEN}[PASS]${RESET}\n" || printf "${RED}[FAIL]${RESET}\n"; \
	elif [ -f "/Users/brandon/Library/Python/3.9/bin/yamllint" ]; then \
		/Users/brandon/Library/Python/3.9/bin/yamllint -c .yamllint.yml *.yaml.template services/ && printf "${GREEN}[PASS]${RESET}\n" || printf "${RED}[FAIL]${RESET}\n"; \
	else \
		printf "${YELLOW}[SKIP] yamllint not found${RESET}\n"; \
	fi

lint-shell: ## Lint shell scripts with shellcheck.
	@printf "${WHITE}[LINT]${RESET} Checking shell scripts... "
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck scripts/*.sh && printf "${GREEN}[PASS]${RESET}\n" || printf "${RED}[FAIL]${RESET}\n"; \
	else \
		printf "${YELLOW}[SKIP] shellcheck not found${RESET}\n"; \
	fi

validate-butane: ## Validate Butane configuration files.
	@printf "${WHITE}[LINT]${RESET} Validating Butane configs... "
	@mkdir -p temp-validate/scripts temp-validate/profile temp-validate/services
	@echo "dummy content" > temp-validate/credentials
	@echo "dummy content" > temp-validate/scripts/backup.sh
	@echo "dummy content" > temp-validate/scripts/init-deps.sh
	@echo "dummy content" > temp-validate/scripts/init-shared.sh
	@echo "dummy content" > temp-validate/scripts/init-services.sh
	@echo "dummy content" > temp-validate/scripts/init-networks.sh
	@echo "dummy content" > temp-validate/profile/starship.toml
	@echo "dummy content" > temp-validate/profile/.zshrc
	@for service in services/*.template; do \
		filename=$$(basename "$$service" .template); \
		echo "dummy content" > "temp-validate/services/$$filename"; \
	done
	@cat users.yaml.template storage.yaml.template systemd.yaml.template > temp-config.yaml
	@sed 's/\$$CORE_PASSWORD/dummy-hash/g; s/\$$CORE_SSH/dummy-key/g' temp-config.yaml > temp-validate/merged.yaml
	@if command -v butane >/dev/null 2>&1; then \
		butane -d temp-validate --strict temp-validate/merged.yaml > /dev/null && printf "${GREEN}[PASS]${RESET}\n" || printf "${RED}[FAIL]${RESET}\n"; \
	elif command -v podman >/dev/null 2>&1; then \
		podman run --rm -v "$$(pwd):/pwd:Z" -w /pwd quay.io/coreos/butane:release -d temp-validate --strict temp-validate/merged.yaml > /dev/null && printf "${GREEN}[PASS]${RESET}\n" || printf "${RED}[FAIL]${RESET}\n"; \
	elif command -v docker >/dev/null 2>&1; then \
		docker run --rm -v "$$(pwd):/pwd" -w /pwd quay.io/coreos/butane:release -d temp-validate --strict temp-validate/merged.yaml > /dev/null && printf "${GREEN}[PASS]${RESET}\n" || printf "${RED}[FAIL]${RESET}\n"; \
	else \
		printf "${YELLOW}[SKIP] butane, podman, and docker not found${RESET}\n"; \
	fi
	@rm -rf temp-config.yaml temp-validate

validate-systemd: ## Validate SystemD service files.
	@printf "${WHITE}[LINT]${RESET} Validating SystemD services... "
	@if command -v systemd-analyze >/dev/null 2>&1; then \
		if [ "$$CI" = "true" ] || ! systemctl list-units rpm-ostreed.service >/dev/null 2>&1; then \
			printf "${CYAN}Basic syntax validation (CI/non-CoreOS mode)${RESET}\n"; \
			for service in services/*.template; do \
				printf "  Checking $$service... "; \
				if grep -E '^\[Unit\]|^\[Service\]|^\[Install\]|^\[Timer\]' "$$service" >/dev/null; then \
					printf "${GREEN}OK${RESET}\n"; \
				else \
					printf "${RED}FAIL - missing required sections${RESET}\n"; \
					exit 1; \
				fi; \
			done; \
			printf "${GREEN}[PASS]${RESET}\n"; \
		else \
			for service in services/*.template; do \
				systemd-analyze verify "$$service" || exit 1; \
			done && printf "${GREEN}[PASS]${RESET}\n" || printf "${RED}[FAIL]${RESET}\n"; \
		fi; \
	else \
		printf "${CYAN}Basic syntax validation (systemd-analyze not available)${RESET}\n"; \
		for service in services/*.template; do \
			printf "  Checking $$service... "; \
			if grep -E '^\[Unit\]|^\[Service\]|^\[Install\]|^\[Timer\]' "$$service" >/dev/null; then \
				printf "${GREEN}OK${RESET}\n"; \
			else \
				printf "${RED}FAIL - missing required sections${RESET}\n"; \
				exit 1; \
			fi; \
		done; \
		printf "${GREEN}[PASS]${RESET}\n"; \
	fi

validate-templates: ## Validate that referenced services have corresponding template files.
	@printf "${WHITE}[LINT]${RESET} Validating template references... "
	@missing_templates=""; \
	for service in $$(grep -E '^\s*-\s*name:\s*' systemd.yaml.template | sed 's/.*name:[[:space:]]*//; s/[[:space:]]*$$//'); do \
		template_file="services/$$service.template"; \
		if [ ! -f "$$template_file" ]; then \
			if [ -z "$$missing_templates" ]; then \
				missing_templates="$$service"; \
			else \
				missing_templates="$$missing_templates, $$service"; \
			fi; \
		fi; \
	done; \
	if [ -n "$$missing_templates" ]; then \
		printf "${RED}[FAIL]${RESET}\n"; \
		printf "${RED}Missing template files for: $$missing_templates${RESET}\n"; \
		printf "${YELLOW}Create missing templates with:${RESET}\n"; \
		for service in $$(echo "$$missing_templates" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$$//'); do \
			case "$$service" in \
				container-*) printf "  make new service NAME=$$(echo $$service | sed 's/container-//; s/.service$$//')\n" ;; \
				task-*.timer) printf "  make new timer NAME=$$(echo $$service | sed 's/task-//; s/.timer$$//')\n" ;; \
				task-*) printf "  make new task NAME=$$(echo $$service | sed 's/task-//; s/.service$$//')\n" ;; \
				*) printf "  Create: services/$$service.template\n" ;; \
			esac; \
		done; \
		exit 1; \
	else \
		printf "${GREEN}[PASS]${RESET}\n"; \
	fi
