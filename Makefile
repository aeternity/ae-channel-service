.POSIX:

mix := mix
aeminer_path := apps/aecore/aeminer
sparse_path := sparse
sparse_git_path := $(sparse_path)/.git/info/sparse-checkout
aecore_git_hash := ed54d2e625fdcf7cf7b0189cd213090edbf3a565
aeminer_git_hash := 1cf2ecfd83f6ca3ec21a183f730083cf63ae7feb

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
		$(sparse_path)/ \
		$(aeminer_path)/ \
		apps/aecore \
		apps/aetx \
		apps/aechannel \
		apps/aecontract \
		apps/aeutils \
		_build \
		deps \
		rebar.lock \
		rebar.config

$(sparse_path)/: ## Get dependencies from Aeternity Core and build Elixir wrapper apps
	mkdir -p $@
	cd $@ && \
		git init && \
		git remote add -f origin https://github.com/aeternity/aeternity.git && \
		git config core.sparseCheckout true
	echo "aecore" >> $(sparse_git_path)
	echo "aetx" >> $(sparse_git_path)
	echo "aechannel" >> $(sparse_git_path)
	echo "aechannel" >> $(sparse_git_path)
	echo "aecontract" >> $(sparse_git_path)
	echo "aeutils" >> $(sparse_git_path)
	cd $@ && \
		git pull origin master && \
		git checkout $(aecore_git_hash)
	cd $@/apps && \
		yes | $(mix) new aecore && \
		yes | $(mix) new aetx && \
		yes | $(mix) new aechannel && \
		yes | $(mix) new aecontract && \
		yes | $(mix) new aeutils

$(aeminer_path)/: ## Get known version of aeminer
	git clone https://github.com/aeternity/aeminer.git $@
	cd $@ && git checkout ${aeminer_git_hash}

.PHONY: prepare
prepare: $(sparse_path)/ $(aeminer_path)/
prepare: ## Get and prepare additional dependencies from Aeternity Core
	cp -r $(sparse_path)/apps .
	$(foreach p,$(wildcard ./patches/*.patch),git apply ${p};)

.PHONY: test
test:
	docker-compose pull
	docker-compose up -d --force-recreate
	mix test --exclude ignore

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
