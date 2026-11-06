#if DEBUG
import SwiftUI

/// Attach once to the root TabView / root navigation shell.
/// Do not ship with production builds: guard usage using `#if DEBUG` in the host app.
public extension View {
    func ycLongScreenshotOnShake(
        configuration: YCLongScreenshotConfiguration = .init(),
        showsCaptureButton: Bool = false
    ) -> some View {
        modifier(YCLongScreenshotDebugModifier(
            configuration: configuration, showsCaptureButton: showsCaptureButton
        ))
    }
}

private struct YCLongScreenshotDebugModifier: ViewModifier {
    let configuration: YCLongScreenshotConfiguration
    let showsCaptureButton: Bool

    @State private var lastResult: YCLongScreenshotResult?
    @State private var showCompletion = false
    @State private var showShareSheet = false
    @State private var isWorking = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    func body(content: Content) -> some View {
        content
            .background {
                YCShakeCaptureView(onShake: startCapture)
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            }
            .onReceive(NotificationCenter.default.publisher(
                for: YCLongScreenshotTrigger.captureRequested
            )) { _ in startCapture() }
            .overlay(alignment: .topTrailing) {
                if showsCaptureButton {
                    Button(action: startCapture) {
                        Image(systemName: "camera.viewfinder")
                            .padding(10)
                            .background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel("生成开发长截图")
                    .accessibilityIdentifier("debug.longScreenshot")
                    .padding(.trailing, 12)
                    .opacity(isWorking ? 0 : 1)
                    .disabled(isWorking)
                }
            }
            .confirmationDialog(
                "长截图已完成",
                isPresented: $showCompletion,
                titleVisibility: .visible
            ) {
                if Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") != nil {
                    Button("保存到相册") { savePhoto() }
                }
                Button("分享 / AirDrop") { showShareSheet = true }
                Button("取消", role: .cancel) {}
            } message: {
                Text(lastResult?.isLongScreenshot == true
                     ? "已生成完整滚动截图。"
                     : "当前页面无法滚动，已生成普通截图。")
            }
            .sheet(isPresented: $showShareSheet) {
                if let result = lastResult {
                    YCLongScreenshotShareSheet(image: result.image)
                        .ignoresSafeArea()
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
    }

    private func startCapture() {
        guard !isWorking else { return }
        isWorking = true
        Task { @MainActor in
            defer { isWorking = false }
            do {
                // Hide any previous sheet/dialog before the next snapshot begins.
                showCompletion = false
                showShareSheet = false
                lastResult = try await YCLongScreenshotKit.shared.captureCurrentPage(
                    configuration: configuration
                )
                showCompletion = true
            } catch {
                alertTitle = "长截图失败"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func savePhoto() {
        guard let result = lastResult else { return }
        Task { @MainActor in
            do {
                try await YCLongScreenshotPhotoLibrary.save(result)
                alertTitle = "已保存"
                alertMessage = "长截图已保存到照片。"
            } catch {
                alertTitle = "保存失败"
                alertMessage = error.localizedDescription
            }
            showAlert = true
        }
    }
}

#endif
