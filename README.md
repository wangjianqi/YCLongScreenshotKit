# YCLongScreenshotKit

**iOS 原生开发调试用长截图 Swift Package**。无需修改各个页面的行视图；在 App 的根视图安装一次摇一摇入口，自动识别当前页面主要垂直滚动视图，滚动、截取、按位置拼接，完成后可保存相册或通过系统分享面板 AirDrop 到 Mac。

- 项目名称、模块名和所有对外 API 均使用 `YC` / `YCLongScreenshot` 命名约定。
- 适用：iOS 16+、SwiftUI / UIKit、Swift Package Manager；零第三方依赖。
- 可用于 `ScrollView`、`LazyVStack`、`List`、`UITableView`、`UICollectionView` 等标准纵向滚动容器（具体页面仍需实机验证）。
- 自动识别不可靠时，允许显式指定 `UIScrollView`。
- 保留导航栏 / 底部栏一次（标准全宽滚动区域）；部分宽度的滚动区自动切换为仅导出滚动内容。
- 捕获结束后恢复之前的 `contentOffset`、交互状态与滚动条显示设置；错误或取消时同样恢复。
- 通过 `maximumSteps`、`maximumOutputPixels` 和 `maximumBufferedPixels` 控制风险，防止无限列表导致内存耗尽。

> **状态**：首版实现/源代码已提供。当前交付环境为 Linux，没有 Apple 的 UIKit 和 iOS Simulator SDK，无法执行 Xcode 编译或真机截图验收。项目中的单元测试、示例工程需要在 Mac Xcode 上运行。它不是已经验证适配所有 iOS 27 Beta 页面类型的正式发布版本。

## 一分钟接入 SwiftUI

1. Xcode → File → Add Package Dependencies → Add Local，选择 `YCLongScreenshotKit` 根目录（含 `Package.swift`）。
2. 在 App target → `Info` 添加 `Privacy - Photo Library Additions Usage Description`（`NSPhotoLibraryAddUsageDescription`），例如「用于保存开发调试生成的长截图」。仅使用系统分享面板则不必调用相册直存接口。
3. 在 App 的**根 `TabView` 或根导航容器**安装一次：

```swift
import SwiftUI
import YCLongScreenshotKit

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                #if DEBUG
                .ycLongScreenshotOnShake()
                #endif
        }
    }
}
```

真机摇一摇；模拟器菜单 `Device → Shake`（各版本菜单名称可能不同）。截取完成后弹出「保存到相册 / 分享 · AirDrop」。**只有 Debug 构建带摇动入口**；Release 不会自动启用该功能。

如需模拟器里点击按钮测试：

```swift
Button("生成当前页面长截图") {
    YCLongScreenshotTrigger.requestCapture()
}
```

## 编程接口

直接抓取当前页面（没有垂直滚动区时自动退化为普通截图）：

```swift
let result = try await YCLongScreenshotKit.shared.captureCurrentPage()
// result.image              UIImage
// result.fileURL            临时 PNG 文件地址
// result.pixelSize          最终像素尺寸
// result.isLongScreenshot   是否实际进行了长截图
```

显式指定滚动区域，适合嵌套滚动或复杂分栏：

```swift
let configuration = YCLongScreenshotConfiguration(
    layout: .contentOnly,
    scale: 2,
    settleDelay: 0.25,
    overlap: 40,
    maximumSteps: 60
)
let result = try await YCLongScreenshotKit.shared.capture(
    scrollView: myScrollView,
    configuration: configuration
)
```

分享和直接保存到相册：

```swift
// 在 SwiftUI .sheet 里展示：
YCLongScreenshotShareSheet(image: result.image)

// 直接写相册（宿主 App 必须声明 NSPhotoLibraryAddUsageDescription）：
try await YCLongScreenshotPhotoLibrary.save(result)
```

## Demo 工程

在 Xcode 打开：`Examples/YCLongScreenshotDemo/YCLongScreenshotDemo.xcodeproj`

