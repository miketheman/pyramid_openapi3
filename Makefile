# Convenience makefile to build the dev env and run common commands
# Based on https://github.com/niteoweb/Makefile

PYTHON ?= python3.11

.PHONY: all
all: tests

# Lock version pins for Python dependencies
.PHONY: lock
lock:
	@rm -rf .venv/
	@poetry lock --no-update
	@rm -rf .venv/
	@nix-shell --run true
	@direnv reload
	@cat pyproject.toml \
		| sed 's/openapi-core = ">=/openapi-core = "==/g' \
		| sed 's/pyramid = ">=/pyramid = "==/g' \
		> py39/pyproject.toml
	@rm -rf .venv/
	@poetry lock --no-update --directory py39
	@rm -rf .venv/
	@nix-shell --run true
	@direnv reload

# Testing and linting targets
all = false

.PHONY: lint
lint:
# 1. get all unstaged modified files
# 2. get all staged modified files
# 3. get all untracked files
# 4. run pre-commit checks on them
ifeq ($(all),true)
	@pre-commit run --hook-stage push --all-files
else
	@{ git diff --name-only ./; git diff --name-only --staged ./;git ls-files --other --exclude-standard; } \
		| sort -u | uniq | xargs pre-commit run --hook-stage push --files
endif

.PHONY: type
type: types

.PHONY: types
types: .
	@mypy examples/todoapp
	@cat ./typecov/linecount.txt
	@typecov 100 ./typecov/linecount.txt
	@mypy pyramid_openapi3
	@cat ./typecov/linecount.txt
	@typecov 100 ./typecov/linecount.txt


# anything, in regex-speak
filter = "."

# additional arguments for pytest
full_suite = "false"
ifeq ($(filter),".")
	full_suite = "true"
endif
ifdef path
	full_suite = "false"
endif
args = ""
pytest_args = -k $(filter) $(args)
ifeq ($(args),"")
	pytest_args = -k $(filter)
endif
verbosity = ""
ifeq ($(full_suite),"false")
	verbosity = -vv
endif
full_suite_args = ""
ifeq ($(full_suite),"true")
	full_suite_args = --junitxml junit.xml --durations 10 --cov=pyramid_openapi3 --cov-branch --cov-report html --cov-report xml:cov.xml --cov-report term-missing --cov-fail-under=100
endif


.PHONY: unit
unit:
ifndef path
	@$(PYTHON) -m pytest pyramid_openapi3 $(verbosity) $(full_suite_args) $(pytest_args)
else
	@$(PYTHON) -m pytest $(path)
endif

.PHONY: test
test: tests

.PHONY: tests
tests: lint types unit
