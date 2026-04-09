import SwiftUI
import Foundation
import UniformTypeIdentifiers
import CryptoKit

private struct IPTVSourceSettings: Codable {
    var userAgent: String
    var autoUpdateMinutes: Int
    var archiveOnly: Bool
    var minArchiveDays: Int
    var use24HourTime: Bool

    init(
        userAgent: String = "",
        autoUpdateMinutes: Int = 0,
        archiveOnly: Bool = false,
        minArchiveDays: Int = 0,
        use24HourTime: Bool = false
    ) {
        self.userAgent = userAgent
        self.autoUpdateMinutes = autoUpdateMinutes
        self.archiveOnly = archiveOnly
        self.minArchiveDays = minArchiveDays
        self.use24HourTime = use24HourTime
    }

    private enum CodingKeys: String, CodingKey {
        case userAgent
        case autoUpdateMinutes
        case archiveOnly
        case minArchiveDays
        case use24HourTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userAgent = try container.decodeIfPresent(String.self, forKey: .userAgent) ?? ""
        autoUpdateMinutes = try container.decodeIfPresent(Int.self, forKey: .autoUpdateMinutes) ?? 0
        archiveOnly = try container.decodeIfPresent(Bool.self, forKey: .archiveOnly) ?? false
        minArchiveDays = try container.decodeIfPresent(Int.self, forKey: .minArchiveDays) ?? 0
        use24HourTime = try container.decodeIfPresent(Bool.self, forKey: .use24HourTime) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userAgent, forKey: .userAgent)
        try container.encode(autoUpdateMinutes, forKey: .autoUpdateMinutes)
        try container.encode(archiveOnly, forKey: .archiveOnly)
        try container.encode(minArchiveDays, forKey: .minArchiveDays)
        try container.encode(use24HourTime, forKey: .use24HourTime)
    }
}

private struct XtreamRuntimeCredentials {
    var server: String
    var username: String
    var password: String
}

struct SavedIPTVSource: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case playlist
        case xtream
    }

    let id: UUID
    var name: String
    var iconEmoji: String
    var kind: Kind

    // Playlist source
    var playlistURL: String?
    var playlistContent: String?

    // Xtream source
    var xtreamServer: String?
    var xtreamUsername: String?
    var xtreamPassword: String?

    init(
        id: UUID = UUID(),
        name: String,
        iconEmoji: String = "",
        kind: Kind,
        playlistURL: String? = nil,
        playlistContent: String? = nil,
        xtreamServer: String? = nil,
        xtreamUsername: String? = nil,
        xtreamPassword: String? = nil
    ) {
        self.id = id
        self.name = name
        self.iconEmoji = iconEmoji
        self.kind = kind
        self.playlistURL = playlistURL
        self.playlistContent = playlistContent
        self.xtreamServer = xtreamServer
        self.xtreamUsername = xtreamUsername
        self.xtreamPassword = xtreamPassword
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case iconEmoji
        case kind
        case playlistURL
        case playlistContent
        case xtreamServer
        case xtreamUsername
        case xtreamPassword
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        iconEmoji = try container.decodeIfPresent(String.self, forKey: .iconEmoji) ?? ""
        kind = try container.decode(Kind.self, forKey: .kind)
        playlistURL = try container.decodeIfPresent(String.self, forKey: .playlistURL)
        playlistContent = try container.decodeIfPresent(String.self, forKey: .playlistContent)
        xtreamServer = try container.decodeIfPresent(String.self, forKey: .xtreamServer)
        xtreamUsername = try container.decodeIfPresent(String.self, forKey: .xtreamUsername)
        xtreamPassword = try container.decodeIfPresent(String.self, forKey: .xtreamPassword)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(iconEmoji, forKey: .iconEmoji)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(playlistURL, forKey: .playlistURL)
        try container.encodeIfPresent(playlistContent, forKey: .playlistContent)
        try container.encodeIfPresent(xtreamServer, forKey: .xtreamServer)
        try container.encodeIfPresent(xtreamUsername, forKey: .xtreamUsername)
        try container.encodeIfPresent(xtreamPassword, forKey: .xtreamPassword)
    }
}

struct SavedSourcesBackup: Codable {
    var version: Int
    var exportedAt: Date
    var encrypted: Bool
    var saltBase64: String?
    var payloadBase64: String?
    var sources: [SavedIPTVSource]?

    init(
        version: Int = 1,
        exportedAt: Date = Date(),
        encrypted: Bool = false,
        saltBase64: String? = nil,
        payloadBase64: String? = nil,
        sources: [SavedIPTVSource]? = nil
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.encrypted = encrypted
        self.saltBase64 = saltBase64
        self.payloadBase64 = payloadBase64
        self.sources = sources
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case exportedAt
        case encrypted
        case saltBase64
        case payloadBase64
        case sources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        encrypted = try container.decodeIfPresent(Bool.self, forKey: .encrypted) ?? false
        saltBase64 = try container.decodeIfPresent(String.self, forKey: .saltBase64)
        payloadBase64 = try container.decodeIfPresent(String.self, forKey: .payloadBase64)
        sources = try container.decodeIfPresent([SavedIPTVSource].self, forKey: .sources)
    }
}

struct SavedSourcesDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var backup: SavedSourcesBackup

    init() {
        backup = SavedSourcesBackup(version: 1, exportedAt: Date(), encrypted: false, sources: [])
    }

    init(sources: [SavedIPTVSource], passphrase: String? = nil) throws {
        let normalizedPassphrase = passphrase?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if normalizedPassphrase.isEmpty {
            backup = SavedSourcesBackup(version: 1, exportedAt: Date(), encrypted: false, sources: sources)
        } else {
            backup = try SavedSourcesCrypto.encrypt(sources: sources, passphrase: normalizedPassphrase)
        }
    }

    init(data: Data) throws {
        do {
            backup = try JSONDecoder().decode(SavedSourcesBackup.self, from: data)
        } catch {
            // Backward-compatible path: allow plain [SavedIPTVSource] imports.
            let sources = try JSONDecoder().decode([SavedIPTVSource].self, from: data)
            backup = SavedSourcesBackup(version: 1, exportedAt: Date(), encrypted: false, sources: sources)
        }
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try self.init(data: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(backup)
        return FileWrapper(regularFileWithContents: data)
    }
}

