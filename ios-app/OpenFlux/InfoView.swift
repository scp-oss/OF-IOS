import SwiftUI
import UIKit

/// About screen with donation addresses (tap a row to copy).
struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copied: String?

    private let sol = "7yXWW2iAkKadyVvMjZLPYo1PqizvKqseG2ZQ1sZk9X1k"
    private let eth = "0xd043E852158C13C8064a73b9cDd920DaAa80f0c1"

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OpenFlux").font(.ui(22, weight: .heavy)).foregroundColor(Theme.ink)
                        Text("TCP-туннель через скрытый транспорт. Клиент поднимает локальный SOCKS5 и системный VPN, трафик идёт через exit-node.")
                            .font(.ui(13)).foregroundColor(Theme.inkMuted)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Поддержать разработку 🖤")
                            .font(.ui(14, weight: .bold)).foregroundColor(Theme.ink)
                        Text("Нажми на адрес, чтобы скопировать.")
                            .font(.ui(11.5)).foregroundColor(Theme.inkMuted)

                        donationRow(title: "Solana (SOL)", address: sol)
                        donationRow(title: "Ethereum (ETH)", address: eth)

                        if let c = copied {
                            Label("\(c) скопирован", systemImage: "checkmark.circle.fill")
                                .font(.ui(12)).foregroundColor(Theme.success)
                        }
                    }
                    .padding(14)
                    .background(Theme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .background(Theme.ground)
            .navigationTitle("О приложении")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func donationRow(title: String, address: String) -> some View {
        Button {
            UIPasteboard.general.string = address
            copied = title
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.ui(13, weight: .semibold)).foregroundColor(Theme.ink)
                    Spacer()
                    Image(systemName: "doc.on.doc").font(.caption).foregroundColor(Theme.inkMuted)
                }
                Text(address)
                    .font(.mono(11))
                    .foregroundColor(Theme.inkMuted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        }
        .buttonStyle(.plain)
    }
}
