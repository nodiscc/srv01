#!/usr/bin/env make
SHELL := '/bin/bash'

tests: shellcheck check_jinja2 ansible_syntax_check ansible_lint yamllint clean

# Install dev tools in virtualenv
# https://pypi.org/rss/project/ansible/releases.xml
venv:
	python3 -m venv .venv && \
	source .venv/bin/activate && \
	pip3 install wheel && \
	pip3 install isort ansible-lint yamllint ansible==2.10.0

# Static syntax checker for shell scripts
# requirements: sudo apt install shellcheck
shellcheck:
	# ignore 'Can't follow non-constant source' warnings
	shellcheck -e SC1090 xsrv

testenv:
	cp tests/playbook.yml test.yml

clean:
	-rm -r test.yml .venv/ nodiscc-xsrv-*.tar.gz

# Playbook syntax check
ansible_syntax_check: venv testenv
	source .venv/bin/activate && \
	ansible-playbook --syntax-check --inventory tests/inventory.yml test.yml

# Ansible linter - https://pypi.org/rss/project/ansible-lint/releases.xml
ansible_lint: venv testenv
	source .venv/bin/activate && \
	ansible-lint test.yml

# YAML syntax check and linter
yamllint: venv
	source .venv/bin/activate && \
	set -o pipefail && \
	find roles/ -iname "*.yml" | xargs yamllint -c tests/.yamllint

check_jinja2: venv
	source .venv/bin/activate && \
	j2_files=$$(find roles/ -name "*.j2") && \
	for i in $$j2_files; do \
	echo "[INFO] checking syntax for $$i"; \
	python3 ./tests/check-jinja2.py "$$i"; \
	done

# Update TODO.md by fetching issues from the main gitea instance API
# requirements: sudo apt install git jq
#               gitea-cli config defined in ~/.config/gitearc
update_todo:
	git clone https://github.com/bashup/gitea-cli gitea-cli
	echo '<!-- This file is automatically generated by "make update_todo" -->' >| docs/TODO.md
	echo -e "\n### xsrv/xsrv\n" >> docs/TODO.md; \
	./gitea-cli/bin/gitea issues xsrv/xsrv | jq -r '.[] | "- #\(.number) - \(.title)"' >> docs/TODO.md
	rm -rf gitea-cli

# build and publish the ansible collection
# ANSIBLE_GALAXY_PRIVATE_TOKEN must be defined in the environment
publish_collection: venv
	tag=$$(git describe --tags --abbrev=0) && \
	sed -i "s/^version:.*/version: $$tag/" galaxy.yml && \
	source .venv/bin/activate && \
	ansible-galaxy collection build && \
	ansible-galaxy collection publish --token "$$ANSIBLE_GALAXY_PRIVATE_TOKEN" nodiscc-xsrv-$$tag.tar.gz


# list all variables names from role defaults
# can be used to establish a list of variables that need to be checked via 'assert' tasks at the beginnning of the role
list_default_variables:
	for i in roles/*; do \
	echo -e "\n#### $$i #####\n"; \
	grep --no-filename -E --only-matching "^(# )?[a-z\_]*:" $$i/defaults/main.yml | sed 's/# //' | sort -u ; \
	done

# get build status of the current commit/branch
# GITLAB_PRIVATE_TOKEN must be defined in the environment
get_build_status:
	@branch=$$(git rev-parse --abbrev-ref HEAD) && \
	commit=$$(git rev-parse HEAD) && \
	curl --silent --header "PRIVATE-TOKEN: $$GITLAB_PRIVATE_TOKEN" "https://gitlab.com/api/v4/projects/nodiscc%2Fxsrv/repository/commits/$$commit/statuses?ref=$$branch" | jq  .[].status
