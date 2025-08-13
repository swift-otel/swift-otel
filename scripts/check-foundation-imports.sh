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

num_errors=0
while IFS= read -r file; do
  imports=$(grep "import.*Foundation" "${file}" | grep -v "FoundationEssentials" || true)
  if [ -n "${imports}" ]; then
    while read -r import; do
      if ! grep -q "${import/Foundation/FoundationEssentials}" "${file}"; then
        error "${file}: import has no FoundationEssentials equivalent: ${import}"
        ((num_errors++))
      fi
    done <<<"${imports}"
  fi
done < <(find Sources -type f -name '*.swift')


if [ "${num_errors}" -gt 0 ]; then
  fatal "❌ Found ${num_errors} errors."
fi

log "✅ Found no errors."
