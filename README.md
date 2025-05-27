[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FdanijelLoc%2FChip8iEmulationCore%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/danijelLoc/Chip8iEmulationCore)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FdanijelLoc%2FChip8iEmulationCore%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/danijelLoc/Chip8iEmulationCore)

# Chip8iEmulationCore

`Chip8iEmulationCore` is a Swift package for emulating the Chip8 system and running its programs. This package provides an emulation core that allows you to start emulation, process Chip8 program operations, handle input, and subscribe to Chip8 screen output and sound updates. 

The emulation core package can be used in frontend apps on macOS and iOS where you just have to propagate user input into the core and subscribe to output from it.

## Features

- Simultaneous key `input`
- `Video` and `Audio` output
- `Debug` info publishing
- `Pause` and `Resume` emulation
- `Save` and `Load` emulation states during gameplay
- `Logging` with custom log levels and handlers

## Installation

To include `Chip8iEmulationCore` in your project, add it as a Swift Package Dependency:

1. In Xcode, go to `File` -> `Add Packages...`
2. Enter the URL of the repository and add the package to your project.

## Usage

### Import the Package

In your Swift file where you want to use the emulator:

```swift
import Chip8iEmulationCore

let emulationCore = Chip8EmulationCore(soundHandler: nil, logger: nil)
```

### Load Chip8 program
First, load the chip8 program binary read-only (ROM) data `[UByte]` from the filesystem or otherwise and save it in `Chip8Program` structure ready for emulation.

```swift
let chip8Program = Chip8Program(name: "My Pong Game", contentROM: myPongGameROMData)
```

### Start emulation

The `emulate` function runs in an infinite loop (Chip8 programs don't have exit command), so ensure that it is run in a proper asynchronous context.
```swift
Task {
    await emulationCore.emulate(chip8Program)
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
emulationCore.onKeyDown(.Zero)  // Example: Press down Chip8 key '0'
emulationCore.onKeyDown(.One)  // Example: Press down Chip8 key '1'
emulationCore.onKeyUp(.F)  // Example: Release Chip8 key 'F'
```
Use the `onKeyDown` and `onKeyUp` methods to send input key `enum` to the emulator. For more details and example of keyboard bindings see `EmulationControls` module. 

> Note: Keyboard/controller/touchscreen-buttons can be custom mapped to Chip8 keys and this should be done in fronted app, emulation core only accepts `Chip8Key` enum.

### Observing Output Publishers
The `outputScreenPublisher` is used for publishing screen information about emulation output, you can subscribe to it and update the view in `SwiftUI`, `UIKit`, or `AppKit`.
The `playingInfoPublisher` sends information about status of the emulation like `hasStarted` and `isPlaying` 

### Screen Output Handling Example

Publisher Buffer `outputScreenPublisher` is a 64x32 grid of Boolean values, representing pixel states.

One way to reactively display screen updates from `outputScreen` publisher buffer is using `CGImage` extension method `fromMonochromeBitmap` included in the `Chip8iEmulationCore` package.

Here is an example of this approach in macOS frontend app which uses this package. Also included in the example is initialization of core, starting the game and subscribing to sound timer change.

```swift
var emulationCore = Chip8EmulationCore(soundHandler: PrerecordedSoundHandler(with: "Beep2.wav"), logger: nil)
@State private var lastFrame: [Bool] = Array(repeating: false, count: 64*32)

var body: some View {
    VStack {
        Image(CGImage.fromMonochromeBitmap(lastFrame,
          width: 64, height: 32)!,
        scale: 5, label: Text("Output"))
            .interpolation(.none)
            .resizable()
            .scaledToFit()
    }
    .padding()
    .onAppear(perform: {
        Task {
            guard let program = loadGameFromBundle(gameName: "Pong.ch8") else { return }
            await emulationCore.emulate(program)
        }
    })
    .onReceive(emulationCore.outputScreenPublisher) { frame in
        self.lastFrame = frame
    }
}

private func loadGameFromBundle(gameName: String) -> Chip8Program? {
    guard let fileUrl = Bundle.main.url(forResource: gameName, withExtension: nil) else { return nil }
    guard let data = try? Data(contentsOf: fileUrl) else { return nil }
    let romData = data.compactMap { $0 }
    return Chip8Program(name: gameName, contentROM: romData)
}
```

### Keyboard input example for macOS

This is the code needed for macOS input propagation to the core.

```swift
// ... 

var body: some View {
    VStack {
        // ...
    }
    // ...
    .focusable()
    .focusEffectDisabled()
    .onKeyPress(phases: .down, action: onKeyDown)
    .onKeyPress(phases: .up, action: onKeyUp)
}

private func onKeyDown(key: KeyPress) -> KeyPress.Result {
    guard let chip8Key = Chip8Key.StandardKeyboardBinding[key.key.character] else { return .ignored }
    emulationCore.onKeyDown(chip8Key)
    return .handled
}

private func onKeyUp(key: KeyPress) -> KeyPress.Result {
    guard let chip8Key = Chip8Key.StandardKeyboardBinding[key.key.character] else { return .ignored }
    emulationCore.onKeyUp(chip8Key)
    return .handled
}
```


### Sound Handling Note
To use sound you need to pass implementation of SoundHandlerProtocol to the Chip8EmulationCore constructor. 
Existing tested implementation is PrerecordedSoundHandler which requires existing short sound file (1 second beep sound is optimal).
```swift
// Example where sound file was in Swift frontend project resources and passed to the core
let soundHandler = PrerecordedSoundHandler(with: "Beep2.wav") 
let emulationCore = Chip8EmulationCore(soundHandler: soundHandler)
```

### Emulation status update with pausing and exiting
To get current emulation status you can use `playingInfoPublisher`, to update it you can use methods: `togglePause` for pause/resume, `stop`, and `emulate` to restart the emulation.

### Usage examples

### Simple macOS frontend

With code provided in this README, you should be able to recreate this simple macOS frontend. Chip8 game ROMs aka .ch8 files can found online and are mainly public domain. 
Emulator frontend provides game binary and key inputs to the core and shows output from the core.

<img src="https://github.com/danijelLoc/Chip8iEmulationCore/blob/screenshots/.assets/example-frontend.png?raw=true" alt="Usage example in macos app" width="700"/>

### More complex iOS and macOS Frontend 

[Chip8iEmulationFrontend](https://github.com/danijelLoc/Chip8iEmulationFrontend)
This multiplatform SwiftUI example uses the majority of the core package features.

## License
This package is licensed under the MIT License. See the `LICENSE` file for more information


