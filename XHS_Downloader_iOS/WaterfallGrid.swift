//
//  WaterfallGrid.swift
//  XHS_Downloader_iOS
//
//  Created by NEORUAA Q on 2026/1/26.
//

import SwiftUI
import UIKit

// MARK: - Waterfall Grid View
struct WaterfallGrid<Data: Identifiable & Hashable, Content: View>: UIViewRepresentable {
    let data: [Data]
    let columns: Int
    let spacing: CGFloat
    let content: (Data) -> Content

    init(
        _ data: [Data],
        columns: Int = 2,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping (Data) -> Content
    ) {
        self.data = data
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = CustomWaterfallFlowLayout(
            columns: columns,
            spacing: spacing
        )
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = UIColor.systemGroupedBackground
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // 注册自定义单元格
        collectionView.register(GridCollectionViewCell.self, forCellWithReuseIdentifier: "GridCell")

        // 设置数据源
        let dataSource = GridDataSource(data: data, content: content, reuseIdentifier: "GridCell")
        collectionView.dataSource = dataSource
        context.coordinator.dataSource = dataSource
        context.coordinator.collectionView = collectionView

        return collectionView
    }

    func updateUIView(_ uiView: UICollectionView, context: Context) {
        // 更新数据源
        if let dataSource = uiView.dataSource as? GridDataSource<Data, Content> {
            dataSource.data = data
            dataSource.content = content
        } else {
            // 如果数据源不匹配，重新设置
            let newDataSource = GridDataSource(data: data, content: content, reuseIdentifier: "GridCell")
            uiView.dataSource = newDataSource
            context.coordinator.dataSource = newDataSource
        }

        // 重新加载数据并刷新布局
        if let collectionViewLayout = uiView.collectionViewLayout as? CustomWaterfallFlowLayout {
            collectionViewLayout.invalidateLayout()
        }
        uiView.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        var dataSource: GridDataSource<Data, Content>?

        // 用于获取collectionView的引用以更新高度
        weak var collectionView: UICollectionView?

        private var notificationObserver: NSObjectProtocol?

        override init() {
            super.init()
            // 监听高度更新通知
            notificationObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("MediaTileHeightUpdated"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleHeightUpdate(notification)
            }
        }

        deinit {
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        private func handleHeightUpdate(_ notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let itemId = userInfo["itemId"] as? UUID,
                  let aspectRatio = userInfo["aspectRatio"] as? CGFloat,
                  let collectionView = collectionView,
                  let layout = collectionView.collectionViewLayout as? CustomWaterfallFlowLayout else {
                return
            }

            // 由于我们不知道具体的数据类型，我们使用反射或其他方式来获取索引
            // 这里我们使用一个通用方法，遍历数据源来查找匹配的ID
            if let identifiableDataSource = dataSource as? any IdentifiableDataSource {
                if let index = identifiableDataSource.indexOfItemId(itemId) {
                    // 根据aspectRatio计算高度（假设宽度为固定值）
                    let width = layout.columnWidth
                    let height = width / aspectRatio // 根据宽高比计算高度
                    layout.updateHeight(for: index, height: height)
                }
            }
        }
    }
}

// MARK: - Protocol for identifying data source
protocol IdentifiableDataSource: AnyObject {
    func indexOfItemId(_ itemId: UUID) -> Int?
}

// MARK: - Collection View Cell
class GridCollectionViewCell: UICollectionViewCell {
    private var hostingController: UIHostingController<AnyView>?
    private var currentView: AnyView?
    private var currentDataId: UUID? // 添加一个标识符来跟踪当前数据

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = UIColor.clear
        layer.cornerRadius = 16
        clipsToBounds = true
    }

    func configure<T: View>(with content: T, dataId: UUID? = nil) {
        let newView = AnyView(content)

        // 检查是否是相同的数据项，如果是，我们不强制更新以避免重置SwiftUI状态
        let isSameData = (dataId != nil && dataId == currentDataId)

        if !isSameData {
            currentDataId = dataId
            currentView = newView

            // 移除旧的hosting controller
            if let oldHost = hostingController {
                oldHost.view.removeFromSuperview()
                hostingController = nil
            }

            // 创建新的hosting controller
            let host = UIHostingController(rootView: newView)
            hostingController = host

            // 配置host view
            let hostView = host.view!
            hostView.translatesAutoresizingMaskIntoConstraints = false
            hostView.backgroundColor = UIColor.clear

            // 清除现有的子视图
            for subview in contentView.subviews {
                subview.removeFromSuperview()
            }

            contentView.addSubview(hostView)

            NSLayoutConstraint.activate([
                hostView.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])

            // 强制布局
            hostView.layoutIfNeeded()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // 在复用时不清除hosting controller，而是保留它
        // 这样SwiftUI的状态不会被重置
        currentDataId = nil
    }
}

// MARK: - Data Source
class GridDataSource<T: Identifiable & Hashable, Content: View>: NSObject, UICollectionViewDataSource, IdentifiableDataSource {
    var data: [T]
    var content: (T) -> Content
    let reuseIdentifier: String

