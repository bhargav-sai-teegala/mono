import Foundation
import Combine

struct Subtask: Codable, Identifiable, Equatable {
    var id   = UUID()
    var text: String
    var done = false
}

struct Task: Codable, Identifiable, Equatable {
    var id        = UUID()
    var text:       String
    var createdAt   = Date()
    var elapsed:    TimeInterval = 0
    var subtasks:   [Subtask] = []

    var subtasksDone:  Int { subtasks.filter(\.done).count }
    var subtaskProgress: Double {
        subtasks.isEmpty ? 0 : Double(subtasksDone) / Double(subtasks.count)
    }
}

struct Done: Codable, Identifiable {
    var id          = UUID()
    var text:         String
    var completedAt   = Date()
    var timeSpent:    TimeInterval
}

private struct Store: Codable {
    var tasks:       [Task] = []
    var history:     [Done] = []
    var activeIndex: Int    = 0
}

final class TaskStore: ObservableObject {
    @Published var tasks:        [Task] = []
    @Published var history:      [Done] = []
    @Published var elapsed:      TimeInterval = 0
    @Published var timerRunning  = false
    @Published var activeIndex:  Int = 0

    private var acc:        TimeInterval = 0
    private var timerStart: Date?
    private var tick:       AnyCancellable?
    private let file:       URL

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mono")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        file = dir.appendingPathComponent("data.json")
        load()
    }

    var current: Task? {
        guard !tasks.isEmpty else { return nil }
        return tasks[min(activeIndex, tasks.count - 1)]
    }

    // MARK: Timer
    func startTimer() {
        guard !timerRunning else { return }
        timerStart   = Date()
        timerRunning = true
        tick = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tickElapsed() }
    }

    func pauseTimer() {
        guard timerRunning, let s = timerStart else { return }
        acc         += Date().timeIntervalSince(s)
        timerStart   = nil
        timerRunning = false
        tick?.cancel()
        elapsed = acc
        flushElapsed()
    }

    func resetTimer() {
        pauseTimer()
        acc     = 0
        elapsed = 0
    }

    private func tickElapsed() {
        guard let s = timerStart else { return }
        elapsed = acc + Date().timeIntervalSince(s)
    }

    private func liveElapsed() -> TimeInterval {
        guard let s = timerStart else { return acc }
        return acc + Date().timeIntervalSince(s)
    }

    private func flushElapsed() {
        guard tasks.indices.contains(activeIndex) else { return }
        tasks[activeIndex].elapsed = acc
    }

    // MARK: Switch task
    func switchTo(index: Int) {
        guard tasks.indices.contains(index), index != activeIndex else { return }
        let wasRunning = timerRunning
        if tasks.indices.contains(activeIndex) {
            tasks[activeIndex].elapsed = liveElapsed()
        }
        pauseTimer()
        activeIndex = index
        acc     = tasks[index].elapsed
        elapsed = acc
        if wasRunning { startTimer() }
        save()
    }

    // MARK: Actions
    func markDone() {
        guard tasks.indices.contains(activeIndex) else { return }
        let task  = tasks[activeIndex]
        let spent = liveElapsed()
        resetTimer()
        tasks.remove(at: activeIndex)
        history.insert(Done(text: task.text, timeSpent: spent), at: 0)
        activeIndex = tasks.isEmpty ? 0 : min(activeIndex, tasks.count - 1)
        acc     = tasks.indices.contains(activeIndex) ? tasks[activeIndex].elapsed : 0
        elapsed = acc
        save()
    }

    func skip() {
        guard tasks.count > 1, tasks.indices.contains(activeIndex) else { return }
        tasks[activeIndex].elapsed = liveElapsed()
        let wasRunning = timerRunning
        pauseTimer()
        let t = tasks.remove(at: activeIndex)
        tasks.append(t)
        if activeIndex >= tasks.count { activeIndex = tasks.count - 1 }
        acc     = tasks[activeIndex].elapsed
        elapsed = acc
        if wasRunning { startTimer() }
        save()
    }

    func add(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        tasks.append(Task(text: t))
        save()
    }

    func deleteTask(at index: Int) {
        guard tasks.indices.contains(index) else { return }
        if index == activeIndex {
            let wasRunning = timerRunning
            resetTimer()
            tasks.remove(at: index)
            activeIndex = tasks.isEmpty ? 0 : min(activeIndex, tasks.count - 1)
            acc     = tasks.indices.contains(activeIndex) ? tasks[activeIndex].elapsed : 0
            elapsed = acc
            if wasRunning && !tasks.isEmpty { startTimer() }
        } else {
            tasks.remove(at: index)
            if index < activeIndex { activeIndex -= 1 }
        }
        save()
    }

    // MARK: Subtasks
    func addSubtask(_ text: String, to taskId: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        tasks[i].subtasks.append(Subtask(text: t))
        save()
    }

    func toggleSubtask(_ subtaskId: UUID, in taskId: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskId }),
              let si = tasks[ti].subtasks.firstIndex(where: { $0.id == subtaskId }) else { return }
        tasks[ti].subtasks[si].done.toggle()
        save()
    }

    func deleteSubtask(_ subtaskId: UUID, from taskId: UUID) {
        guard let ti = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[ti].subtasks.removeAll { $0.id == subtaskId }
        save()
    }

    // MARK: Persistence
    private func load() {
        guard let data = try? Data(contentsOf: file),
              let s    = try? JSONDecoder().decode(Store.self, from: data) else { return }
        tasks       = s.tasks
        history     = s.history
        activeIndex = max(0, min(s.activeIndex, max(0, s.tasks.count - 1)))
        acc         = tasks.indices.contains(activeIndex) ? tasks[activeIndex].elapsed : 0
        elapsed     = acc
    }

    private func save() {
        let s = Store(tasks: tasks, history: history, activeIndex: activeIndex)
        try? JSONEncoder().encode(s).write(to: file)
    }
}
