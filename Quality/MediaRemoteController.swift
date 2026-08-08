//
//  MediaRemoteController.swift
//  LosslessSwitcher
//
//  Created by Vincent Neo on 1/5/22.
//

import Cocoa
import MediaRemoteAdapter

class MediaRemoteController {
    
    private let controller: MediaController
    private var restartWorkItem: DispatchWorkItem?
    
    init(outputDevices: OutputDevices) {
        
        // Listen to all now-playing apps so we can reset when playback leaves Music.
        let controller = MediaController()
        self.controller = controller
        
        controller.onTrackInfoReceived = { [weak outputDevices] trackInfo in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                guard let outputDevices else { return }
                let bundleId = trackInfo.payload.bundleIdentifier
                let isMusic = bundleId == MusicApp.bundleIdentifier
                
                if !isMusic {
                    outputDevices.resetToDefaultSampleRate()
                    return
                }
                
                if trackInfo.payload.isPlaying == false {
                    outputDevices.musicPlaybackPaused()
                    return
                }
                
                outputDevices.trackDidChange(trackInfo)
            }
        }
        
        controller.onListenerTerminated = { [weak self] in
            self?.scheduleRestart()
        }
        
        controller.startListening()
    }
    
    deinit {
        restartWorkItem?.cancel()
        controller.onListenerTerminated = nil
        controller.stopListening()
    }
    
    private func scheduleRestart() {
        restartWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.controller.startListening()
        }
        restartWorkItem = work
        // Brief delay avoids a tight crash/restart loop if perl exits immediately.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }
    
}
