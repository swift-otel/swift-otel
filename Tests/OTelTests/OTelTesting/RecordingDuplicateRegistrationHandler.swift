//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2024 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOConcurrencyHelpers
@testable import OTel

final class RecordingDuplicateRegistrationHandler: DuplicateRegistrationHandler {
    let invocations = NIOLockedValueBox([(InstrumentIdentifier, Set<InstrumentIdentifier>)]())

    func handle(newRegistration: InstrumentIdentifier, existingRegistrations: Set<InstrumentIdentifier>) {
        invocations.withLockedValue { $0.append((newRegistration, existingRegistrations)) }
    }
}
