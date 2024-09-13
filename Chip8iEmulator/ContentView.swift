//
//  ContentView.swift
//  Chip8iEmulator
//
//  Created by Danijel Stracenski on 28.05.2024..
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject var emulationCore = Chip8EmuCore()
    private let beepingSound = NSSound(named: NSSound.Name("Ping"))
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "gamecontroller")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Let's play!")
            }
            Image(CGImage.fromMonochromeBitmap(pixels: emulationCore.outputScreen, width: 64, height: 32)!, scale: 5, label: Text("Output")) // TODO: create separate component
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        }
        .padding()
        .onAppear(perform: {
            Task {
                await emulationCore.emulate("Pong")
            }
        })
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(phases: .down, action: onKeyDown)
        .onKeyPress(phases: .up, action: onKeyUp)
        .onChange(of: emulationCore.outputSoundTimer) { oldValue, newValue in
            handleSoundTimer(soundTimer: newValue)
        }
    }
    
    func onKeyDown(key: KeyPress) -> KeyPress.Result {
        emulationCore.onKeyDown(key: key.key.character)
        return .handled
    }
    
    func onKeyUp(key: KeyPress) -> KeyPress.Result {
        emulationCore.onKeyUp(key: key.key.character)
        return .handled
    }
    
    func handleSoundTimer(soundTimer: UByte) {
        if soundTimer > 0 && !(beepingSound?.isPlaying == true) {
            beepingSound?.play()
        } else if soundTimer == 0 && beepingSound?.isPlaying == true {
            beepingSound?.stop()
        }
    }
}



#Preview {
    ContentView()
}

extension CGImage {
    public static func fromMonochromeBitmap(pixels: [Bool], width: Int, height: Int) -> CGImage? {
        guard width > 0 && height > 0 else { return nil }
        guard pixels.count == width * height else { return nil }
        
        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo: CGBitmapInfo = [CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderDefault.rawValue)]

        var data: [UByte] = pixels.map {x in (x ? 1 : 0)  * 255 } // Copy to mutable []
//        data[64*0 + 0] = 255
//        data[64*0 + 1] = 255
//        data[64*1 + 0] = 255
        
        // Testing output
//        data[64*5 + 14] = 255
//        data[64*5 + 15] = 255
//        data[64*5 + 16] = 255
//        data[64*5 + 17] = 255
////        
//        data[64*6 + 15] = 255
//        data[64*6 + 16] = 255


        guard let providerRef = CGDataProvider(data: NSData(bytes: &data, length: data.count * MemoryLayout<UInt8>.size))
        else { return nil }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width * MemoryLayout<UInt8>.size,
            space: grayColorSpace,
            bitmapInfo: bitmapInfo,
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }

        return cgImage
    }
}
