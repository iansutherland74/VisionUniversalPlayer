import Foundation
import Combine
import Metal
import CoreImage
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class PlayerViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case flat = "Flat"
        case vr180 = "180"
        case vr360 = "360"
        case sbs = "SBS"
        case tab = "TAB"
        case convert2DTo3D = "2D->3D"

        var id: String { rawValue }
    }

    // MARK: - BD_to_AVP port: playback pipeline steps

    private func makePlaybackPipelineSteps(item: MediaItem, engine: VideoOutputEngine) -> [ConversionPipelineStep] {
        [
            // Stage 1: probe container metadata and configure renderer mode.
            ConversionPipelineStep(stage: .probeMetadata) { [weak self] in
                guard let self else { return }
                self.configureForMediaFormat(item.vrFormat)
                self.startSpatialProbeIfNeeded(for: item)
            },
            // Stage 2: resolve adaptive manifest (HLS) if applicable; no-op otherwise.
            ConversionPipelineStep(stage: .resolveManifest) { [weak self] in
                guard let self else { return }
                if item.sourceKind == .ffmpegContainer,
                   item.url.pathExtension.lowercased() == "m3u8",
                   item.url.host() != nil {
                    await self.loadHLSPlaybackOptions(from: item.url)
                }
            },
            // Stage 3: renderer already configured above; structural marker.
            ConversionPipelineStep(stage: .configureRenderer) { },
            // Stage 4: stereo baseline and disparity are set during state reset; structural marker.
            ConversionPipelineStep(stage: .scheduleStereo) { },
            // Stage 5: color profile applied per-frame by VideoColorSpaceDetector; structural marker.
            ConversionPipelineStep(stage: .applyColorProfile) { },
            // Stage 6: audio routing; structural marker (no explicit Swift-layer audio init required).
            ConversionPipelineStep(stage: .initializeAudio) { },
            // Stage 7: launch the video engine — begins decoding and publishing pixel buffers.
            ConversionPipelineStep(stage: .startEngine) { [weak self] in
                guard let self else { return }
                await self.startEngineWithFallback(item: item, initialEngine: engine, startAtSeconds: self.resumeTimeSeconds)
            },
            // Stage 8: engine is streaming; structural marker.
            ConversionPipelineStep(stage: .beginStreaming) { },
        ]
    }
    @Published var currentMedia: MediaItem?
    @Published var currentPixelBuffer: CVPixelBuffer?
    @Published var enable2Dto3DConversion = false
    @Published var depthStrength: Float = 1.0
    @Published var convergence: Float = 1.0
    @Published var stereoBaseline: Float = 60.0
    @Published var horizontalDisparity: Float = 0.0 {
        didSet {
            vrRenderer?.horizontalDisparityAdjustment = horizontalDisparity
        }
    }
    @Published var selectedMode: Mode = .flat
    @Published var renderSurface: VisionUIRenderSurface = .standard
    @Published private(set) var hlsBitrateRungs: [HLSBitrateRung] = []
    @Published private(set) var hlsAudioOptions: [HLSAudioOption] = []
    @Published private(set) var selectedHLSBitrateRungId: String?
    @Published private(set) var selectedHLSAudioOptionId: String?

    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var adaptiveBufferingThresholdSeconds: TimeInterval = 0.7
    @Published private(set) var transportStatus: TransportStatus = .idle
    @Published private(set) var stallRiskScore: Double = 0
    @Published private(set) var stallRiskLevel: StallRiskLevel = .low
    @Published private(set) var playbackDiagnosis: PlaybackDiagnosis = .stable
    @Published private(set) var advisorySegments: [AdvisorySegment] = []
    @Published private(set) var advisoryPartialText: String = ""
    @Published private(set) var immersiveSnapshot: ImmersiveSceneSnapshot?
    @Published private(set) var spatialProbeResult: SpatialProbeResult?
    @Published private(set) var currentStereoPixelBuffers: (CVPixelBuffer, CVPixelBuffer)?
    @Published private(set) var pipelineStage: ConversionStage?
    @Published private(set) var abRepeatStartSeconds: TimeInterval?
    @Published private(set) var abRepeatEndSeconds: TimeInterval?
    @Published private(set) var abRepeatEnabled: Bool = false
    @Published private(set) var abLoopSlots: [ABLoopSlot] = []
    @Published private(set) var repeatOneEnabled: Bool = false
    @Published private(set) var playbackRate: Double = 1.0
    @Published private(set) var volume: Float = 1.0
    @Published private(set) var isMuted: Bool = false
    @Published private(set) var audioEffectsProfile: AudioEffectsProfile = .flat
    @Published private(set) var subtitleDelaySeconds: TimeInterval = 0
    @Published private(set) var subtitleCues: [SubtitleCue] = []
    @Published private(set) var subtitlesVisible: Bool = true
    @Published private(set) var activeSubtitleText: String?
    @Published private(set) var playbackBookmarks: [TimeInterval] = []
    @Published private(set) var audioTrackOptions: [MediaTrackOption] = []
    @Published private(set) var subtitleTrackOptions: [MediaTrackOption] = []
    @Published private(set) var selectedAudioTrackID: String?
    @Published private(set) var selectedSubtitleTrackID: String?
    @Published private(set) var snapshotStatusMessage: String = ""
    @Published private(set) var snapshotFiles: [URL] = []
    @Published private(set) var playbackTimeSeconds: TimeInterval = 0
    @Published private(set) var resumeTimeSeconds: TimeInterval?
    @Published private(set) var queueItems: [MediaItem] = []
    @Published private(set) var queueIndex: Int?
    @Published private(set) var shuffleEnabled: Bool = false
    @Published private(set) var repeatAllEnabled: Bool = false
    @Published private(set) var hasSavedQueueSnapshot: Bool = false
    @Published private(set) var autoRemoveWatchedQueueItems: Bool = false
    @Published private(set) var pinFavoriteItemsInQueue: Bool = false
    @Published private(set) var protectPinnedFromAutoRemove: Bool = true
    @Published private(set) var loudnessCompensationDB: Float = 0
    @Published private(set) var subtitleImportStatusMessage: String = ""
    @Published private(set) var subdlSearchResults: [SubDLSearchResult] = []
    @Published private(set) var subdlSubtitleCandidates: [SubDLSubtitleCandidate] = []
    @Published private(set) var unifiedSubtitleProviderResults: [SubtitleProviderResult] = []
    @Published private(set) var isSubdlLoading: Bool = false
    @Published private(set) var subdlStatusMessage: String = ""
    @Published private(set) var subtitleProviderAccessReports: [SubtitleProviderAccessReport] = []
    @Published private(set) var isSubtitleProviderAccessLoading: Bool = false
    @Published private(set) var subtitleProviderAccessStatusMessage: String = ""
    @Published private(set) var cinemaModeSettings: CinemaModeSettings = .default
    @Published private(set) var hudSettings: HUDSettings = .default
    @Published var isHUDVisible = false

    let stats = PlayerStats()
    let audioEngine = AudioEngine()
    let voiceCommandEngine = VoiceCommandEngine()

    private var engine: VideoOutputEngine?
    private var pixelBufferSubscription: AnyCancellable?
    private var stereoPairSubscription: AnyCancellable?
    private var dimensionSubscription: AnyCancellable?
    private var playbackTimeSubscription: AnyCancellable?
    private var transportStatusSubscription: AnyCancellable?
    private var bufferingMonitorTask: Task<Void, Never>?
    private var probeTask: Task<Void, Never>?
    private var subtitleLoadTask: Task<Void, Never>?
    private let pipeline = ConversionPipeline()
    private var pipelineEventSubscription: AnyCancellable?
    private var isABRepeatSeeking = false
    private var suppressRepeatOneForInternalStop = false
    private var lastFrameReceivedAt: Date?
    private let nowProvider: () -> Date
    private let hlsManifestReader = HLSManifestReader()
    private let playbackResumeStore = PlaybackResumeStore.shared
    private let playbackQueueStore = PlaybackQueueStore.shared
    private let queueRulesStore = QueueRulesStore.shared
    private let mediaLoudnessStore = MediaLoudnessStore.shared
    private let abLoopStore = ABLoopStore.shared
    private let subdlClient = SubDLClient()
    private let flareSolverrClient = FlareSolverrClient()
    private let diagnosisEngine: PlaybackDiagnosing
    private let advisoryStreamer: PlaybackAdvisoryStreaming
    private let adaptiveBufferingTuner = AdaptiveBufferingTuner()
    private let stallPredictor = PlaybackStallPredictor()
    private var queueLinearItems: [MediaItem] = []
    private var favoritePinnedItemIDs: Set<UUID> = []
    private var hlsMasterURL: URL?
    private var hlsMasterRawText: String?
    private let ciContext = CIContext(options: nil)

    private let pixelBufferSubject = PassthroughSubject<CVPixelBuffer, Never>()
    var pixelBufferPublisher: AnyPublisher<CVPixelBuffer, Never> {
        pixelBufferSubject.eraseToAnyPublisher()
    }

    private(set) var vrRenderer: VRRenderer?
    private(set) var depth3DConverter: Depth3DConverter?

    init(
        mtlDevice: MTLDevice? = MTLCreateSystemDefaultDevice(),
        diagnosisEngine: PlaybackDiagnosing = PlaybackDiagnosisEngine(),
        advisoryStreamer: PlaybackAdvisoryStreaming = PlaybackAdvisoryStreamer(),
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.diagnosisEngine = diagnosisEngine
        self.advisoryStreamer = advisoryStreamer
        self.nowProvider = nowProvider

        if let device = mtlDevice {
            vrRenderer = VRRenderer(device: device)
            depth3DConverter = Depth3DConverter(device: device)
        }

        hasSavedQueueSnapshot = playbackQueueStore.hasSnapshot
        let queueRules = queueRulesStore.load()
        autoRemoveWatchedQueueItems = queueRules.autoRemoveWatched
        pinFavoriteItemsInQueue = queueRules.pinFavoritesFirst
        protectPinnedFromAutoRemove = queueRules.protectPinnedFromAutoRemove
        refreshSupplementalSystems()

        // BD_to_AVP port: surface active pipeline stage for HUD display.
        pipelineEventSubscription = pipeline.events.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .started(let stage):
                self.pipelineStage = stage
                self.stats.pipelineStageDisplay = stage.displayName
            case .completed:
                break
            case .failed(let stage, _):
                self.pipelineStage = nil
                self.stats.pipelineStageDisplay = "\(stage.displayName) failed"
            case .allComplete:
                self.pipelineStage = nil
                self.stats.pipelineStageDisplay = ""
            }
        }
    }

    func playMedia(_ item: MediaItem) async {
        await playMediaCore(item, clearQueue: true)
    }

    func playQueue(_ items: [MediaItem], startingAt selectedItem: MediaItem) async {
        let uniqueItems = deduplicatedQueueItems(items)
        guard uniqueItems.isEmpty == false else {
            await playMedia(selectedItem)
            return
        }

        queueLinearItems = uniqueItems
        let startIndex = uniqueItems.firstIndex(where: { $0.id == selectedItem.id }) ?? 0

        if shuffleEnabled {
            queueItems = shuffledQueue(from: uniqueItems, pinningStartIndex: startIndex)
            queueIndex = 0
        } else {
            queueItems = uniqueItems
            queueIndex = startIndex
        }

        applyPinningToQueueIfNeeded()
        persistQueueStateIfAvailable()

        let current = queueItems[queueIndex ?? 0]
        await playMediaCore(current, clearQueue: false)
    }

    func appendToQueue(_ item: MediaItem) {
        if queueItems.contains(where: { $0.id == item.id }) {
            return
        }

        if queueItems.isEmpty {
            queueItems = [item]
            queueLinearItems = [item]
            queueIndex = 0
        } else {
            queueItems.append(item)
            queueLinearItems = queueLinearItems.isEmpty ? queueItems : (queueLinearItems + [item])
        }

        applyPinningToQueueIfNeeded()
        persistQueueStateIfAvailable()
    }

    func insertNextInQueue(_ item: MediaItem) {
        if queueItems.contains(where: { $0.id == item.id }) {
            return
        }

        if queueItems.isEmpty {
            queueItems = [item]
            queueLinearItems = [item]
            queueIndex = 0
            persistQueueStateIfAvailable()
            return
        }

        let insertionIndex = min((queueNowPlayingIndex ?? 0) + 1, queueItems.count)
        queueItems.insert(item, at: insertionIndex)
        queueLinearItems = queueLinearItems.isEmpty ? queueItems : (queueLinearItems + [item])
        applyPinningToQueueIfNeeded()
        persistQueueStateIfAvailable()
    }

    func playNextInQueue() async {
        guard let next = advanceQueue(forward: true) else { return }
        await playMediaCore(next, clearQueue: false)
    }

    func playPreviousInQueue() async {
        guard let previous = advanceQueue(forward: false) else { return }
        await playMediaCore(previous, clearQueue: false)
    }

    var canStepQueue: Bool {
        queueItems.count > 1
    }

    var canManageQueue: Bool {
        !queueItems.isEmpty
    }

    func setQueueAutoRemoveWatched(_ enabled: Bool) {
        autoRemoveWatchedQueueItems = enabled
        persistQueueRules()
    }

    func setQueuePinFavorites(_ enabled: Bool) {
        pinFavoriteItemsInQueue = enabled
        persistQueueRules()
        applyPinningToQueueIfNeeded()
    }

    func setProtectPinnedFromAutoRemove(_ enabled: Bool) {
        protectPinnedFromAutoRemove = enabled
        persistQueueRules()
    }

    func setFavoritePinnedItems(_ ids: [UUID]) {
        favoritePinnedItemIDs = Set(ids)
        applyPinningToQueueIfNeeded()
    }

    var queueNowPlayingIndex: Int? {
        guard let current = currentMedia else { return nil }
        return queueItems.firstIndex(where: { $0.id == current.id })
    }

    var canRestoreQueueSnapshot: Bool {
        hasSavedQueueSnapshot
    }

    func saveQueueSnapshot() {
        guard let queueIndex,
              queueItems.indices.contains(queueIndex),
              !queueItems.isEmpty
        else {
            return
        }

        let snapshot = PlaybackQueueSnapshot(
            linearItems: queueLinearItems.isEmpty ? queueItems : queueLinearItems,
            queueItems: queueItems,
            queueIndex: queueIndex,
            shuffleEnabled: shuffleEnabled,
            repeatAllEnabled: repeatAllEnabled
        )
        playbackQueueStore.save(snapshot)
        hasSavedQueueSnapshot = playbackQueueStore.hasSnapshot
    }

    func clearQueueSnapshot() {
        playbackQueueStore.clear()
        hasSavedQueueSnapshot = playbackQueueStore.hasSnapshot
    }

    func clearSubtitleImportStatus() {
        subtitleImportStatusMessage = ""
    }

    func checkSubtitleProviderAccess(query: String, flareSolverrEndpoint: String?) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            subtitleProviderAccessReports = []
            subtitleProviderAccessStatusMessage = "Enter a title to probe provider access"
            return
        }

        isSubtitleProviderAccessLoading = true
        subtitleProviderAccessStatusMessage = "Checking provider access..."
        defer { isSubtitleProviderAccessLoading = false }

        let configuredEndpoint = normalizedFlareSolverrEndpoint(from: flareSolverrEndpoint)
        let targets = providerAccessTargets(for: trimmed)
        var reports: [SubtitleProviderAccessReport] = []

        for target in targets {
            let directResult = await evaluateProviderAccess(at: target.url)
            var solverSummary: String?
            var nativeFetch = directResult.challengeMarkers.isEmpty

            if !nativeFetch,
               let endpoint = configuredEndpoint {
                do {
                    let solved = try await flareSolverrClient.fetchHTML(url: target.url, endpoint: endpoint)
                    let solvedMarkers = challengeMarkers(in: solved.responseHTML)
                    if solved.statusCode >= 200,
                       solved.statusCode < 400,
                       solvedMarkers.isEmpty {
                        solverSummary = "FlareSolverr solved (\(solved.statusCode))"
                        nativeFetch = true
                    } else {
                        let markerText = solvedMarkers.isEmpty ? "still challenged" : solvedMarkers.joined(separator: ", ")
                        solverSummary = "FlareSolverr incomplete: \(markerText)"
                    }
                } catch {
                    solverSummary = "FlareSolverr failed: \(error.localizedDescription)"
                }
            } else if !nativeFetch {
                solverSummary = "Configure FlareSolverr to retry this provider"
            }

            reports.append(
                SubtitleProviderAccessReport(
                    id: "\(target.providerName)-\(target.endpointLabel)-\(target.url.absoluteString)",
                    providerName: target.providerName,
                    endpointLabel: target.endpointLabel,
                    searchURL: target.url,
                    directSummary: directResult.summary,
                    directMarkers: directResult.challengeMarkers,
                    flareSolverrSummary: solverSummary,
                    canAttemptNativeFetch: nativeFetch
                )
            )
        }

        subtitleProviderAccessReports = reports
        let blockedCount = reports.filter { $0.canAttemptNativeFetch == false }.count
        if blockedCount == 0 {
            subtitleProviderAccessStatusMessage = "Provider checks passed"
        } else {
            subtitleProviderAccessStatusMessage = "\(blockedCount) provider endpoint(s) still challenged"
        }
    }

    func searchSubDL(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            subdlSearchResults = []
            subdlSubtitleCandidates = []
            unifiedSubtitleProviderResults = []
            subdlStatusMessage = ""
            return
        }

        isSubdlLoading = true
        subdlStatusMessage = "Searching SubDL..."
        defer { isSubdlLoading = false }

        do {
            let results = try await subdlClient.searchTitles(query: trimmed)
            subdlSearchResults = results
            subdlSubtitleCandidates = []
            unifiedSubtitleProviderResults = makeExternalProviderResults(for: trimmed)
            subdlStatusMessage = results.isEmpty ? "No SubDL titles found" : "Found \(results.count) titles"
        } catch {
            subdlSearchResults = []
            subdlSubtitleCandidates = []
            unifiedSubtitleProviderResults = []
            subdlStatusMessage = "SubDL search failed: \(error.localizedDescription)"
        }
    }

    func loadSubDLSubtitleCandidates(for result: SubDLSearchResult) async {
        isSubdlLoading = true
        subdlStatusMessage = "Loading subtitles for \(result.name)..."
        defer { isSubdlLoading = false }

        do {
            let candidates = try await subdlClient.fetchSubtitleCandidates(
                detailPath: result.linkPath,
                preferredLanguageKey: currentSubtitleLanguageKey
            )
            subdlSubtitleCandidates = candidates
            unifiedSubtitleProviderResults = rankUnifiedProviderResults(
                candidates: candidates,
                query: result.name,
                preferredReleaseQuery: nil,
                preferredQuality: nil
            )
            subdlStatusMessage = candidates.isEmpty ? "No subtitles found for selected title" : "Found \(candidates.count) subtitles"
        } catch {
            subdlSubtitleCandidates = []
            unifiedSubtitleProviderResults = []
            subdlStatusMessage = "SubDL subtitle load failed: \(error.localizedDescription)"
        }
    }

    func importSubDLSubtitleCandidate(at index: Int) async {
        guard subdlSubtitleCandidates.indices.contains(index) else { return }
        let candidate = subdlSubtitleCandidates[index]
        await importSubtitles(fromURLString: candidate.downloadURL.absoluteString)
    }

    func importUnifiedSubtitleProviderResult(at index: Int) async -> URL? {
        guard unifiedSubtitleProviderResults.indices.contains(index) else { return nil }
        let item = unifiedSubtitleProviderResults[index]
        switch item.action {
        case .directDownload(let url):
            await importSubtitles(fromURLString: url.absoluteString)
            return url
        case .externalLink(let url):
            return url
        }
    }

    func applySubtitleCandidateFilters(searchQuery: String, releaseQuery: String, preferredQuality: String?) {
        unifiedSubtitleProviderResults = rankUnifiedProviderResults(
            candidates: subdlSubtitleCandidates,
            query: searchQuery,
            preferredReleaseQuery: releaseQuery,
            preferredQuality: preferredQuality
        )
    }

    func autoPickBestSubtitleMatch(searchQuery: String, releaseQuery: String, preferredQuality: String?) async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await searchSubDL(query: trimmed)
        guard let bestTitle = subdlSearchResults.first else { return }
        await loadSubDLSubtitleCandidates(for: bestTitle)
        applySubtitleCandidateFilters(searchQuery: trimmed, releaseQuery: releaseQuery, preferredQuality: preferredQuality)

        guard let best = unifiedSubtitleProviderResults.first else { return }
        switch best.action {
        case .directDownload(let url):
            await importSubtitles(fromURLString: url.absoluteString)
        case .externalLink:
            break
        }
    }

    func importSubtitles(fromURLString urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), ["http", "https", "file"].contains(url.scheme?.lowercased() ?? "") else {
            subtitleImportStatusMessage = "Subtitle import failed: invalid URL"
            return
        }

        do {
            let data: Data
            if url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                var request = URLRequest(url: url)
                request.timeoutInterval = 8
                let (remoteData, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse,
                   !(200...299).contains(http.statusCode) {
                    subtitleImportStatusMessage = "Subtitle import failed: HTTP \(http.statusCode)"
                    return
                }
                data = remoteData
            }

            let parsed = try SubtitleSidecar.parse(data: data, sourceURL: url)
            subtitleCues = parsed.cues
            subtitlesVisible = true
            updateActiveSubtitle(at: playbackTimeSeconds)
            if parsed.sourceLabel.isEmpty {
                subtitleImportStatusMessage = "Subtitles loaded: \(parsed.cues.count) cues"
            } else {
                subtitleImportStatusMessage = "Subtitles loaded: \(parsed.cues.count) cues from \(parsed.sourceLabel)"
            }
        } catch {
            subtitleImportStatusMessage = "Subtitle import failed: \(error.localizedDescription)"
        }
    }

    func restoreQueueSnapshot() async {
        guard let snapshot = playbackQueueStore.load(),
              !snapshot.queueItems.isEmpty,
              snapshot.queueItems.indices.contains(snapshot.queueIndex)
        else {
            hasSavedQueueSnapshot = playbackQueueStore.hasSnapshot
            return
        }

        queueLinearItems = snapshot.linearItems.isEmpty ? snapshot.queueItems : snapshot.linearItems
        queueItems = snapshot.queueItems
        queueIndex = snapshot.queueIndex
        shuffleEnabled = snapshot.shuffleEnabled
        repeatAllEnabled = snapshot.repeatAllEnabled

        let current = snapshot.queueItems[snapshot.queueIndex]
        await playMediaCore(current, clearQueue: false)
        hasSavedQueueSnapshot = playbackQueueStore.hasSnapshot
    }

    func toggleRepeatAllEnabled() {
        repeatAllEnabled.toggle()
        persistQueueStateIfAvailable()
    }

    func playQueueItem(at index: Int) async {
        guard queueItems.indices.contains(index) else { return }
        queueIndex = index
        persistQueueStateIfAvailable()
        await playMediaCore(queueItems[index], clearQueue: false)
    }

    func removeQueueItems(at offsets: IndexSet) {
        guard !offsets.isEmpty else { return }

        let currentID = currentMedia?.id
        queueItems.remove(atOffsets: offsets)
        queueLinearItems = queueLinearItems.filter { item in
            queueItems.contains(where: { $0.id == item.id })
        }

        applyPinningToQueueIfNeeded()

        if queueItems.isEmpty {
            queueIndex = nil
            persistQueueStateIfAvailable()
            return
        }

        if let currentID,
           let currentIndex = queueItems.firstIndex(where: { $0.id == currentID }) {
            queueIndex = currentIndex
        } else if let queueIndex, queueIndex >= queueItems.count {
            self.queueIndex = max(0, queueItems.count - 1)
        }

        persistQueueStateIfAvailable()
    }

    func moveQueueItems(fromOffsets: IndexSet, toOffset: Int) {
        guard !fromOffsets.isEmpty else { return }
        let currentID = currentMedia?.id

        queueItems.move(fromOffsets: fromOffsets, toOffset: toOffset)

        if shuffleEnabled == false {
            queueLinearItems = queueItems
        }

        applyPinningToQueueIfNeeded()

        if let currentID,
           let currentIndex = queueItems.firstIndex(where: { $0.id == currentID }) {
            queueIndex = currentIndex
        }

        persistQueueStateIfAvailable()
    }

    func moveQueueItemNext(at index: Int) {
        guard queueItems.indices.contains(index),
              let currentIndex = queueNowPlayingIndex,
              queueItems.count > 1,
              index != currentIndex
        else {
            return
        }

        let item = queueItems.remove(at: index)
        let destination = min(currentIndex + 1, queueItems.count)
        queueItems.insert(item, at: destination)

        if shuffleEnabled == false {
            queueLinearItems = queueItems
        }

        applyPinningToQueueIfNeeded()

        if let updatedCurrentIndex = queueItems.firstIndex(where: { $0.id == currentMedia?.id }) {
            queueIndex = updatedCurrentIndex
        }

        persistQueueStateIfAvailable()
    }

    func toggleShuffleEnabled() {
        shuffleEnabled.toggle()

        guard queueItems.count > 1,
              let currentIndex = queueIndex,
              queueItems.indices.contains(currentIndex)
        else {
            return
        }

        let currentID = queueItems[currentIndex].id
        if shuffleEnabled {
            let base = queueLinearItems.isEmpty ? queueItems : queueLinearItems
            if let baseIndex = base.firstIndex(where: { $0.id == currentID }) {
                queueItems = shuffledQueue(from: base, pinningStartIndex: baseIndex)
                queueIndex = 0
            }
        } else {
            let base = queueLinearItems.isEmpty ? queueItems : queueLinearItems
            queueItems = base
            queueIndex = queueItems.firstIndex(where: { $0.id == currentID })
        }
    }

    private func playMediaCore(_ item: MediaItem, clearQueue: Bool) async {
        await stopPlayback(clearQueue: clearQueue)

        if clearQueue {
            queueLinearItems = []
            queueItems = []
            queueIndex = nil
        } else if let queueIndex,
                  queueItems.indices.contains(queueIndex),
                  queueItems[queueIndex].id != item.id,
                  let matchedIndex = queueItems.firstIndex(where: { $0.id == item.id }) {
            self.queueIndex = matchedIndex
        }

        currentMedia = item
        loudnessCompensationDB = mediaLoudnessStore.compensationDB(for: item)
        abLoopSlots = abLoopStore.slots(for: item)
        if isResumable(item) {
            resumeTimeSeconds = playbackResumeStore.position(for: item)
        } else {
            resumeTimeSeconds = nil
        }
        playbackTimeSeconds = 0
        hlsBitrateRungs = []
        hlsAudioOptions = []
        selectedHLSBitrateRungId = nil
        selectedHLSAudioOptionId = nil
        hlsMasterURL = nil
        hlsMasterRawText = nil
        stereoBaseline = item.stereoBaseline
        horizontalDisparity = item.stereoHorizontalDisparity
        stats.reset()
        stats.codecName = item.codec.rawValue.uppercased()
        stats.isPlaying = true
        isPlaying = true
        isBuffering = true
        adaptiveBufferingThresholdSeconds = 0.7
        stats.adaptiveBufferingThreshold = 0.7
        transportStatus = .connecting
        adaptiveBufferingTuner.reset()
        stallPredictor.reset()
        stallRiskScore = 0
        stallRiskLevel = .low
        playbackDiagnosis = .stable
        advisoryStreamer.reset()
        advisorySegments = []
        advisoryPartialText = ""
        immersiveSnapshot = nil
        subtitleLoadTask?.cancel()
        subtitleLoadTask = nil
        subtitleCues = []
        activeSubtitleText = nil
        playbackBookmarks = []
        audioTrackOptions = []
        subtitleTrackOptions = []
        selectedAudioTrackID = nil
        selectedSubtitleTrackID = nil
        snapshotStatusMessage = ""
        snapshotFiles = []
        abRepeatStartSeconds = nil
        abRepeatEndSeconds = nil
        abRepeatEnabled = false
        isABRepeatSeeking = false
        suppressRepeatOneForInternalStop = false
        stats.diagnosisSummary = playbackDiagnosis.summary
        stats.diagnosisRecommendation = playbackDiagnosis.recommendation
        stats.diagnosisConfidence = playbackDiagnosis.confidence
        stats.advisoryLiveText = ""
        stats.advisoryLastFinalText = ""
        stats.advisoryFinalSegmentCount = 0
        lastFrameReceivedAt = nil
        stats.playbackRateDisplay = formatPlaybackRate(playbackRate)
        stats.volumeDisplay = formatVolume(volume, isMuted: isMuted)
        stats.subtitleDelayDisplay = formatSubtitleDelay(subtitleDelaySeconds)
        stats.decodePathDisplay = "Selecting..."
        stats.repeatOneDisplay = repeatOneEnabled ? "On" : "Off"
        stats.bookmarkCountDisplay = "0"
        refreshAudioEffectsStatsAndEngine()
        configureForMediaFormat(item.vrFormat)
        spatialProbeResult = nil
        stats.spatialProbeDisplay = ""
        pipelineStage = nil
        stats.pipelineStageDisplay = ""

        let nextEngine: VideoOutputEngine
        switch item.sourceKind {
        case .rawAnnexB:
            if shouldPreferContainerEngine(for: item.url) {
                nextEngine = AVFoundationEngine()
            } else {
                nextEngine = RawStreamEngine()
            }
        case .ffmpegContainer:
            switch item.codec {
            case .h264, .hevc:
                nextEngine = FFmpegEngine()
            case .av1, .vp9, .vp8, .mpeg2:
                nextEngine = AVFoundationEngine()
            }
        case .mvhevcLocal:
            nextEngine = MVHEVCLocalEngine()
        }

        loadSubtitleSidecarIfAvailable(for: item)

        startBufferingMonitor()

        // BD_to_AVP port: run named-stage pipeline with start-stage resume support.
        await pipeline.run(
            steps: makePlaybackPipelineSteps(item: item, engine: nextEngine),
            startFrom: .probeMetadata
        )
    }

    private func startEngineWithFallback(
        item: MediaItem,
        initialEngine: VideoOutputEngine,
        startAtSeconds: TimeInterval?
    ) async {
        let candidates = decoderCandidates(for: item, initialEngine: initialEngine)
        suppressRepeatOneForInternalStop = true

        for candidate in candidates {
            clearEngineSubscriptions()
            currentStereoPixelBuffers = nil

            engine = candidate.engine
            candidate.engine.setPlaybackRate(playbackRate)
            candidate.engine.setVolume(volume)
            candidate.engine.setMuted(isMuted)
            candidate.engine.setAudioEffects(audioEffectsProfile)
            stats.decodePathDisplay = candidate.pathLabel
            subscribe(to: candidate.engine)

            await candidate.engine.start(item: item, startAtSeconds: startAtSeconds)

            let didConnect = await waitForEngineConnection(candidate.engine, timeoutNanoseconds: candidate.timeoutNanoseconds)
            if didConnect {
                stats.error = nil
                refreshTrackOptionsFromEngine(candidate.engine)
                suppressRepeatOneForInternalStop = false
                return
            }

            candidate.engine.stop()
        }

        suppressRepeatOneForInternalStop = false
        transportStatus = .failed(message: "No compatible decoder path for codec \(item.codec.rawValue)")
        isPlaying = false
        isBuffering = false
        stats.error = "Decoder fallback exhausted for codec \(item.codec.rawValue)"
        stats.decodePathDisplay = "Unavailable"
    }

    private func decoderCandidates(for item: MediaItem, initialEngine: VideoOutputEngine) -> [(engine: VideoOutputEngine, pathLabel: String, timeoutNanoseconds: UInt64)] {
        let timeout: UInt64 = 12_000_000_000
        let ffmpegBridgeAvailable = ffmpeg_bridge_is_available() != 0
        let ffmpegSoftwareBridgeAvailable = ffmpeg_sw_bridge_is_available() != 0

        switch item.sourceKind {
        case .rawAnnexB:
            if shouldPreferContainerEngine(for: item.url) {
                return [(AVFoundationEngine(), "System (AVFoundation)", timeout)]
            }
            return [(initialEngine, "HW (Annex-B)", timeout)]
        case .mvhevcLocal:
            return [(initialEngine, "HW (MV-HEVC)", timeout)]
        case .ffmpegContainer:
            switch item.codec {
            case .h264, .hevc:
                var candidates: [(engine: VideoOutputEngine, pathLabel: String, timeoutNanoseconds: UInt64)] = [
                    (AVFoundationEngine(), "System (AVFoundation)", timeout)
                ]
                if ffmpegBridgeAvailable {
                    candidates.insert((initialEngine, "HW (VideoToolbox)", timeout), at: 0)
                }
                if ffmpegSoftwareBridgeAvailable {
                    candidates.append((FFmpegSoftwareEngine(), "SW (FFmpeg)", timeout))
                }
                return candidates
            case .av1, .vp9, .vp8, .mpeg2:
                var candidates: [(engine: VideoOutputEngine, pathLabel: String, timeoutNanoseconds: UInt64)] = [
                    (initialEngine, "System (AVFoundation)", timeout)
                ]
                if ffmpegSoftwareBridgeAvailable {
                    candidates.append((FFmpegSoftwareEngine(), "SW (FFmpeg)", timeout))
                }
                return candidates
            }
        }
    }

    private func shouldPreferContainerEngine(for url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ["m3u8", "mp4", "mov", "mkv", "m4v", "webm", "ts"].contains(ext) {
            return true
        }

        let absolute = url.absoluteString.lowercased()
        return absolute.contains(".m3u8") || absolute.contains("playlist")
    }

    private func waitForEngineConnection(_ engine: VideoOutputEngine, timeoutNanoseconds: UInt64) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await self.awaitTerminalEngineStatus(engine)
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return false
            }

            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
    }

    private func awaitTerminalEngineStatus(_ engine: VideoOutputEngine) async -> Bool {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            var token: AnyCancellable?

            token = engine.transportStatusPublisher
                .receive(on: DispatchQueue.main)
                .sink { status in
                    guard !hasResumed else { return }
                    switch status {
                    case .connected:
                        hasResumed = true
                        token?.cancel()
                        continuation.resume(returning: true)
                    case .failed:
                        hasResumed = true
                        token?.cancel()
                        continuation.resume(returning: false)
                    case .idle, .connecting, .reconnecting, .stopped:
                        break
                    }
                }
        }
    }

    private func clearEngineSubscriptions() {
        pixelBufferSubscription = nil
        stereoPairSubscription = nil
        dimensionSubscription = nil
        playbackTimeSubscription = nil
        transportStatusSubscription = nil
    }

    private func refreshTrackOptionsFromEngine(_ engine: VideoOutputEngine) {
        let audio = engine.availableAudioTracks()
        let subtitle = engine.availableSubtitleTracks()

        audioTrackOptions = audio
        subtitleTrackOptions = subtitle
        selectedAudioTrackID = audio.first?.id
        selectedSubtitleTrackID = subtitle.first?.id
    }

    var selectedAudioTrackLabel: String {
        guard let id = selectedAudioTrackID,
              let option = audioTrackOptions.first(where: { $0.id == id })
        else {
            return "Audio"
        }
        return option.title
    }

    var selectedSubtitleTrackLabel: String {
        guard let id = selectedSubtitleTrackID,
              let option = subtitleTrackOptions.first(where: { $0.id == id })
        else {
            return "Subtitles"
        }
        return option.title
    }

    func stopPlayback(clearQueue: Bool = true) async {
        if let media = currentMedia, isResumable(media) {
            playbackResumeStore.savePosition(for: media, seconds: playbackTimeSeconds)
        }

        isPlaying = false
        isBuffering = false
        adaptiveBufferingThresholdSeconds = 0.7
        stats.adaptiveBufferingThreshold = 0.7
        transportStatus = .stopped
        adaptiveBufferingTuner.reset()
        stallPredictor.reset()
        stallRiskScore = 0
        stallRiskLevel = .low
        playbackDiagnosis = .stable
        advisoryStreamer.reset()
        advisorySegments = []
        advisoryPartialText = ""
        immersiveSnapshot = nil
        probeTask?.cancel()
        probeTask = nil
        subtitleLoadTask?.cancel()
        subtitleLoadTask = nil
        pipelineStage = nil
        stats.pipelineStageDisplay = ""
        spatialProbeResult = nil
        stats.spatialProbeDisplay = ""
        subtitleCues = []
        activeSubtitleText = nil
        playbackBookmarks = []
        audioTrackOptions = []
        subtitleTrackOptions = []
        selectedAudioTrackID = nil
        selectedSubtitleTrackID = nil
        snapshotStatusMessage = ""
        snapshotFiles = []
        stats.diagnosisSummary = playbackDiagnosis.summary
        stats.diagnosisRecommendation = playbackDiagnosis.recommendation
        stats.diagnosisConfidence = playbackDiagnosis.confidence
        stats.advisoryLiveText = ""
        stats.advisoryLastFinalText = ""
        stats.advisoryFinalSegmentCount = 0
        stats.isPlaying = false
        abRepeatStartSeconds = nil
        abRepeatEndSeconds = nil
        abRepeatEnabled = false
        isABRepeatSeeking = false
        suppressRepeatOneForInternalStop = false
        playbackTimeSeconds = 0
        resumeTimeSeconds = nil
        hlsBitrateRungs = []
        hlsAudioOptions = []
        selectedHLSBitrateRungId = nil
        selectedHLSAudioOptionId = nil
        hlsMasterURL = nil
        hlsMasterRawText = nil
        if clearQueue {
            queueLinearItems = []
            queueItems = []
            queueIndex = nil
        }
        loudnessCompensationDB = 0
        engine?.stop()
        engine = nil
        pixelBufferSubscription = nil
        stereoPairSubscription = nil
        currentStereoPixelBuffers = nil
        dimensionSubscription = nil
        playbackTimeSubscription = nil
        transportStatusSubscription = nil
        bufferingMonitorTask?.cancel()
        bufferingMonitorTask = nil
        lastFrameReceivedAt = nil
    }

    func persistResumeProgressIfNeeded() {
        guard let media = currentMedia, isResumable(media) else { return }
        playbackResumeStore.savePosition(for: media, seconds: playbackTimeSeconds)
    }

    func clearAdvisoryHistory() {
        advisoryStreamer.reset()
        advisorySegments = []
        advisoryPartialText = ""
        stats.advisoryLiveText = ""
        stats.advisoryLastFinalText = ""
        stats.advisoryFinalSegmentCount = 0
    }

    func updateImmersiveSnapshot(_ snapshot: ImmersiveSceneSnapshot) {
        immersiveSnapshot = snapshot
    }

    func clearImmersiveSnapshot() {
        immersiveSnapshot = nil
    }

    // MARK: - Spatial probe (SpatialPlayer port)

    private func startSpatialProbeIfNeeded(for item: MediaItem) {
        guard item.sourceKind == .ffmpegContainer,
              item.url.isFileURL || item.url.scheme == "file" else { return }
        let url = item.url
        probeTask = Task { [weak self] in
            guard let result = await SpatialVideoProbe.probe(url: url) else { return }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.spatialProbeResult = result
                self.stats.spatialProbeDisplay = result.summaryDisplay
            }
        }
    }

    private func isResumable(_ media: MediaItem) -> Bool {
        guard let duration = media.duration, duration > 0 else { return false }
        return true
    }

    var canChooseHLSResolution: Bool {
        hlsBitrateRungs.count > 1
    }

    var canChooseHLSAudio: Bool {
        hlsAudioOptions.count > 1
    }

    func openHLSBitrateRung(_ rung: HLSBitrateRung) {
        selectedHLSBitrateRungId = rung.id
        Task { await restartHLSFromSelection() }
    }

    func resetHLSBitrateRungSelection() {
        selectedHLSBitrateRungId = nil
        Task { await restartHLSFromSelection() }
    }

    func openHLSAudioOption(_ option: HLSAudioOption) {
        selectedHLSAudioOptionId = option.id
        Task { await restartHLSFromSelection() }
    }

    func resetHLSAudioSelection() {
        selectedHLSAudioOptionId = nil
        Task { await restartHLSFromSelection() }
    }

    // MARK: - VLC-inspired A-B repeat

    func markABRepeatStart(at seconds: TimeInterval) {
        abRepeatStartSeconds = max(0, seconds)

        if let end = abRepeatEndSeconds,
           let start = abRepeatStartSeconds,
           end <= start {
            abRepeatEndSeconds = start + 1
        }

        if abRepeatEndSeconds != nil {
            abRepeatEnabled = true
        }
    }

    func markABRepeatEnd(at seconds: TimeInterval) {
        let clamped = max(0, seconds)
        if let start = abRepeatStartSeconds {
            abRepeatEndSeconds = max(clamped, start + 1)
            abRepeatEnabled = true
        } else {
            abRepeatStartSeconds = clamped
            abRepeatEndSeconds = clamped + 1
            abRepeatEnabled = true
        }
    }

    func toggleABRepeatEnabled() {
        guard abRepeatStartSeconds != nil, abRepeatEndSeconds != nil else {
            abRepeatEnabled = false
            return
        }
        abRepeatEnabled.toggle()
    }

    func clearABRepeat() {
        abRepeatStartSeconds = nil
        abRepeatEndSeconds = nil
        abRepeatEnabled = false
    }

    func saveCurrentABLoopSlot(named name: String? = nil) {
        guard let media = currentMedia,
              let start = abRepeatStartSeconds,
              let end = abRepeatEndSeconds,
              end > start
        else {
            return
        }

        let cleanedName = (name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? name!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "Loop \(abLoopSlots.count + 1)"

        let slot = ABLoopSlot(id: UUID(), name: cleanedName, startSeconds: start, endSeconds: end)
        abLoopSlots = abLoopStore.add(slot, for: media)
    }

    func loadABLoopSlot(at index: Int) {
        guard abLoopSlots.indices.contains(index) else { return }
        let slot = abLoopSlots[index]
        abRepeatStartSeconds = slot.startSeconds
        abRepeatEndSeconds = slot.endSeconds
        abRepeatEnabled = true
    }

    func removeABLoopSlot(at index: Int) {
        guard let media = currentMedia,
              abLoopSlots.indices.contains(index)
        else {
            return
        }

        let slotID = abLoopSlots[index].id
        abLoopSlots = abLoopStore.remove(slotID: slotID, for: media)
    }

    func clearABLoopSlotsForCurrentMedia() {
        guard let media = currentMedia else { return }
        abLoopStore.clear(for: media)
        abLoopSlots = []
    }

    var currentSubtitleLanguageKey: String {
        let rawSource = selectedSubtitleTrackLabel
        let lowered = rawSource.lowercased()

        let separators = CharacterSet(charactersIn: " _-()[]{}:|/\\.,")
        let tokens = lowered.components(separatedBy: separators).filter { !$0.isEmpty }

        if let code = tokens.first(where: { $0.count == 2 && $0.range(of: "^[a-z]{2}$", options: .regularExpression) != nil }) {
            return code
        }

        if lowered.contains("english") { return "en" }
        if lowered.contains("spanish") { return "es" }
        if lowered.contains("french") { return "fr" }
        if lowered.contains("german") { return "de" }
        if lowered.contains("japanese") { return "ja" }
        if lowered.contains("korean") { return "ko" }
        if lowered.contains("chinese") { return "zh" }

        return "default"
    }

    func toggleRepeatOneEnabled() {
        repeatOneEnabled.toggle()
        stats.repeatOneDisplay = repeatOneEnabled ? "On" : "Off"
    }

    private func deduplicatedQueueItems(_ items: [MediaItem]) -> [MediaItem] {
        var seen = Set<UUID>()
        var output: [MediaItem] = []
        output.reserveCapacity(items.count)

        for item in items where seen.insert(item.id).inserted {
            output.append(item)
        }

        return output
    }

    private func shuffledQueue(from items: [MediaItem], pinningStartIndex startIndex: Int) -> [MediaItem] {
        guard items.indices.contains(startIndex) else { return items }
        let start = items[startIndex]
        var remaining = items
        remaining.remove(at: startIndex)
        remaining.shuffle()
        return [start] + remaining
    }

    private func advanceQueue(forward: Bool) -> MediaItem? {
        guard let currentIndex = queueIndex,
              queueItems.indices.contains(currentIndex),
              queueItems.count > 1
        else {
            return nil
        }

        let nextIndex: Int
        if forward {
            if currentIndex + 1 < queueItems.count {
                nextIndex = currentIndex + 1
            } else if repeatAllEnabled {
                nextIndex = 0
            } else {
                return nil
            }
        } else {
            if currentIndex > 0 {
                nextIndex = currentIndex - 1
            } else if repeatAllEnabled {
                nextIndex = queueItems.count - 1
            } else {
                return nil
            }
        }

        queueIndex = nextIndex
        return queueItems[nextIndex]
    }

    private func autoAdvanceQueueAfterStop() async -> Bool {
        if autoRemoveWatchedQueueItems,
           let current = currentMedia,
           let currentIndex = queueItems.firstIndex(where: { $0.id == current.id }) {
            let canRemoveCurrent = !(protectPinnedFromAutoRemove && favoritePinnedItemIDs.contains(current.id))

            if canRemoveCurrent {
                queueItems.remove(at: currentIndex)
                queueLinearItems = queueLinearItems.filter { $0.id != current.id }
            }

            guard !queueItems.isEmpty else {
                queueIndex = nil
                persistQueueStateIfAvailable()
                return false
            }

            let nextIndex: Int
            if canRemoveCurrent {
                nextIndex = currentIndex % queueItems.count
            } else {
                if let candidateIndex = queueItems.indices.first(where: { index in
                    index != currentIndex && !favoritePinnedItemIDs.contains(queueItems[index].id)
                }) {
                    nextIndex = candidateIndex
                } else {
                    nextIndex = min(currentIndex + 1, queueItems.count - 1)
                }
            }
            queueIndex = nextIndex
            persistQueueStateIfAvailable()
            await playMediaCore(queueItems[nextIndex], clearQueue: false)
            return true
        }

        guard let next = advanceQueue(forward: true) else { return false }
        await playMediaCore(next, clearQueue: false)
        return true
    }

    func toggleSubtitlesVisible() {
        subtitlesVisible.toggle()
        updateActiveSubtitle(at: playbackTimeSeconds)
    }

    func addPlaybackBookmark(at seconds: TimeInterval) {
        let normalized = max(0, seconds)
        if playbackBookmarks.contains(where: { abs($0 - normalized) < 1.0 }) {
            return
        }
        playbackBookmarks.append(normalized)
        playbackBookmarks.sort()
        if playbackBookmarks.count > 8 {
            playbackBookmarks = Array(playbackBookmarks.suffix(8))
        }
        stats.bookmarkCountDisplay = "\(playbackBookmarks.count)"
    }

    func removePlaybackBookmark(at index: Int) {
        guard playbackBookmarks.indices.contains(index) else { return }
        playbackBookmarks.remove(at: index)
        stats.bookmarkCountDisplay = "\(playbackBookmarks.count)"
    }

    func seekToPlaybackBookmark(at index: Int) async {
        guard playbackBookmarks.indices.contains(index) else { return }
        await seek(to: playbackBookmarks[index])
    }

    // MARK: - VLC-inspired playback speed and subtitle sync

    func setPlaybackRate(_ rate: Double) {
        let clamped = max(0.5, min(rate, 2.0))
        playbackRate = clamped
        stats.playbackRateDisplay = formatPlaybackRate(clamped)
        engine?.setPlaybackRate(clamped)
    }

    func setVolume(_ value: Float) {
        let clamped = max(0, min(value, 1))
        volume = clamped
        stats.volumeDisplay = formatVolume(clamped, isMuted: isMuted)
        engine?.setVolume(clamped)
        refreshSupplementalSystems()
    }

    func toggleMute() {
        isMuted.toggle()
        stats.volumeDisplay = formatVolume(volume, isMuted: isMuted)
        engine?.setMuted(isMuted)
        refreshSupplementalSystems()
    }

    func setPreampDB(_ value: Float) {
        audioEffectsProfile.preampDB = max(-12, min(value, 12))
        refreshAudioEffectsStatsAndEngine()
    }

    func adjustLoudnessCompensation(by deltaDB: Float) {
        let next = max(-12, min(loudnessCompensationDB + deltaDB, 12))
        setLoudnessCompensation(next)
    }

    func resetLoudnessCompensationForCurrentMedia() {
        guard let media = currentMedia else { return }
        loudnessCompensationDB = 0
        mediaLoudnessStore.clearCompensation(for: media)
        refreshAudioEffectsStatsAndEngine()
    }

    func clearAllStoredLoudnessCompensation() {
        mediaLoudnessStore.clearAll()
        loudnessCompensationDB = 0
        refreshAudioEffectsStatsAndEngine()
    }

    func adjustEqualizerBand(at index: Int, deltaDB: Float) {
        guard audioEffectsProfile.bandGainsDB.indices.contains(index) else { return }
        let next = audioEffectsProfile.bandGainsDB[index] + deltaDB
        audioEffectsProfile.setBandGain(at: index, db: next)
        refreshAudioEffectsStatsAndEngine()
    }

    func setEqualizerBand(at index: Int, db: Float) {
        audioEffectsProfile.setBandGain(at: index, db: db)
        refreshAudioEffectsStatsAndEngine()
    }

    func resetEqualizer() {
        audioEffectsProfile.resetEqualizer()
        refreshAudioEffectsStatsAndEngine()
    }

    func applyAudioEffectsPreset(_ preset: AudioEffectsPreset) {
        let currentNormalization = audioEffectsProfile.normalizationEnabled
        let currentLimiter = audioEffectsProfile.limiterEnabled

        var next = preset.profile
        next.normalizationEnabled = currentNormalization
        next.limiterEnabled = currentLimiter
        audioEffectsProfile = next
        refreshAudioEffectsStatsAndEngine()
    }

    func toggleNormalization() {
        audioEffectsProfile.normalizationEnabled.toggle()
        refreshAudioEffectsStatsAndEngine()
    }

    func toggleLimiter() {
        audioEffectsProfile.limiterEnabled.toggle()
        refreshAudioEffectsStatsAndEngine()
    }

    func setPrefersDolbyAtmos(_ enabled: Bool) {
        audioEngine.mixer.setPrefersDolbyAtmos(enabled)
        refreshSupplementalSystems()
    }

    func setDolbyAtmosDownmixMode(_ mode: AudioMixer.DolbyAtmosMode) {
        audioEngine.mixer.setDownmixMode(mode)
        refreshSupplementalSystems()
    }

    func setDialogEnhancementEnabled(_ enabled: Bool) {
        audioEngine.mixer.setDialogEnhancementEnabled(enabled)
        refreshSupplementalSystems()
    }

    func setSpatialAudioEnabled(_ enabled: Bool) {
        audioEngine.spatializer.setEnabled(enabled)
        refreshSupplementalSystems()
    }

    func setHeadTrackingEnabled(_ enabled: Bool) {
        audioEngine.spatializer.setHeadTrackingEnabled(enabled)
        refreshSupplementalSystems()
    }

    func setSpatialRoomSize(_ value: Float) {
        audioEngine.spatializer.setRoomSize(value)
        refreshSupplementalSystems()
    }

    func setAudioFieldAzimuth(_ value: Float) {
        audioEngine.spatializer.setListenerAzimuth(value)
        refreshSupplementalSystems()
    }

    func setAudioFieldElevation(_ value: Float) {
        audioEngine.spatializer.setListenerElevation(value)
        refreshSupplementalSystems()
    }

    func setSpatialWidening(_ value: Float) {
        audioEngine.spatializer.setWideness(value)
        refreshSupplementalSystems()
    }

    func setAudioSyncOffsetMS(_ value: Double) {
        audioEngine.setAudioSyncOffsetMS(value)
        refreshSupplementalSystems()
    }

    func setLipSyncCalibrationMS(_ value: Double) {
        audioEngine.setLipSyncCalibrationMS(value)
        refreshSupplementalSystems()
    }

    func setCinemaModeEnabled(_ enabled: Bool) {
        cinemaModeSettings.isEnabled = enabled
    }

    func setCinemaAmbientLighting(_ value: Double) {
        cinemaModeSettings.ambientLighting = max(0, min(value, 1))
    }

    func setCinemaSeatDistance(_ value: Double) {
        cinemaModeSettings.seatDistance = max(0, min(value, 1))
    }

    func setCinemaScreenScale(_ value: Double) {
        cinemaModeSettings.screenScale = max(0.8, min(value, 1.4))
    }

    func setCinemaScreenCurvature(_ value: Double) {
        cinemaModeSettings.screenCurvature = max(0, min(value, 1))
    }

    func setCinemaEnvironmentDimming(_ value: Double) {
        cinemaModeSettings.environmentDimming = max(0, min(value, 1))
    }

    func resetCinemaModeSettings() {
        cinemaModeSettings = .default
    }

    func setHUDShowVideoStats(_ enabled: Bool) {
        hudSettings.showVideoStats = enabled
    }

    func setHUDShowPlaybackDiagnosis(_ enabled: Bool) {
        hudSettings.showPlaybackDiagnosis = enabled
    }

    func setHUDShowAudioMeters(_ enabled: Bool) {
        hudSettings.showAudioMeters = enabled
    }

    func setHUDShowSpatialDetails(_ enabled: Bool) {
        hudSettings.showSpatialDetails = enabled
    }

    func setHUDShowPipelineStatus(_ enabled: Bool) {
        hudSettings.showPipelineStatus = enabled
    }

    func setHUDShowRecommendations(_ enabled: Bool) {
        hudSettings.showRecommendations = enabled
    }

    func setHUDOpacity(_ value: Double) {
        hudSettings.opacity = max(0.25, min(value, 1.0))
    }

    func setHUDAutoHideInterval(_ value: Double) {
        hudSettings.autoHideInterval = max(2, min(value, 12))
    }

    func adjustSubtitleDelay(by deltaSeconds: TimeInterval) {
        subtitleDelaySeconds = max(-10, min(10, subtitleDelaySeconds + deltaSeconds))
        stats.subtitleDelayDisplay = formatSubtitleDelay(subtitleDelaySeconds)
        updateActiveSubtitle(at: playbackTimeSeconds)
    }

    func resetSubtitleDelay() {
        subtitleDelaySeconds = 0
        stats.subtitleDelayDisplay = formatSubtitleDelay(0)
        updateActiveSubtitle(at: playbackTimeSeconds)
    }

    private func formatPlaybackRate(_ value: Double) -> String {
        String(format: "%.2fx", value)
    }

    private func formatSubtitleDelay(_ value: TimeInterval) -> String {
        let milliseconds = Int((value * 1000).rounded())
        return String(format: "%+d ms", milliseconds)
    }

    private func formatVolume(_ value: Float, isMuted: Bool) -> String {
        if isMuted {
            return "Muted"
        }
        return String(format: "%.0f%%", value * 100)
    }

    private func refreshSupplementalSystems() {
        let effectiveProfile = audioEffectsProfile.clamped()
        let isImmersiveAudio = renderSurface == .immersive || currentMedia?.vrFormat.isImmersive == true || selectedMode == .vr180 || selectedMode == .vr360
        audioEngine.refresh(volume: volume, isMuted: isMuted, profile: effectiveProfile, isImmersive: isImmersiveAudio)
        stats.audioSpatialDisplay = audioEngine.spatializer.summary
        stats.audioSyncDisplay = String(format: "%+.0f ms", audioEngine.audioSyncOffsetMS)
        stats.lipSyncDisplay = String(format: "%+.0f ms", audioEngine.lipSyncCalibrationMS)
    }

    private func refreshAudioEffectsStatsAndEngine() {
        let baseProfile = audioEffectsProfile.clamped()
        audioEffectsProfile = baseProfile

        let effectivePreamp = max(-12, min(baseProfile.preampDB + loudnessCompensationDB, 12))
        var effectiveProfile = baseProfile
        effectiveProfile.preampDB = effectivePreamp

        stats.equalizerDisplay = baseProfile.displaySummary
        stats.preampDisplay = String(format: "%+.1f dB", effectivePreamp)
        stats.loudnessDisplay = String(format: "%+.1f dB", loudnessCompensationDB)
        stats.normalizationDisplay = baseProfile.normalizationEnabled ? "On" : "Off"
        stats.limiterDisplay = baseProfile.limiterEnabled ? "On" : "Off"
        engine?.setAudioEffects(effectiveProfile)
        refreshSupplementalSystems()
    }

    private func setLoudnessCompensation(_ value: Float) {
        let clamped = max(-12, min(value, 12))
        loudnessCompensationDB = clamped
        if let media = currentMedia {
            mediaLoudnessStore.setCompensationDB(clamped, for: media)
        }
        refreshAudioEffectsStatsAndEngine()
    }

    private func persistQueueStateIfAvailable() {
        guard let queueIndex,
              queueItems.indices.contains(queueIndex),
              !queueItems.isEmpty
        else {
            hasSavedQueueSnapshot = playbackQueueStore.hasSnapshot
            return
        }

        let snapshot = PlaybackQueueSnapshot(
            linearItems: queueLinearItems.isEmpty ? queueItems : queueLinearItems,
            queueItems: queueItems,
            queueIndex: queueIndex,
            shuffleEnabled: shuffleEnabled,
            repeatAllEnabled: repeatAllEnabled
        )
        playbackQueueStore.save(snapshot)
        hasSavedQueueSnapshot = playbackQueueStore.hasSnapshot
    }

    private func applyPinningToQueueIfNeeded() {
        guard pinFavoriteItemsInQueue,
              !favoritePinnedItemIDs.isEmpty,
              !queueItems.isEmpty
        else {
            return
        }

        let pinned = queueItems.filter { favoritePinnedItemIDs.contains($0.id) }
        let regular = queueItems.filter { !favoritePinnedItemIDs.contains($0.id) }
        let reordered = pinned + regular

        if reordered == queueItems {
            return
        }

        let currentID = currentMedia?.id
        queueItems = reordered
        if shuffleEnabled == false {
            queueLinearItems = queueItems
        }
        if let currentID,
           let idx = queueItems.firstIndex(where: { $0.id == currentID }) {
            queueIndex = idx
        }
        persistQueueStateIfAvailable()
    }

    private func persistQueueRules() {
        queueRulesStore.save(
            autoRemoveWatched: autoRemoveWatchedQueueItems,
            pinFavoritesFirst: pinFavoriteItemsInQueue,
            protectPinnedFromAutoRemove: protectPinnedFromAutoRemove
        )
    }

    private func rankUnifiedProviderResults(
        candidates: [SubDLSubtitleCandidate],
        query: String,
        preferredReleaseQuery: String?,
        preferredQuality: String?
    ) -> [SubtitleProviderResult] {
        let trimmedRelease = preferredReleaseQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedPreferredQuality = preferredQuality?.lowercased()

        let directItems = candidates.map { candidate in
            SubtitleProviderResult(
                id: "subdl-\(candidate.id)",
                provider: .subdl,
                title: candidate.title,
                subtitleLanguage: candidate.language,
                quality: candidate.quality,
                score: scoreSubtitleCandidate(candidate, releaseQuery: trimmedRelease, preferredQuality: normalizedPreferredQuality),
                action: .directDownload(candidate.downloadURL)
            )
        }

        let merged = directItems + makeExternalProviderResults(for: query)
        return merged.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.title < rhs.title
        }
    }

    private func makeExternalProviderResults(for query: String) -> [SubtitleProviderResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            return []
        }

        let languageKey = currentSubtitleLanguageKey
        let providers: [(SubtitleProviderKind, URL?, Int)] = [
            (.openSubtitles, URL(string: "https://www.opensubtitles.org/en/search2/sublanguageid-\(languageKey)/moviename-\(encoded)"), 72),
            (.podnapisi, URL(string: "https://www.podnapisi.net/subtitles/search/?keywords=\(encoded)"), 68),
            (.subtitleCat, URL(string: "https://www.subtitlecat.com/index.php?search=\(encoded)"), 60)
        ]

        return providers.compactMap { provider, url, score in
            guard let url else { return nil }
            return SubtitleProviderResult(
                id: "\(provider.rawValue)-\(url.absoluteString)",
                provider: provider,
                title: trimmed,
                subtitleLanguage: currentSubtitleLanguageKey.uppercased(),
                quality: "search",
                score: score,
                action: .externalLink(url)
            )
        }
    }

    private func providerAccessTargets(for query: String) -> [(providerName: String, endpointLabel: String, url: URL)] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }

        let languageKey = currentSubtitleLanguageKey
        let targetRows: [(String, String, String)] = [
            ("SubDL", "API", "https://api.subdl.com/auto?query=\(encoded)"),
            ("OpenSubtitles", "HTML", "https://www.opensubtitles.org/en/search2/sublanguageid-\(languageKey)/moviename-\(encoded)"),
            ("OpenSubtitles", "REST", "https://rest.opensubtitles.org/search/query-\(encoded)/sublanguageid-\(languageKey)"),
            ("Podnapisi", "HTML", "https://www.podnapisi.net/subtitles/search/?keywords=\(encoded)")
        ]

        return targetRows.compactMap { providerName, endpointLabel, urlString in
            guard let url = URL(string: urlString) else { return nil }
            return (providerName, endpointLabel, url)
        }
    }

    private func normalizedFlareSolverrEndpoint(from value: String?) -> URL? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              let url = URL(string: trimmed),
              url.scheme?.hasPrefix("http") == true
        else {
            return nil
        }

        return url
    }

    private func evaluateProviderAccess(at url: URL) async -> (summary: String, challengeMarkers: [String]) {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0 Safari/537.36",
                forHTTPHeaderField: "User-Agent"
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data.prefix(6000), encoding: .utf8) ?? ""
            let markers = challengeMarkers(in: body)
            if markers.isEmpty {
                return ("Direct access OK (\(statusCode))", [])
            }
            return ("Challenge detected (\(statusCode))", markers)
        } catch {
            return ("Request failed: \(error.localizedDescription)", ["transport-error"])
        }
    }

    private func challengeMarkers(in text: String) -> [String] {
        let lowered = text.lowercased()
        let markers = [
            "cloudflare",
            "cf-ray",
            "attention required",
            "making sure you're not a bot",
            "just a moment",
            "captcha",
            "turnstile",
            "challenge-platform",
            "ddos-guard",
            "anubis"
        ]

        return markers.filter { lowered.contains($0) }
    }

    private func scoreSubtitleCandidate(_ candidate: SubDLSubtitleCandidate, releaseQuery: String, preferredQuality: String?) -> Int {
        var score = 100
        let titleLower = candidate.title.lowercased()
        let qualityLower = candidate.quality.lowercased()
        let languageLower = candidate.language.lowercased()

        if languageLower.contains(currentSubtitleLanguageKey.lowercased()) || languageLower.contains(selectedSubtitleTrackLabel.lowercased()) {
            score += 30
        }

        if !releaseQuery.isEmpty {
            let terms = releaseQuery.lowercased().split(separator: " ").map(String.init)
            let matches = terms.filter { titleLower.contains($0) }.count
            score += matches * 12
        }

        if let preferredQuality, !preferredQuality.isEmpty {
            if qualityLower == preferredQuality {
                score += 20
            } else if titleLower.contains(preferredQuality) {
                score += 10
            } else {
                score -= 8
            }
        }

        if candidate.comment?.isEmpty == false {
            score += 4
        }

        return score
    }

    private func loadSubtitleSidecarIfAvailable(for item: MediaItem) {
        subtitleLoadTask = Task { [weak self] in
            guard let self else { return }

            let candidates = SubtitleSidecar.candidateURLs(for: item.url)
            for candidate in candidates {
                guard !Task.isCancelled else { return }
                do {
                    let data: Data
                    if candidate.isFileURL {
                        data = try Data(contentsOf: candidate)
                    } else {
                        var request = URLRequest(url: candidate)
                        request.timeoutInterval = 2.5
                        let (remoteData, response) = try await URLSession.shared.data(for: request)
                        if let http = response as? HTTPURLResponse,
                           !(200...299).contains(http.statusCode) {
                            continue
                        }
                        data = remoteData
                    }

                    let parsed = try SubtitleSidecar.parse(data: data, sourceURL: candidate)
                    if !parsed.cues.isEmpty {
                        await MainActor.run {
                            self.subtitleCues = parsed.cues
                            self.updateActiveSubtitle(at: self.playbackTimeSeconds)
                        }
                        return
                    }
                } catch {
                    continue
                }
            }
        }
    }

    private func updateActiveSubtitle(at playbackSeconds: TimeInterval) {
        guard subtitlesVisible, !subtitleCues.isEmpty else {
            activeSubtitleText = nil
            return
        }

        let effectiveTime = playbackSeconds + subtitleDelaySeconds
        if let cue = subtitleCues.first(where: { $0.contains(time: effectiveTime) }) {
            activeSubtitleText = cue.text
        } else {
            activeSubtitleText = nil
        }
    }

    func seek(to seconds: TimeInterval) async {
        guard let currentMedia else { return }

        let target = max(0, seconds)
        suppressRepeatOneForInternalStop = true
        engine?.stop()
        transportStatus = .connecting
        isBuffering = true
        playbackTimeSeconds = target
        await engine?.start(item: currentMedia, startAtSeconds: target)
        suppressRepeatOneForInternalStop = false
    }

    func seekBy(delta seconds: TimeInterval) async {
        let target = max(0, playbackTimeSeconds + seconds)
        await seek(to: target)
    }

    func stepFrameForward() async {
        let fps = stats.framesPerSecond > 0 ? stats.framesPerSecond : 30.0
        let frameDelta = 1.0 / max(1.0, fps)
        await seek(to: playbackTimeSeconds + frameDelta)
    }

    func captureSnapshot() {
        guard let pixelBuffer = currentPixelBuffer else {
            snapshotStatusMessage = "Snapshot failed: no frame"
            return
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            snapshotStatusMessage = "Snapshot failed: render error"
            return
        }

        let stamp = Int(Date().timeIntervalSince1970)
        let filename = "snapshot_\(stamp).png"
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)

        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            snapshotStatusMessage = "Snapshot failed: file error"
            return
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        if CGImageDestinationFinalize(destination) {
            snapshotStatusMessage = "Snapshot saved: \(outputURL.lastPathComponent)"
            refreshSnapshotGallery()
        } else {
            snapshotStatusMessage = "Snapshot failed: write error"
        }
    }

    func refreshSnapshotGallery() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            snapshotFiles = []
            return
        }

        let snapshots = files
            .filter { $0.lastPathComponent.hasPrefix("snapshot_") && $0.pathExtension.lowercased() == "png" }
            .sorted { lhs, rhs in
                let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lDate > rDate
            }

        snapshotFiles = snapshots
    }

    func deleteSnapshot(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        refreshSnapshotGallery()
    }

    func clearSnapshots() {
        for file in snapshotFiles {
            try? FileManager.default.removeItem(at: file)
        }
        refreshSnapshotGallery()
    }

    func cycleAudioTrack() {
        guard !audioTrackOptions.isEmpty else { return }

        let currentIndex = audioTrackOptions.firstIndex(where: { $0.id == selectedAudioTrackID }) ?? -1
        let nextIndex = (currentIndex + 1) % audioTrackOptions.count
        let next = audioTrackOptions[nextIndex]
        selectedAudioTrackID = next.id
        engine?.selectAudioTrack(id: next.id)
    }

    func selectAudioTrack(id: String) {
        guard audioTrackOptions.contains(where: { $0.id == id }) else { return }
        selectedAudioTrackID = id
        engine?.selectAudioTrack(id: id)
    }

    func cycleSubtitleTrack() {
        guard !subtitleTrackOptions.isEmpty else { return }

        let currentIndex = subtitleTrackOptions.firstIndex(where: { $0.id == selectedSubtitleTrackID }) ?? -1
        let nextIndex = (currentIndex + 1) % subtitleTrackOptions.count
        let next = subtitleTrackOptions[nextIndex]
        selectedSubtitleTrackID = next.id
        engine?.selectSubtitleTrack(id: next.id)
    }

    func selectSubtitleTrack(id: String) {
        guard subtitleTrackOptions.contains(where: { $0.id == id }) else { return }
        selectedSubtitleTrackID = id
        engine?.selectSubtitleTrack(id: id)
    }

    private func restartHLSFromSelection() async {
        guard let media = currentMedia else { return }
        guard hlsMasterRawText != nil else {
            if let rung = hlsBitrateRungs.first(where: { $0.id == selectedHLSBitrateRungId }) {
                let updated = MediaItem(
                    id: media.id,
                    title: media.title,
                    description: media.description,
                    url: rung.url,
                    sourceKind: media.sourceKind,
                    codec: media.codec,
                    vrFormat: media.vrFormat,
                    projection: media.projection,
                    framePacking: media.framePacking,
                    thumbnailURL: media.thumbnailURL,
                    duration: media.duration
                )
                await playMedia(updated)
            }
            return
        }

        let selectedRung = hlsBitrateRungs.first(where: { $0.id == selectedHLSBitrateRungId }) ?? hlsBitrateRungs.last
        let selectedAudio = hlsAudioOptions.first(where: { $0.id == selectedHLSAudioOptionId })

        let playlistText = HLSVariantPlaylistBuilder.makeMasterPlaylist(
            selectedBitrate: selectedRung,
            selectedAudio: selectedAudio
        )

        do {
            let fileURL = try HLSVariantPlaylistBuilder.writeTemporaryPlaylist(playlistText)
            let updated = MediaItem(
                id: media.id,
                title: media.title,
                description: media.description,
                url: fileURL,
                sourceKind: media.sourceKind,
                codec: media.codec,
                vrFormat: media.vrFormat,
                projection: media.projection,
                framePacking: media.framePacking,
                thumbnailURL: media.thumbnailURL,
                duration: media.duration
            )

            let savedRungs = hlsBitrateRungs
            let savedAudios = hlsAudioOptions
            let savedMasterURL = hlsMasterURL
            let savedMasterRawText = hlsMasterRawText
            let savedBitrateSelection = selectedHLSBitrateRungId
            let savedAudioSelection = selectedHLSAudioOptionId

            await playMedia(updated)

            hlsBitrateRungs = savedRungs
            hlsAudioOptions = savedAudios
            hlsMasterURL = savedMasterURL
            hlsMasterRawText = savedMasterRawText
            selectedHLSBitrateRungId = savedBitrateSelection
            selectedHLSAudioOptionId = savedAudioSelection
        } catch {
            Task {
                await DebugCategory.hls.errorLog(
                    "Failed to build temporary HLS variant playlist",
                    context: ["error": error.localizedDescription]
                )
            }
        }
    }

    private func loadHLSPlaybackOptions(from url: URL) async {
        do {
            let manifest = try await hlsManifestReader.parseMasterPlaylist(url: url)
            hlsBitrateRungs = manifest.bitrateRungs
            hlsAudioOptions = manifest.audioOptions
            hlsMasterURL = url
            hlsMasterRawText = manifest.rawText
        } catch {
            hlsBitrateRungs = []
            hlsAudioOptions = []
            hlsMasterURL = nil
            hlsMasterRawText = nil
            Task {
                await DebugCategory.hls.errorLog(
                    "HLS option parsing failed",
                    context: ["url": url.absoluteString, "error": error.localizedDescription]
                )
            }
        }
    }

    func togglePlayPause() {
        stats.isPlaying.toggle()
        isPlaying = stats.isPlaying
        
        Task {
            await DebugEventBus.shared.post(
                category: .appLifecycle,
                severity: .info,
                message: "Playback toggled",
                context: ["isPlaying": stats.isPlaying ? "true" : "false"]
            )
        }
    }

    func set2Dto3DConversion(enabled: Bool, depthStrength: Float, convergence: Float) {
        enable2Dto3DConversion = enabled
        self.depthStrength = depthStrength
        self.convergence = convergence
    }

    func updateStereoTuning(baseline: Float? = nil, horizontalDisparity: Float? = nil) {
        if let baseline {
            stereoBaseline = baseline
        }
        if let horizontalDisparity {
            self.horizontalDisparity = horizontalDisparity
        }
    }

    func configureForMediaFormat(_ format: VRFormat) {
        switch format {
        case .flat2D:
            selectedMode = .flat
            vrRenderer?.setRenderMode(.flatQuad)
            vrRenderer?.stereoscopicMode = .mono

        case .sideBySide3D:
            selectedMode = .sbs
            vrRenderer?.setRenderMode(.flatQuad)
            vrRenderer?.stereoscopicMode = .sideBySide

        case .topBottom3D:
            selectedMode = .tab
            vrRenderer?.setRenderMode(.flatQuad)
            vrRenderer?.stereoscopicMode = .topAndBottom

        case .mono180:
            selectedMode = .vr180
            vrRenderer?.setRenderMode(.hemisphere180)
            vrRenderer?.stereoscopicMode = .mono

        case .stereo180SBS:
            selectedMode = .vr180
            vrRenderer?.setRenderMode(.hemisphere180)
            vrRenderer?.stereoscopicMode = .sideBySide

        case .stereo180TAB:
            selectedMode = .vr180
            vrRenderer?.setRenderMode(.hemisphere180)
            vrRenderer?.stereoscopicMode = .topAndBottom

        case .mono360:
            selectedMode = .vr360
            vrRenderer?.setRenderMode(.sphere360)
            vrRenderer?.stereoscopicMode = .mono

        case .stereo360SBS:
            selectedMode = .vr360
            vrRenderer?.setRenderMode(.sphere360)
            vrRenderer?.stereoscopicMode = .sideBySide

        case .stereo360TAB:
            selectedMode = .vr360
            vrRenderer?.setRenderMode(.sphere360)
            vrRenderer?.stereoscopicMode = .topAndBottom
        }
    }

    func switchMode(_ mode: Mode) {
        selectedMode = mode

        switch mode {
        case .flat:
            renderSurface = .standard
            vrRenderer?.setRenderMode(.flatQuad)
            vrRenderer?.stereoscopicMode = .mono
        case .vr180:
            renderSurface = .immersive
            vrRenderer?.setRenderMode(.hemisphere180)
            vrRenderer?.stereoscopicMode = .mono
        case .vr360:
            renderSurface = .immersive
            vrRenderer?.setRenderMode(.sphere360)
            vrRenderer?.stereoscopicMode = .mono
        case .sbs:
            renderSurface = .visionMetal
            vrRenderer?.setRenderMode(.flatQuad)
            vrRenderer?.stereoscopicMode = .sideBySide
        case .tab:
            renderSurface = .visionMetal
            vrRenderer?.setRenderMode(.flatQuad)
            vrRenderer?.stereoscopicMode = .topAndBottom
        case .convert2DTo3D:
            renderSurface = .converted2DTo3D
            enable2Dto3DConversion = true
        }

        refreshSupplementalSystems()
    }

    func switchRenderSurface(_ surface: VisionUIRenderSurface) {
        renderSurface = surface
        switch surface {
        case .standard:
            enable2Dto3DConversion = false
            if selectedMode == .convert2DTo3D {
                selectedMode = .flat
            }
        case .visionMetal:
            if selectedMode == .flat {
                selectedMode = .sbs
            }
        case .immersive:
            if selectedMode == .flat || selectedMode == .sbs || selectedMode == .tab {
                selectedMode = .vr360
            }
        case .converted2DTo3D:
            selectedMode = .convert2DTo3D
            enable2Dto3DConversion = true
        }

        refreshSupplementalSystems()
    }

    private func subscribe(to engine: VideoOutputEngine) {
        pixelBufferSubscription = engine.pixelBufferPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] buffer in
                guard let self else { return }

                var output = buffer
                if enable2Dto3DConversion,
                   let converter = depth3DConverter,
                   let media = currentMedia,
                   media.vrFormat == .flat2D,
                   let converted = converter.convert2DToStereo3DSBS(
                        pixelBuffer: buffer,
                        convergence: convergence,
                        depthStrength: depthStrength
                   ) {
                    output = converted
                }

                currentPixelBuffer = output
                pixelBufferSubject.send(output)
                // NutshellPlayer port: detect color space per-frame and propagate to VRRenderer.
                let csInfo = VideoColorSpaceDetector.detect(pixelBuffer: output)
                vrRenderer?.colorSpaceInfo = csInfo
                let frameTime = nowProvider()
                lastFrameReceivedAt = frameTime
                adaptiveBufferingTuner.recordFrameArrival(at: frameTime)
                stallPredictor.recordFrame(at: frameTime)
                if isBuffering {
                    isBuffering = false
                }
            }

        dimensionSubscription = engine.dimensionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dims in
                guard let self else { return }
                stats.videoWidth = Int(dims.width)
                stats.videoHeight = Int(dims.height)
            }

        playbackTimeSubscription = engine.playbackTimePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] seconds in
                guard let self else { return }
                guard seconds.isFinite, seconds >= 0 else { return }
                playbackTimeSeconds = seconds
                updateActiveSubtitle(at: seconds)

                guard abRepeatEnabled,
                      let abStart = abRepeatStartSeconds,
                      let abEnd = abRepeatEndSeconds,
                      abEnd > abStart
                else { return }

                guard seconds >= abEnd, isABRepeatSeeking == false else { return }
                isABRepeatSeeking = true
                Task { [weak self] in
                    guard let self else { return }
                    await self.seek(to: abStart)
                    self.isABRepeatSeeking = false
                }
            }

        transportStatusSubscription = engine.transportStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                transportStatus = status

                switch status {
                case .failed(let message):
                    stats.error = "Transport: \(message)"
                case .connected:
                    stats.error = nil
                case .stopped:
                    if repeatOneEnabled,
                       isPlaying,
                       suppressRepeatOneForInternalStop == false,
                       let media = currentMedia {
                        Task { [weak self] in
                            guard let self else { return }
                            await self.playMediaCore(media, clearQueue: false)
                        }
                    } else if isPlaying,
                              suppressRepeatOneForInternalStop == false {
                        Task { [weak self] in
                            guard let self else { return }
                            _ = await self.autoAdvanceQueueAfterStop()
                        }
                    }
                case .idle, .connecting, .reconnecting:
                    break
                }
            }

        // SpatialMediaKit port: subscribe to stereo pair from MVHEVCLocalEngine.
        if let mvEngine = engine as? MVHEVCLocalEngine {
            stereoPairSubscription = mvEngine.stereoPairPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] pair in
                    self?.currentStereoPixelBuffers = pair
                }
        }
    }

    private func startBufferingMonitor() {
        bufferingMonitorTask?.cancel()

        bufferingMonitorTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let now = nowProvider()
                let isTransportRecovering: Bool
                switch transportStatus {
                case .connecting, .reconnecting:
                    isTransportRecovering = true
                case .idle, .connected, .failed, .stopped:
                    isTransportRecovering = false
                }

                let threshold = adaptiveBufferingTuner.thresholdSeconds(
                    isTransportRecovering: isTransportRecovering
                )
                adaptiveBufferingThresholdSeconds = threshold
                stats.adaptiveBufferingThreshold = threshold
                let previousBufferingState = isBuffering

                if !isPlaying {
                    isBuffering = false
                } else if case .failed = transportStatus {
                    isBuffering = false
                } else if case .stopped = transportStatus {
                    isBuffering = false
                } else if let lastFrameReceivedAt {
                    let elapsed = now.timeIntervalSince(lastFrameReceivedAt)
                    isBuffering = elapsed > threshold
                } else {
                    isBuffering = true
                }

                if previousBufferingState != isBuffering {
                    adaptiveBufferingTuner.recordBufferingStateChange(isBuffering: isBuffering)
                }

                let riskScore = stallPredictor.score(
                    now: now,
                    isBuffering: isBuffering,
                    transportStatus: transportStatus
                )
                stallRiskScore = riskScore
                stallRiskLevel = stallPredictor.level(for: riskScore)

                let diagnosis = diagnosisEngine.diagnose(
                    PlaybackObservation(
                        isBuffering: isBuffering,
                        transportStatus: transportStatus,
                        stallRiskScore: riskScore,
                        adaptiveThresholdSeconds: threshold
                    )
                )
                playbackDiagnosis = diagnosis
                stats.diagnosisSummary = diagnosis.summary
                stats.diagnosisRecommendation = diagnosis.recommendation
                stats.diagnosisConfidence = diagnosis.confidence

                let advisoryUpdate = advisoryStreamer.update(text: diagnosis.recommendation, now: now)
                advisoryPartialText = advisoryUpdate.partialText
                stats.advisoryLiveText = advisoryUpdate.partialText

                if let segment = advisoryUpdate.finalizedSegment {
                    advisorySegments.append(segment)
                    if advisorySegments.count > 12 {
                        advisorySegments.removeFirst(advisorySegments.count - 12)
                    }
                    stats.advisoryLastFinalText = segment.text
                    stats.advisoryFinalSegmentCount = advisorySegments.count
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }
}
