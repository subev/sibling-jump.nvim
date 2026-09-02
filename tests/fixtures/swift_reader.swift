import Foundation
import SwiftUI

struct ReaderScreen: View {
    let book: Book
    @State private var state: LoadState = .loading
    @State private var player = PlayerModel()
    @State private var request = ChapterRequest(
        start: ReaderScreen.launched("-autoplay") ? .playing : .paused)
    @AppStorage("reader.columns") private var columns = true
    // Two sheets cannot stand on each other.
    @State private var chaptersAfterPlayer = false

    private static let launchArguments = ProcessInfo.processInfo.arguments

    private static func launched(_ argument: String) -> Bool {
        launchArguments.contains(argument)
    }

    init(book: Book) {
        self.book = book
        _coverage = State(initialValue: CoverageRecorder(book: book))
    }

    enum LoadState {
        case loading
        case loaded(LoadedChapter)
        case nothingMapped
        case failed(String)
    }

    enum Start: Equatable {
        case paused
        case playing
        // Where the reader was when they last closed the book.
        case at(ms: Int)
        case beforeTheEnd(byMs: Int, playing: Bool)
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .loaded(let loaded):
                reader(for: loaded)
            case .nothingMapped:
                ContentUnavailableView(
                    "Nothing to line up", systemImage: "text.page",
                    description: Text("This book has no page-mapped narrated chapter."))
            case .failed(let message):
                ContentUnavailableView(
                    "Couldn't open this chapter", systemImage: "exclamationmark.triangle",
                    description: Text(message))
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        // One tap and the chrome goes.
        .toolbar(immersive ? .hidden : .automatic, for: .navigationBar)
        .toolbar {
            if !showingText {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fit to the screen", systemImage: fitSymbol) { fitRequests += 1 }
                        .accessibilityValue(fitState)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Text options", systemImage: "textformat.size") { showingTextOptions = true }
            }
            if book.manifest.chapters.count > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chapters", systemImage: "list.bullet") { showingChapters = true }
                }
            }
        }
        .sheet(isPresented: $showingChapters) {
            ChapterPicker(
                chapters: book.manifest.chapters, currentID: loadedChapter?.id, player: player,
                state: coverage.state, onPick: open)
        }
        .task(id: request) { await load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                player.startTicking()
                coverage.heard(
                    through: player.playheadMs, playing: player.isPlaying,
                    audioMs: player.durationMs)
            } else {
                player.stopTicking()
                coverage.backgrounded(at: player.playheadMs)
            }
        }
        .onDisappear {
            coverage.closed(at: player.playheadMs)
            player.unload()
        }
    }

    private var title: String {
        if case .loaded(let loaded) = state { return loaded.chapter.title }
        return book.manifest.book.title
    }

    private var fitState: String {
        if zoom > 1.02 {
            return "zoomed in"
        } else if zoom < 0.98 {
            return "smaller than the screen"
        } else {
            return "fitted"
        }
    }

    private func openChaptersIfAsked() {
        guard chaptersAfterPlayer else { return }
        chaptersAfterPlayer = false
        showingChapters = true
    }

    @ViewBuilder private func reader(for loaded: LoadedChapter) -> some View {
        let narrated = loaded.chapter.audio != nil
        let reading = readsAsText(loaded)
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let notice =
                immersive
                ? nil
                : chapterNotice(for: loaded, across: proxy.size.width - insets.leading)
            let topBar = notice != nil || (immersive && !reading)
            ZStack(alignment: .top) {
                surface(
                    for: loaded,
                    readable: UIEdgeInsets(
                        top: insets.top + (topBar ? topBarHeight : 0),
                        left: insets.leading,
                        bottom: insets.bottom,
                        right: insets.trailing + (narrated ? Self.marginRibbon : 0))
                )
                .ignoresSafeArea(.container)
                if narrated {
                    MarginRibbon(
                        player: player, coverage: coverage, chapterID: loaded.chapter.id
                    )
                    .frame(height: proxy.size.height - insets.top - insets.bottom)
                    .allowsHitTesting(false)
                }
                VStack(spacing: 0) {
                    if topBar {
                        ChapterNoticeBar(notice: notice)
                            .padding(.horizontal, 12)
                    }
                    Spacer(minLength: 0)
                    if !following {
                        BackToTheVoice { following = true }
                    }
                }
            }
        }
    }

    private func chapterNotice(for loaded: LoadedChapter, across width: CGFloat) -> Notice? {
        if readsAsText(loaded) {
            guard !loaded.chapter.showsPrint else { return nil }
            return Notice(text: "There is no print to line this chapter up with.")
        }
        switch narration {
        case .none:
            return Notice(text: "This chapter hasn't been narrated yet.")
        case .unmarked:
            return Notice(text: "Narrated before its pages could be marked.")
        case .marked:
            break
        }
        if let fit = legibility(of: loaded, across: width), fit.percent < 70 {
            return Notice(
                text: "The print comes out small here.",
                offer: ("Read as text", { text = true }))
        }
        return nil
    }

    private func seek(toSentence tapped: TappedSentence, in loaded: LoadedChapter) {
        let cues = loaded.cues?.cues ?? []
        let target = book.manifest.tapTarget(
            page: tapped.page, x: tapped.x, y: tapped.y, in: cues, reading: loaded.chapter.id,
            neighbours: loaded.neighbours)
        FollowLog.tapped(page: tapped.page, x: tapped.x, y: tapped.y)
        switch target {
        case .cue(let index):
            play(cues[index].startMs)
        case .chapter(let id):
            guard let chapter = book.manifest.chapter(id: id) else { return }
            go(to: chapter, start: .atSentence(tapped))
        case .nothing:
            break
        }
    }

    private func load() async {
        let book = self.book
        guard
            let chapter = request.id.flatMap({ book.manifest.chapter(id: $0) })
                ?? book.manifest.firstOpenableChapter
        else {
            state = .nothingMapped
            return
        }
        coverage.closed(at: player.playheadMs)
        player.pause()
        do {
            let task = Task.detached { try Self.loadChapter(chapter, of: book) }
            let chapterLoad = try await task.value
            guard !Task.isCancelled else { return }
            guard let loaded = chapterLoad else {
                player.unload()
                state = .chapterEmpty
                return
            }
            state = .loaded(loaded)
            if let audio = loaded.chapter.audio {
                player.load(
                    url: book.fileURL(for: audio),
                    durationMs: durationMs ?? 1,
                    showing: subject(for: loaded.chapter))
                player.onEvent = { event in handle(event, next: next, previous: previous) }
                start(opening, in: loaded)
            } else {
                player.unload()
                stopShowingThePlayer()
            }
            advanceHighlight(to: player.currentMs)
        } catch {
            guard !Task.isCancelled else { return }
            player.unload()
            state = .failed(errorMessage(for: error))
        }
    }

    private func rects(_ cueRects: [CueRect]?, on page: ReaderPage) -> [CGRect] {
        (cueRects ?? [])
            .filter { $0.page == page.index }
            .map { CueEngine.pageRect($0, on: page).cgRect }
    }

    private nonisolated static func loadChapter(
        _ chapter: ReaderChapter, of book: LibraryBook
    ) throws -> LoadedChapter? {
        let cues = try book.cues(of: chapter)
        var neighbours: [String: [ReaderCue]] = [:]
        for other in own.first.map({ book.manifest.chapters(atPage: $0.index) }) ?? []
        where other.id != chapter.id {
            neighbours[other.id] = (try? book.cues(of: other))?.cues ?? []
        }
        return LoadedChapter(
            chapter: chapter, cues: cues, pages: pages, pdfURL: url,
            neighbours: neighbours)
    }
}

// Upright, and its own view.
private struct MarginRibbon: View {
    let player: PlayerModel
    let chapterID: String

    var body: some View {
        GeometryReader { proxy in
            CoverageRibbon(heard: heard, nowMs: player.currentMs)
                .frame(width: proxy.size.height)
                .rotationEffect(.degrees(90))
        }
        .frame(width: ReaderScreen.marginRibbon)
    }
}

extension View {
    func measured(into height: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) {
            $0.size.height
        } action: {
            height.wrappedValue = $0
        }
    }
}

extension LibratoryKit.Rect {
    nonisolated var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}
