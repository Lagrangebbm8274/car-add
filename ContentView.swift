import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var sourceName = ""
    @State private var sourceData: Data?
    @State private var outputData: Data?
    @State private var cars: [CarRecord] = []
    @State private var newCarName = ""
    @State private var status = "请选择游戏的 plist 文件。"
    @State private var errorMessage: String?
    @State private var addedCar: CarRecord?

    private var suggestedName: String { sourceName.isEmpty ? "Cars.plist" : sourceName }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "car.garage.fill").font(.system(size: 42)).foregroundStyle(.blue)
                Text("Car Plist Editor").font(.title2.bold())
                Button { showingImporter = true } label: {
                    Label(sourceName.isEmpty ? "导入游戏 Plist" : "重新选择 Plist", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent)

                if sourceData != nil {
                    HStack {
                        Text("已识别车辆")
                        Spacer()
                        Text("\(cars.count) 辆").foregroundStyle(.secondary)
                    }.font(.headline)
                    List(cars) { car in
                        HStack {
                            Text(car.keyName).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
                            Text(car.name)
                        }
                    }.frame(minHeight: 180)
                    TextField("输入完整车型名称，例如 Supra JZA80 Fusion", text: $newCarName)
                        .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                    Button { addCar() } label: {
                        Label("添加车辆", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).disabled(newCarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Text(status).font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                if outputData != nil {
                    Button { showingExporter = true } label: {
                        Label("导出 Plist（保持原文件名）", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent)
                }
                Spacer(minLength: 0)
            }.padding()
            .navigationTitle("车辆管理")
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.propertyList, .data], allowsMultipleSelection: false) { result in
                do {
                    let url = try result.get().first!
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    let (_, foundCars) = try CarPlistCrypto.read(data)
                    sourceName = url.lastPathComponent
                    sourceData = data
                    outputData = nil
                    cars = foundCars
                    status = "已读取 \(foundCars.count) 辆车。"
                } catch { errorMessage = error.localizedDescription }
            }
            .fileExporter(isPresented: $showingExporter,
                          document: outputData.map { PlistDocument(data: $0) },
                          contentType: .propertyList,
                          defaultFilename: suggestedName) { result in
                switch result {
                case .success: status = "导出完成。文件名保持为：\(suggestedName)"
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
            .alert("提示", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .alert("添加成功", isPresented: Binding(get: { addedCar != nil }, set: { if !$0 { addedCar = nil } })) {
                Button("好", role: .cancel) { addedCar = nil }
            } message: { Text(addedCar.map { "\($0.keyName)：\($0.name)" } ?? "") }
        }
    }

    private func addCar() {
        guard let sourceData else { return }
        do {
            let name = newCarName.trimmingCharacters(in: .whitespacesAndNewlines)
            let (data, record) = try CarPlistCrypto.adding(name, to: sourceData)
            outputData = data
            addedCar = record
            newCarName = ""
            status = "已添加 \(record.keyName)。导出时将沿用输入文件名。"
        } catch { errorMessage = error.localizedDescription }
    }
}
