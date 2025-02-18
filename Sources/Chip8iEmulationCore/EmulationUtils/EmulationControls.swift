//
//  EmulationControls.swift
//
//
//  Created by Danijel Stracenski on 21.09.2024..
//

import Foundation

public extension Dictionary where Value: Equatable {
    func KeyFromValue(_ value: Value) -> Key? {
        return self.first(where: { $1 == value })?.key
    }
    
}

/// Chip8 system keys for gameplay. Keys are originally set to be hexadecimal digits, so from 0x0 to 0xF
///
/// The standard Chip8 keypad layout is:
/// ```
/// 1 2 3 C
/// 4 5 6 D
/// 7 8 9 E
/// A 0 B F
/// ```
public enum Chip8Key: UByte, CaseIterable, Equatable {
    case Zero = 0x0
    case One = 0x1
    case Two = 0x2
    case Three = 0x3
    case Four = 0x4
    case Five = 0x5
    case Six = 0x6
    case Seven = 0x7
    case Eight = 0x8
    case Nine = 0x9
    case A = 0xA
    case B = 0xB
    case C = 0xC
    case D = 0xD
    case E = 0xE
    case F = 0xF

    public var label: String {
        return String(format: "%0X", self.rawValue)
    }
    
    

    public static let StandardLayout: [[Chip8Key]] = [
        [.One, .Two, .Three, .C],
        [.Four, .Five, .Six, .D],
        [.Seven, .Eight, .Nine, .E],
        [.A, .Zero, .B, .F],
    ]
    
    /// Example of keyboard bindings for Chip8 keys. This is just an example for QWERTZ keyboard, bindings should be configured in frontend app depending on controller device.
    ///
    /// MacBook keyboard
    /// ```
    /// 1 2 3 4
    /// q w e r
    /// a s d f
    /// y x c v
    /// ```
    ///
    /// Chip8 system
    /// ```
    /// 1 2 3 C
    /// 4 5 6 D
    /// 7 8 9 E
    /// A 0 B F
    ///```
    public static let StandardKeyboardBinding:
        [Character: Chip8Key] = [
            "1": .One, "2": .Two, "3": .Three, "4": .C,
            "q": .Four, "w": .Five, "e": .Six, "r": .D,
            "a": .Seven, "s": .Eight, "d": .Nine, "f": .E,
            "y": .A, "x": .Zero, "c": .B, "v": .F,
        ]
}
