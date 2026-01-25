//
//  ContentView.swift
//  XHS_Downloader_iOS
//
//  Created by NEORUAA Q on 2025/11/15.
//

import SwiftUI
import AVFoundation
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = DownloaderViewModel()
    @State private var showingSettings = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(showingSettings: $showingSettings)
                .tag(0)
                .tabItem {
                    Image(systemName: "link")
                    Text("操作")
                }

            LogView(showingSettings: $showingSettings)
                .tag(1)
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("日志")
                }

            DownloadsView(showingSettings: $showingSettings)
                .tag(2)
                .tabItem {
                    Image(systemName: "arrow.down")
                    Text("下载")
                }
        }
        .onChange(of: viewModel.shouldSwitchToLogTab) { shouldSwitch in
            if shouldSwitch {
                selectedTab = 1
                // 重置标志
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.shouldSwitchToLogTab = false
                }
            }
        }
        .environmentObject(viewModel)
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                SettingsSheet()
                    .navigationTitle("设置")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完成") {
                                showingSettings = false
                            }
                        }
                    }
            }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var viewModel: DownloaderViewModel
    @Binding var showingSettings: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("输入链接")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        ShareInputField(text: $viewModel.shareText)
                            .padding(.horizontal, 16)

                        HStack(spacing: 10) {
                            Button {
                                pasteLinkFromClipboard()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("粘贴链接")
                                        .fontWeight(.semibold)
                                        .padding(.vertical, 10)
                                    Spacer()
                                }
                            }
                            .glassEffect()
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isDownloading)
                            .frame(maxWidth: .infinity)

                            Button {
                                viewModel.startDownload()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text(viewModel.isDownloading ? "下载中…" : "开始下载")
                                        .fontWeight(.semibold)
                                        .padding(.vertical, 10)
                                    Spacer()
                                }
                            }
                            .glassEffect()
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.shareText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isDownloading)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 16)

                        Button {
                            viewModel.copyDescription { message in
                                // 在实际应用中，可以使用更合适的UI反馈
                                print(message) // 临时输出到控制台
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("提取文案")
                                    .fontWeight(.semibold)
                                    .padding(.vertical, 10)
                                Spacer()
                            }
                        }
                        .glassEffect()
                        .buttonStyle(.bordered)
                        .disabled(viewModel.shareText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isDownloading)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                    }

                    // 工具部分暂时为空，因为移除了"网页爬取模式"按钮
                }
                .padding(.top, 10)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("小红书下载器")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    private func pasteLinkFromClipboard() {
        if let clipboardContent = UIPasteboard.general.string {
            viewModel.shareText = clipboardContent
        }
    }
}

struct LogView: View {
    @EnvironmentObject var viewModel: DownloaderViewModel
    @Binding var showingSettings: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    if viewModel.showProgress || viewModel.isDownloading {
                        VStack(spacing: 6) {
                            HStack {
                                Text("进度")
                                Spacer()
                                Text(viewModel.progressText.isEmpty ? "--" : viewModel.progressText)
                                    .foregroundColor(.gray)
                            }
                            ProgressView(value: viewModel.progressValue)
                                .progressViewStyle(LinearProgressViewStyle())
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 16)
                    }

//                    Text("日志状态")
//                        .font(.headline)
//                        .padding(.horizontal, 16)

