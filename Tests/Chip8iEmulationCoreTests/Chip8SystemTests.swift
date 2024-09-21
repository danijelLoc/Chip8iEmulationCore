import XCTest
@testable import Chip8iEmulationCore

final class Chip8SystemTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }
    
    func testLoadFontAndChip8ProgramRomIntoSystemRam() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        let system = Chip8System()
        XCTAssertEqual(Chip8System.DefaultFontSet[0], system.state.randomAccessMemory[system.state.fontStartingLocation.toInt]) // first byte of font
        XCTAssertEqual(Chip8System.DefaultFontSet[0x4F], system.state.randomAccessMemory[system.state.fontStartingLocation.toInt + Int(0x4F)]) // last (80th) byte of font at index 0x4F (79)
        
        let programROM: [UByte] = [0x00, 0x01]
        system.loadProgram(programROM)
        XCTAssertEqual(4096, system.state.randomAccessMemory.count)
        XCTAssertEqual(programROM[0], system.state.randomAccessMemory[0x200])
        XCTAssertEqual(programROM[1], system.state.randomAccessMemory[0x201])
    }
    
    func testExecuteOperationAndPcChange() {
        let parser = Chip8OperationParser();
        let system = Chip8System()
        let programROM: [UByte] = [0x00, 0xE0]
        system.loadProgram(programROM)
        
        XCTAssertEqual(0x200, system.state.pc)
        var opCodeToBeExecuted = system.fetchOperationCode(memoryLocation: system.state.pc)
        XCTAssertEqual(UShort(0x00E0), opCodeToBeExecuted) // Chip8 uses big endian
        
        // Execute the operation
        system.executeOperation(operation: parser.decode(operationCode: opCodeToBeExecuted), logger: EmulationConsoleLogger())
        
        // PC should change
        XCTAssertEqual(0x202, system.state.pc)
        opCodeToBeExecuted = system.fetchOperationCode(memoryLocation: system.state.pc)
        XCTAssertEqual(UShort(0x0), opCodeToBeExecuted)
    }
    
    func testLoadAndExportState() {
        let parser = Chip8OperationParser();
        let system = Chip8System()
        
        let programROM: [UByte] = [0x00, 0xE0]
        system.loadProgram(programROM)
        
        let initialSavedState = system.state
        
        XCTAssertEqual(0x200, system.state.pc)
        var opCodeToBeExecuted = system.fetchOperationCode(memoryLocation: system.state.pc)
        XCTAssertEqual(UShort(0x00E0), opCodeToBeExecuted) // Chip8 uses big endian
        
        // Execute the operation
        system.executeOperation(operation: parser.decode(operationCode: opCodeToBeExecuted), logger: EmulationConsoleLogger())
        
        // PC of system should change
        XCTAssertEqual(0x202, system.state.pc)
        opCodeToBeExecuted = system.fetchOperationCode(memoryLocation: system.state.pc)
        XCTAssertEqual(UShort(0x0), opCodeToBeExecuted)
        
        XCTAssertEqual(0x200, initialSavedState.pc) // Exported initial state was not changed
        
        system.loadState(initialSavedState)
        XCTAssertEqual(0x200, system.state.pc)
        opCodeToBeExecuted = system.fetchOperationCode(memoryLocation: system.state.pc)
        XCTAssertEqual(UShort(0x00E0), opCodeToBeExecuted) // Initial state successfully loaded back
    }
    
    func testKeys() {
        let system = Chip8System()
        let key1: UByte = 0x1
        let key1Index = key1.toInt // Chip8 key 0x1 is saved at the index 1 in the system.state.InputKeys. Same for the rest of the 16 keys. 0x0 at index 0 and 0xF at index 15
        
        XCTAssertEqual(false, system.state.InputKeys[key1.toInt]) // All keys initially released (not pressed)
        
        // Press down one key
        system.keyDown(key: key1)
        XCTAssertEqual(true, system.state.InputKeys[key1Index])
        
        // Release the key
        system.keyUp(key: key1)
        XCTAssertEqual(false, system.state.InputKeys[key1Index]) // Key should be released now
        
        let keyF: UByte = 0xF
        let keyFIndex = keyF.toInt
        
        // Multiple keys can be pressed down at the same time
        system.keyDown(key: key1)
        system.keyDown(key: keyF)
        XCTAssertEqual(true, system.state.InputKeys[key1Index])
        XCTAssertEqual(true, system.state.InputKeys[keyFIndex])
        
        system.keyUp(key: key1)
        system.keyUp(key: keyF)
        XCTAssertEqual(false, system.state.InputKeys[key1Index])
        XCTAssertEqual(false, system.state.InputKeys[keyFIndex])
    }

    func testPerformanceExample() throws {
        // TODO: Implement
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
}