private enum SavedSourcesCryptoError: LocalizedError {
    case missingEncryptionFields
    case wrongPassphraseOrCorruptBackup

    var errorDescription: String? {
        switch self {
        case .missingEncryptionFields:
            return "The backup file is missing encryption metadata."
        case .wrongPassphraseOrCorruptBackup:
            return "Unable to decrypt backup. Check the passphrase or verify the file is not corrupted."
        }
    }
}

private enum SavedSourcesCrypto {
    static func encrypt(sources: [SavedIPTVSource], passphrase: String) throws -> SavedSourcesBackup {
        let payload = try JSONEncoder().encode(sources)
        let salt = randomData(count: 16)
        let key = deriveKey(passphrase: passphrase, salt: salt)
        let sealed = try AES.GCM.seal(payload, using: key)

        guard let combined = sealed.combined else {
            throw CocoaError(.coderInvalidValue)
        }

        return SavedSourcesBackup(
            version: 1,
            exportedAt: Date(),
            encrypted: true,
            saltBase64: salt.base64EncodedString(),
            payloadBase64: combined.base64EncodedString(),
            sources: nil
        )
    }

    static func decrypt(backup: SavedSourcesBackup, passphrase: String) throws -> [SavedIPTVSource] {
        if backup.encrypted == false {
            return backup.sources ?? []
        }

        guard
            let saltBase64 = backup.saltBase64,
            let payloadBase64 = backup.payloadBase64,
            let salt = Data(base64Encoded: saltBase64),
            let payload = Data(base64Encoded: payloadBase64)
        else {
            throw SavedSourcesCryptoError.missingEncryptionFields
        }

        let key = deriveKey(passphrase: passphrase, salt: salt)
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: payload)
            let decrypted = try AES.GCM.open(sealedBox, using: key)
            return try JSONDecoder().decode([SavedIPTVSource].self, from: decrypted)
        } catch {
            throw SavedSourcesCryptoError.wrongPassphraseOrCorruptBackup
        }
    }

    private static func deriveKey(passphrase: String, salt: Data) -> SymmetricKey {
        let input = Data(passphrase.utf8) + salt
        let digest = SHA256.hash(data: input)
        return SymmetricKey(data: Data(digest))
    }

    private static func randomData(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
}

@MainActor
final class IPTVStore: ObservableObject {
    @Published var playlist: IPTVPlaylist?
    @Published var selectedGroup: IPTVGroup?
    @Published var selectedChannel: IPTVChannel?
    @Published var epgPrograms: [EPGProgram] = []
    @Published var isEPGLoading = false
    @Published var searchText: String = ""
    @Published var favoriteChannelIDs: Set<String> = []
    @Published var savedSources: [SavedIPTVSource] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let playlistLoader = IPTVPlaylistLoader()
    private let epgLoader = EPGLoader()
    private let defaults = UserDefaults.standard
    private var sourceSettingsByKey: [String: IPTVSourceSettings] = [:]
    private var sourceAutoUpdateTask: Task<Void, Never>?
    private var activeSourceKey: String?
    private var activeSourceName: String?
    private var activeSourceType: SourceType?
    private var lastXtreamCredentials: XtreamRuntimeCredentials?
    private var activeSavedSourceID: UUID?
    private var activePlaylistInlineContent: String?

    enum SourceType {
        case playlist
        case xtream
    }

    init() {
        loadFavorites()
        loadSettings()
        loadSavedSources()
        Task { await autoLoadSavedSources() }
    }

    var groups: [IPTVGroup] {
        playlist?.groups ?? []
    }

    var channels: [IPTVChannel] {
        guard let playlist else { return [] }
        let sourceSettings = activeSourceSettings

        let scoped = if let selectedGroup {
            playlist.channels.filter { $0.groupTitle == selectedGroup.name }
        } else {
            playlist.channels
        }

        let archiveFiltered = scoped.filter { channel in
            if sourceSettings.archiveOnly && channel.hasArchive == false {
                return false
            }

            if sourceSettings.minArchiveDays > 0 {
                let archiveDays = channel.archiveDays ?? 0
                if archiveDays < sourceSettings.minArchiveDays {
                    return false
                }
            }

            return true
        }

        if searchText.isEmpty {
            return archiveFiltered
        }

        let query = searchText.lowercased()
        return archiveFiltered.filter {
            $0.name.lowercased().contains(query)
            || $0.groupTitle.lowercased().contains(query)
            || ($0.tvgName?.lowercased().contains(query) ?? false)
        }
    }

    var favoriteChannels: [IPTVChannel] {
        guard let playlist else { return [] }
        return playlist.channels.filter { favoriteChannelIDs.contains($0.id) }
    }

    var activePlaylistURLString: String? {
        playlist?.sourceURL.absoluteString
    }

    var hasActiveSource: Bool {
        activeSourceKey != nil
    }

    var activeSourceLabel: String {
        activeSourceName ?? ""
    }

    var activeSavedSourceName: String? {
        guard let activeSavedSourceID else { return nil }
        return savedSources.first(where: { $0.id == activeSavedSourceID })?.name
    }

    var activeSavedSourceIDValue: UUID? {
        activeSavedSourceID
    }

    var activeSourceUserAgent: String {
        guard let key = activeSourceKey else { return "" }
        return sourceSettingsByKey[key]?.userAgent ?? ""
    }

    var activeSourceAutoUpdateMinutes: Int {
        guard let key = activeSourceKey else { return 0 }
        return sourceSettingsByKey[key]?.autoUpdateMinutes ?? 0
    }

    var activeSourceArchiveOnly: Bool {
        activeSourceSettings.archiveOnly
    }

    var activeSourceMinArchiveDays: Int {
        activeSourceSettings.minArchiveDays
    }

