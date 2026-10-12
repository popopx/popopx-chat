import SwiftUI

struct OpenSourceLicenseView: View {
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                aboutSection
                originalCopyrightSection
                bitchatAttributionSection
                modificationsSection
                licenseSection
                sourceCodeSection
                disclaimerSection
                footerSection
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("license_nav_title", comment: "Navigation title for open source licenses screen"))
        .navigationBarTitleDisplayMode(.inline)
        .modifier(ThemedBackground())
        .popopxBranded()
    }

    private var aboutSection: some View {
        LicenseSection(title: NSLocalizedString("license_about_title", comment: "Section header for licensing and copyright information"), icon: "doc.text") {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: NSLocalizedString("license_about_body", comment: "Attribution notice explaining this is a derivative work"), Branding.originalCredit, Branding.appName))
                    .font(.body)
            }
        }
    }

    private var originalCopyrightSection: some View {
        LicenseSection(title: NSLocalizedString("license_original_copyright", comment: "Section header for original project copyright"), icon: "star") {
            VStack(alignment: .leading, spacing: 8) {
                Text(Branding.originalCopyright)
                    .font(.body)

                Divider().padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(NSLocalizedString("license_website", comment: "Label for website URL")).font(.caption).foregroundColor(.secondary)
                        if let url = URL(string: Branding.originalWebsite) {
                            ExternalLink(destination: url) {
                                Text(Branding.originalWebsite).font(.body)
                            }
                        }
                    }
                    HStack(spacing: 4) {
                        Text(NSLocalizedString("license_source", comment: "Label for source code repository URL")).font(.caption).foregroundColor(.secondary)
                        if let url = URL(string: Branding.originalRepo) {
                            ExternalLink(destination: url) {
                                Text(Branding.originalRepo).font(.body)
                            }
                        }
                    }
                }
            }
        }
    }

    private var bitchatAttributionSection: some View {
        LicenseSection(title: NSLocalizedString("license_bitchat_title", comment: "Section header for BLE mesh engine attribution"), icon: "antenna.radiowaves.left.and.right") {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: NSLocalizedString("license_bitchat_body", comment: "Attribution for BLE mesh functionality"), Branding.bitchatCredit))
                    .font(.body)

                Divider().padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(NSLocalizedString("license_source", comment: "Label for source code repository URL")).font(.caption).foregroundColor(.secondary)
                        ExternalLink(destination: URL(string: Branding.bitchatRepo) ?? URL(fileURLWithPath: NSTemporaryDirectory())) {
                            Text(Branding.bitchatRepo).font(.body)
                        }
                    }
                    HStack(spacing: 4) {
                        Text(NSLocalizedString("license_license_label", comment: "Label for license type")).font(.caption).foregroundColor(.secondary)
                        ExternalLink(destination: URL(string: Branding.bitchatLicense) ?? URL(fileURLWithPath: NSTemporaryDirectory())) {
                            Text(NSLocalizedString("license_unlicense", comment: "License name indicating public domain dedication")).font(.body)
                        }
                    }
                }

                Divider().padding(.vertical, 4)

                Text(NSLocalizedString("license_public_domain_info", comment: "Explanation of public domain license with URL reference"))
                    .font(.caption)
                    .foregroundColor(theme.colors.secondary)

                Text(NSLocalizedString("license_subcomponents", comment: "List of included sub-components with same license"))
                    .font(.caption)
                    .foregroundColor(theme.colors.secondary)
            }
        }
    }

    private var modificationsSection: some View {
        LicenseSection(title: NSLocalizedString("license_modifications_title", comment: "Modifications section header"), icon: "pencil") {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: NSLocalizedString("license_copyright_notice", comment: "Copyright notice with app name"), Branding.appName))
                    .font(.body)
                    .foregroundColor(theme.colors.secondary)

                Text(String(format: NSLocalizedString("license_modifications_intro", comment: "Modifications introduction with app name"), Branding.appName))
                    .font(.body)

                ModificationItem(NSLocalizedString("license_mod_rebrand", comment: "Modification: rebranded from SimpleX Chat"))
                ModificationItem(NSLocalizedString("license_mod_dual_transport", comment: "Modification: dual-transport architecture"))
                ModificationItem(NSLocalizedString("license_mod_identity", comment: "Modification: unified identity management"))
                ModificationItem(NSLocalizedString("license_mod_quantum", comment: "Modification: quantum-resistant cryptography"))
                ModificationItem(NSLocalizedString("license_mod_tokens", comment: "Modification: token-based monetization"))
                ModificationItem(NSLocalizedString("license_mod_encrypted_docs", comment: "Modification: encrypted document sharing"))
                ModificationItem(NSLocalizedString("license_mod_community", comment: "Modification: community features"))
                ModificationItem(NSLocalizedString("license_mod_bots", comment: "Modification: bot platform"))
                ModificationItem(NSLocalizedString("license_mod_nostr", comment: "Modification: Nostr relay bridge"))
            }
        }
    }

    private var licenseSection: some View {
        LicenseSection(title: NSLocalizedString("license_license_title", comment: "License section header"), icon: "scalemass") {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("license_agpl_name", comment: "GNU AGPL license name"))
                    .font(.headline)
                Text(NSLocalizedString("license_agpl_version", comment: "AGPL version and date"))
                    .font(.subheadline)
                    .foregroundColor(theme.colors.secondary)

                Text(NSLocalizedString("license_agpl_summary", comment: "Brief AGPL description"))
                    .font(.body)

                ExternalLink(LocalizedStringKey(NSLocalizedString("license_read_full", comment: "Read full license text link")), destination: URL(string: Branding.licenseURL) ?? URL(fileURLWithPath: NSTemporaryDirectory()))
                    .font(.body)

                Text(NSLocalizedString("license_free_software", comment: "Free software disclaimer"))
                    .font(.caption)
                    .foregroundColor(theme.colors.secondary)

                Text(NSLocalizedString("license_no_warranty", comment: "No warranty disclaimer"))
                    .font(.caption)
                    .foregroundColor(theme.colors.secondary)
            }
        }
    }

    private var sourceCodeSection: some View {
        LicenseSection(title: NSLocalizedString("license_source_access_title", comment: "Source Code Access section header"), icon: "chevron.left.forwardslash.chevron.right") {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("license_source_access_body", comment: "Source code availability statement"))
                    .font(.body)

                VStack(alignment: .leading, spacing: 12) {
                    SourceLinkRow(label: NSLocalizedString("license_client_source_label", comment: "Client source label"), url: Branding.clientSourceRepo)
                    Button {
                        UIPasteboard.general.setItems([["public.utf8-plain-text": Branding.clientSourceRepo]], options: [.expirationDate: Date().addingTimeInterval(60), .localOnly: true])
                    } label: {
                        Label(NSLocalizedString("license_copy_client_url", comment: "Copy client source URL button"), systemImage: "doc.on.doc")
                            .font(.caption)
                    }

                    SourceLinkRow(label: NSLocalizedString("license_server_source_label", comment: "Server source label"), url: Branding.serverSourceRepo)
                    Button {
                        UIPasteboard.general.setItems([["public.utf8-plain-text": Branding.serverSourceRepo]], options: [.expirationDate: Date().addingTimeInterval(60), .localOnly: true])
                    } label: {
                        Label(NSLocalizedString("license_copy_server_url", comment: "Copy server source URL button"), systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                }

                Text(NSLocalizedString("license_agpl13_notice", comment: "AGPLv3 Section 13 entitlement notice"))
                    .font(.caption)
                    .foregroundColor(theme.colors.secondary)
            }
        }
    }

    private var disclaimerSection: some View {
        LicenseSection(title: NSLocalizedString("license_disclaimer_title", comment: "Disclaimer section header"), icon: "exclamationmark.triangle") {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("license_disclaimer_body", comment: "Standard software disclaimer"))
                    .font(.caption)
                    .foregroundColor(theme.colors.secondary)
            }
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text(NSLocalizedString("license_footer_license", comment: "Licensed under AGPLv3 footer notice"))
                .font(.caption2)
                .foregroundColor(theme.colors.secondary)
            ExternalLink(destination: URL(string: "https://www.gnu.org") ?? URL(fileURLWithPath: NSTemporaryDirectory())) {
                Text("https://www.gnu.org").font(.caption2)
            }
            Text(NSLocalizedString("license_footer_source", comment: "Source code available on request notice"))
                .font(.caption2)
                .foregroundColor(theme.colors.secondary)
        }
    }
}

private struct LicenseSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(theme.colors.primary)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.colors.primary.opacity(0.2), lineWidth: 0.5)
        )
    }
}

private struct ModificationItem: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.accentColor)
            Text(verbatim: text)
                .font(.body)
        }
    }
}

private struct SourceLinkRow: View {
    let label: String
    let url: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            if let url = URL(string: url) {
                ExternalLink(destination: url) {
                    Text(url.absoluteString)
                        .font(.body)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        OpenSourceLicenseView()
    }
}
