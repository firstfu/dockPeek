//
//  PreviewContentView.swift
//  dockPeek
//
//  預覽面板的 SwiftUI 內容視圖。顯示 app 名稱與視窗縮圖清單，
//  提供點擊切換視窗、關閉視窗及退出 app 等互動操作。
//

import SwiftUI

struct PreviewContentView: View {
    let appName: String
    let windows: [WindowInfo]
    let thumbnailWidth: CGFloat
    let previewScale: CGFloat
    var onWindowClick: ((WindowInfo) -> Void)?
    var onWindowClose: ((WindowInfo) -> Void)?
    var onQuitApp: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * previewScale) {
            // Title bar
            HStack {
                Text(appName)
                    .font(.system(size: 13 * previewScale, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: { onQuitApp?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14 * previewScale))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit \(appName)")
            }
            .padding(.horizontal, 12 * previewScale)
            .padding(.top, 8 * previewScale)

            if windows.isEmpty {
                Text("No windows open")
                    .font(.system(size: 12 * previewScale))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20 * previewScale)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10 * previewScale) {
                        ForEach(windows) { windowInfo in
                            WindowThumbnailCard(
                                windowInfo: windowInfo,
                                thumbnailWidth: thumbnailWidth,
                                previewScale: previewScale,
                                onClick: { onWindowClick?(windowInfo) },
                                onClose: { onWindowClose?(windowInfo) }
                            )
                        }
                    }
                    .padding(.horizontal, 12 * previewScale)
                }
            }
        }
        .padding(.bottom, 10 * previewScale)
        .frame(minWidth: thumbnailWidth + 24 * previewScale)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10 * previewScale))
        .shadow(color: .black.opacity(0.2), radius: 8 * previewScale, x: 0, y: 4 * previewScale)
    }
}

struct WindowThumbnailCard: View {
    let windowInfo: WindowInfo
    let thumbnailWidth: CGFloat
    let previewScale: CGFloat
    var onClick: (() -> Void)?
    var onClose: (() -> Void)?
    @State private var isHovered = false

    private var thumbnailHeight: CGFloat {
        guard windowInfo.bounds.width > 0 else { return thumbnailWidth * 0.6 }
        let aspect = windowInfo.bounds.height / windowInfo.bounds.width
        return thumbnailWidth * aspect
    }

    var body: some View {
        VStack(spacing: 4 * previewScale) {
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
                                    .font(.system(size: 24 * previewScale))
                                    .foregroundStyle(.tertiary)
                            }
                    }
                }
                .frame(width: thumbnailWidth, height: thumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: 6 * previewScale))

                // Minimized window overlay indicator
                if windowInfo.isMinimized {
                    RoundedRectangle(cornerRadius: 6 * previewScale)
                        .fill(.black.opacity(0.3))
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .overlay {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 20 * previewScale, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                }

                if isHovered {
                    Button(action: { onClose?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16 * previewScale))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                    }
                    .buttonStyle(.plain)
                    .padding(4 * previewScale)
                    .transition(.opacity)
                }
            }

            Text(windowInfo.displayTitle)
                .font(.system(size: 11 * previewScale))
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
