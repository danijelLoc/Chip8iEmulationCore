//
//  Chip8SystemState.swift
//  Chip8iEmulator
//
//  Created by Danijel Stracenski on 24.06.2024..
//

import Foundation

///
/// Chip 8 SystemState - Snapshot of system in given moment
///
struct Chip8SystemSnapshot {
    let currentOperationCode: UShort
    /// 4096 bytes of memory. Chip8 uses BIG ENDIAN (when saving UShort value  we save upper byte at address x and then lower byte at memory address x+1)
    let randomAccessMemory: [UByte]
    
    /// 15 general purpose registers and 1 "carry-flag" register
    let registers: [UByte]
    let indexRegister: UShort
    /// Program Counter - points to memory location of operation that will be executed next. Each operation takes 2 memory addresses so increment should be done by 2
    let pc: UShort
    
    let callStack: [UShort] // 16 levels // Saves Current ProgramCounter
    let callStackPointer: UShort // Remembers which level of stack is used
    
    // if set above 0 they are counting down. Counting at 60Hz
    let delayTimer: UByte
    let soundTimer: UByte // Buzzer when reaches zero
    
    /// One dimension Byte array representing output screen (64x32). One byte represents one pixel (0: Black and 255: White), order from left top of the screen.
    let OutputScreen: [UByte] // 64x32
}
