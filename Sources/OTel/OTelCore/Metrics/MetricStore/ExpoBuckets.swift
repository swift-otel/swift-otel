//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2026 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Sparse bucket storage for exponential histograms.
///
/// Stores a dense array of counts starting at `startBin`. Expands
/// automatically when recording bins outside the current range.
struct ExpoBuckets: Sendable, Equatable {
    var startBin: Int32 = 0
    var counts: [UInt64] = []

    var length: Int { counts.count }

    var totalCount: UInt64 {
        counts.reduce(0, +)
    }

    /// Increments the count at the given bin index, expanding the array as needed.
    mutating func record(_ bin: Int32) {
        if counts.isEmpty {
            counts = [1]
            startBin = bin
            return
        }

        let endBin = Int(startBin) + counts.count - 1

        if bin >= startBin, Int(bin) <= endBin {
            counts[Int(bin - startBin)] += 1
            return
        }

        if bin < startBin {
            let newLength = endBin - Int(bin) + 1
            let shift = Int(startBin - bin)
            var newCounts = [UInt64](repeating: 0, count: newLength)
            for i in 0 ..< counts.count {
                newCounts[i + shift] = counts[i]
            }
            newCounts[0] = 1
            counts = newCounts
            startBin = bin
            return
        }

        let newLength = Int(bin - startBin) + 1
        counts.append(contentsOf: repeatElement(UInt64(0), count: newLength - counts.count))
        counts[Int(bin - startBin)] = 1
    }

    /// Merges adjacent buckets by reducing resolution by `delta` scale levels.
    ///
    /// Merges every `2^delta` adjacent buckets by summing their counts.
    mutating func downscale(by delta: Int32) {
        if counts.count <= 1 || delta < 1 {
            startBin >>= delta
            return
        }

        let steps = Int32(1) << delta
        let offset = ((startBin % steps) + steps) % steps
        for i in 1 ..< counts.count {
            let idx = i + Int(offset)
            if idx % Int(steps) == 0 {
                counts[idx / Int(steps)] = counts[i]
            } else {
                counts[idx / Int(steps)] += counts[i]
            }
        }

        let lastIdx = (counts.count - 1 + Int(offset)) / Int(steps)
        counts.removeLast(counts.count - lastIdx - 1)
        startBin >>= delta
    }
}
