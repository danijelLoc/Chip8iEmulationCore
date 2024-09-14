//
//  Chip8EmulationCore+Constants.swift
//
//
//  Created by Danijel Stracenski on 14.09.2024..
//

import Foundation

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
