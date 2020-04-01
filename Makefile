.POSIX:

mix := mix
repo_name := aeternity
release_version := latest
platform := ubuntu
aeternity_url := https://api.github.com/repos/aeternity/${repo_name}/releases/$(release_version)

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

$(repo_name)/: ## Get dependencies from Aeternity Core
	mkdir -p $@
	cd $@ && \
	curl -s $(aeternity_url) \
	| grep -E 'browser_download_url' \
	| cut -d '"' -f 4 | grep -E "*-$(platform)-*" \
	| xargs curl -L --output $(repo_name).tar.gz

.PHONY: prepare
prepare: $(repo_name)/
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
