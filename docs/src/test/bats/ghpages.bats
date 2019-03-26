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

export -f fake_git

@test "should " {
	export GIT_BIN="fake_git"
	export SPRING_CLOUD_STATIC_REPO="${TEMP_DIR}/spring-cloud-static"

	cd "${TEMP_DIR}/spring-cloud-stream/"
	echo "Running the build of docs"
	./mvnw clean install -DskipTests -Pdocs -pl docs

	"${SOURCE_DIR}"/ghpages.sh

	run toLowerCase "Foo"
	assert_output "foo"

	run toLowerCase "FOObar"
	assert_output "foobar"
}