    var activeSourceUses24HourTime: Bool {
        activeSourceSettings.use24HourTime
    }

    private var activeSourceSettings: IPTVSourceSettings {
        guard let key = activeSourceKey else { return IPTVSourceSettings() }
        return sourceSettingsByKey[key] ?? IPTVSourceSettings()
    }

    func loadPlaylist(urlString: String, persistAsDefault: Bool = true) async {
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid playlist URL"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let key = playlistKey(urlString)
            let settings = sourceSettingsByKey[key]
            let userAgent = normalized(settings?.userAgent ?? "")
            let loaded = try await playlistLoader.load(from: url, userAgent: userAgent)
            playlist = loaded
            selectedGroup = loaded.groups.first
            if selectedChannel == nil {
                selectedChannel = loaded.channels.first
            }
            activeSourceType = .playlist
            activeSourceKey = key
            activeSourceName = urlString
            lastXtreamCredentials = nil
            activePlaylistInlineContent = nil
            activeSavedSourceID = savedSources.first(where: {
                $0.kind == .playlist && $0.playlistURL == urlString && $0.playlistContent == nil
            })?.id

            configureAutoUpdateForPlaylist(urlString: urlString)

            if persistAsDefault {
                defaults.set(urlString, forKey: "IPTVLastPlaylistURL")
            }
            persistSettings()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPlaylistFromText(
        _ content: String,
        title: String,
        iconEmoji: String? = nil,
        sourceID: UUID? = nil,
        saveAsSource: Bool = true
    ) async {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTitle = normalizedTitle.isEmpty ? "Pasted Playlist" : normalizedTitle

        isLoading = true
        defer { isLoading = false }

        do {
            let resolvedSourceID = sourceID ?? UUID()
            let sourceURL = URL(string: "memory://pasted-playlist/\(resolvedSourceID.uuidString).m3u8")!
            let key = playlistKey(sourceURL.absoluteString)
            let loaded = try await playlistLoader.load(
                fromContent: content,
                title: effectiveTitle,
                sourceURL: sourceURL
            )

            playlist = loaded
            selectedGroup = loaded.groups.first
            if selectedChannel == nil {
                selectedChannel = loaded.channels.first
            }
            activeSourceType = .playlist
            activeSourceKey = key
            activeSourceName = effectiveTitle
            lastXtreamCredentials = nil
            activePlaylistInlineContent = content
            activeSavedSourceID = sourceID

            configureAutoUpdateForPlaylist(urlString: sourceURL.absoluteString)

            if saveAsSource {
                let savedSource = SavedIPTVSource(
                    id: resolvedSourceID,
                    name: effectiveTitle,
                    iconEmoji: normalizeInlineSourceEmoji(iconEmoji),
                    kind: .playlist,
                    playlistURL: nil,
                    playlistContent: content
                )

                if let existingIndex = savedSources.firstIndex(where: { $0.id == resolvedSourceID }) {
                    savedSources[existingIndex] = savedSource
                } else {
                    savedSources.append(savedSource)
                }
                activeSavedSourceID = resolvedSourceID
                persistSavedSources()
            }

            persistSettings()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadEPG(urlString: String, persistAsDefault: Bool = true) async {
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid EPG URL"
            return
        }

        isEPGLoading = true
        defer { isEPGLoading = false }

        do {
            epgPrograms = try await epgLoader.loadPrograms(from: url)
            if persistAsDefault {
                defaults.set(urlString, forKey: "IPTVLastEPGURL")
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadXtream(server: String, username: String, password: String, persistAsDefault: Bool = true) async {
        guard let serverURL = URL(string: server) else {
            errorMessage = "Invalid Xtream server URL"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let key = xtreamKey(server: server, username: username)
            let settings = sourceSettingsByKey[key]
            let api = IPTVXtreamAPI(
                credentials: .init(serverURL: serverURL, username: username, password: password),
                userAgent: normalized(settings?.userAgent ?? "")
            )
            let channels = try await api.fetchLiveStreams()
            playlist = IPTVPlaylist(title: "Xtream Live", sourceURL: serverURL, channels: channels)
            selectedGroup = groups.first
            selectedChannel = channels.first
            activeSourceType = .xtream
            activeSourceKey = key
            activeSourceName = "\(server) (\(username))"
            lastXtreamCredentials = XtreamRuntimeCredentials(server: server, username: username, password: password)
            activeSavedSourceID = savedSources.first(where: {
                $0.kind == .xtream
                && $0.xtreamServer == server
                && $0.xtreamUsername == username
                && $0.xtreamPassword == password
            })?.id

            configureAutoUpdateForXtream(server: server, username: username)

            if persistAsDefault {
                defaults.set(server, forKey: "IPTVLastXtreamServer")
                defaults.set(username, forKey: "IPTVLastXtreamUsername")
            }
            persistSettings()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleFavorite(_ channel: IPTVChannel) {
        if favoriteChannelIDs.contains(channel.id) {
            favoriteChannelIDs.remove(channel.id)
        } else {
            favoriteChannelIDs.insert(channel.id)
        }
        persistFavorites()
    }

    func isFavorite(_ channel: IPTVChannel) -> Bool {
        favoriteChannelIDs.contains(channel.id)
    }

    func timeline() -> EPGTimeline {
        EPGTimeline(channels: playlist?.channels ?? [], programs: epgPrograms)
    }

    func canPlayCatchup(for channel: IPTVChannel, program: EPGProgram) -> Bool {
        archiveURL(for: channel, program: program) != nil
    }

    func catchupUnavailableReason(for channel: IPTVChannel, program: EPGProgram) -> String? {
        if program.endDate > Date() {
            return nil
        }

        if channel.hasArchive == false && normalized(channel.catchupSource ?? "") == nil {
            return "No archive metadata is available for this channel."
        }

        if channel.isXtream {
            guard let creds = lastXtreamCredentials else {
                return "Xtream credentials are missing for catchup playback."
            }

            if URL(string: creds.server) == nil {
                return "Xtream server URL is invalid."
            }

            if Int(channel.id) == nil {
                return "Xtream stream ID is invalid for catchup playback."
            }
        }

        if archiveURL(for: channel, program: program) == nil {
            return "Archive URL could not be resolved for this program."
        }

        return nil
    }

    func catchupChannel(for channel: IPTVChannel, program: EPGProgram) -> IPTVChannel? {
        guard let url = archiveURL(for: channel, program: program) else {
            return nil
        }

        return IPTVChannel(
            id: "\(channel.id)-catchup-\(program.id)",
            name: "\(channel.name) · \(program.title)",
            streamURL: url,
            logoURL: channel.logoURL,
            groupTitle: "\(channel.groupTitle) Catchup",
            tvgID: channel.tvgID,
            tvgName: channel.tvgName,
            tvgShift: channel.tvgShift,
            countryCode: channel.countryCode,
            languageCode: channel.languageCode,
            hasArchive: channel.hasArchive,
            archiveDays: channel.archiveDays,
            catchupSource: channel.catchupSource,
            isXtream: channel.isXtream
        )
    }

    func applySettingsForActiveSource(
        userAgent: String,
        autoUpdateMinutes: Int,
        archiveOnly: Bool,
        minArchiveDays: Int,
        use24HourTime: Bool
    ) async {
        guard let key = activeSourceKey else { return }

        sourceSettingsByKey[key] = IPTVSourceSettings(
            userAgent: userAgent,
            autoUpdateMinutes: max(0, autoUpdateMinutes),
            archiveOnly: archiveOnly,
            minArchiveDays: max(0, minArchiveDays),
            use24HourTime: use24HourTime
        )
        persistSettings()

        switch activeSourceType {
        case .playlist:
            guard let source = activePlaylistURLString else { return }
            configureAutoUpdateForPlaylist(urlString: source)
            await loadPlaylist(urlString: source, persistAsDefault: false)
        case .xtream:
            guard let creds = lastXtreamCredentials else {
                configureAutoUpdateForXtream(server: "", username: "")
                return
            }
            configureAutoUpdateForXtream(server: creds.server, username: creds.username)
            await loadXtream(
                server: creds.server,
                username: creds.username,
                password: creds.password,
                persistAsDefault: false
            )
        case nil:
            break
        }
    }

    func saveCurrentSource(named proposedName: String?) {
        saveCurrentSource(named: proposedName, iconEmoji: nil)
    }

    func saveCurrentSource(named proposedName: String?, iconEmoji proposedEmoji: String?) {
        guard let activeSourceType else {
            errorMessage = "No active source to save"
            return
        }

        let fallbackName = if let current = activeSavedSourceName, current.isEmpty == false {
            current
        } else {
            defaultSourceName(for: activeSourceType)
        }
        let name = normalizeSourceName(proposedName, fallback: fallbackName)
        let iconEmoji = normalizeIconEmoji(proposedEmoji, for: activeSourceType)

        switch activeSourceType {
        case .playlist:
            if let inlineContent = activePlaylistInlineContent {
                let sourceID = activeSavedSourceID ?? UUID()
                let source = SavedIPTVSource(
                    id: sourceID,
                    name: name,
                    iconEmoji: iconEmoji,
                    kind: .playlist,
                    playlistURL: nil,
                    playlistContent: inlineContent
                )

                if let existingIndex = savedSources.firstIndex(where: { $0.id == sourceID }) {
                    savedSources[existingIndex] = source
                } else {
                    savedSources.append(source)
                }
                activeSavedSourceID = sourceID
                persistSavedSources()
                return
            }

            guard let url = activePlaylistURLString else {
                errorMessage = "No active playlist URL to save"
                return
            }

            if let existingIndex = savedSources.firstIndex(where: {
                $0.kind == .playlist && $0.playlistURL == url && $0.playlistContent == nil
            }) {
                savedSources[existingIndex].name = name
                savedSources[existingIndex].iconEmoji = iconEmoji
                activeSavedSourceID = savedSources[existingIndex].id
            } else {
                let source = SavedIPTVSource(name: name, iconEmoji: iconEmoji, kind: .playlist, playlistURL: url, playlistContent: nil)
                savedSources.append(source)
                activeSavedSourceID = source.id
            }

        case .xtream:
            guard let creds = lastXtreamCredentials else {
                errorMessage = "No active Xtream credentials to save"
                return
            }

            if let existingIndex = savedSources.firstIndex(where: {
                $0.kind == .xtream
                && $0.xtreamServer == creds.server
                && $0.xtreamUsername == creds.username
            }) {
                savedSources[existingIndex].name = name
                savedSources[existingIndex].iconEmoji = iconEmoji
                savedSources[existingIndex].xtreamPassword = creds.password
                activeSavedSourceID = savedSources[existingIndex].id
            } else {
                let source = SavedIPTVSource(
                    name: name,
                    iconEmoji: iconEmoji,
                    kind: .xtream,
                    xtreamServer: creds.server,
                    xtreamUsername: creds.username,
                    xtreamPassword: creds.password
                )
                savedSources.append(source)
                activeSavedSourceID = source.id
            }
        }

        persistSavedSources()
    }

    func removeSavedSource(_ source: SavedIPTVSource) {
        savedSources.removeAll { $0.id == source.id }
        if activeSavedSourceID == source.id {
            activeSavedSourceID = nil
        }
        persistSavedSources()
    }

    func connectSavedSource(_ source: SavedIPTVSource) async {
        switch source.kind {
        case .playlist:
            if let playlistContent = source.playlistContent {
                await loadPlaylistFromText(
                    playlistContent,
                    title: source.name,
                    iconEmoji: source.iconEmoji,
                    sourceID: source.id,
                    saveAsSource: false
                )
                activeSavedSourceID = source.id
                return
            }

            guard let playlistURL = source.playlistURL else {
                errorMessage = "Saved playlist URL is missing"
                return
            }
            await loadPlaylist(urlString: playlistURL)
            activeSavedSourceID = source.id

        case .xtream:
            guard
                let server = source.xtreamServer,
                let username = source.xtreamUsername,
                let password = source.xtreamPassword
            else {
                errorMessage = "Saved Xtream credentials are incomplete"
                return
            }
            await loadXtream(server: server, username: username, password: password)
            activeSavedSourceID = source.id
        }
    }

    func refreshActiveSource() async {
        switch activeSourceType {
        case .playlist:
            guard let source = activePlaylistURLString else {
                errorMessage = "No active playlist source to refresh"
                return
            }
            await loadPlaylist(urlString: source, persistAsDefault: false)

        case .xtream:
            guard let creds = lastXtreamCredentials else {
                errorMessage = "No active Xtream source to refresh"
                return
            }
            await loadXtream(
                server: creds.server,
                username: creds.username,
                password: creds.password,
                persistAsDefault: false
            )

        case nil:
            errorMessage = "No active source to refresh"
        }
    }

    func makeSavedSourcesExportDocument(passphrase: String?) throws -> SavedSourcesDocument {
        try SavedSourcesDocument(sources: savedSources, passphrase: passphrase)
    }

    func importSavedSources(from document: SavedSourcesDocument, merge: Bool, passphrase: String?) throws {
        let normalizedPassphrase = passphrase?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let imported = try SavedSourcesCrypto.decrypt(backup: document.backup, passphrase: normalizedPassphrase)

        if merge {
            var merged = savedSources
            for source in imported {
                if let existingIndex = merged.firstIndex(where: { sourceIdentityKey($0) == sourceIdentityKey(source) }) {
                    merged[existingIndex] = source
                } else {
                    merged.append(source)
                }
            }
            savedSources = merged
        } else {
            savedSources = imported
        }

        if let currentActive = activeSavedSourceID, savedSources.contains(where: { $0.id == currentActive }) == false {
            activeSavedSourceID = nil
        }

        persistSavedSources()
    }

    private func persistFavorites() {
        UserDefaults.standard.set(Array(favoriteChannelIDs), forKey: "IPTVFavorites")
    }

    private func loadFavorites() {
        let values = UserDefaults.standard.stringArray(forKey: "IPTVFavorites") ?? []
        favoriteChannelIDs = Set(values)
    }

    private func persistSavedSources() {
        do {
            let data = try JSONEncoder().encode(savedSources)
            defaults.set(data, forKey: "IPTVSavedSources")
        } catch {
            Task {
                await DebugCategory.iptv.errorLog(
                    "Failed to persist IPTV saved sources",
                    context: ["error": error.localizedDescription]
                )
            }
        }
    }

    private func loadSavedSources() {
        guard let data = defaults.data(forKey: "IPTVSavedSources") else {
            savedSources = []
            return
        }

        do {
            savedSources = try JSONDecoder().decode([SavedIPTVSource].self, from: data)
        } catch {
            savedSources = []
            Task {
                await DebugCategory.iptv.errorLog(
                    "Failed to decode IPTV saved sources",
                    context: ["error": error.localizedDescription]
                )
            }
        }
    }

    private func persistSettings() {
        do {
            let data = try JSONEncoder().encode(sourceSettingsByKey)
            defaults.set(data, forKey: "IPTVSourceSettingsByKey")
        } catch {
            Task {
                await DebugCategory.settings.errorLog(
                    "Failed to persist IPTV source settings",
                    context: ["error": error.localizedDescription]
                )
            }
        }
    }

    private func loadSettings() {
        guard let data = defaults.data(forKey: "IPTVSourceSettingsByKey") else {
            sourceSettingsByKey = [:]
            return
        }

        do {
            sourceSettingsByKey = try JSONDecoder().decode([String: IPTVSourceSettings].self, from: data)
        } catch {
            sourceSettingsByKey = [:]
            Task {
                await DebugCategory.settings.errorLog(
                    "Failed to decode IPTV source settings",
                    context: ["error": error.localizedDescription]
                )
            }
        }
    }

    private func autoLoadSavedSources() async {
        if let savedPlaylist = defaults.string(forKey: "IPTVLastPlaylistURL"), savedPlaylist.isEmpty == false {
            await loadPlaylist(urlString: savedPlaylist, persistAsDefault: false)
        }

        if let savedEPG = defaults.string(forKey: "IPTVLastEPGURL"), savedEPG.isEmpty == false {
            await loadEPG(urlString: savedEPG, persistAsDefault: false)
        }
    }

    private func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func archiveURL(for channel: IPTVChannel, program: EPGProgram) -> URL? {
        let now = Date()
        guard program.startDate < now else { return nil }
        guard channel.hasArchive || channel.catchupSource?.isEmpty == false else { return nil }

        let durationSeconds = max(Int(program.endDate.timeIntervalSince(program.startDate)), 1)
        let durationMinutes = max(durationSeconds / 60, 1)

        if let template = normalized(channel.catchupSource ?? ""),
           let built = renderCatchupTemplate(template: template, channel: channel, program: program, durationSeconds: durationSeconds, durationMinutes: durationMinutes) {
            return built
        }

        if channel.isXtream,
           let creds = lastXtreamCredentials,
           creds.server.isEmpty == false,
           creds.username.isEmpty == false,
           creds.password.isEmpty == false,
           let streamId = Int(channel.id),
           let baseURL = URL(string: creds.server)
        {
            let start = formatXtreamStartDate(program.startDate)
            return baseURL
                .appendingPathComponent("timeshift")
                .appendingPathComponent(creds.username)
                .appendingPathComponent(creds.password)
                .appendingPathComponent("\(durationMinutes)")
                .appendingPathComponent(start)
                .appendingPathComponent("\(streamId).ts")
        }

        return nil
    }

    private func renderCatchupTemplate(
        template: String,
        channel: IPTVChannel,
        program: EPGProgram,
        durationSeconds: Int,
        durationMinutes: Int
    ) -> URL? {
        let startUnix = Int(program.startDate.timeIntervalSince1970)
        let endUnix = Int(program.endDate.timeIntervalSince1970)
        let nowUnix = Int(Date().timeIntervalSince1970)
        let streamID = channel.tvgID ?? channel.id

        var rendered = template
        let replacements: [String: String] = [
            "{start}": "\(startUnix)",
            "{utc}": "\(startUnix)",
            "{timestamp}": "\(startUnix)",
            "{end}": "\(endUnix)",
            "{duration}": "\(durationSeconds)",
            "{duration_sec}": "\(durationSeconds)",
            "{duration_min}": "\(durationMinutes)",
            "{offset}": "\(max(nowUnix - startUnix, 0))",
            "{stream_id}": streamID,
            "{channel_id}": streamID,
            "${start}": "\(startUnix)",
            "${utc}": "\(startUnix)",
            "${duration}": "\(durationSeconds)",
            "${stream_id}": streamID
        ]

        for (key, value) in replacements {
            rendered = rendered.replacingOccurrences(of: key, with: value)
        }

        if rendered.contains("{Y}") || rendered.contains("{m}") || rendered.contains("{d}") || rendered.contains("{H}") || rendered.contains("{M}") || rendered.contains("{S}") {
            let dateParts = xtreamDateParts(program.startDate)
            rendered = rendered
                .replacingOccurrences(of: "{Y}", with: dateParts.year)
                .replacingOccurrences(of: "{m}", with: dateParts.month)
                .replacingOccurrences(of: "{d}", with: dateParts.day)
                .replacingOccurrences(of: "{H}", with: dateParts.hour)
                .replacingOccurrences(of: "{M}", with: dateParts.minute)
                .replacingOccurrences(of: "{S}", with: dateParts.second)
        }

        if let absolute = URL(string: rendered), absolute.scheme != nil {
            return absolute
        }

        guard let base = playlist?.sourceURL else { return nil }
        return URL(string: rendered, relativeTo: base)?.absoluteURL
    }

    private func formatXtreamStartDate(_ date: Date) -> String {
        let parts = xtreamDateParts(date)
        return "\(parts.year)-\(parts.month)-\(parts.day):\(parts.hour)-\(parts.minute)"
    }

    private func xtreamDateParts(_ date: Date) -> (year: String, month: String, day: String, hour: String, minute: String, second: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        let year = String(comps.year ?? 1970)
        let month = String(format: "%02d", comps.month ?? 1)
        let day = String(format: "%02d", comps.day ?? 1)
        let hour = String(format: "%02d", comps.hour ?? 0)
        let minute = String(format: "%02d", comps.minute ?? 0)
        let second = String(format: "%02d", comps.second ?? 0)
        return (year, month, day, hour, minute, second)
    }

    private func playlistKey(_ urlString: String) -> String {
        "playlist|\(urlString)"
    }

    private func xtreamKey(server: String, username: String) -> String {
        let normalizedServer = server.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "xtream|\(normalizedServer)|\(normalizedUsername)"
    }

    private func configureAutoUpdateForPlaylist(urlString: String) {
        let key = playlistKey(urlString)
        let intervalMinutes = sourceSettingsByKey[key]?.autoUpdateMinutes ?? 0
        scheduleAutoUpdate(intervalMinutes: intervalMinutes) { [weak self] in
            guard let self else { return }
            await self.loadPlaylist(urlString: urlString, persistAsDefault: false)
        }
    }

    private func configureAutoUpdateForXtream(server: String, username: String) {
        guard server.isEmpty == false, username.isEmpty == false else {
            sourceAutoUpdateTask?.cancel()
            sourceAutoUpdateTask = nil
            return
        }

        let key = xtreamKey(server: server, username: username)
        let intervalMinutes = sourceSettingsByKey[key]?.autoUpdateMinutes ?? 0
        scheduleAutoUpdate(intervalMinutes: intervalMinutes) { [weak self] in
            guard let self else { return }
            guard let creds = self.lastXtreamCredentials else { return }
            await self.loadXtream(
                server: creds.server,
                username: creds.username,
                password: creds.password,
                persistAsDefault: false
            )
        }
    }

    private func scheduleAutoUpdate(intervalMinutes: Int, action: @escaping @MainActor () async -> Void) {
        sourceAutoUpdateTask?.cancel()
        sourceAutoUpdateTask = nil

        guard intervalMinutes > 0 else { return }

        sourceAutoUpdateTask = Task {
            let intervalNanos = UInt64(intervalMinutes) * 60 * 1_000_000_000
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanos)
                if Task.isCancelled { break }
                await action()
            }
        }
    }

    private func normalizeSourceName(_ name: String?, fallback: String) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func defaultSourceName(for type: SourceType) -> String {
        switch type {
        case .playlist:
            if let url = activePlaylistURLString, let host = URL(string: url)?.host(), host.isEmpty == false {
                return host
            }
            return "Playlist"
        case .xtream:
            if let creds = lastXtreamCredentials,
               let host = URL(string: creds.server)?.host(),
               host.isEmpty == false {
                return "Xtream - \(host)"
            }
            return "Xtream"
        }
    }

    private func sourceIdentityKey(_ source: SavedIPTVSource) -> String {
        switch source.kind {
        case .playlist:
            if source.playlistContent != nil {
                return "playlist-inline|\(source.id.uuidString)"
            }
            return "playlist|\(source.playlistURL ?? "")"
        case .xtream:
            return "xtream|\(source.xtreamServer ?? "")|\(source.xtreamUsername ?? "")"
        }
    }

    private func normalizeIconEmoji(_ iconEmoji: String?, for type: SourceType) -> String {
        let trimmed = iconEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.isEmpty == false else {
            switch type {
            case .playlist: return "📺"
            case .xtream: return "📡"
            }
        }
        return String(trimmed.prefix(2))
    }

    private func normalizeInlineSourceEmoji(_ iconEmoji: String?) -> String {
        let trimmed = iconEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "📺" : String(trimmed.prefix(2))
    }
}

struct IPTVHomeView: View {
    @StateObject var store = IPTVStore()
    let onPlayChannel: (IPTVChannel) -> Void

    @State private var playlistURL = ""
    @State private var epgURL = ""
    @State private var showXtreamSheet = false
    @State private var showSourcesSheet = false
    @State private var showPastePlaylistSheet = false
    @State private var showSourceExporter = false
    @State private var showSourceImporter = false
    @State private var xtreamServer = ""
    @State private var xtreamUser = ""
    @State private var xtreamPassword = ""
    @State private var pastedPlaylistName = "Pasted Playlist"
    @State private var pastedPlaylistContent = ""
    @State private var pastedPlaylistEmoji = "📺"
    @State private var showSourceSettings = false
    @State private var saveSourceName = ""
    @State private var saveSourceEmoji = "📺"
    @State private var showEmojiPickerSheet = false
    @State private var showPastedPlaylistEmojiPickerSheet = false
    @State private var saveSourceBurstTrigger = 0
    @State private var mergeImportedSources = true
    @State private var encryptBackup = false
    @State private var backupPassphrase = ""
    @State private var exportSourcesDocument = SavedSourcesDocument()
    @State private var settingsUserAgent = ""
    @State private var settingsAutoUpdateMinutes = 0
    @State private var settingsArchiveOnly = false
    @State private var settingsMinArchiveDays = 0
    @State private var settingsUse24HourTime = false
    @AppStorage("ui.blur.profile") private var blurProfileStorage = "medium"
    @AppStorage("ui.blur.iptvNoise") private var iptvBlurNoiseStorage = 0.18

    var body: some View {
        NavigationSplitView {
            IPTVGroupListView(store: store)
        } content: {
            VStack(spacing: 0) {
                IPTVSearchView(store: store)
                Divider()
                IPTVChannelListView(store: store, onPlayChannel: onPlayChannel)
            }
        } detail: {
            VStack(spacing: 0) {
                IPTVEPGView(
                    store: store,
                    use24HourTime: store.activeSourceUses24HourTime,
                    onPlayChannel: onPlayChannel
                )
                Divider()
                IPTVFavoritesView(store: store, onPlayChannel: onPlayChannel)
            }
        }
        .navigationTitle("IPTV")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Load M3U") {
                    Task { await store.loadPlaylist(urlString: playlistURL) }
                }
                Button("Load EPG") {
                    Task { await store.loadEPG(urlString: epgURL) }
                }
                Button("Xtream") {
                    showXtreamSheet = true
                }
                Button("Paste M3U") {
                    pastedPlaylistEmoji = "📺"
                    showPastePlaylistSheet = true
                }
                Button("Sources") {
                    saveSourceName = store.activeSavedSourceName ?? ""
                    saveSourceEmoji = store.savedSources.first(where: { $0.id == store.activeSavedSourceIDValue })?.iconEmoji ?? "📺"
                    showSourcesSheet = true
                }
                Button("Refresh") {
                    Task { await store.refreshActiveSource() }
                }
                .disabled(store.hasActiveSource == false)
                Button("Source Settings") {
                    settingsUserAgent = store.activeSourceUserAgent
                    settingsAutoUpdateMinutes = store.activeSourceAutoUpdateMinutes
                    settingsArchiveOnly = store.activeSourceArchiveOnly
                    settingsMinArchiveDays = store.activeSourceMinArchiveDays
                    settingsUse24HourTime = store.activeSourceUses24HourTime
                    showSourceSettings = true
                }
                .disabled(store.hasActiveSource == false)
            }
        }
        .safeAreaInset(edge: .top) {
            let blurProfile = ProgressiveBlurProfile(storageValue: blurProfileStorage)

            VStack(spacing: 8) {
                TextField("Playlist URL (http/https/ftp)", text: $playlistURL)
                    .textFieldStyle(.roundedBorder)
                TextField("XMLTV EPG URL", text: $epgURL)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .progressiveBlur(
                offset: 0.0,
                interpolation: 0.72,
                direction: .down,
                noise: iptvBlurNoiseStorage,
                profile: blurProfile
            )
        }
        .overlay(alignment: .bottom) {
            if let selected = store.selectedChannel {
                IPTVPlayerOverlay(
                    channel: selected,
                    program: store.timeline().currentProgram(for: selected),
                    use24HourTime: store.activeSourceUses24HourTime
                )
                    .padding()
            }
        }
        .sheet(isPresented: $showXtreamSheet) {
            NavigationStack {
                Form {
                    TextField("Server URL", text: $xtreamServer)
                    TextField("Username", text: $xtreamUser)
                    SecureField("Password", text: $xtreamPassword)
                }
                .navigationTitle("Xtream Codes")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showXtreamSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Connect") {
                            Task {
                                await store.loadXtream(server: xtreamServer, username: xtreamUser, password: xtreamPassword)
                                showXtreamSheet = false
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPastePlaylistSheet) {
            NavigationStack {
                VStack(spacing: 12) {
                    TextField("Playlist Name", text: $pastedPlaylistName)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        showPastedPlaylistEmojiPickerSheet = true
                    } label: {
                        HStack {
                            Text("Icon")
                            Spacer()
                            Text(pastedPlaylistEmoji)
                                .font(.title3)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    SimpleCodeEditorView(
                        text: $pastedPlaylistContent,
                        placeholder: "#EXTM3U\n#EXTINF:-1 tvg-id=\"example\" tvg-name=\"Example TV\" group-title=\"News\",Example TV\nhttps://example.com/live.m3u8"
                    )
                    .frame(minHeight: 320)

                    HStack {
                        let lines = max(pastedPlaylistContent.components(separatedBy: "\n").count, 1)
                        let extinfCount = pastedPlaylistContent.components(separatedBy: "\n").filter { $0.hasPrefix("#EXTINF:") }.count

                        Label("\(lines) lines", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label("\(extinfCount) items", systemImage: "list.bullet.rectangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .navigationTitle("Paste M3U")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showPastePlaylistSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Load") {
                            Task {
                                await store.loadPlaylistFromText(
                                    pastedPlaylistContent,
                                    title: pastedPlaylistName,
                                    iconEmoji: pastedPlaylistEmoji
                                )
                                showPastePlaylistSheet = false
                            }
                        }
                        .disabled(pastedPlaylistContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showSourcesSheet) {
            NavigationStack {
                List {
                    Section("Backup") {
                        Toggle("Merge On Import", isOn: $mergeImportedSources)
                        Toggle("Encrypt Backup", isOn: $encryptBackup)
                        SecureField("Backup Passphrase", text: $backupPassphrase)

                        Button("Export JSON") {
                            do {
                                let passphrase = encryptBackup ? backupPassphrase : nil
                                if encryptBackup && backupPassphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    store.errorMessage = "Passphrase is required when encryption is enabled"
                                    return
                                }

                                exportSourcesDocument = try store.makeSavedSourcesExportDocument(passphrase: passphrase)
                                showSourceExporter = true
                            } catch {
                                store.errorMessage = "Export preparation failed: \(error.localizedDescription)"
                            }
                        }

                        Button("Import JSON") {
                            showSourceImporter = true
                        }
                    }

                    Section("Save Current Source") {
                        Button {
                            showEmojiPickerSheet = true
                        } label: {
                            HStack {
                                Text("Icon")
                                Spacer()
                                Text(saveSourceEmoji)
                                    .font(.title3)
                            }
                        }
                        TextField("Source Name", text: $saveSourceName)
                        Button("Save Current") {
                            store.saveCurrentSource(named: saveSourceName, iconEmoji: saveSourceEmoji)
                            if store.errorMessage == nil {
                                saveSourceBurstTrigger += 1
                            }
                        }
                        .particleBurstEffect(
                            trigger: saveSourceBurstTrigger,
                            symbols: ["sparkles", "star", "square.fill"],
                            tint: .cyan,
                            particleCount: 16
                        )
                        .disabled(store.hasActiveSource == false)
                    }

                    Section("Saved Sources") {
                        if store.savedSources.isEmpty {
                            Text("No saved sources yet")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(store.savedSources) { source in
                                Button {
                                    Task {
                                        await store.connectSavedSource(source)
                                        showSourcesSheet = false
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 8) {
                                                Text(source.iconEmoji.isEmpty ? (source.kind == .playlist ? "📺" : "📡") : source.iconEmoji)
                                                Text(source.name)
                                            }
                                            Text(source.kind == .playlist ? "Playlist" : "Xtream")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if store.activeSavedSourceIDValue == source.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        }
                                    }
                                }
                            }
                            .onDelete { offsets in
                                let targets = offsets.map { store.savedSources[$0] }
                                for source in targets {
                                    store.removeSavedSource(source)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Sources")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showSourcesSheet = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showEmojiPickerSheet) {
            NavigationStack {
                EmojiPickerView(selectedEmoji: $saveSourceEmoji)
                    .padding()
                    .navigationTitle("Pick Emoji")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showEmojiPickerSheet = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPastedPlaylistEmojiPickerSheet) {
            NavigationStack {
                EmojiPickerView(selectedEmoji: $pastedPlaylistEmoji)
                    .padding()
                    .navigationTitle("Pick Emoji")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showPastedPlaylistEmojiPickerSheet = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .fileExporter(
            isPresented: $showSourceExporter,
            document: exportSourcesDocument,
            contentType: .json,
            defaultFilename: "iptv-sources-backup"
        ) { result in
            if case .failure(let error) = result {
                store.errorMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showSourceImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            do {
                let url = try result.get().first
                guard let url else { return }

                let needsSecurity = url.startAccessingSecurityScopedResource()
                defer {
                    if needsSecurity {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let data = try Data(contentsOf: url)
                let document = try SavedSourcesDocument(data: data)
                try store.importSavedSources(
                    from: document,
                    merge: mergeImportedSources,
                    passphrase: backupPassphrase
                )
            } catch {
                store.errorMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showSourceSettings) {
            NavigationStack {
                Form {
                    if store.activeSourceLabel.isEmpty == false {
                        Text(store.activeSourceLabel)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Custom User-Agent", text: $settingsUserAgent)

                    Stepper(value: $settingsAutoUpdateMinutes, in: 0...240) {
                        if settingsAutoUpdateMinutes == 0 {
                            Text("Auto Update: Off")
                        } else {
                            Text("Auto Update: Every \(settingsAutoUpdateMinutes) min")
                        }
                    }

                    Toggle("Show Archive Channels Only", isOn: $settingsArchiveOnly)

                    Stepper(value: $settingsMinArchiveDays, in: 0...30) {
                        if settingsMinArchiveDays == 0 {
                            Text("Minimum Archive Days: Any")
                        } else {
                            Text("Minimum Archive Days: \(settingsMinArchiveDays)+")
                        }
                    }

                    Toggle("Use 24-Hour Time", isOn: $settingsUse24HourTime)

                    Section("Visual Effects") {
                        Picker("Blur Profile", selection: $blurProfileStorage) {
                            Text("Soft").tag("soft")
                            Text("Medium").tag("medium")
                            Text("Strong").tag("strong")
                        }

                        Picker("Inset Blur Noise", selection: $iptvBlurNoiseStorage) {
                            Text("Off").tag(0.0)
                            Text("Low").tag(0.1)
                            Text("Medium").tag(0.18)
                            Text("High").tag(0.32)
                        }
                    }
                }
                .navigationTitle("Source Settings")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showSourceSettings = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await store.applySettingsForActiveSource(
                                    userAgent: settingsUserAgent,
                                    autoUpdateMinutes: settingsAutoUpdateMinutes,
                                    archiveOnly: settingsArchiveOnly,
                                    minArchiveDays: settingsMinArchiveDays,
                                    use24HourTime: settingsUse24HourTime
                                )
                                showSourceSettings = false
                            }
                        }
                    }
                }
            }
        }
        .alert("IPTV Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { _ in store.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "Unknown error")
        }
    }
}
