//
//  PreviewContentView.swift
//  dockPeek
//

import SwiftUI

struct PreviewContentView: View {
    let appName: String
    let windows: [WindowInfo]
    let thumbnailWidth: CGFloat
    var onWindowClick: ((WindowInfo) -> Void)?
    var onWindowClose: ((WindowInfo) -> Void)?
    var onQuitApp: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title bar
            HStack {
                Text(appName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: { onQuitApp?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit \(appName)")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if windows.isEmpty {
                Text("No windows open")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(windows) { windowInfo in
                            WindowThumbnailCard(
                                windowInfo: windowInfo,
                                thumbnailWidth: thumbnailWidth,
                                onClick: { onWindowClick?(windowInfo) },
                                onClose: { onWindowClose?(windowInfo) }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .padding(.bottom, 10)
        .frame(minWidth: thumbnailWidth + 24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct WindowThumbnailCard: View {
    let windowInfo: WindowInfo
    let thumbnailWidth: CGFloat
    var onClick: (() -> Void)?
    var onClose: (() -> Void)?
    @State private var isHovered = false

    private var thumbnailHeight: CGFloat {
        guard windowInfo.bounds.width > 0 else { return thumbnailWidth * 0.6 }
        let aspect = windowInfo.bounds.height / windowInfo.bounds.width
        return thumbnailWidth * aspect
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumbnail = windowInfo.thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "macwindow")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.tertiary)
                            }
                    }
                }
                .frame(width: thumbnailWidth, height: thumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                if isHovered {
                    Button(action: { onClose?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .transition(.opacity)
                }
            }

            Text(windowInfo.displayTitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: thumbnailWidth)
        }
        .onTapGesture { onClick?() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
