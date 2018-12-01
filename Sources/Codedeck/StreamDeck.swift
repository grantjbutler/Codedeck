//
//  StreamDeck.swift
//  Codedeck
//
//  Created by Sherlock, James on 26/11/2018.
//  Copyright © 2018 Sherlouk. All rights reserved.
//

import Foundation
import HIDSwift

public class StreamDeck {
    
    public enum Error: Swift.Error, LocalizedError {
        case keyIndexOutOfRange
        case brightnessOutOfRange
        
        public var localizedDescription: String {
            switch self {
            case .keyIndexOutOfRange: return "Key Index out of bounds"
            case .brightnessOutOfRange: return "Brightness out of bounds"
            }
        }
    }
    
    let device: HIDDevice
    let product: StreamDeckProduct
    var keysPressed = [Int: Bool]()
    
    public init(device: HIDDevice) throws {
        self.device = device
        self.product = try device.makeStreamDeckProduct()
        
        device.startReading(callback: receiveDataFromDevice(data:))
    }
    
    // Public
    
    public func setBrightness(_ brightness: Int) throws {
        guard (0...100).contains(brightness) else {
            throw Error.brightnessOutOfRange
        }
        
        let bytes: [UInt8] = [0x05, 0x55, 0xaa, 0xd1, 0x01, UInt8(brightness)]
        var data = Data(bytes: bytes)
        data.pad(toLength: device.reportSize)
        
        device.sendFeatureReport(data: data)
        Logger.success("Set Brightness to \(brightness)%")
    }
    
    public func clearAllKeys() throws {
        try allKeys().forEach {
            try $0.clear()
        }
    }
    
    public func key(for index: Int) throws -> StreamDeckKey {
        try assertKeyInRange(index)
        return StreamDeckKey(streamDeck: self, keyIndex: index)
    }
    
    public func allKeys() -> [StreamDeckKey] {
        return keysRange().map({
            StreamDeckKey(streamDeck: self, keyIndex: $0)
        })
    }
    
    // Private
    
    private func keysRange() -> Range<Int> {
        return 0 ..< product.keyCount
    }
    
    private func assertKeyInRange(_ key: Int) throws {
        guard keysRange().contains(key) else {
            throw Error.keyIndexOutOfRange
        }
    }
    
    // Reading
    
    internal func receiveDataFromDevice(data: Data) {
        guard data.count == product.keyCount + 2 else {
            Logger.error("Data received from device was not correct size (\(data.count) != \(product.keyCount + 2))")
            return
        }
        
        // The first byte is the report ID
        // The last byte appears to be padding
        // We'll ignore these for now, the count should be equal to the key count.
        let keyData = data[1 ..< (data.count - 1)]
        
        for (keyIndex, keyValue) in keyData.enumerated() {
            keysPressed[keyIndex] = keyValue == 1
        }
        
        // End of functional logic, just printing out the pressed key to console
        
        let currentKeysPressed = keysPressed.filter({ $0.value })
            
        if currentKeysPressed.isEmpty {
            Logger.info("No Keys Pressed")
        } else {
            let keysPressedDescription = currentKeysPressed.map({ String($0.key) }).joined(separator: ", ")
            Logger.info("Keys Pressed: \(keysPressedDescription)")
        }
        
    }
    
    // Writing
    
    internal func write(data: Data) {
        device.write(data: data)
    }
    
    // Data Management
    
    static let PAGE_PACKET_SIZE = 8191
    
    internal func dataPageOne(keyIndex: Int, data: Data) -> Data {
        let bytes: [UInt8] = [
            0x02, 0x01, 0x01, 0x00, 0x00, UInt8(keyIndex + 1),
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x42, 0x4d, 0xf6, 0x3c, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x36, 0x00, 0x00, 0x00,
            0x28, 0x00, 0x00, 0x00, 0x48, 0x00, 0x00, 0x00,
            0x48, 0x00, 0x00, 0x00, 0x01, 0x00, 0x18, 0x00,
            0x00, 0x00, 0x00, 0x00, 0xc0, 0x3c, 0x00, 0x00,
            0xc4, 0x0e, 0x00, 0x00, 0xc4, 0x0e, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ]
        
        var pageOneData = Data(bytes: bytes)
        pageOneData.append(data)
        pageOneData.pad(toLength: StreamDeck.PAGE_PACKET_SIZE)
        
        return pageOneData
    }
    
    internal func dataPageTwo(keyIndex: Int, data: Data) -> Data {
        let bytes: [UInt8] = [
            0x02, 0x01, 0x02, 0x00, 0x01, UInt8(keyIndex + 1),
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ]
        
        var pageTwoData = Data(bytes: bytes)
        pageTwoData.append(data)
        pageTwoData.pad(toLength: StreamDeck.PAGE_PACKET_SIZE)
        
        return pageTwoData
    }
    
}