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

CURRENT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT=$(git -C "${CURRENT_SCRIPT_DIR}" rev-parse --show-toplevel)

log "Checking running in Linux"
if [ "$(uname)" != Linux ]; then
  fatal "This script has only been written for Linux CI. Run in a container."
fi

log "Checking running in repository root"
if [ "${PWD}" != "${REPO_ROOT}" ] || [ ! -r "${PWD}/Package.swift" ]; then
  fatal "This script should be run from the root of the Swift OTel repository."
fi

log "Checking required environment variable arguments"
test -n "${MODULE_NAME:-}" || fatal "MODULE_NAME unset"
test -n "${BASELINE_REF:-}" || fatal "BASELINE_REF unset"

SIDEWORLD_DIR=${PWD}/.build/apidiff-sideworld
API_BASELINE_JSON_PATH="${SIDEWORLD_DIR}/api-baseline.json"
API_DIGEST_DIAGNOSTICS_PATH="${SIDEWORLD_DIR}/api-diagnostics"

log "Cloning into sideworld: ${SIDEWORLD_DIR}"
git clone . "${SIDEWORLD_DIR}" || git -C "${SIDEWORLD_DIR}" fetch "${PWD}"

log "Checking out sideworld at commit: ${BASELINE_REF}"
git -C "${SIDEWORLD_DIR}" checkout "${BASELINE_REF}"
log "Building sideworld for baseline"
swift build --package-path "${SIDEWORLD_DIR}"

log "Dumping API for baseline: ${BASELINE_REF}"
(cd "${SIDEWORLD_DIR}" &&
  swift-api-digester \
  -dump-sdk -json \
  -module "${MODULE_NAME}" \
  -o "${API_BASELINE_JSON_PATH}" \
  -v \
  -compiler-style-diags \
  -I .build/debug/Modules \
  -I .build/debug/CAsyncHTTPClient.build/ \
  -I .build/debug/CGRPCNIOTransportZlib.build/ \
  -I .build/debug/CNIOAtomics.build/ \
  -I .build/debug/CNIOBoringSSL.build/ \
  -I .build/debug/CNIOBoringSSLShims.build/ \
  -I .build/debug/CNIODarwin.build/ \
  -I .build/debug/CNIOExtrasZlib.build/ \
  -I .build/debug/CNIOLLHTTP.build/ \
  -I .build/debug/CNIOLinux.build/ \
  -I .build/debug/CNIOPosix.build/ \
  -I .build/checkouts/swift-atomics/Sources/_AtomicsShims/include/ \
  -I .build/checkouts/swift-crypto/Sources/CCryptoBoringSSL/include/ \
  -I .build/checkouts/swift-crypto/Sources/CCryptoBoringSSLShims/include/ \
  -I .build/checkouts/swift-nio-ssl/Sources/CNIOBoringSSL/include/ \
  -I .build/checkouts/swift-nio/Sources/CNIOAtomics/include/ \
  -I .build/checkouts/swift-nio/Sources/CNIOWindows/include/ \
  -I .build/checkouts/swift-numerics/Sources/_NumericsShims/include/
)

log "Building in current world"
swift build

log "Diagnosing breakages since ${BASELINE_REF}"
swift-api-digester \
  -diagnose-sdk \
  -module "${MODULE_NAME}" \
  -baseline-path "${API_BASELINE_JSON_PATH}" \
  -serialize-diagnostics-path "${API_DIGEST_DIAGNOSTICS_PATH}" \
  -v \
  -I .build/debug/Modules \
  -I .build/debug/CAsyncHTTPClient.build/ \
  -I .build/debug/CGRPCNIOTransportZlib.build/ \
  -I .build/debug/CNIOAtomics.build/ \
  -I .build/debug/CNIOBoringSSL.build/ \
  -I .build/debug/CNIOBoringSSLShims.build/ \
  -I .build/debug/CNIODarwin.build/ \
  -I .build/debug/CNIOExtrasZlib.build/ \
  -I .build/debug/CNIOLLHTTP.build/ \
  -I .build/debug/CNIOLinux.build/ \
  -I .build/debug/CNIOPosix.build/ \
  -I .build/checkouts/swift-atomics/Sources/_AtomicsShims/include/ \
  -I .build/checkouts/swift-crypto/Sources/CCryptoBoringSSL/include/ \
  -I .build/checkouts/swift-crypto/Sources/CCryptoBoringSSLShims/include/ \
  -I .build/checkouts/swift-nio-ssl/Sources/CNIOBoringSSL/include/ \
  -I .build/checkouts/swift-nio/Sources/CNIOAtomics/include/ \
  -I .build/checkouts/swift-nio/Sources/CNIOWindows/include/ \
  -I .build/checkouts/swift-numerics/Sources/_NumericsShims/include/

log "✅ No API breaks detected."
