import XCTest
import Combine
@testable import Chip8iEmulationCore

final class Chip8EmulationCoreTests: XCTestCase {
    
    func testEmulationAndErrorHandling() async throws {
        let core = Chip8EmulationCore(logger: .none);
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
        
        var cb = Set<AnyCancellable>()
        
        core.$outputScreen.sink { value in
            // print(EmulationConsoleLogger.getStringOutput(value, width: 64, height: 32))
        }.store(in: &cb)
        
        await core.emulate(program: program)
        
        // Cut out selected screen area x10y0 x18y5 where number 7 should have been drawn
        let selectedArea = core.outputScreen.getSelectedArea(locationX: 10, locationY: 0, selectedWidth: 8, selectedHeight: 5, totalWidth: 64, totalHeight: 32)
        let selectedAreaData = selectedArea?.toRowsBytes(totalWidth: 8, totalHeight: 5)
        // Digit 7 font character byte representation
        let fontCharacterStartingAddress: Int = core.debugSystemStateInfo!.fontStartingLocation.toInt + 7 * 5
        let fontCharacterData = Array(core.debugSystemStateInfo!.randomAccessMemory[fontCharacterStartingAddress..<fontCharacterStartingAddress+5])
        
        XCTAssertEqual(fontCharacterData, selectedAreaData) // Font character 7 is drawn on the screen
        XCTAssertEqual(0, core.debugSystemStateInfo?.registers[0xF]) // No collision was detected
        // print(EmulationConsoleLogger.getStringOutput(core.outputScreen, width: 64, height: 32)) // Show final output screen state in terminal
        
        XCTAssertEqual(EmulationError.unknownOpcode(opcode: 0x0), core.debugErrorInfo as! EmulationError) // Error has halted program execution and debug info was sent to observers
    }
    
    func testErrorHandling() async throws {
        let core = Chip8EmulationCore(logger: .none);
        var unsupported: [UByte] = [
            0x00, 0x00 // Unsupported operation
        ]
        
        var program = Chip8Program(name: "unsupported", contentROM: unsupported)
        await core.emulate(program: program)
        
        XCTAssertEqual(EmulationError.unknownOpcode(opcode: 0x0), core.debugErrorInfo as! EmulationError) // Error has halted program execution and debug info was sent to observers
        XCTAssertEqual(0x200, core.debugSystemStateInfo?.pc) // Execution was halted immediately because of unknown operation code at 0x200 so PC is not changed
        
        unsupported = [
            0x60, 0x00, // Set V0 to 0 (starting x position for 0) - regular operation
            0x1F, 0xFF // Jump - opcode fetch out of bounds, second part of opcode starting at 0xFFF(4095) is out of bounds at 4096
        ]
        
        program = Chip8Program(name: "unsupported", contentROM: unsupported)
        await core.emulate(program: program)
        
        XCTAssertEqual(0xFFF, core.debugSystemStateInfo?.pc) // Jump was made and system could not get second part of new opcode
        XCTAssertEqual(EmulationError.opcodeFetchError(address: 0xFFF), core.debugErrorInfo as! EmulationError) // Error has halted program execution and debug info was sent to observers
    }
    
    
}
