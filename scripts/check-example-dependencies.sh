#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift OTel open source project
##
## Copyright (c) 2025 the Swift OTel project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

current_script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
repo_root="$(git -C "${current_script_dir}" rev-parse --show-toplevel)"

if [ "${PWD}" == "${repo_root}" ] || [ ! -r "${PWD}/Package.resolved" ]; then
  fatal "This script should be run from the package root of an example projects _after_ building."
fi

swift_otel_dependencies=$(swift package show-dependencies --format json | jq -er '
  .dependencies[]
  | select((.identity | startswith("swift-otel")))
  | .dependencies[].identity')

log "Checking traits used for swift-otel dependency..."
# Right now, swift package describe doesn't show traits, so we'll use dump-package.
swift_otel_traits=$(swift package dump-package | jq -er '
  .dependencies[] | .fileSystem + .sourceControl | .[]
  | select(.identity == "swift-otel" or .nameForTargetDependencyResolutionOnly == "swift-otel")
  | .traits | map(.name) | sort | .[] // ""
')

log "Example package depends on swift-otel with the following traits:
${swift_otel_traits}
"

expected_otlpcommon_dependencies="swift-protobuf"
expected_otlpgrpc_dependencies="grpc-swift-protobuf grpc-swift-2 grpc-swift-nio-transport"
expected_otlphttp_dependencies="async-http-client"
num_errors=0

if echo "${swift_otel_traits}" | grep -q "default"; then
    log "Traits include default; checking for expected HTTP and gRPC dependencies..."
    for expected_dependency in $expected_otlpcommon_dependencies $expected_otlphttp_dependencies $expected_otlpgrpc_dependencies; do
      if ! echo "${swift_otel_dependencies}" | grep -q "${expected_dependency}"; then
        error "Missing expected dependency: ${expected_dependency}"
        ((num_errors++))
      fi
    done
fi
if echo "${swift_otel_traits}" | grep -q "OTLPHTTP"; then
    log "Traits include OTLPHTTP; checking for expected HTTP dependencies..."
    for expected_dependency in $expected_otlpcommon_dependencies $expected_otlphttp_dependencies; do
      if ! echo "${swift_otel_dependencies}" | grep -q "${expected_dependency}"; then
        error "Missing expected dependency: ${expected_dependency}"
        ((num_errors++))
      fi
    done
fi
if echo "${swift_otel_traits}" | grep -q "OTLPGRPC"; then
    log "Traits include OTLPGRPC; checking for expected gRPC dependencies..."
    for expected_dependency in $expected_otlpcommon_dependencies $expected_otlpgrpc_dependencies; do
      if ! echo "${swift_otel_dependencies}" | grep -q "${expected_dependency}"; then
        error "Missing expected dependency: ${expected_dependency}"
        ((num_errors++))
      fi
    done
fi
if ! echo "${swift_otel_traits}" | grep -q -e "default" -e "OTLPHTTP"; then
    log "Traits does NOT contain OTLPHTTP or default; checking for unexpected HTTP dependencies..."
    for unexpected_dependency in $expected_otlphttp_dependencies; do
      if echo "${swift_otel_dependencies}" | grep "${unexpected_dependency}"; then
        error "Unexpected dependency: ${unexpected_dependency}"
        ((num_errors++))
      fi
    done
fi
if ! echo "${swift_otel_traits}" | grep -q -e "default" -e "OTLPGRPC"; then
    log "Traits does NOT contain OTLPGRPC or default; checking for unexpected gPRC dependencies..."
    for unexpected_dependency in $expected_otlpgrpc_dependencies; do
      if echo "${swift_otel_dependencies}" | grep -q "${unexpected_dependency}"; then
        error "Unexpected dependency: ${unexpected_dependency}"
        ((num_errors++))
      fi
    done
fi
if ! echo "${swift_otel_traits}" | grep -q -e "default" -e "OTLPHTTP" -e "OTLPGRPC"; then
    log "Traits does NOT contain OTLPHTTP, OTLPGRPC, or default; checking for unexpected HTTP or gRPC dependencies..."
    for unexpected_dependency in $expected_otlpcommon_dependencies $expected_otlphttp_dependencies $expected_otlpgrpc_dependencies; do
      if echo "${swift_otel_dependencies}" | grep "${unexpected_dependency}"; then
        error "Unexpected dependency: ${unexpected_dependency}"
        ((num_errors++))
      fi
    done
fi

if [ "${num_errors}" -gt 0 ]; then
  fatal "❌ Found ${num_errors} errors."
fi

log "✅ Found no errors."
