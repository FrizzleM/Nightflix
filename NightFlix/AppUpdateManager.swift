import Foundation
import SwiftUI

struct NightflixAppUpdate: Identifiable, Equatable {
    let latestVersionCode: Int
    let currentVersionCode: Int

    var id: Int {
        latestVersionCode
    }

    var latestSemanticVersion: String {
        NightflixVersionCode.semanticVersion(from: latestVersionCode)
    }

    var currentSemanticVersion: String {
        NightflixVersionCode.semanticVersion(from: currentVersionCode)
    }

    var downloadURL: URL {
        NightflixUpdateChecker.downloadURL(for: latestVersionCode)
    }
}

enum NightflixUpdateChecker {
    private static let latestVersionURL = URL(
        string: "https://raw.githubusercontent.com/FrizzleM/Nightflix/main/latest-version.txt"
    )!

    static func availableUpdate() async throws -> NightflixAppUpdate? {
        guard let currentVersionCode else {
            return nil
        }

        let latestVersionCode = try await fetchLatestVersionCode()
        guard latestVersionCode > currentVersionCode else {
            return nil
        }

        return NightflixAppUpdate(
            latestVersionCode: latestVersionCode,
            currentVersionCode: currentVersionCode
        )
    }

    static func downloadURL(for versionCode: Int) -> URL {
        let semanticVersion = NightflixVersionCode.semanticVersion(from: versionCode)
        return URL(
            string: "https://github.com/FrizzleM/Nightflix/releases/download/v\(semanticVersion)/Nightflix.ipa"
        )!
    }

    private static var currentVersionCode: Int? {
        let infoDictionary = Bundle.main.infoDictionary

        if let version = infoDictionary?["CFBundleShortVersionString"] as? String,
           let versionCode = NightflixVersionCode.versionCode(fromSemanticVersion: version) {
            return versionCode
        }

        if let buildVersion = infoDictionary?["CFBundleVersion"] as? String {
            return NightflixVersionCode.versionCode(fromRawText: buildVersion)
        }

        return nil
    }

    private static func fetchLatestVersionCode() async throws -> Int {
        var request = URLRequest(url: latestVersionURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let rawText = String(data: data, encoding: .utf8),
              let versionCode = NightflixVersionCode.versionCode(fromRawText: rawText) else {
            throw NightflixUpdateError.invalidLatestVersionResponse
        }

        return versionCode
    }
}

enum NightflixVersionCode {
    static func versionCode(fromRawText rawText: String) -> Int? {
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstToken = trimmedText.components(separatedBy: .whitespacesAndNewlines).first ?? trimmedText

        if firstToken.contains("."),
           let semanticVersionCode = versionCode(fromSemanticVersion: firstToken) {
            return semanticVersionCode
        }

        let digits = rawText.drop { !$0.isNumber }.prefix { $0.isNumber }
        guard !digits.isEmpty else {
            return nil
        }

        return Int(String(digits))
    }

    static func versionCode(fromSemanticVersion semanticVersion: String) -> Int? {
        let normalizedVersion = semanticVersion
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingLeadingVersionPrefix()
        let parts = normalizedVersion.split(separator: ".").map(String.init)

        guard let majorText = parts.first,
              let major = Int(majorText) else {
            return nil
        }

        let minor = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        let patch = parts.count > 2 ? Int(parts[2]) ?? 0 : 0

        return major * 100 + minor * 10 + patch
    }

    static func semanticVersion(from versionCode: Int) -> String {
        let major = versionCode / 100
        let minor = (versionCode % 100) / 10
        let patch = versionCode % 10

        return "\(major).\(minor).\(patch)"
    }
}

enum NightflixUpdateError: Error {
    case invalidLatestVersionResponse
}

struct NightflixUpdatePromptView: View {
    let update: NightflixAppUpdate
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.74)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 20) {
                closeButton

                updateIcon

                VStack(spacing: 8) {
                    Text("Update Available")
                        .font(.title2.weight(.black))
                        .foregroundStyle(.white)

                    Text("Nightflix v\(update.latestSemanticVersion) is ready. You are currently on v\(update.currentSemanticVersion).")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    promptButton(title: "Later", systemImage: "xmark", isPrimary: false) {
                        onDismiss()
                    }

                    promptButton(title: "Yes, Update", systemImage: "arrow.down.circle.fill", isPrimary: true) {
                        onUpdate()
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                NightFlixStyle.accentColor.opacity(0.96),
                                NightFlixStyle.accentColor.opacity(0.34),
                                NightFlixStyle.accentColor.opacity(0.84)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.6
                    )
            }
            .shadow(color: NightFlixStyle.accentColor.opacity(0.42), radius: 32)
            .shadow(color: NightFlixStyle.accentColor.opacity(0.22), radius: 64)
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }

    private var closeButton: some View {
        HStack {
            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.black))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(NightFlixStyle.accentColor.opacity(0.48), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close update prompt")
        }
        .padding(.bottom, -8)
    }

    private var updateIcon: some View {
        ZStack {
            Circle()
                .fill(NightFlixStyle.accentColor.opacity(0.22))
                .frame(width: 94, height: 94)
                .blur(radius: 22)

            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 38, weight: .black))
                .foregroundStyle(NightFlixStyle.accentColor)
                .frame(width: 74, height: 74)
                .background(.white.opacity(0.08), in: Circle())
                .overlay {
                    Circle()
                        .stroke(NightFlixStyle.accentColor.opacity(0.68), lineWidth: 1)
                }
                .shadow(color: NightFlixStyle.accentColor.opacity(0.55), radius: 18)
        }
    }

    private func promptButton(
        title: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.black))
                .foregroundStyle(isPrimary ? .white : NightFlixStyle.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    isPrimary ? NightFlixStyle.accentColor : Color.black,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(NightFlixStyle.accentColor.opacity(isPrimary ? 0.72 : 0.88), lineWidth: 1.2)
                }
                .shadow(color: NightFlixStyle.accentColor.opacity(isPrimary ? 0.32 : 0.12), radius: 16)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}

private extension String {
    func trimmingLeadingVersionPrefix() -> String {
        guard first == "v" || first == "V" else {
            return self
        }

        return String(dropFirst())
    }
}
