//
//  BeaconCodes.swift
//  C19X
//
//  Created by Freddy Choi on 23/03/2020.
//  Copyright © 2020 C19X. All rights reserved.
//

import Foundation
import os

/**
 Beacon codes are derived from day codes. On each new day, the day code for the day, being a long value,
 is taken as 64-bit raw data. The bits are reversed and then hashed (SHA) to create a seed for the beacon
 codes for the day. It is cryptographically challenging to derive the day code from the seed, and it is this seed
 that will eventually be distributed by the central server for on-device matching. The generation of beacon
 codes is similar to that for day codes, it is based on recursive hashing and taking the modulo to produce
 a collection of long values, that are randomly selected as beacon codes. Given the process is deterministic,
 on-device matching is possible, once the beacon code seed is provided by the server.
 */
protocol BeaconCodes {
    func get() -> BeaconCode?
}

typealias BeaconCode = Int64

class ConcreteBeaconCodes : BeaconCodes {
    private let log = OSLog(subsystem: "org.c19x.beacon", category: "BeaconCodes")
    static let codesPerDay = 240
    private var dayCodes: DayCodes
    private var seed: BeaconCodeSeed?
    private var values:[BeaconCode]?
    
    init(_ dayCodes: DayCodes) {
        self.dayCodes = dayCodes
        let _ = get()
    }
    
    func get() -> BeaconCode? {
        if seed == nil {
            guard let (seed, _) = dayCodes.seed() else {
                os_log("No seed code available", log: log, type: .fault)
                return nil
            }
            self.seed = seed
        }
        guard let (seedToday, today) = dayCodes.seed() else {
            os_log("No seed code available", log: log, type: .fault)
            return nil
        }
        if values == nil || seed != seedToday {
            os_log("Generating beacon codes for new day (day=%s,seed=%s)", log: log, type: .debug, today.description, seedToday.description)
            seed = seedToday
            values = ConcreteBeaconCodes.beaconCodes(seedToday, count: ConcreteBeaconCodes.codesPerDay)
        }
        guard let values = values else {
            os_log("No beacon code available", log: log, type: .fault)
            return nil
        }
        return values[Int.random(in: 0 ... (values.count - 1))]
    }
    
    static func beaconCodes(_ beaconCodeSeed: BeaconCodeSeed, count: Int) -> [BeaconCode] {
        let data = Data(withUnsafeBytes(of: beaconCodeSeed) { Data($0) }.reversed())
        var hash = SHA.hash(data: data)
        var values = [BeaconCode](repeating: 0, count: count)
        for i in (0 ... (count - 1)).reversed() {
            values[i] = SHA.javaLongValue(digest: hash)
            let hashData = Data(hash)
            hash = SHA.hash(data: hashData)
        }
        return values
    }

}