                    if viewModel.logEntries.isEmpty {
                        VStack {
                            Text("暂无内容，开始下载后会显示日志")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(16)
                        }
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 6) {
                                    ForEach(viewModel.logEntries) { log in
                                        Text(log.displayText)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(log.id == viewModel.logEntries.last?.id ? .accentColor : .primary)
                                            .padding(.vertical, 2)
                                            .id(log.id)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                            }
                            .onChange(of: viewModel.logEntries.last?.id) { id in
                                guard let id else { return }
                                DispatchQueue.main.async {
                                    withAnimation {
                                        proxy.scrollTo(id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("日志状态")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }
}

struct DownloadsView: View {
    @EnvironmentObject var viewModel: DownloaderViewModel
    @Binding var showingSettings: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.mediaItems.isEmpty {
                    VStack {
                        Text("暂无内容，开始下载后会显示缩略图")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(16)
                        
                        Spacer() // 向下顶
                    }
                } else {
                    VStack(spacing: 0) {
                        WaterfallGrid(viewModel.mediaItems, columns: 2, spacing: 12) { item in
                            MediaTile(item: item)
                        }
                    }
                    .ignoresSafeArea(edges: .all)
                }
            }
            .navigationTitle("已下载")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }
}


struct ShareInputField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    private let placeholder = "苹果iPhone原生4K壁... http://xhslink.com/o/8xU2muQboVH 复制后打开【小红书】查看笔记！"

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                ZStack(alignment: .topTrailing) {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(3...6)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .focused($isFocused)

                    if !text.isEmpty {
                        ClearButton(text: $text)
                            .padding(.trailing, 8)
                            .padding(.top, 8)
                    }
                }
            } else {
                legacyTextEditor
            }
        }
    }

    private var legacyTextEditor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .focused($isFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(minHeight: 90, maxHeight: 130)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if !text.isEmpty {
                        ClearButton(text: $text)
                            .padding(12)
                    }
                }
        }
    }

    private struct ClearButton: View {
        @Binding var text: String

        var body: some View {
            Button {
                text = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }
}

struct MediaTile: View {
    let item: MediaPreviewItem
    @State private var thumbnail: UIImage?
    @State private var aspectRatio: CGFloat = 1
    @State private var isLoading: Bool = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image = thumbnail, !isLoading {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.secondary.opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            ProgressView()
                                .controlSize(.small)
                        )
                }
            }
            .onAppear {
                loadThumbnail()
            }

            if item.isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                    .padding(8)
            }
        }
    }

    private func loadThumbnail() {
        // 防止重复加载
        if thumbnail != nil && !isLoading {
            return
        }

        isLoading = true

        Task {
            if let image = await ThumbnailGenerator.shared.thumbnail(for: item) {
                await MainActor.run {
                    thumbnail = image
                    let ratio = image.size.width / max(image.size.height, 1)
                    aspectRatio = ratio.isFinite && ratio > 0 ? ratio : 1
                    isLoading = false

                    // 通知布局更新高度
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("MediaTileHeightUpdated"),
                            object: nil,
                            userInfo: ["itemId": item.id, "aspectRatio": aspectRatio]
                        )
                    }
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct SettingsSheet: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(NamingPreferences.enableKey) private var enableCustomNaming = false
    @AppStorage(NamingPreferences.templateKey) private var customTemplate = NamingFormatter.defaultTemplate

    private let tokens: [NamingToken] = [
        NamingToken(placeholder: "{username}", title: "用户名"),
        NamingToken(placeholder: "{userId}", title: "小红书号"),
        NamingToken(placeholder: "{title}", title: "标题"),
        NamingToken(placeholder: "{postId}", title: "笔记ID"),
        NamingToken(placeholder: "{publishTime}", title: "发布时间"),
        NamingToken(placeholder: "{downloadTimestamp}", title: "开始下载时的时间戳"),
//        NamingToken(placeholder: "{index}", title: "第几张（自然数）"),
//        NamingToken(placeholder: "{index_padded}", title: "第几张（两位数）")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
//                Capsule()
//                    .fill(Color.secondary.opacity(0.25))
//                    .frame(width: 40, height: 4)
//                    .frame(maxWidth: .infinity)
//                    .padding(.top, 8)

//                Text("设置")
//                    .font(.title3)
//                    .fontWeight(.semibold)

                Toggle("启用自定义命名格式", isOn: $enableCustomNaming)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                VStack(alignment: .leading, spacing: 10) {
                    Text("当前命名格式")
                        .font(.headline)

                    TextEditor(text: $customTemplate)
                        .frame(minHeight: 80, maxHeight: 120)
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.2)))
                        .disabled(!enableCustomNaming)
                        .opacity(enableCustomNaming ? 1 : 0.4)

                    Text("例如：{title}_{publishTime}_{downloadTimestamp}")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("可自定义任意字符与字段组合，字段使用花括号包裹；文件末尾会自动追加编号保障唯一。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("重置为默认格式") {
                        customTemplate = NamingFormatter.defaultTemplate
                    }
                    .disabled(!enableCustomNaming)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("可用字段")
                        .font(.headline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(tokens) { token in
                            Button {
                                appendPlaceholder(token.placeholder)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(token.placeholder)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    Text(token.title)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                            }
                            .disabled(!enableCustomNaming)
                        }
                    }

                    Text("点击字段可插入占位符，系统会在末尾自动追加编号保障唯一。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Divider()
                
                // 版本号显示
                VStack {
                    HStack {
                        Text("版本号")
                        Spacer()
                        Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .foregroundColor(.gray)
                    }
                }
//                .padding(.top, 10)

                Button {
                    if let githubURL = URL(string: "https://github.com/NEORUAA/XHS_Downloader_iOS") {
                        openURL(githubURL)
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("打开GitHub仓库")
                            .fontWeight(.semibold)
                            .padding(.vertical, 10)
                        Spacer()
                    }
                }
                .glassEffect()
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .onAppear {
            if customTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                customTemplate = NamingFormatter.defaultTemplate
            }
        }
    }

    private func appendPlaceholder(_ placeholder: String) {
        guard enableCustomNaming else { return }
        if customTemplate.isEmpty {
            customTemplate = placeholder
        } else {
            if customTemplate.last?.isWhitespace == false {
                customTemplate.append(" ")
            }
            customTemplate.append(placeholder)
        }
    }

    struct NamingToken: Identifiable {
        let placeholder: String
        let title: String
        var id: String { placeholder }
    }
}

private actor ThumbnailGenerator {
    static let shared = ThumbnailGenerator()

    func thumbnail(for item: MediaPreviewItem) async -> UIImage? {
        if item.isVideo {
            let asset = AVAsset(url: item.localURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 600, height: 600)
            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                return UIImage(cgImage: cgImage)
            }
            return nil
        } else {
            return UIImage(contentsOfFile: item.localURL.path)
        }
    }
}

private extension View {
    @ViewBuilder
    func ifAvailableiOS16<Content: View>(_ transform: (Self) -> Content) -> some View {
        if #available(iOS 16.0, *) {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    ContentView()
}
