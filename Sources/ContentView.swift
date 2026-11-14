import SwiftUI
import UniformTypeIdentifiers

private enum HelperMode: String, CaseIterable, Identifiable {
    case nickname = "修改昵称"
    case gems = "增加宝石"
    case cars = "添加车辆"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .nickname: return "person.crop.circle"; case .gems: return "diamond.fill"; case .cars: return "car.side.fill" }
    }
}

private struct CarInputRow: Identifiable {
    let id = UUID()
    var name = ""
    var quantity = 1
}

private struct HelperAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct ContentView: View {
    @State private var mode: HelperMode = .nickname
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var workspace: PlistWorkspace?
    @State private var workingDictionary: [String: Any] = [:]
    @State private var outputData: Data?
    @State private var cars: [CarRecord] = []
    @State private var nickname = ""
    @State private var gemAmount = ""
    @State private var carInputs: [CarInputRow] = [CarInputRow()]
    @State private var status = "先导入游戏存档，再选择需要的功能。"
    @State private var activeAlert: HelperAlert?

    private let carPresets = ["supramkv", "jza80fusion", "huricane"]
    private var exportName: String { workspace?.sourceName ?? "GameData.plist" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.055, green: 0.055, blue: 0.075).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        appHeading
                        importPanel
                        if workspace != nil {
                            modePicker
                            operationPanel
                            exportPanel
                        } else {
                            Text("导入后即可使用昵称、宝石和车辆三个工具。")
                                .font(.footnote).foregroundStyle(.white.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                        }
                        statusPanel
                        Text("本工具仅在本机处理你选择的 plist，不会主动连接游戏服务器。")
                            .font(.caption2).foregroundStyle(.white.opacity(0.35))
                            .multilineTextAlignment(.center).padding(.top, 4)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showingImporter) {
                PlistDocumentPicker(
                    onPick: { urls in
                        showingImporter = false
                        // Let the document picker dismiss before reading the copied file.
                        DispatchQueue.main.async {
                            importFile(urls)
                        }
                    },
                    onCancel: {
                        showingImporter = false
                    }
                )
                .ignoresSafeArea()
            }
            .fileExporter(isPresented: $showingExporter,
                          document: outputData.map { PlistDocument(data: $0) },
                          contentType: .propertyList,
                          defaultFilename: exportName) { result in
                switch result {
                case .success: status = "导出完成：\(exportName)"
                case .failure(let error): showError("导出失败：\(error.localizedDescription)")
                }
            }
            .alert(item: $activeAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("好"))
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private var appHeading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("hashiriya（china） helper")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("本地存档编辑工具")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private var importPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workspace == nil ? "第一步 · 导入存档" : "已载入存档")
                        .font(.headline).foregroundStyle(.white)
                    Text(workspace?.sourceName ?? "支持二进制与 XML plist，不依赖文件扩展名")
                        .font(.caption).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
                Spacer()
                Image(systemName: workspace == nil ? "doc.badge.plus" : "checkmark.circle.fill")
                    .font(.title2).foregroundStyle(workspace == nil ? .white.opacity(0.65) : Color.green)
            }
            Button { showingImporter = true } label: {
                Label(workspace == nil ? "选择 plist 文件" : "重新导入文件", systemImage: "folder.badge.plus")
                    .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(Color(red: 0.78, green: 0.24, blue: 0.39))
        }
        .padding(15).background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("第二步 · 选择功能").font(.headline).foregroundStyle(.white)
            HStack(spacing: 8) {
                ForEach(HelperMode.allCases) { item in
                    Button { mode = item } label: {
                        VStack(spacing: 7) {
                            Image(systemName: item.symbol).font(.system(size: 19, weight: .semibold))
                            Text(item.rawValue).font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(mode == item ? .white : .white.opacity(0.62))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(mode == item ? Color(red: 0.65, green: 0.17, blue: 0.32) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(mode == item ? .white.opacity(0.22) : .clear, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private var operationPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch mode {
            case .nickname:
                Label("修改玩家昵称", systemImage: "person.crop.circle").font(.headline)
                Text("输入新昵称后才会修改；留空则跳过，不影响其他存档内容。")
                    .font(.caption).foregroundStyle(.white.opacity(0.55))
                TextField("新昵称（留空不修改）", text: $nickname).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                if !nickname.isEmpty && nickname.utf8.count > 6 {
                    Label("昵称长度为 \(nickname.utf8.count) 字节，超过 6 字节的用户名在游戏中可能显示为空白。仍可继续修改。", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                actionButton("应用昵称修改", icon: "checkmark") { applyNickname() }
                    .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            case .gems:
                Label("设置宝石数量", systemImage: "diamond.fill").font(.headline)
                Text("输入目标宝石总数；留空则不修改。只更新 ExtraGems，不改动初始值与差值字段。")
                    .font(.caption).foregroundStyle(.white.opacity(0.55))
                HStack {
                    Image(systemName: "diamond.fill").foregroundStyle(Color(red: 1, green: 0.76, blue: 0.32))
                    TextField("目标数量（留空不修改）", text: $gemAmount).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                }
                actionButton("应用宝石修改", icon: "plus.circle.fill") { applyGems() }
                    .disabled(gemAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            case .cars:
                Label("批量添加车辆", systemImage: "car.side.fill").font(.headline)
                HStack {
                    Text("当前识别").font(.caption).foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("\(cars.count) 辆").font(.caption.bold()).foregroundStyle(.white)
                }
                Text("每行填写一种车型和添加数量。可直接输入名称，也可从三个预设中选择；空白行会自动跳过。")
                    .font(.caption).foregroundStyle(.white.opacity(0.55))
                ForEach($carInputs) { $item in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            TextField("车型名称（可直接输入）", text: $item.name)
                                .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                            Stepper("数量：\(item.quantity)", value: $item.quantity, in: 1...99)
                                .fixedSize()
                        }
                        HStack {
                            Menu {
                                ForEach(carPresets, id: \.self) { preset in
                                    Button(preset) { item.name = preset }
                                }
                            } label: {
                                Label("选择预设车型", systemImage: "chevron.down")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.78))
                            }
                            Spacer()
                        }
                        if carInputs.count > 1 {
                            HStack { Spacer(); Button(role: .destructive) { carInputs.removeAll { $0.id == item.id } } label: { Label("删除这一行", systemImage: "minus.circle") }.font(.caption) }
                        }
                    }
                    .padding(10).background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                }
                Button { carInputs.append(CarInputRow()) } label: {
                    Label("添加另一种车型", systemImage: "plus.circle.fill").font(.subheadline.bold())
                }.tint(Color(red: 1, green: 0.68, blue: 0.74))
                actionButton("批量添加已填写车辆", icon: "car.side.fill") { applyCars() }
                    .disabled(!carInputs.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("第三步 · 导出修改结果").font(.headline).foregroundStyle(.white)
            Text("导出建议文件名：\(exportName)").font(.caption).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
            Button { showingExporter = true } label: {
                Label("导出 plist（沿用原文件名）", systemImage: "square.and.arrow.down")
                    .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 12)
            }.buttonStyle(.borderedProminent).tint(Color(red: 0.22, green: 0.48, blue: 0.72))
        }
        .padding(15).background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private var statusPanel: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle.fill").foregroundStyle(Color(red: 0.55, green: 0.72, blue: 0.96))
            Text(status).font(.caption).foregroundStyle(.white.opacity(0.68)).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(12).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 11)
        }.buttonStyle(.borderedProminent).tint(Color(red: 0.78, green: 0.24, blue: 0.39))
    }

    private func importFile(_ urls: [URL]) {
        guard let url = urls.first else {
            showError("没有收到选中的文件。请重新点击“选择 plist 文件”并选择一个存档文件。")
            return
        }

        do {
            let data = try readPickedFile(url)
            let loaded = try PlistWorkspace.load(data: data, filename: url.lastPathComponent)
            let foundCars = (try? CarPlistCrypto.read(from: loaded.dictionary)) ?? []

            // Commit the newly loaded workspace only after parsing succeeds.
            workspace = loaded
            workingDictionary = loaded.dictionary
            cars = foundCars
            outputData = nil
            nickname = ""
            gemAmount = ""
            carInputs = [CarInputRow()]
            status = "读取成功：\(url.lastPathComponent)（\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))），识别到 \(foundCars.count) 辆车。可以依次执行多个功能，再统一导出。"
        } catch {
            showError("导入失败：\(error.localizedDescription)\n\n已选中的文件：\(url.lastPathComponent)\n\n请确认它是游戏存档 plist。支持 XML 和二进制 plist，文件扩展名不作限制。")
        }
    }

    private func readPickedFile(_ url: URL) throws -> Data {
        // The document picker is configured with asCopy: true, so its result is normally
        // an app-owned copy. Keep security-scope access for providers that still return
        // a scoped URL, and coordinate as a fallback for cloud/file-provider URLs.
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard !data.isEmpty else { throw PlistToolError.invalidPlist }
            return data
        } catch {
            let directReadError = error
            var coordinatedData: Data?
            var coordinatedReadError: Error?
            var coordinationError: NSError?

            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
                do {
                    coordinatedData = try Data(contentsOf: coordinatedURL, options: [.mappedIfSafe])
                } catch {
                    coordinatedReadError = error
                }
            }

            if let coordinatedData, !coordinatedData.isEmpty {
                return coordinatedData
            }
            if let coordinatedReadError {
                throw coordinatedReadError
            }
            if let coordinationError {
                throw coordinationError
            }
            throw directReadError
        }
    }

    private func showError(_ message: String) {
        activeAlert = HelperAlert(title: "提示", message: message)
    }

    private func showSuccess(_ message: String) {
        activeAlert = HelperAlert(title: "操作完成", message: message)
    }

    private func refreshOutput(_ updated: [String: Any], message: String) throws {
        guard let workspace else { return }
        let data = try workspace.serialized(updated)
        // Round-trip validation: re-open the exact output before making it exportable.
        let verified = try PlistWorkspace.load(data: data, filename: workspace.sourceName)
        workingDictionary = verified.dictionary
        outputData = data
        cars = (try? CarPlistCrypto.read(from: workingDictionary)) ?? cars
        status = message + " 可继续选择其他功能，最后统一导出。"
    }

    private func applyNickname() {
        do {
            let value = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            let updated = try NicknameCrypto.updating(value, in: workingDictionary)
            try refreshOutput(updated, message: "昵称已更新：\(value)。")
            showSuccess("昵称修改成功")
        } catch { showError(error.localizedDescription) }
    }

    private func applyGems() {
        let value = gemAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { status = "宝石输入框为空，已跳过修改。"; return }
        guard let amount = Int(value) else { showError(PlistToolError.gemInvalid.localizedDescription); return }
        do {
            let updated = try GemCrypto.updating(amount, in: workingDictionary)
            try refreshOutput(updated, message: "宝石数量已设置为 \(amount)。")
            showSuccess("宝石数量修改成功：\(amount)")
        } catch { showError(error.localizedDescription) }
    }

    private func applyCars() {
        do {
            let requests = carInputs.compactMap { row -> (String, Int)? in
                let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? nil : (name, row.quantity)
            }
            guard !requests.isEmpty else { status = "车辆名称均为空，已跳过添加。"; return }
            var updated = workingDictionary
            var added: [String] = []
            for (name, quantity) in requests {
                for _ in 0..<quantity {
                    let (next, record) = try CarPlistCrypto.adding(name, to: updated, allowDuplicate: true)
                    updated = next
                    added.append(record.name)
                }
            }
            try refreshOutput(updated, message: "已添加 \(added.count) 辆车辆：\(requests.map { "\($0.0) × \($0.1)" }.joined(separator: "、"))。")
            carInputs = [CarInputRow()]
            showSuccess("批量添加成功，共添加 \(added.count) 辆车。")
        } catch { showError(error.localizedDescription) }
    }
}