.POSIX:

mix := mix
repo_name := aeternity
release_version := latest
aeternity_url := https://api.github.com/repos/aeternity/${repo_name}/releases/$(release_version)
release_tarball := $(repo_name)/$(repo_name).tar.gz

all: help

.PHONY: deps
deps: prepare
deps: ## Get and compile Elixir dependencies
	$(mix) deps.get

.PHONY: compile
compile: ## Compile Elixir code
	$(mix) compile

.PHONY: shell
shell: ## Launch a mix shell with all modules compiled and loaded
	iex -S mix

.PHONY: format
format: ## Format Elixir code
	$(mix) format

.PHONY: clean
clean: ## Clean all artifacts
	$(mix) clean
	rm -rf \
		$(repo_name)/ \
		_build \
		deps \
		rebar.lock \
		rebar.config

$(release_tarball): ## Get dependencies from Aeternity Core
	mkdir -p $(repo_name)
	curl -s $(aeternity_url) | \
		jq '.assets[1].browser_download_url' | \
		xargs curl -L --output $@

.PHONY: prepare
prepare: $(release_tarball)
prepare: ## Get and  prepare additional dependencies from Aeternity Core
	cd $(repo_name) && tar -xf $(repo_name).tar.gz

.PHONY: test
test:
	docker-compose pull
	docker-compose up -d --force-recreate
	AE_NODE_NETWORK_ID="ae_channel_service_test" mix test --exclude ignore

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
