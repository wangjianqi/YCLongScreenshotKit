# 架构与维护说明

## 数据流

1. `YCShakeCaptureView` / `YCLongScreenshotTrigger` 触发 `YCLongScreenshotDebugModifier`。
2. `YCLongScreenshotKit.shared.captureCurrentPage` 寻找激活窗口和目标滚动容器。
3. 暂存 `contentOffset` / `isUserInteractionEnabled` / indicators，并在 `defer` 中恢复。
4. 滚动至顶部后，依次改变 offset，等待异步布局，抓取 UIScrollView 的当前可见绘制。
5. 根据实际偏移量，`YCScrollSlicePlanner` 去除重叠区域；如出现空洞，抛错而非悄悄输出缺失图。
6. `YCCaptureRendering` 合成一次性导航栏与滚动主体（非全宽场景仅内容）。
7. 输出 PNG 到临时目录；原生照片/分享接口由宿主选择。

## 为什么不将 ScrollView frame 改成 contentSize？

SwiftUI 的懒加载、UITableView 重用机制和 WKWebView 的绘制都依赖可见区域。整体扩张 bounds 可能导致空白区域、布局错乱或大量内存分配。本项目采用分段截取可视区域。

## 改进建议（后续版本）

- 对 Dynamic Type 和自适应估算高度进行两次布局扫描；
- 支持显式排除/保留固定浮层，解决中间浮层混入滚动主体的问题；
- 流式拼接：输出较大的 PNG 时，将条带分片落盘，减小内存峰值；
- 多窗口/Stage Manager 场景显式关联触发源 UIWindowScene；
- 提供 UIKit/SwiftUI 可测试的实际屏幕快照 golden test；
- 正确裁剪被透明导航栏覆盖的 scroll viewport；
- 可注册每页滚动视图的弱引用，避免多层内嵌时自动选错。

## 验收检查

- 首次启动，Today 顶部、底部各行均出现在最终图中；
- 在 Today 中途摇一摇，完成后应恢复原滚动偏移；
- List、Form、子页面能正确获取内容；
- 保存到相册 / AirDrop 在真机可用；
- 摇动连续触发只产生一个任务；
- 切换深色模式；中英文/长文本；横屏；iPad；
- 超出图片限制时明确失败且不损坏页面状态；
- Release 版不出现开发截图入口。
