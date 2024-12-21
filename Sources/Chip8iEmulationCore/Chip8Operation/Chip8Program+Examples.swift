//
//  Chip8Program+Examples.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 21.12.2024..
//

extension Chip8Program {
    public static var HelloWorldExample: Chip8Program {
        // See Chip8Operation and parser to understand machine opcodes and decoding.
        
        let draw123: [UByte] = [
            0x30, 0x00, // Skip next command if V0 == 0
            0x12, 0x00, // Jump to start
            
            0x00, 0xE0, // Clear the screen
            0x60, 0x00, // Set V0 to 0 (starting x position for 0)
            0x61, 0x00, // Set V1 to 0 (starting y position for 0)
            0x62, 0x01, // Set V2 to 1 (character in mind)
            
            0xF2, 0x29, // Load the address of the font char in V2 into I
            0xD0, 0x15, // Draw digit 1 at (V0, V1) with no collision
            
            0x60, 0x05, // Set V0 to 5 (starting x position for second 0)
            0x61, 0x00, // Set V1 to 0 (starting y position for second 0)
            0x62, 0x02, // Set V2 to 2 (character in mind)
            
            0xF2, 0x29, // Load the address of the font char in V2 into I
            0xD0, 0x15, // Draw digit 2 at (V0, V1)
            
            0x60, 0x0A, // Set V0 to 10 (starting x position for second 0)
            0x61, 0x00, // Set V1 to 0 (starting y position for second 0)
            0x62, 0x03, // Set V2 to 3 (character in mind)
            
            0xF2, 0x29, // Load the address of the font char in V2 into I
            0xD0, 0x15, // Draw digit 3 at (V0, V1)
            
            0x60, 0x01, // Set V0 = 1, our job is done, drawing will not be repeated.
            0x12, 0x00  // Jump to start
            
        ]
        let program = Chip8Program(name: "Hello World", contentROM: draw123)
        
        return program
    }
    
    public static var StopwatchExample: Chip8Program {
        let parser = Chip8OperationParser()
        let stopwatchOpcodes: [UShort] = [
            // Set seconds and minutes registers -------------- Address of first opcode when loaded into RAM will be 0x200
            // Every Chip8 operation code takes 2 UBytes (UShort that is stored using big endian order)
            parser.encode(.SetValueToRegister(registerIndex: 5, value: 0)), // V5 = seconds
            parser.encode(.SetValueToRegister(registerIndex: 6, value: 0)), // V6 = minutes - Address when loaded into RAM will be 0x202
            
            parser.encode(.ConditionalPauseUntilKeyTap(registerIndex: 0)), // Wait for any key press down and up (start button)
            
            // Set Character ":" into ROM memory --------------
            parser.encode(.SetValueToRegister(registerIndex: 0, value: 0x00)),
            parser.encode(.SetValueToRegister(registerIndex: 1, value: 0x10)),
            parser.encode(.SetValueToRegister(registerIndex: 2, value: 0x00)),
            parser.encode(.SetValueToRegister(registerIndex: 3, value: 0x10)),
            parser.encode(.SetValueToIndexRegister(value: 0x600)),
            parser.encode(.RegistersStorage(maxIncludedRegisterIndex: 3, isRestoring: false)),
            
            // DRAW_LOOP - On start and after second passed -------------- Address when loaded into RAM will be 0x212 (218)
            
            // Check delay timer (decremented by rate of 60Hz)
            // If timer has reached 0 then 1 seconds has passed and we should proceed and skip next command
            parser.encode(.DelayTimerStore(registerIndex: 9)),
            parser.encode(.ConditionalSkipRegisterValue(registerIndex: 9, value: 0, isEqual: true)),
            parser.encode(.JumpToAddress(address: 0x212)), // Jump to DRAW_LOOP
            
            parser.encode(.ClearScreen),
            
            // Draw Minutes --------------
            parser.encode(.SetValueToIndexRegister(value: 0x500)),
            parser.encode(.RegisterStoreDecimalDigits(registerXIndex: 6)),
            parser.encode(.RegistersStorage(maxIncludedRegisterIndex: 3, isRestoring: true)),
            
            parser.encode(.SetValueToRegister(registerIndex: 7, value: 18)), // set pX
            parser.encode(.SetValueToRegister(registerIndex: 8, value: 13)), // set pY
            
            parser.encode(.SetFontCharacterAddressToIndexRegister(registerIndex: 1)), // Set I to font location
            parser.encode(.DrawSprite(height: 5, registerXIndex: 7, registerYIndex: 8)), // Draw it on screen
            
            parser.encode(.AddValueToRegister(registerIndex: 7, value: 6)), // Increment pX
            parser.encode(.SetFontCharacterAddressToIndexRegister(registerIndex: 2)), // Set I to font location
            parser.encode(.DrawSprite(height: 5, registerXIndex: 7, registerYIndex: 8)), // Draw it on screen
            
            // Draw ":" --------------
            parser.encode(.SetValueToRegister(registerIndex: 7, value: 28)), // set pX
            parser.encode(.SetValueToRegister(registerIndex: 8, value: 13)), // set pY
            parser.encode(.SetValueToIndexRegister(value: 0x600)), // Location of saved ":" character
            parser.encode(.DrawSprite(height: 5, registerXIndex: 7, registerYIndex: 8)), // Draw it on screen
            
            // Draw seconds --------------
            parser.encode(.SetValueToIndexRegister(value: 0x500)),
            parser.encode(.RegisterStoreDecimalDigits(registerXIndex: 5)),
            parser.encode(.RegistersStorage(maxIncludedRegisterIndex: 3, isRestoring: true)),
            
            parser.encode(.SetValueToRegister(registerIndex: 7, value: 35)), // set pX
            parser.encode(.SetValueToRegister(registerIndex: 8, value: 13)), // set pY
            
            parser.encode(.SetFontCharacterAddressToIndexRegister(registerIndex: 1)), // Set I to font location
            parser.encode(.DrawSprite(height: 5, registerXIndex: 7, registerYIndex: 8)), // Draw it on screen
            
            parser.encode(.AddValueToRegister(registerIndex: 7, value: 6)), // Increment pX
            parser.encode(.SetFontCharacterAddressToIndexRegister(registerIndex: 2)), // Set I to font location
            parser.encode(.DrawSprite(height: 5, registerXIndex: 7, registerYIndex: 8)), // Draw it on screen
            
            
            // Logic for incrementing seconds and minutes --------------
            
            parser.encode(.AddValueToRegister(registerIndex: 5, value: 1)), // Increment seconds
            parser.encode(.SetValueToRegister(registerIndex: 9, value: 0x3C)), // V9 = 60
            parser.encode(.DelayTimerSet(registerIndex: 9)), // Set delay timer to 60 since it is decremented by 60Hz
            
            parser.encode(.ConditionalSkipRegisterValue(registerIndex: 5, value: 0x3C, isEqual: true)), // Skip next command if 60 seconds passed
            
            parser.encode(.JumpToAddress(address: 0x212)), // Jump to DRAW_LOOP
            
            parser.encode(.SetValueToRegister(registerIndex: 5, value: 0)), // reset seconds
            parser.encode(.AddValueToRegister(registerIndex: 6, value: 1)), // Increment minutes
            
            parser.encode(.JumpToAddress(address: 0x212)), // Jump to DRAW_LOOP
        ]
        
        let program = Chip8Program(name: "Stopwatch", contentROM: stopwatchOpcodes.toBytes(isBigEndian: true))
        return program
    }
}
