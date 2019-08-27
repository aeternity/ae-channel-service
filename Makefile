.POSIX:

mix := mix
aeminer_path := apps/aecore/aeminer
sparse_path := sparse
sparse_git_path := $(sparse_path)/.git/info/sparse-checkout

all: help

.PHONY: deps
deps: prepare
deps: ## Get and compile Elixir dependencies
	$(mix) do deps.get, deps.compile

.PHONY: compile
compile: ## Compile Elixir code
	$(mix) compile

.PHONY: format
format: ## Format Elixir code
	$(mix) format

.PHONY: clean
clean: ## Clean all artifacts
	$(mix) clean
	rm -rf \
		test/ \
		$(sparse_path)/ \
		$(aeminer_path)/ \
		apps/aecore \
		apps/aetx \
		apps/aechannel \
		apps/aecontract

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
	cd $@ && \
		git pull origin master && \
		git checkout a2fdf3bfcc1a0610e9bf02a4abe7a42b28dfb4e0
	cd $@apps && \
		yes | $(mix) new aecore && \
		yes | $(mix) new aetx && \
		yes | $(mix) new aechannel && \
		yes | $(mix) new aecontract

$(aeminer_path)/: ## Get known version of aeminer
	git clone https://github.com/aeternity/aeminer.git $@
	cd $@ && git checkout 1cf2ecfd83f6ca3ec21a183f730083cf63ae7feb

.PHONY: prepare
prepare: $(sparse_path)/ $(aeminer_path)/
prepare: ## Get and prepare additional dependencies from Aeternity Core
	cp -r $(sparse_path)/apps .
	git apply patches/0001-aechannel-now-builds.patch
	git apply patches/0001-aecore-patches.patch

.PHONY: help
help:
		@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