    init(data: [T], content: @escaping (T) -> Content, reuseIdentifier: String) {
        self.data = data
        self.content = content
        self.reuseIdentifier = reuseIdentifier
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return data.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as? GridCollectionViewCell else {
            fatalError("Could not dequeue GridCollectionViewCell")
        }

        let item = data[indexPath.item]
        let view = content(item)

        // 尝试获取数据项的ID，用于避免不必要的重绘
        var dataId: UUID? = nil
        let mirror = Mirror(reflecting: item)
        for child in mirror.children {
            if child.label == "id", let id = child.value as? UUID {
                dataId = id
                break
            }
        }

        cell.configure(with: view, dataId: dataId)

        return cell
    }

    // 实现IdentifiableDataSource协议
    func indexOfItemId(_ itemId: UUID) -> Int? {
        // 假设T类型是MediaPreviewItem，它有UUID类型的id属性
        // 使用Mirror来动态检查
        return data.firstIndex { item in
            let mirror = Mirror(reflecting: item)
            if let idChild = mirror.children.first(where: { $0.label == "id" }),
               let uuid = idChild.value as? UUID {
                return uuid == itemId
            }
            // 如果没有找到id属性，尝试其他可能的属性名
            for child in mirror.children {
                if child.label?.lowercased().contains("id") == true,
                   let uuid = child.value as? UUID {
                    return uuid == itemId
                }
            }
            return false
        }
    }
}

// MARK: - Custom Waterfall Flow Layout
class CustomWaterfallFlowLayout: UICollectionViewLayout {
    private let columns: Int
    private let spacing: CGFloat

    private var cache: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var contentHeight: CGFloat = 0
    private var contentWidth: CGFloat = 0

    // 用于缓存已知的高度
    private var itemHeights: [Int: CGFloat] = [:] // 使用item index作为key

    var columnWidth: CGFloat {
        let totalSpacing = sectionInset.left + sectionInset.right + CGFloat(columns - 1) * spacing
        return (contentWidth - totalSpacing) / CGFloat(columns)
    }

    private var shouldInvalidateLayout = true

    var sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

    init(columns: Int, spacing: CGFloat) {
        self.columns = columns
        self.spacing = spacing
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }

    override func prepare() {
        // 只有在需要重新计算时才重新准备布局
        guard shouldInvalidateLayout else { return }

        guard let collectionView = collectionView else { return }

        // 更新内容宽度
        contentWidth = collectionView.bounds.width

        // 清除缓存
        cache.removeAll()
        contentHeight = 0

        let columnWidth = self.columnWidth
        var xOffset: [CGFloat] = []
        for column in 0..<columns {
            xOffset.append(sectionInset.left + CGFloat(column) * (columnWidth + spacing))
        }

        var yOffset: [CGFloat] = Array(repeating: sectionInset.top, count: columns)

        for item in 0..<collectionView.numberOfItems(inSection: 0) {
            let indexPath = IndexPath(item: item, section: 0)

            let column = getShortestColumn(yOffset: &yOffset)

            // 计算高度 - 先从缓存获取，如果没有则使用默认值
            let height = heightForItem(at: indexPath, width: columnWidth)

            let frame = CGRect(
                x: xOffset[column],
                y: yOffset[column],
                width: columnWidth,
                height: height
            )

            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = frame
            cache[indexPath] = attributes

            yOffset[column] = attributes.frame.maxY + spacing
            contentHeight = max(contentHeight, attributes.frame.maxY)
        }

        shouldInvalidateLayout = false
    }

    private func heightForItem(at indexPath: IndexPath, width: CGFloat) -> CGFloat {
        // 检查是否已经有缓存的高度
        if let cachedHeight = itemHeights[indexPath.item] {
            return cachedHeight
        }

        // 否则返回默认高度，后续可以通过外部方法更新
        return 200
    }

    // 提供一个公共方法来更新特定项目的高度
    func updateHeight(for itemIndex: Int, height: CGFloat) {
        // 检查高度是否真的发生了变化，避免不必要的更新
        let oldHeight = itemHeights[itemIndex] ?? 0
        if abs(oldHeight - height) < 1.0 { // 如果高度变化小于1像素，则忽略
            return
        }

        itemHeights[itemIndex] = height
        // 通知collectionView重新计算布局，但只刷新布局而不重新加载数据
        if let collectionView = collectionView {
            DispatchQueue.main.async {
                collectionView.collectionViewLayout.invalidateLayout()
                collectionView.layoutIfNeeded()
            }
        }
    }

    private func getShortestColumn(yOffset: inout [CGFloat]) -> Int {
        var shortestColumn = 0
        var shortestY = yOffset[0]

        for column in 1..<columns {
            if yOffset[column] < shortestY {
                shortestColumn = column
                shortestY = yOffset[column]
            }
        }

        return shortestColumn
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cache[indexPath]
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var visibleLayoutAttributes: [UICollectionViewLayoutAttributes] = []

        for (_, attributes) in cache {
            if attributes.frame.intersects(rect) {
                visibleLayoutAttributes.append(attributes)
            }
        }

        return visibleLayoutAttributes
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        // 当边界发生变化时（如旋转屏幕），重新计算布局
        let boundsChanged = newBounds.width != contentWidth
        if boundsChanged {
            shouldInvalidateLayout = true
        }
        return boundsChanged
    }

    override func invalidateLayout() {
        shouldInvalidateLayout = true
        super.invalidateLayout()
    }
}

// 扩展View以支持相等性比较
extension AnyView {
    func bodyEquals(_ other: AnyView) -> Bool {
        // 简单的相等性检查，实际应用中可能需要更复杂的逻辑
        return true
    }
}