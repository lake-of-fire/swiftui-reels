//
//  File.swift
//
//
//  Created by Jordan Howlett on 6/25/24.
//

import Nuke
import SwiftUI

public enum ScaleType {
    case fit, fill
}

@available(iOS 16.0, macOS 13.0, *)
public struct StreamingImage: View {
    @EnvironmentObject private var recorder: Recorder

    let url: URL?
    private let scaleType: ScaleType
    @State private var image: PlatformImage? = nil

    public init(url: URL?, scaleType: ScaleType = .fill) {
        self.url = url
        self.scaleType = scaleType
    }

    public var body: some View {
        VStack {
            if let image = image {
                platformImageView(image)
                    .resizable()
                    .aspectRatio(contentMode: scaleType == .fill ? .fill : .fit)
                    .onAppear {
                        recorder.resumeRecording()
                    }
            }
        }
        .onAppear {
            recorder.pauseRecording()
            Task {
                await loadImage()
            }
        }
    }

    private func loadImage() async {
        guard let url = url else { return }

        do {
            self.image = try await PreloadManager.shared.image(from: url)
        } catch {
            LoggerHelper.shared.error("Failed to preload image: \(error)")
        }
    }

    private func platformImageView(_ image: PlatformImage) -> Image {
        #if canImport(UIKit)
        Image(uiImage: image)
        #elseif canImport(AppKit)
        Image(nsImage: image)
        #else
        Image(systemName: "photo")
        #endif
    }
}
