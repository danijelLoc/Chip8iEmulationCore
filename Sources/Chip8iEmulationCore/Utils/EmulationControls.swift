//
//  EmulationControls.swift
//
//
//  Created by Danijel Stracenski on 21.09.2024..
//

import Foundation

public class EmulationControls {
    
    /// Chip8 system keys for gameplay. Keys are originally set to be hexadecimal digits, so from 0x0 to 0xF
    ///
    /// The standard Chip8 keypad layout is:
    /// ```
    /// 1 2 3 C
    /// 4 5 6 D
    /// 7 8 9 E
    /// A 0 B F
    /// ```
    public enum Chip8Key: UByte {
        case Zero = 0x0
        case One  = 0x1
        case Two  = 0x2
        case Three = 0x3
        case Four = 0x4
        case Five = 0x5
        case Six  = 0x6
        case Seven = 0x7
        case Eight = 0x8
        case Nine = 0x9
        case A    = 0xA
        case B    = 0xB
        case C    = 0xC
        case D    = 0xD
        case E    = 0xE
        case F    = 0xF
    }
    
    /// Example of keyboard bindings for Chip8 keys. This is just an example for QWERTZ keyboard, bindings should be configured in frontend app depending on controller device.
    ///
    /// Chip8 system
    /// ```
    /// 1 2 3 C
    /// 4 5 6 D
    /// 7 8 9 E
    /// A 0 B F
    ///```
    /// MacBook keyboard
    /// ```
    /// 1 2 3 4
    /// q w e r
    /// a s d f
    /// y x c v
    /// ```
    public static let Chip8KeysQWERTZKeyboardBindingExample: Dictionary<Character, Chip8Key> = [
        "1": .One,   "2": .Two,   "3": .Three, "4": .C,
        "q": .Four,  "w": .Five,  "e": .Six,   "r": .D,
        "a": .Seven, "s": .Eight, "d": .Nine,  "f": .E,
        "y": .A,     "x": .Zero,  "c": .B,     "v": .F
    ]
}
