//
//  File.swift
//  
//
//  Created by Danijel Stracenski on 14.09.2024..
//

import Foundation

extension Chip8System {
    ///
    /// Chip8 only supports font with 16 letters  (0,1,...,9,A,....F)
    /// Reasons: memory constraints and input that also has 16 keys, so Hexadecimal digits were chosen for default font.
    /// This font is saved in RAM and can then be replaced by game ROM when executed. Size 80 Bytes or in hex 0x50 Bytes.
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

extension Chip8EmulationCore {
    /// Default keyboard bindings for Chip8 keys
    ///
    /// "1": 1, "2": 2, "3": 3, "4": 0xC,
    ///
    /// "q": 4, "w": 5, "e": 6, "r": 0xD,
    ///
    /// "a": 7, "s": 8, "d": 9, "f": 0xE,
    ///
    /// "y": 0xA, "x": 0, "c": 0xB, "v": 0xF
    public static let DefaultChip8KeyboardBindings: Dictionary<Character, UByte> = [
        "1": 1, "2": 2, "3": 3, "4": 0xC,
        "q": 4, "w": 5, "e": 6, "r": 0xD,
        "a": 7, "s": 8, "d": 9, "f": 0xE,
        "y": 0xA, "x": 0, "c": 0xB, "v": 0xF
    ]
    /// Default keyboard bindings for emulation menu
    ///
    /// "p": EmulationMenuControl.Pause
    ///
    public static let DefaultEmulationMenuKeyboardBindings: Dictionary<Character, EmulationMenuControl> = [
        "p": EmulationMenuControl.Pause
    ]
}
