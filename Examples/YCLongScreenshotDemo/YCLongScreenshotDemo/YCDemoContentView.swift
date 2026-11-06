import SwiftUI
import YCLongScreenshotKit

struct YCDemoContentView: View {
    var body: some View {
        tabs
            #if DEBUG
            .ycLongScreenshotOnShake()
            #endif
    }

    private var tabs: some View {
        TabView {
            NavigationStack {
                home
                    .navigationTitle("Today")
                    .toolbar { screenshotButton }
            }
            .tabItem { Label("Today", systemImage: "house") }

            NavigationStack {
                history
                    .navigationTitle("History")
                    .toolbar { screenshotButton }
            }
            .tabItem { Label("History", systemImage: "clock") }

            NavigationStack {
                settings
                    .navigationTitle("Settings")
                    .toolbar { screenshotButton }
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }

    @ToolbarContentBuilder
    private var screenshotButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            #if DEBUG
            Button {
                YCLongScreenshotTrigger.requestCapture()
            } label: {
                Image(systemName: "camera.viewfinder")
            }
            .accessibilityLabel("生成长截图")
            #endif
        }
    }

    private var home: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("YCLongScreenshotKit")
                        .font(.title2.bold())
                    Text("摇一摇手机，或点击右上角相机按钮")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

                ForEach(0..<65, id: \.self) { index in
                    NavigationLink {
                        detail(index)
                    } label: {
                        HStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.gray.opacity(0.15))
                                .frame(width: 46, height: 46)
                                .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("今日任务 #\(index + 1)")
                                    .foregroundStyle(.primary)
                                Text("可滚动的懒加载内容")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(16)
        }
    }

    private var history: some View {
        List(0..<55, id: \.self) { index in
            HStack {
                Image(systemName: "checkmark.circle")
                Text("历史记录 \(index + 1)")
            }
            .padding(.vertical, 9)
        }
    }

    private var settings: some View {
        Form {
            Section("截图设置") {
                Text("仅调试模式启用")
                Text("可保存到照片或分享到 Mac")
            }
            ForEach(0..<8, id: \.self) { section in
                Section("设置分组 \(section + 1)") {
                    ForEach(0..<5, id: \.self) { row in
                        Label("设置项 \(row + 1)", systemImage: "gearshape")
                    }
                }
            }
        }
    }

    private func detail(_ index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("任务详情 #\(index + 1)")
                    .font(.title.bold())
                ForEach(0..<45, id: \.self) { item in
                    Text("详情内容 \(item + 1)：用于测试导航子页面的长截图。")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.gray.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { screenshotButton }
    }
}
