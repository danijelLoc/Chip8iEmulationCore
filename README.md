# Chip8iEmulationCore

`Chip8EmulationCore` is a Swift package for emulating the Chip8 system. This package provides an emulation core that allows you to start emulation, handle input, and subscribe to screen output and sound updates. The package can be used in a custom emulator frontend.

## Installation

To include `Chip8EmulationCore` in your project, add it as a Swift Package Dependency:

1. In Xcode, go to `File` -> `Add Packages...`
2. Enter the URL of the repository and add the package to your project.

## Usage

### Import the Package

In your Swift file where you want to use the emulator:

```swift
import Chip8EmulationCore

let emulationCore = Chip8EmulationCore()
```

### Load Chip8 program
First, load the chip8 program binary read-only (ROM) data `[UByte]` from the filesystem or otherwise and save it in `Chip8Program` structure ready for emulation.

```swift
let programROM = Chip8Program(name: "My Pong Game", contentROM: myPongGameROMData)
```

### Start emulation

The emulate function runs in an infinite loop, so ensure that it is run in a proper asynchronous context.
```swift
Task {
    await emulationCore.emulate(program: programROM)
}
```

### Handling Key Events
To handle key press and release events:
```swift
  emulationCore.onKeyDown(key: "w")  // Example: Press down keyboard key 'w'
  emulationCore.onKeyUp(key: "5")    // Example: Release keyboard key '5'
  emulationCore.onKeyDown(key: "p")  // Example: Press down keyboard key 'p' which is as default mapped to emulation pause function
```
Use the onKeyDown and onKeyUp methods to send input to the emulator. Keys are mapped based on the `Chip8InputBindings` and `EmulationMenuBindings` dictionaries that can be modified for custom bindings.

### Observing Output
The `outputScreen` and `outputSoundTimer` properties are marked with `@Published`, so you can use them in `SwiftUI`, `UIKit`, or `AppKit` views to reactively display updates.
Publisher Buffer `outputScreen` is a 64x32 grid of Boolean values, representing pixel states.

### Sound Output Handling Note
Publisher `outputSoundTimer` is the UByte value of Chip8 System Sound timer. A short sound effect should be played on every value change if that value is larger than 0.

### License
This package is licensed under the MIT License. See the `LICENSE` file for more information