运行 iPhone 模拟器或真机，测试下列页面：

- **Today**：`ScrollView + LazyVStack`、65 条项目；
- **History**：SwiftUI `List`、55 条项目；
- **Settings**：`Form` 多个分组；
- **详情页**：导航栈 Push 后的长内容；
- 每个页面右上角都有 Debug 备用截图按钮，也可摇一摇触发。

开发测试命令：

```bash
cd YCLongScreenshotKit
xcodebuild test -scheme YCLongScreenshotKit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# 根据本机模拟器名称调整 -destination
xcrun simctl list devices available
```

## 设计取舍 / 已知边界

1. **不是系统级万能截图**。SwiftUI `List` / `LazyVStack` 会懒加载、预估动态高度；有网络增量分页、滚动时高度剧变或无限加载的页面可能不完整，超过限制会明确抛错。
2. **当前可见页面**是当前前台 UIWindow 的最上层可见页面，自动选取最大且可滚动的纵向 UIScrollView。嵌套滚动或双栏需要调用 `capture(scrollView:)` 指定目标。
3. `WKWebView`、Metal/RealityKit、AVPlayer、地图、复杂背景模糊、固定在滚动内容内部的悬浮控件等，不保证像素一致；这类页面建议做专项适配。不会读取屏幕以外的数据模型，也不会突破 iOS 系统的渲染保护。
4. **上下固定栏只保留一次**：从初始窗口截图取得滚动框以外的顶部/底部区域，滚动主体单独截图拼接。若导航栏覆盖整个 ScrollView 的内部区域（透明导航栏或特殊 safe-area 布局），可能需要修正可见裁剪区域；中间浮层也可能在导出后缺失。
5. 若视图宽度明显小于窗口（例如 iPad Split View），默认只导出滚动部分，避免将其他栏错误拉长。
6. **滚动会真实改变页面位置**，结束后恢复；它不是完全无副作用的离屏渲染。具有 `onAppear` 分页、副作用或滚动联动的页面，请使用专门的屏幕截图测试数据源。
7. 长图**默认 1.5x**，可选 1–3x；超高图可能被系统相册或第三方分享目标拒绝。默认临时 PNG 不主动清理；App 可以在分享完成后删除 `result.fileURL`。
8. SwiftUI 的摇一摇实现基于 responder chain：当键盘/TextField 占据第一响应者时，可能无法收到 Shake。UIKit 应用可使用 `YCShakeCaptureWindow`；SwiftUI 应保留备用按钮，不建议采用全局 method swizzling。
9. `#if DEBUG` 应包住**宿主 App 的触发入口**；SPM 模块本身不会在 Release 自动消失。如果明确要求产品内使用，需要自己决定权限和入口。

## 维护目录

```text
Sources/YCLongScreenshotKit/
  YCLongScreenshotKit.swift       # 对外入口，状态恢复和导出
  YCLongScreenshotTypes.swift     # 公共配置 / 结果 / 错误
  YCScrollViewLocator.swift       # 活动窗口 / 当前滚动区域选择
  YCScrollSlicePlanner.swift      # 重叠区域消除计算
  YCCaptureRendering.swift       # UIKit 快照 / 最终 PNG 合成
  YCShakeCaptureView.swift        # 摇一摇触发器和备用触发
  YCLongScreenshotDebugModifier.swift # SwiftUI 一次性接入
  YCLongScreenshotSharing.swift   # 相册与分享
Tests/                          # 几何测试 / 集成测试
Examples/YCLongScreenshotDemo/   # 独立 Xcode Demo
```

## 参考与许可

核心实现独立编写，参考了 [num42/swift-ScreenshotKit](https://github.com/num42/swift-ScreenshotKit) 对滚动截图问题的**方案描述**；未复制该仓库的源码。第三方仓库当前仅见 README 标注 MIT，需以其仓库实际许可证和历史提交为准。本仓库源代码采用 MIT License（详见 `LICENSE`）。

不包含 GitHub Actions 或外部网络依赖。
