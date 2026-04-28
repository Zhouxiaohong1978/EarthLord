//
//  SplashView.swift
//  EarthLord
//
//  Created by 周晓红 on 2025/12/25.
//

import SwiftUI
import AVFoundation

// MARK: - AVPlayerLayer 包装（比 VideoPlayer 更稳定）

class _PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var player: AVPlayer? {
        get { (layer as? AVPlayerLayer)?.player }
        set {
            (layer as? AVPlayerLayer)?.player = newValue
            (layer as? AVPlayerLayer)?.videoGravity = .resizeAspect
        }
    }
}

struct _PlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> _PlayerUIView {
        let view = _PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: _PlayerUIView, context: Context) {
        uiView.player = player
    }
}

// MARK: - SplashView

struct SplashView: View {
    @Binding var isFinished: Bool

    @State private var player: AVPlayer?

    private let authManager = AuthManager.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                _PlayerView(player: player)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            setupVideo()
            checkSession()
        }
    }

    // MARK: - 视频播放

    private func setupVideo() {
        let preferredLanguage = Locale.preferredLanguages.first ?? ""
        let isChinese = preferredLanguage.hasPrefix("zh")
        let resourceName = isChinese ? "splash_video" : "splash_video_en"
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mov") ?? Bundle.main.url(forResource: "splash_video", withExtension: "mov") else {
            isFinished = true
            return
        }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.isMuted = false
        player = p
        p.play()

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isFinished = true
            }
        }
    }

    // MARK: - session 后台检查，不阻塞跳转

    private func checkSession() {
        Task { await authManager.checkSession() }
    }
}

#Preview {
    SplashView(isFinished: .constant(false))
}
