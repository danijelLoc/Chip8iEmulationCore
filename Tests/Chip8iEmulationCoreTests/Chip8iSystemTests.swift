import XCTest
@testable import Chip8iEmulationCore

final class Chip8iSystemTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }
    
    func testLoadFontAndChip8ProgramRomIntoSystemRam() async throws {
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
    
    func testEmulateCycleAndPcChange() async {
        let system = Chip8System()
        let programROM: [UByte] = [0x00, 0xE0]
        system.loadProgram(programROM)
        
        XCTAssertEqual(0x200, system.state.pc)
        var commandToBeExecuted = system.fetchOperationCode(memoryLocation: system.state.pc)
        XCTAssertEqual(UShort(0x00E0), commandToBeExecuted) // Chip8 uses big endian
        
        let parser = Chip8OperationParser();
        system.executeOperation(operation: parser.decode(operationCode: commandToBeExecuted), logger: EmulationConsoleLogger())
        
        XCTAssertEqual(0x202, system.state.pc)
        commandToBeExecuted = system.fetchOperationCode(memoryLocation: system.state.pc)
        XCTAssertEqual(UShort(0x0), commandToBeExecuted)
    }

    func testPerformanceExample() throws {
        // TODO: Implement
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
}
