// MusicSource Protocol – Strategy Pattern
protocol MusicSource {
    func load(song: Song)
    func play()
    func pause()
    func stop()
}
//Concrete Sources (Local & Spotify)
class LocalFileSource: MusicSource {
    func load(song: Song) {
        print("Loading local song: \(song.title)")
    }
    func play() { print("Playing local file") }
    func pause() { print("Paused local file") }
    func stop() { print("Stopped local file") }
}

class SpotifySource: MusicSource {
    func load(song: Song) {
        print("Mock loading from Spotify: \(song.title)")
    }
    func play() { print("Playing from Spotify") }
    func pause() { print("Paused Spotify") }
    func stop() { print("Stopped Spotify") }
}
//Song Model
enum SourceType {
    case local
    case spotify
}

struct Song: Identifiable {
    let id: UUID = UUID()
    let title: String
    let artist: String
    let duration: TimeInterval
    let sourceType: SourceType
}
//MusicSourceFactory – Factory Pattern
class MusicSourceFactory {
    static func createSource(for type: SourceType) -> MusicSource {
        switch type {
        case .local: return LocalFileSource()
        case .spotify: return SpotifySource()
        }
    }
}
// MusicPlayer – Singleton + Observer + Command
import Combine

class MusicPlayer {
    static let shared = MusicPlayer()
    
    @Published private(set) var currentSong: Song?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var progress: TimeInterval = 0
    
    private var currentSource: MusicSource?
    private var queue: [Song] = []
    private var index = 0
    private var timer: Timer?

    private init() { }

    func loadQueue(_ songs: [Song]) {
        queue = songs
        index = 0
        loadCurrent()
    }

    func play() {
        guard let song = currentSong else { return }
        currentSource?.play()
        isPlaying = true
        startProgressTimer()
    }

    func pause() {
        currentSource?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    func skip() {
        guard index + 1 < queue.count else { return }
        index += 1
        loadCurrent()
        play()
    }

    func previous() {
        guard index > 0 else { return }
        index -= 1
        loadCurrent()
        play()
    }

    private func loadCurrent() {
        currentSong = queue[index]
        currentSource = MusicSourceFactory.createSource(for: queue[index].sourceType)
        currentSource?.load(song: queue[index])
        progress = 0
    }

    private func startProgressTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard let duration = self.currentSong?.duration else { return }
            self.progress += 1
            if self.progress >= duration {
                self.skip()
            }
        }
    }
}
//MusicPlayerViewModel – MVVM + Combine
class MusicPlayerViewModel: ObservableObject {
    @Published var songTitle = ""
    @Published var isPlaying = false
    @Published var progress: Double = 0

    private var cancellables = Set<AnyCancellable>()

    init() {
        let player = MusicPlayer.shared
        
        player.$currentSong
            .sink { [weak self] song in
                self?.songTitle = song?.title ?? "No song"
            }
            .store(in: &cancellables)

        player.$isPlaying
            .assign(to: &$isPlaying)

        player.$progress
            .assign(to: &$progress)
    }

    func play() { MusicPlayer.shared.play() }
    func pause() { MusicPlayer.shared.pause() }
    func skip() { MusicPlayer.shared.skip() }
    func previous() { MusicPlayer.shared.previous() }
}
//SwiftUI View (Example)
struct PlayerView: View {
    @StateObject var vm = MusicPlayerViewModel()

    var body: some View {
        VStack {
            Text(vm.songTitle)
            Slider(value: $vm.progress, in: 0...100)
            HStack {
                Button("Prev", action: vm.previous)
                Button(vm.isPlaying ? "Pause" : "Play", action: {
                    vm.isPlaying ? vm.pause() : vm.play()
                })
                Button("Next", action: vm.skip)
            }
        }.padding()
    }
}
