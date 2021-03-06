PATH        := ./node_modules/.bin:${PATH}

NPM_PACKAGE := $(shell node -e 'console.log(require("./package.json").name)')
NPM_VERSION := $(shell node -e 'console.log(require("./package.json").version)')

TMP_PATH    := /tmp/${NPM_PACKAGE}-$(shell date +%s)

REMOTE_NAME ?= origin
REMOTE_REPO ?= $(shell git config --get remote.${REMOTE_NAME}.url)

CUT         := command -v gcut || command -v cut
CURR_HEAD   := $(firstword $(shell git show-ref --hash HEAD | ${CUT} --bytes=-6) master)
GITHUB_PROJ := trott/${NPM_PACKAGE}

CP          := command -v gcp || command -v cp

help:
	echo "make help       - Print this help"
	echo "make lint       - Lint sources with JSHint"
	echo "make test       - Lint sources and run all tests"
	echo "make doc        - Build API docs"
	echo "make gh-pages   - Build and push API docs into gh-pages branch"
	echo "make publish    - Set new version tag and publish npm package"
	echo "make todo       - Find and list all TODOs"


lint:
	npx jshint . --show-non-errors

test: lint
	rm -rf ./tmp/sandbox && mkdir -p ./tmp/sandbox
	$(shell ${CP}) -r ./support/sandbox-template ./tmp/sandbox/copy
	$(shell ${CP}) -r ./support/sandbox-template ./tmp/sandbox/mkdir
	$(shell ${CP}) -r ./support/sandbox-template ./tmp/sandbox/mkdir-sync
	$(shell ${CP}) -r ./support/sandbox-template ./tmp/sandbox/remove
	$(shell ${CP}) -r ./support/sandbox-template ./tmp/sandbox/remove-sync
	$(shell ${CP}) -r ./support/sandbox-template ./tmp/sandbox/walk
	$(shell ${CP}) -r ./support/sandbox-template ./tmp/sandbox/walk-sync
	$(shell ${CP}) -r ./support/sandbox-template ./tmp/sandbox/move
	$(shell ${CP}) -r ./support/sandbox-template ./tmp/sandbox/find-sorted
	npx tape ./test/*-test.js

doc:
	rm -rf ./doc
	ndoc --link-format "{package.homepage}/blob/${CURR_HEAD}/{file}#L{line}"

gh-pages:
	@if test -z ${REMOTE_REPO} ; then \
		echo 'Remote repo URL not found' >&2 ; \
		exit 128 ; \
		fi
	$(MAKE) doc && \
		${CP} -r ./doc ${TMP_PATH} && \
		touch ${TMP_PATH}/.nojekyll
	cd ${TMP_PATH} && \
		git init && \
		git add . && \
		git commit -q -m 'Recreated docs'
	cd ${TMP_PATH} && \
		git remote add remote ${REMOTE_REPO} && \
		git push --force remote +master:gh-pages 
	rm -rf ${TMP_PATH}


publish:
	@if test 0 -ne `git status --porcelain | wc -l` ; then \
		echo "Unclean working tree. Commit or stash changes first." >&2 ; \
		exit 128 ; \
		fi
	@if test 0 -ne `git fetch ; git status | grep '^# Your branch' | wc -l` ; then \
		echo "Local/Remote history differs. Please push/pull changes." >&2 ; \
		exit 128 ; \
		fi
	@if test 0 -ne `git tag -l ${NPM_VERSION} | wc -l` ; then \
		echo "Tag ${NPM_VERSION} exists. Update package.json" >&2 ; \
		exit 128 ; \
		fi
	git tag ${NPM_VERSION} && git push origin ${NPM_VERSION}
	npm publish https://github.com/${GITHUB_PROJ}/tarball/${NPM_VERSION}


todo:
	grep 'TODO' -n -r ./lib 2>/dev/null || test true


.PHONY: publish lint test doc gh-pages todo
.SILENT: help lint test doc todo
