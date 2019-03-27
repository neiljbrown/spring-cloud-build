#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"
	
	cp -a "${SOURCE_DIR}" "${TEMP_DIR}/sc-build"

	cp -a "${FIXTURES_DIR}/spring-cloud-stream" "${TEMP_DIR}/"
	mv "${TEMP_DIR}/spring-cloud-stream/git" "${TEMP_DIR}/spring-cloud-stream/.git"
	cp -a "${FIXTURES_DIR}/spring-cloud-static" "${TEMP_DIR}/"
	mv "${TEMP_DIR}/spring-cloud-static/git" "${TEMP_DIR}/spring-cloud-static/.git"

	export SOURCE_FUNCTIONS="true"
}

teardown() {
	rm -rf "${TEMP_DIR}"
}

function fake_git {
	if [[ "$*" == *"push"* ]]; then
		echo "pushing the project"
	elif [[ "$*" == *"pull"* ]]; then
		echo "pulling the project"
	fi
	git $*
}

function git_with_remotes {
	if [[ "$*" == *"set-url"* ]]; then
		echo "git $*"
	elif [[ "$*" == *"config remote.origin.url"* ]]; then
		echo "git://foo.bar/baz.git"
	else 
		git $*
	fi
}

function printing_git {
	echo "git $*"
}

export -f fake_git
export -f git_with_remotes
export -f printing_git

@test "should set all the env vars" {
	export SPRING_CLOUD_STATIC_REPO="${TEMP_DIR}/spring-cloud-static"

	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	set_default_props

	assert_success
	assert [ "${ROOT_FOLDER}" != "" ]
	assert [ "${MAVEN_EXEC}" != "" ]
	assert [ "${REPO_NAME}" != "" ]
	assert [ "${SPRING_CLOUD_STATIC_REPO}" != "" ]
}

@test "should not add auth token to URL if token not present" {
	export GIT_BIN="git_with_remotes"
	
	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	run add_oauth_token_to_remote_url

	assert_success
	assert_output --partial "git remote set-url --push origin https://foo.bar/baz.git"
}

@test "should add auth token to URL if token is present" {
	export GIT_BIN="git_with_remotes"
	export RELEASER_GIT_OAUTH_TOKEN="mytoken"
	
	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	run add_oauth_token_to_remote_url

	assert_success
	assert_output --partial "git remote set-url --push origin https://mytoken@foo.bar/baz.git"
}

@test "should retrieve the name of the current branch" {
	export GIT_BIN="printing_git"
	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	run retrieve_current_branch

	assert_success
	assert_output --partial "git checkout git symbolic-ref -q HEAD"
}

@test "should retrieve the name of the current branch when previous branch was set" {
	export GIT_BIN="printing_git"
	export BRANCH="gh-pages"
	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	run retrieve_current_branch

	assert_success
	assert_output --partial "Current branch is [gh-pages]"
	refute_output --partial "git checkout git symbolic-ref -q HEAD"
	assert_output --partial "git checkout gh-pages"
	assert_output --partial "Previous branch was [gh-pages]"
}

@test "should not switch to tag for release train" {
	export GIT_BIN="printing_git"
	export RELEASE_TRAIN="yes"

	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	run switch_to_tag

	assert_success
	refute_output --partial "git checkout"
}

@test "should switch to tag for release train" {
	export GIT_BIN="printing_git"
	export RELEASE_TRAIN="no"
	export VERSION="1.0.0"

	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	run switch_to_tag

	assert_success
	assert_output --partial "git checkout v1.0.0"
}
