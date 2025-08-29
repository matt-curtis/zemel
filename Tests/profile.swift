//
//  profile.swift
//  Zemel
//
//  Created by Matt Curtis on 3/26/25.
//

import os

let log = OSLog(subsystem: "profiling", category: .pointsOfInterest)
let signposter = OSSignposter(logHandle: log)

func profile(_ name: StaticString, body: () throws -> Void) rethrows {
    for _ in 0..<10 {
        let staticSignpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval(name, id: staticSignpostID)
        
        try body()
        
        signposter.endInterval(name, state)
    }
}
