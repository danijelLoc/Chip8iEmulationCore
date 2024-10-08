[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FdanijelLoc%2FChip8iEmulationCore%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/danijelLoc/Chip8iEmulationCore)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FdanijelLoc%2FChip8iEmulationCore%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/danijelLoc/Chip8iEmulationCore)

# Chip8iEmulationCore

`Chip8iEmulationCore` is a Swift package for emulating the Chip8 system and running its programs. This package provides an emulation core that allows you to start emulation, process Chip8 program operations, handle input, and subscribe to Chip8 screen output and sound updates. 

The emulation core package can be used in frontend apps on macOS and iOS where you just have to propagate user input into the core and subscribe to output from it.

## Installation

To include `Chip8iEmulationCore` in your project, add it as a Swift Package Dependency:

1. In Xcode, go to `File` -> `Add Packages...`
2. Enter the URL of the repository and add the package to your project.

## Usage

### Import the Package

In your Swift file where you want to use the emulator:

```swift
import Chip8iEmulationCore

let emulationCore = Chip8EmulationCore()
```

### Load Chip8 program
First, load the chip8 program binary read-only (ROM) data `[UByte]` from the filesystem or otherwise and save it in `Chip8Program` structure ready for emulation.

```swift
let programROM = Chip8Program(name: "My Pong Game", contentROM: myPongGameROMData)
```

### Start emulation

The `emulate` function runs in an infinite loop (Chip8 programs don't have exit command), so ensure that it is run in a proper asynchronous context.
```swift
Task {
    await emulationCore.emulate(program: programROM)
}
```

### Handling Key Events
Chip8 has 16 system keys, from 0 to F. 
```swift
    1 2 3 C
    4 5 6 D
    7 8 9 E
    A 0 B F
```
To handle key press and release events:
```swift
emulationCore.onKeyDown(key: .Zero)  // Example: Press down Chip8 key '0'
emulationCore.onKeyDown(key: .One)  // Example: Press down Chip8 key '1'
emulationCore.onKeyUp(key: .F)  // Example: Release Chip8 key 'F'
```
Use the `onKeyDown` and `onKeyUp` methods to send input key `enum` to the emulator. For more details and example of keyboard bindings see `EmulationControls` module. 

> Note: Keyboard/controller/touchscreen-buttons can be custom mapped to Chip8 keys and this should be done in fronted app, emulation core only accepts `EmulationControls.Chip8Key` enum.

### Observing Output
The `outputScreen` and `outputSoundTimer` properties are marked with `@Published`, so you can subscribe to them and update the view and play the sound in `SwiftUI`, `UIKit`, or `AppKit`. 

### Screen Output Handling Example

Publisher Buffer `outputScreen` is a 64x32 grid of Boolean values, representing pixel states.

One way to reactively display screen updates from `outputScreen` publisher buffer is using `CGImage` extension method `fromMonochromeBitmap` included in the `Chip8iEmulationCore` package.

Here is an example of this approach in macOS frontend app which uses this package. Also included in the example is initialisation of core, starting the game and subscribing to sound timer change.

```swift
    @StateObject var emulationCore = Chip8EmulationCore()
    private let singlePingSound = NSSound(named: NSSound.Name("Ping"))

    var body: some View {
        VStack {
            Image(CGImage.fromMonochromeBitmap(emulationCore.outputScreen, 
              width: 64, height: 32)!, 
            scale: 5, label: Text("Output"))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        }
        .padding()
        .onAppear(perform: {
            Task {
                let program = readProgramFromFile(fileName: "Pong.ch8")
                await emulationCore.emulate(program: program)
            }
        })
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(phases: .down, action: onKeyDown)
        .onKeyPress(phases: .up, action: onKeyUp)
        .onChange(of: emulationCore.outputSoundTimer) { oldValue, newValue in
            handleSoundTimerChange(soundTimer: newValue)
        }
    }

```

### Sound Output Handling Note
Publisher `outputSoundTimer` is the UByte value of Chip8 System Sound timer. A short sound effect should be played on every value change if that value is larger than 0.

```swift
    func handleSoundTimerChange(soundTimer: UByte) {
        if soundTimer > 0 && !(singlePingSound?.isPlaying == true) {
            singlePingSound?.play()
        } else if soundTimer == 0 && singlePingSound?.isPlaying == true {
            singlePingSound?.stop()
        }
    }
```

### Usage example

This is example of integrating the chip8 emulation core and running it from simple macOS emulator frontend which provides game binary and key inputs to the core, and shows output from the core.

<img src="https://github.com/danijelLoc/Chip8iEmulationCore/blob/screenshots/.assets/example-frontend.png?raw=true" alt="Usage example in macos app" width="700"/>

### License
This package is licensed under the MIT License. See the `LICENSE` file for more information


