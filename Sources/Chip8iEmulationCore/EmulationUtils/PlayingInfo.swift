//
//  PlayingInfo.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 24.02.2025..
//

public struct PlayingInfo: Equatable, Codable {
    public var hasStarted: Bool
    public var isPlaying: Bool

    public init(hasStarted: Bool, isPlaying: Bool) {
        self.hasStarted = hasStarted
        self.isPlaying = isPlaying
    }

    public static func == (lhs: PlayingInfo, rhs: PlayingInfo) -> Bool {
        return lhs.hasStarted == rhs.hasStarted
            && lhs.isPlaying == rhs.isPlaying
    }
}
