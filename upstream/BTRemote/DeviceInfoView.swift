import CoreBluetooth
import SwiftUI

struct DeviceInfoView: View {
    let entry: DeviceEntry
    @EnvironmentObject private var names: DeviceNameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(macOS)
            NavigationStack { content.formStyle(.grouped) }
        #else
            NavigationView { content }
                .navigationViewStyle(.stack)
        #endif
    }

    private var content: some View {
        Form {
            Section(header: Text(L10n.DeviceInfo.device)) {
                if entry.isHostConnected {
                    NavigationLink {
                        NameEditView(title: L10n.DeviceInfo.name, name: _deviceNameBinding)
                    } label: {
                        infoRow(L10n.DeviceInfo.name, Text(verbatim: entry.displayName))
                    }
                } else {
                    infoRow(L10n.DeviceInfo.name, Text(verbatim: entry.displayName))
                }
                identifierRow(Text(verbatim: entry.id.uuidString))
                infoRow(L10n.DeviceInfo.manufacturer, Text(verbatim: entry.manufacturer ?? L10n.Value.noneString))
            }
            if hasAdvertisement {
                Section(header: Text(L10n.DeviceInfo.advertisement)) {
                    if entry.rssi != 0 {
                        infoRow(L10n.DeviceInfo.signal, Text(verbatim: L10n.Device.rssi(entry.rssi)))
                    }
                    if let isConnectable = entry.isConnectable {
                        infoRow(L10n.DeviceInfo.connectable, Text(isConnectable ? L10n.Value.yes : L10n.Value.no))
                    }
                    if let txPower = entry.txPower {
                        infoRow(L10n.DeviceInfo.txPower, Text(verbatim: "\(txPower) dBm"))
                    }
                }
            }
            if !entry.advertisedServices.isEmpty {
                Section(header: Text(L10n.DeviceInfo.services)) {
                    ForEach(entry.advertisedServices, id: \.self) { serviceRow($0) }
                }
            }
        }
        .navigationTitle(L10n.DeviceInfo.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.DeviceInfo.done) { dismiss() }
                }
            }
    }

    private var hasAdvertisement: Bool {
        entry.rssi != 0 || entry.isConnectable != nil || entry.txPower != nil
    }

    @ViewBuilder
    private func serviceRow(_ uuid: CBUUID) -> some View {
        if let name = BluetoothNumbers.service(uuid) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                Text(verbatim: uuid.uuidString).font(.caption2).foregroundColor(.secondary)
            }
        } else {
            Text(verbatim: uuid.uuidString)
        }
    }

    private func infoRow(_ label: LocalizedStringKey, _ value: Text) -> some View {
        HStack {
            Text(label)
            Spacer()
            value.foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func identifierRow(_ value: Text) -> some View {
        let label = Text(L10n.DeviceInfo.identifier)
        let detail = value.foregroundColor(.secondary).lineLimit(1).minimumScaleFactor(0.5).textSelection(.enabled)
        if #available(iOS 16, *) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    label
                    Spacer(minLength: 12)
                    detail
                }
                stackedRow(label, detail)
            }
        } else {
            stackedRow(label, detail)
        }
    }

    private func stackedRow(_ label: Text, _ detail: some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            label
            detail
        }
    }

    private var _deviceNameBinding: Binding<String> {
        Binding(
            get: { names.name(for: entry.id) ?? "" },
            set: { names.setName($0, for: entry.id) }
        )
    }
}

struct NameEditView: View {
    let title: LocalizedStringKey
    var footer: LocalizedStringKey?
    var maxLength: Int?
    @Binding var name: String
    var onCommit: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        Form {
            Section(footer: _footer) {
                TextField(title, text: _clamped)
                    .focused($focused)
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .onAppear { focused = true }
            .onDisappear(perform: onCommit)
    }

    @ViewBuilder private var _footer: some View {
        if let footer { Text(footer) }
    }

    private var _clamped: Binding<String> {
        Binding(
            get: { name },
            set: { new in name = maxLength.map { String(new.prefix($0)) } ?? new }
        )
    }
}
