# 当前交付验证记录

环境：Linux x86_64，Swift 6.2.1；缺少 Apple UIKit、Xcode、iOS Simulator SDK。

通过的静态检查：

- `swift package dump-package`：SwiftPM 清单可以加载；
- `swift package describe --type json`：产品与测试 Target 可以识别；
- `swiftc -frontend -parse`：所有 Swift 源码、测试与 Demo 均可解析；
- `plutil -lint`：Demo 的 `project.pbxproj` 语法合法；
- 将 `YCScrollSlicePlanner.swift` 与轻量错误类型在 Linux 单独编译执行：偏移重叠、非零滚动起点、重复偏移、截图空洞均符合预期。

尚未验证：

- iOS/UIKit 的完整 Swift 类型检查和链接；
- Xcode 编译、Simulator 及真机运行；
- SwiftUI `List`、`LazyVStack`、`Form` 的真实渲染结果；
- 照片权限弹窗与 AirDrop 分享行为；
- iOS 27 Beta 不同容器/屏幕状态的兼容性。

第一次在 Mac 上构建并运行后，应将上述项目的结果更新到此文档，遇到问题请优先附上截图页面类型和输出日志。
