//
//  ConnectionFormView.swift
//  cheap-connection
//
//  连接表单视图
//

import SwiftUI

/// 连接表单视图
struct ConnectionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ConnectionManager.self) private var connectionManager

    @State private var viewModel: ConnectionFormViewModel

    init(config: ConnectionConfig? = nil) {
        if let config = config {
            _viewModel = State(initialValue: ConnectionFormViewModel(config: config))
        } else {
            _viewModel = State(initialValue: ConnectionFormViewModel())
        }
    }

    var body: some View {
        Form {
            // 基本信息
            Section("基本信息") {
                TextField("名称", text: $viewModel.formData.name)

                Picker("数据库类型", selection: $viewModel.formData.databaseKind) {
                    ForEach(DatabaseKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .onChange(of: viewModel.formData.databaseKind) {
                    viewModel.onDatabaseKindChange()
                }
            }

            // 连接信息
            Section("连接信息") {
                TextField("主机", text: $viewModel.formData.host)
                    .autocorrectionDisabled()

                HStack {
                    Text("端口")
                    TextField("", value: $viewModel.formData.port, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }

                TextField("用户名", text: $viewModel.formData.username)
                    .autocorrectionDisabled()

                SecureField("密码", text: $viewModel.formData.password)

                TextField("默认数据库", text: $viewModel.formData.defaultDatabase)
                    .autocorrectionDisabled()

                Toggle("启用 SSL", isOn: $viewModel.formData.sslEnabled)
            }

            // 错误提示
            if let error = viewModel.errorMessage {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 400)
        .navigationTitle(viewModel.isEditing ? "编辑连接" : "新建连接")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.isEditing ? "保存" : "创建") {
                    saveAndDismiss()
                }
                .disabled(viewModel.isSaving)
            }
        }
    }

    private func saveAndDismiss() {
        viewModel.save(using: connectionManager)

        if viewModel.errorMessage == nil {
            dismiss()
        }
    }
}

#Preview("新建") {
    ConnectionFormView()
        .environment(ConnectionManager())
}

#Preview("编辑") {
    ConnectionFormView(
        config: ConnectionConfig(
            name: "本地 MySQL",
            databaseKind: .mysql,
            host: "localhost",
            port: 3306,
            username: "root"
        )
    )
    .environment(ConnectionManager())
}
