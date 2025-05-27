import Combine
import Testing
@testable import Chip8iEmulationCore

struct Chip8EmuCoreTests {
    
    @Test func testEmulationAndOutputPublishing() async throws {
        let core = await Chip8EmulationCore(logger: .none);
        let draw007: [UByte] = [
            0x00, 0xE0, // Clear the screen
            0x60, 0x00, // Set V0 to 0 (starting x position for 0)
            0x61, 0x00, // Set V1 to 0 (starting y position for 0)
            0x62, 0x00, // Set V2 to 0 (character in mind)

            0xF2, 0x29, // Load the address of the font char in V2 into I
            0xD0, 0x15, // Draw digit 0 at (V0, V1) with no collision
            
            0x60, 0x05, // Set V0 to 5 (starting x position for second 0)
            0x61, 0x00, // Set V1 to 0 (starting y position for second 0)
            0x62, 0x00, // Set V2 to 0 (character in mind)

            0xF2, 0x29, // Load the address of the font char in V2 into I
            0xD0, 0x15, // Draw digit 0 at (V0, V1)
            
            0x60, 0x0A, // Set V0 to 10 (starting x position for second 0)
            0x61, 0x00, // Set V1 to 0 (starting y position for second 0)
            0x62, 0x07, // Set V2 to 7 (character in mind)

            0xF2, 0x29, // Load the address of the font char in V2 into I
            0xD0, 0x15, // Draw digit 7 at (V0, V1)
        ]
        
        let program = Chip8Program(name: "007", contentROM: draw007)
        
//        var cb = Set<AnyCancellable>()
//        core.$outputScreen.sink { value in
//            // print(EmulationConsoleLogger.getStringOutput(value, width: 64, height: 32))
//        }.store(in: &cb)
        
        await core.emulate(program)
        
        // Cut out selected screen area x10y0 x18y5 where number 7 should have been drawn
        let selectedArea = await core.outputScreen.getSelectedArea(locationX: 10, locationY: 0, selectedWidth: 8, selectedHeight: 5, totalWidth: 64, totalHeight: 32)
        let selectedAreaData = selectedArea?.toRowsBytes(totalWidth: 8, totalHeight: 5)
        // Digit 7 font character byte representation
        let fontCharacterStartingAddress: Int = await core.debugSystemState!.fontStartingLocation.toInt + 7 * 5
        let fontCharacterData = await Array(core.debugSystemState!.randomAccessMemory[fontCharacterStartingAddress..<fontCharacterStartingAddress+5])
        
        #expect(fontCharacterData == selectedAreaData) // Font character 7 is drawn on the screen
        let debugSystemState = await core.debugSystemState!
        #expect(0 == debugSystemState.registers[0xF]) // No collision was detected
        // print(EmulationConsoleLogger.getStringOutput(core.outputScreen, width: 64, height: 32)) // Show final output screen state in terminal
        let debugErrorInfo = await core.debugErrorInfo as! EmulationError
        #expect(EmulationError.unknownOpcode(opcode: 0x0) == debugErrorInfo ) // Error has halted program execution and debug info was sent to observers
    }
    
    @Test func testErrorHandling() async throws {
        let core = await Chip8EmulationCore(soundHandler: nil, logger: .none);
        var unsupported: [UByte] = [
            0x00, 0x00 // Unsupported operation
        ]
        
        var program = Chip8Program(name: "unsupported", contentROM: unsupported)
        await core.emulate(program)
        var debugErrorInfo = await core.debugErrorInfo as! EmulationError
        #expect(EmulationError.unknownOpcode(opcode: 0x0) == debugErrorInfo) // Error has halted program execution and debug info was sent to observers
        var pc = await core.debugSystemState!.pc
        #expect(0x200 == pc) // Execution was halted immediately because of unknown operation code at 0x200 so PC is not changed
        
        unsupported = [
            0x60, 0x00, // Set V0 to 0 (starting x position for 0) - regular operation
            0x1F, 0xFF // Jump - opcode fetch out of bounds, second part of opcode starting at 0xFFF(4095) is out of bounds at 4096
        ]
        
        program = Chip8Program(name: "unsupported", contentROM: unsupported)
        await core.emulate(program)
        pc = await core.debugSystemState!.pc
        #expect(0xFFF == pc) // Jump was made and system could not get second part of new opcode
        debugErrorInfo = await core.debugErrorInfo as! EmulationError
        #expect(EmulationError.opcodeFetchError(address: 0xFFF) == debugErrorInfo) // Error has halted program execution and debug info was sent to observers
    }
    
    @Test func testInput() async throws {
        let core = await Chip8EmulationCore(logger: .none);
        let waitForKey: [UByte] = [
            0x00, 0xE0, // Clear the screen
            0x60, 0x00, // Set V0 to 0 (starting x position for 0)
            0x61, 0x00, // Set V1 to 0 (starting y position for 0)
            0x62, 0x00, // Set V2 to 0 (character in mind)

            0xF2, 0x29, // Load the address of the font char in V2 into I
            0xD0, 0x15, // Draw digit 0 at (V0, V1) with no collision

            0x63, 0x01, // Set V3 to 1 (button at index 1)
            0xE3, 0x9E, // Skip next command if button 1 is pressed
            0x12, 0x00, // Jump to beginning
            0x00, 0x00  // Invalid operation
        ]
        
        let program = Chip8Program(name: "Key", contentROM: waitForKey)
        
//        var cb = Set<AnyCancellable>()
//        core.$outputScreen.sink { value in
//            // print(EmulationConsoleLogger.getStringOutput(value, width: 64, height: 32))
//        }.store(in: &cb)
        
        let emuTask = Task {
            await core.emulate(program)
        }
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // Sleep for 1 second
        #expect(false == emuTask.isCancelled)
        
        
        Task { // Simulate calling from the main thread of the frontend app
            await core.onKeyDown(.One)
        }
        
        emuTask.cancel()
        
        let res = await emuTask.result
        #expect(res != nil) // Finished and did not throw the error outside (invalid operation caught in the core)
//        core.onKeyDown(key: .A)
//        core.onKeyDown(key: .A)
//        core.onKeyUp(key: .A)
        
    }
    
}
