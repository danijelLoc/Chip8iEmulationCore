import XCTest
@testable import Chip8iEmulationCore

final class Chip8OperationParserTests: XCTestCase {
    
    func testParseOpCodes() throws {
        let parser = Chip8OperationParser();
        
        XCTAssertEqual(Chip8Operation.ClearScreen, parser.decode(0x00E0))
        
        XCTAssertNotEqual(Chip8Operation.ClearScreen, parser.decode(0x00E1))
        XCTAssertEqual(Chip8Operation.Unknown(operationCode: 0x00E1), parser.decode(0x00E1)) // 0x00E1 is not a valid op code -> unknown
        
        XCTAssertEqual(Chip8Operation.JumpToAddress(address: 0x222), parser.decode(0x1222))
        XCTAssertEqual(Chip8Operation.JumpToAddressPlusV0(address: 0x222), parser.decode(0xB222))
        
        XCTAssertEqual(Chip8Operation.ConditionalSkipRegisterValue(registerIndex: 5, value: 0x22, isEqual: true), parser.decode(0x3522))
        XCTAssertEqual(Chip8Operation.ConditionalSkipRegisterValue(registerIndex: 0xF, value: 0x22, isEqual: true), parser.decode(0x3F22))
        
        XCTAssertEqual(Chip8Operation.RegistersOperation(registerXIndex: 1, registerYIndex: 0, operation: .subtractSecondFromFirst), parser.decode(0x8105))
        XCTAssertEqual(Chip8Operation.RegistersOperation(registerXIndex: 1, registerYIndex: 0xA, operation: .subtractFirstFromSecond), parser.decode(0x81A7))
        
        XCTAssertEqual(Chip8Operation.RegistersOperation(registerXIndex: 1, registerYIndex: 9, operation: .shiftRight), parser.decode(0x8196))
        XCTAssertNotEqual(Chip8Operation.RegistersOperation(registerXIndex: 1, registerYIndex: 9, operation: .shiftLeft), parser.decode(0x8196))
        
        XCTAssertEqual(Chip8Operation.DrawSprite(height: 8, registerXIndex: 3, registerYIndex: 1), parser.decode(0xD318))
        XCTAssertEqual(Chip8Operation.DrawSprite(height: 0xF, registerXIndex: 0xF, registerYIndex: 0xF), parser.decode(0xDFFF))
    }
    
    /// Will test decoding machine opcodes and encoding back.
    func testDecodeEncode() {
        let testCases: [(UShort, Chip8Operation)] = [
            // Test cases for all operations
            (0x00E0, .ClearScreen),
            (0x1123, .JumpToAddress(address: 0x123)),
            (0xB456, .JumpToAddressPlusV0(address: 0x456)),
            (0x2789, .CallSubroutine(address: 0x789)),
            (0x00EE, .ReturnFromSubroutine),
            (0x3001, .ConditionalSkipRegisterValue(registerIndex: 0, value: 1, isEqual: true)),
            (0x4002, .ConditionalSkipRegisterValue(registerIndex: 0, value: 2, isEqual: false)),
            (0x5010, .ConditionalSkipRegisters(registerXIndex: 0, registerYIndex: 1, isEqual: true)),
            (0x9010, .ConditionalSkipRegisters(registerXIndex: 0, registerYIndex: 1, isEqual: false)),
            (0xE09E, .ConditionalSkipKeyDown(registerIndex: 0, isKeyDown: true)),
            (0xE0A1, .ConditionalSkipKeyDown(registerIndex: 0, isKeyDown: false)),
            (0xF00A, .ConditionalPauseUntilKeyTap(registerIndex: 0)),
            (0x6001, .SetValueToRegister(registerIndex: 0, value: 1)),
            (0x7002, .AddValueToRegister(registerIndex: 0, value: 2)),
            (0xA123, .SetValueToIndexRegister(value: 0x123)),
            (0xC034, .SetValueToRegisterWithRandomness(registerIndex: 0, value: 0x34)),
            (0x8011, .RegistersOperation(registerXIndex: 0, registerYIndex: 1, operation: .bitwiseOr)),
            (0xD123, .DrawSprite(height: 3, registerXIndex: 1, registerYIndex: 2)),
            (0xF01E, .AddRegisterValueToIndexRegister(registerIndex: 0)),
            (0xF029, .SetFontCharacterAddressToIndexRegister(registerIndex: 0)),
            (0xF065, .RegistersStorage(maxIncludedRegisterIndex: 0, isRestoring: true)),
            (0xF055, .RegistersStorage(maxIncludedRegisterIndex: 0, isRestoring: false)),
            (0xF033, .RegisterStoreDecimalDigits(registerXIndex: 0)),
            (0xF007, .DelayTimerStore(registerIndex: 0)),
            (0xF015, .DelayTimerSet(registerIndex: 0)),
            (0xF018, .SoundTimerSet(registerIndex: 0)),
        ]

        for (opCode, expectedOperation) in testCases {
            // Decode the machine operation code
            let parser = Chip8OperationParser()
            let decodedOperation = parser.decode(opCode)

            // Ensure the decoded operation matches the expected one
            XCTAssertEqual(decodedOperation, expectedOperation,
                           "Decoded operation did not match expected operation for machine operation code \(opCode.hexDescription).")

            // Encode the decoded operation back to machine code
            let reEncodedMachineCode = parser.encode(decodedOperation)

            // Ensure the re-encoded machine code matches the original machine code
            XCTAssertEqual(reEncodedMachineCode, opCode,
                           "Re-encoded machine code did not match the original machine code for operation \(expectedOperation).")
        }
    }
}



