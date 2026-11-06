# 维护约定

- Package / module 固定使用 `YCLongScreenshotKit`；公开类型、文件名采用 `YC` / `YCLongScreenshot` 前缀。
- SwiftUI 和 UIKit 对外集成接口保持兼容；优先增加带默认值的配置项。
- 修复拼接问题时，先给 `YCScrollSlicePlannerTests` 添加覆盖用例，再改几何计算。
- 涉及 UI 绘制的修改需要至少验证 SwiftUI ScrollView、List、Form、UITableView 和深色模式。
- 新增可见进度提示或弹层时，要确保它不会出现在被截图的窗口快照中。
- 考虑 MainActor、取消恢复、内存限制和用户隐私；不要添加无必要的网络服务或统计依赖。
- 保留 MIT 许可证说明，保持纯 Swift Package，无须 GitHub Actions。
