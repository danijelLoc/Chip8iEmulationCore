//
//  ExtensionsAndConstants.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 10.09.2024..
//

import Foundation
import CoreGraphics

public typealias UByte = UInt8
public typealias UShort = UInt16

extension UShort {
    public var fullDescription: String {
        let bits = String(self, radix: 2).padding(toLength: 16, withPad: "0", startingAt: 0)
        return "\(String(format:"0x%04X", self))|0b\(bits)|\(self)"
    }
    
    public var hexDescription: String {
        return "\(String(format:"0x%04X", self))"
    }
    
    public var toInt: Int {
        return Int(self)
    }
}

extension UByte {
    public var fullDescription: String {
        let bits = String(self, radix: 2).padding(toLength: 8, withPad: "0", startingAt: 0)
        return "\(String(format:"0x%02X", self))|0b\(bits)|\(self)"
    }
    
    public var hexDescription: String {
        return "\(String(format:"0x%02X", self))"
    }
    
    public var toInt: Int {
        return Int(self)
    }
}

extension Bool {
    public func xor(other: Bool) -> Bool {
        return other != self;
    }
    
    /// Returns true for 1, false for 0. Otherwise throws error.
    public static func fromOneOrZero(_ value: UByte) ->  Bool {
        if value > 1 {
            fatalError("Method expects 1 or 0")
        } else if value == 1 {
            return true;
        } else {
            return false;
        }
    }
}

extension CGImage {
    /// Tries to create the CGImage from pixels data. Can be used to display screen output of the Chip8EmulationCore.
    public static func fromMonochromeBitmap(_ pixels: [Bool], width: Int, height: Int) -> CGImage? {
        guard width > 0 && height > 0 else { return nil }
        guard pixels.count == width * height else { return nil }
        
        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo: CGBitmapInfo = [CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderDefault.rawValue)]

        var data: [UByte] = pixels.map {x in (x ? 1 : 0)  * 255 }

        guard let providerRef = CGDataProvider(data: NSData(bytes: &data, length: data.count * MemoryLayout<UInt8>.size))
        else { return nil }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width * MemoryLayout<UInt8>.size,
            space: grayColorSpace,
            bitmapInfo: bitmapInfo,
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }

        return cgImage
    }
}

extension Chip8SystemState {
    ///
    /// Chip8 only supports font with 16 letters  (0,1,...,9,A,....F)
    /// Reasons: memory constraints and input that also has 16 keys, so Hexadecimal digits were chosen for default font.
    /// This font is saved in RAM and can then be replaced by game ROM when executed. 
    /// Size of the set is 80 Bytes (each character takes 5 bytes where one pixel row is 1 byte ->  so character takes 8x5 pixels on the screen).
    ///
    public static let DefaultFontSet: [UByte] = [
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80  // F
    ]
}

extension Array<Bool> {
    public func getSelectedArea(locationX: Int, locationY: Int, selectedWidth: Int, selectedHeight: Int, totalWidth: Int, totalHeight: Int) -> [Bool]? {
        guard totalWidth * totalHeight == self.count &&
                locationX + selectedWidth < totalWidth &&
                locationY + selectedHeight < totalHeight &&
                locationX >= 0 && locationY >= 0 &&
                selectedHeight >= 0 && selectedWidth >= 0 &&
                totalHeight >= 0 && totalWidth >= 0
        else { return nil }
        
        var output: [Bool] = []
        for i in locationY..<locationY+selectedHeight {
            var rowPixels: [Bool] = []
            for j in locationX..<locationX+selectedWidth {
                let index = i * totalWidth + j
                rowPixels.append(self[index])
            }
            output.append(contentsOf: rowPixels)
        }
        
        return output
    }
    
    /// Returns cropped image area as bytes rows where one pixel(bool) is one bit. Max width is 8 (Chip8 uses sprites with max width of 8, and max height of 15).
    public func toRowsBytes(totalWidth: Int, totalHeight: Int) -> [UByte]? {
        guard totalWidth * totalHeight == self.count &&
                totalHeight >= 0 && totalWidth >= 0 && totalWidth <= 8
        else { return nil }
        
        var output: [UByte] = []
        for i in 0..<totalHeight {
            var rowByte: UByte = 0
            for j in 0..<totalWidth {
                let index = i * totalWidth + j
                if self[index] {
                    rowByte |= (1 << (7 - j))
                }
            }
            output.append(rowByte)
        }
        
        return output
    }
}
