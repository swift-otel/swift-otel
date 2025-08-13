#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift OTel open source project
##
## Copyright (c) 2025 the Swift OTel project authors ## Licensed under Apache License v2.0
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

canary_product_name=_OTelFoundationEssentialsCanary

log "Building ${canary_product_name} ..."
swift build --product "${canary_product_name}"
canary_shared_lib_path=$(swift build --show-bin-path)/lib_OTelFoundationEssentialsCanary.so
test -f "${canary_shared_lib_path}" || fatal "Cannot find built library: ${canary_shared_lib_path}"

log "Checking dependencies of {canary_shared_lib_path} ..."
dependencies=$(ldd "${canary_shared_lib_path}")
log "${dependencies}"


if echo "${dependencies}" | grep -q libFoundation.so; then
  error "Found depenency on Foundation"
  ((num_errors++))
fi
if echo "${dependencies}" | grep -q libFoundationInternationalization.so; then
  error "Found depenency on FoundationInternationalization"
  ((num_errors++))
fi

if [ "${num_errors}" -gt 0 ]; then
  fatal "❌ Found ${num_errors} errors."
fi

log "✅ Found no errors."
