// Copyright (c) 2019 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import Foundation

/// Parses Swift Function times generated by `swiftc`
/// if you pass the flags `-Xfrontend -debug-time-expression-type-checking`
class SwiftCompilerTypeCheckOptionParser: SwiftCompilerTimeOptionParser {

    private static let compilerFlag = "-debug-time-expression-type-checking"

    private static let invalidLoc = "<invalid loc>"

    private lazy var regexp: NSRegularExpression? = {
        let pattern = "\\t*([0-9]+\\.[0-9]+)ms\\t(.+):([0-9]+):([0-9]+)\\r"
        return NSRegularExpression.fromPattern(pattern)
    }()

    func hasCompilerFlag(commandDesc: String) -> Bool {
        commandDesc.range(of: Self.compilerFlag) != nil
    }

    func parse(from commands: [String: Int]) -> [String: [SwiftTypeCheck]] {
        return commands.compactMap { parse(command: $0.key, occurrences: $0.value) }
            .joined().reduce([:]) { (typeChecksPerFile, typeCheckTime)
        -> [String: [SwiftTypeCheck]] in
            var typeChecksPerFile = typeChecksPerFile
            if var typeChecks = typeChecksPerFile[typeCheckTime.file] {
                typeChecks.append(typeCheckTime)
                typeChecksPerFile[typeCheckTime.file] = typeChecks
            } else {
                typeChecksPerFile[typeCheckTime.file] = [typeCheckTime]
            }
            return typeChecksPerFile
        }
    }

    private func parse(command: String, occurrences: Int) -> [SwiftTypeCheck]? {
        guard let regexp = regexp else {
            return nil
        }
        let range = NSRange(location: 0, length: command.count)
        let matches = regexp.matches(in: command, options: .reportProgress, range: range)
        let typeCheckerTimes = matches.compactMap { result -> SwiftTypeCheck? in

            let durationString = command.substring(result.range(at: 1))
            let fileName = command.substring(result.range(at: 2))
            let lineStr = command.substring(result.range(at: 3))
            let columnStr = command.substring(result.range(at: 4))
            if isInvalid(fileName: fileName) {
                return nil
            }
            guard let line = Int(lineStr), let column = Int(columnStr) else {
                return nil
            }
            let fileURL = prefixWithFileURL(fileName: fileName)
            let duration = parseCompileDuration(durationString)
            return SwiftTypeCheck(file: fileURL,
                                durationMS: duration,
                                startingLine: line,
                                startingColumn: column,
                                occurrences: occurrences)
        }
        return typeCheckerTimes
    }

}
