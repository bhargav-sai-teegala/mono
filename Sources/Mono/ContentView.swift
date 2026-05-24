import SwiftUI

// MARK: - Palette
private extension Color {
    static let bg0     = Color(red: 0.028, green: 0.028, blue: 0.050)
    static let bg1     = Color(red: 0.075, green: 0.075, blue: 0.110)
    static let bg2     = Color(red: 0.130, green: 0.130, blue: 0.180)
    static let line    = Color(white: 1, opacity: 0.09)
    static let primary = Color(red: 0.486, green: 0.227, blue: 0.929)
    static let soft    = Color(red: 0.655, green: 0.545, blue: 0.973)
    static let success = Color(red: 0.290, green: 0.867, blue: 0.502)
    static let hi      = Color(red: 0.957, green: 0.957, blue: 0.969)
    static let mid     = Color(red: 0.549, green: 0.549, blue: 0.620)
    static let lo      = Color(red: 0.310, green: 0.310, blue: 0.384)
}

private let gradColors: [Color] = [
    Color(red: 0.99, green: 0.78, blue: 0.10),
    Color(red: 0.99, green: 0.58, blue: 0.18),
    Color(red: 0.97, green: 0.38, blue: 0.22),
    Color(red: 0.92, green: 0.22, blue: 0.32),
    Color(red: 0.99, green: 0.45, blue: 0.28),
    Color(red: 0.99, green: 0.68, blue: 0.14),
    Color(red: 0.99, green: 0.78, blue: 0.10),
]

private let confettiColors: [Color] = [
    .primary, .soft,
    Color(red: 0.96, green: 0.25, blue: 0.37),
    Color(red: 0.98, green: 0.75, blue: 0.14),
    .success,
    Color(red: 0.30, green: 0.80, blue: 0.98),
]

// MARK: - Gradient ring border
struct GradientBorder: ViewModifier {
    @State private var rot: Double = 0
    var radius: Double = 14; var width: Double = 1.5
    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        AngularGradient(colors: gradColors, center: .center,
                                        startAngle: .degrees(rot), endAngle: .degrees(rot + 360)),
                        lineWidth: width)
            }
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { rot = 360 }
            }
    }
}
extension View { func gradientBorder(radius: Double = 14) -> some View { modifier(GradientBorder(radius: radius)) } }

// MARK: - Confetti
private struct Confetti: Identifiable {
    let id = UUID(); let color: Color; let size: CGFloat
    var x, y: CGFloat; var rotation: Double; var opacity: Double = 1
}

// MARK: - Root
struct ContentView: View {
    @EnvironmentObject var store: TaskStore
    @State private var screen: Screen = .focus
    @State private var addText = ""
    @FocusState private var inputFocused: Bool

    @State private var addingSubtask   = false
    @State private var newSubtaskText  = ""
    @FocusState private var subtaskFocused: Bool

    @State private var appeared    = false
    @State private var exiting     = false
    @State private var headingRot: Double = 0
    @State private var orb1 = CGSize(width: -320, height: -220)
    @State private var orb2 = CGSize(width:  290, height:  140)
    @State private var orb3 = CGSize(width: -110, height:  280)
    @State private var confetti: [Confetti] = []

    private var shown: Bool { appeared && !exiting }

    enum Screen { case focus, queue, history }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                background(geo: geo)

                VStack(spacing: 0) {
                    topBar
                    ZStack {
                        switch screen {
                        case .focus:
                            focusContent(geo: geo)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal:   .move(edge: .trailing).combined(with: .opacity)))
                        case .queue:
                            queueContent(geo: geo)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal:   .move(edge: .leading).combined(with: .opacity)))
                        case .history:
                            historyContent(geo: geo)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal:   .move(edge: .leading).combined(with: .opacity)))
                        }
                    }
                    .animation(.spring(duration: 0.35), value: screen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if screen == .focus { addBar(geo: geo) }
                }
                .opacity(shown ? 1 : 0)
                .scaleEffect(shown ? 1 : 0.94)
                .blur(radius: shown ? 0 : 10)

                ForEach(confetti) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 0.55)
                        .rotationEffect(.degrees(p.rotation))
                        .position(x: p.x, y: p.y)
                        .opacity(p.opacity)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startOrbs()
            // Heading gradient spins forever — keeps going even when panel is hidden
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                headingRot = 360
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .monoWillShow)) { _ in
            // Reset so the entrance animation replays every time the panel opens
            exiting  = false
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) { appeared = true }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .monoBeginExit)) { _ in
            withAnimation(.easeIn(duration: 0.16)) { exiting = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .monoFocusInput)) { _ in
            inputFocused = true
        }
        .onChange(of: store.current?.id) { _ in
            addingSubtask = false
            newSubtaskText = ""
        }
    }

    // MARK: Background
    private func background(geo: GeometryProxy) -> some View {
        ZStack {
            Color(red: 0.028, green: 0.028, blue: 0.050).ignoresSafeArea()
            orbView(color: Color.primary.opacity(0.40), size: 580)
                .offset(x: geo.size.width/2 + orb1.width, y: geo.size.height/2 + orb1.height).blur(radius: 90)
            orbView(color: Color(red:0.96,green:0.25,blue:0.37).opacity(0.22), size: 460)
                .offset(x: geo.size.width/2 + orb2.width, y: geo.size.height/2 + orb2.height).blur(radius: 100)
            orbView(color: Color(red:0.15,green:0.45,blue:0.95).opacity(0.18), size: 400)
                .offset(x: geo.size.width/2 + orb3.width, y: geo.size.height/2 + orb3.height).blur(radius: 110)
            RadialGradient(colors: [.clear, Color.black.opacity(0.55)], center: .center,
                           startRadius: min(geo.size.width, geo.size.height) * 0.28,
                           endRadius:   max(geo.size.width, geo.size.height) * 0.72)
                .ignoresSafeArea().allowsHitTesting(false)
        }
    }

    private func orbView(color: Color, size: CGFloat) -> some View {
        Circle().fill(RadialGradient(colors: [color, .clear], center: .center,
                                     startRadius: 0, endRadius: size/2)).frame(width: size, height: size)
    }

    private func startOrbs() {
        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) { orb1 = CGSize(width: 210, height: -140) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeInOut(duration: 13).repeatForever(autoreverses: true)) { orb2 = CGSize(width: -230, height: 95) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) { orb3 = CGSize(width: 140, height: -240) }
        }
    }

    // MARK: Top bar
    private var topBar: some View {
        HStack(spacing: 0) {
            if screen != .focus {
                Button {
                    withAnimation(.spring(duration: 0.3)) { screen = .focus }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                        Text(screen == .queue ? "Queue" : "History").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color.mid)
                }
                .buttonStyle(.plain)
            } else {
                Text("mono").font(.system(size: 11, weight: .bold)).tracking(3).foregroundColor(Color.lo)
            }

            Spacer()

            if screen == .focus {
                Button {
                    withAnimation(.spring(duration: 0.3)) { screen = .queue }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "list.bullet").font(.system(size: 12))
                        Text("Queue").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color.lo)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)

                Button {
                    withAnimation(.spring(duration: 0.3)) { screen = .history }
                } label: {
                    Image(systemName: "clock").font(.system(size: 13)).foregroundColor(Color.lo)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            }

            Button { close() } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.lo)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close  (esc)")
        }
        .padding(.horizontal, 32)
        .frame(height: 56)
    }

    // MARK: Focus content
    private func focusContent(geo: GeometryProxy) -> some View {
        let sideW = min(max((geo.size.width - 560) / 2, 72), 160)
        return ZStack {
            // ── Side navigation arrows ──────────────────────────────────────
            if store.tasks.count > 1 {
                HStack(spacing: 0) {
                    // Prev
                    navArrow(isPrev: true, width: sideW)
                        .opacity(store.activeIndex > 0 ? 1 : 0)
                        .allowsHitTesting(store.activeIndex > 0)
                    Spacer()
                    // Next
                    navArrow(isPrev: false, width: sideW)
                        .opacity(store.activeIndex < store.tasks.count - 1 ? 1 : 0)
                        .allowsHitTesting(store.activeIndex < store.tasks.count - 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeOut(duration: 0.2), value: store.activeIndex)
            }

            // ── Main scrollable content ─────────────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Position dots
                    if store.tasks.count > 1 {
                        positionDots
                            .padding(.top, 12)
                            .padding(.bottom, 22)
                    }

                    if let task = store.current {
                        // Task title — spinning angular gradient + layered neon glow
                        Text(task.text)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(
                                AngularGradient(
                                    colors: gradColors,
                                    center: .center,
                                    startAngle: .degrees(headingRot),
                                    endAngle:   .degrees(headingRot + 360)
                                )
                            )
                            .shadow(color: Color(red:0.99,green:0.68,blue:0.14).opacity(0.50), radius: 10, y: 0)
                            .shadow(color: Color(red:0.97,green:0.38,blue:0.22).opacity(0.28), radius: 24, y: 0)
                            .shadow(color: Color(red:0.99,green:0.58,blue:0.18).opacity(0.12), radius: 40, y: 0)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 24)
                            .id(task.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal:   .move(edge: .leading).combined(with: .opacity)))
                            .animation(.spring(duration: 0.35), value: task.id)

                        // Subtasks
                        subtaskSection(task: task)
                            .padding(.top, 18)
                            .padding(.horizontal, 24)

                        // Timer
                        Text(fmt(store.elapsed))
                            .font(.system(size: 88, weight: .ultraLight, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(store.timerRunning ? Color.soft : Color.lo)
                            .shadow(color: store.timerRunning ? Color.primary.opacity(0.55) : .clear, radius: 28)
                            .shadow(color: store.timerRunning ? Color.primary.opacity(0.25) : .clear, radius: 60)
                            .animation(.easeInOut(duration: 0.4), value: store.timerRunning)
                            .padding(.top, 24)

                        timerButton.padding(.top, 20)

                        // Done / Skip
                        HStack(spacing: 12) {
                            actionPill(label: "Done", icon: "checkmark",
                                       fg: Color.success, bg: Color.success.opacity(0.12),
                                       border: Color.success.opacity(0.30)) {
                                spawnConfetti(at: CGPoint(x: geo.size.width/2, y: geo.size.height/2))
                                withAnimation(.spring(duration: 0.3)) { store.markDone() }
                            }
                            actionPill(label: "Skip", icon: "arrow.right",
                                       fg: Color.mid, bg: Color.white.opacity(0.05),
                                       border: Color.white.opacity(0.10)) {
                                withAnimation(.spring(duration: 0.3)) { store.skip() }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 32)

                    } else {
                        emptyState
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .frame(maxWidth: min(geo.size.width - sideW * 2, 560))
        }
    }

    // Full-height side arrow — uses the blank space on either side of content
    private func navArrow(isPrev: Bool, width: CGFloat) -> some View {
        let adjIndex = isPrev ? store.activeIndex - 1 : store.activeIndex + 1
        let adjTask  = store.tasks.indices.contains(adjIndex) ? store.tasks[adjIndex] : nil

        return Button {
            withAnimation(.spring(duration: 0.28)) { store.switchTo(index: adjIndex) }
        } label: {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: isPrev ? "chevron.left" : "chevron.right")
                    .font(.system(size: 22, weight: .ultraLight))
                    .foregroundColor(Color.lo)
                if let t = adjTask {
                    Text(t.text)
                        .font(.system(size: 10))
                        .foregroundColor(Color.lo.opacity(0.45))
                        .lineLimit(2)
                        .multilineTextAlignment(isPrev ? .trailing : .leading)
                        .frame(width: width - 16)
                }
                Spacer()
            }
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // Dot position indicator (read-only, not the primary way to switch)
    private var positionDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<min(store.tasks.count, 11), id: \.self) { i in
                Capsule()
                    .fill(i == store.activeIndex ? Color.primary : Color.white.opacity(0.14))
                    .frame(width: i == store.activeIndex ? 20 : 5, height: 5)
                    .animation(.spring(duration: 0.25), value: store.activeIndex)
            }
            if store.tasks.count > 11 {
                Text("+\(store.tasks.count - 11)")
                    .font(.system(size: 9)).foregroundColor(Color.lo)
            }
        }
    }

    // MARK: Subtask section
    private func subtaskSection(task: Task) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !task.subtasks.isEmpty {
                // Progress bar
                HStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(LinearGradient(colors: [Color.primary, Color.soft],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * task.subtaskProgress)
                                .animation(.spring(duration: 0.4), value: task.subtaskProgress)
                        }
                    }
                    .frame(height: 4)

                    Text("\(task.subtasksDone)/\(task.subtasks.count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(task.subtaskProgress == 1 ? Color.success : Color.lo)
                }

                // Checklist
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(task.subtasks) { sub in
                        subtaskRow(sub, task: task)
                    }
                }
                .padding(.top, 2)
            }

            // Add subtask input or button
            if addingSubtask {
                HStack(spacing: 10) {
                    Circle()
                        .stroke(Color.lo, lineWidth: 1.5)
                        .frame(width: 18, height: 18)

                    TextField("Subtask name…", text: $newSubtaskText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(Color.hi)
                        .focused($subtaskFocused)
                        .onSubmit {
                            let t = newSubtaskText.trimmingCharacters(in: .whitespaces)
                            if !t.isEmpty {
                                withAnimation(.spring(duration: 0.25)) {
                                    store.addSubtask(t, to: task.id)
                                }
                                newSubtaskText = ""
                                // keep field open for more
                                DispatchQueue.main.async { subtaskFocused = true }
                            } else {
                                addingSubtask = false
                            }
                        }

                    Button {
                        addingSubtask = false
                        newSubtaskText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.lo)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                .onAppear { subtaskFocused = true }
            } else {
                Button {
                    withAnimation(.spring(duration: 0.2)) { addingSubtask = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle").font(.system(size: 12))
                        Text("Add subtask").font(.system(size: 12))
                    }
                    .foregroundColor(Color.lo)
                }
                .buttonStyle(.plain)
                .padding(.top, task.subtasks.isEmpty ? 0 : 4)
            }
        }
    }

    private func subtaskRow(_ sub: Subtask, task: Task) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    store.toggleSubtask(sub.id, in: task.id)
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(sub.done ? Color.success : Color.lo, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if sub.done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.success)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(sub.text)
                .font(.system(size: 13))
                .foregroundColor(sub.done ? Color.lo : Color.mid)
                .strikethrough(sub.done, color: Color.lo)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.2), value: sub.done)

            Button {
                withAnimation(.spring(duration: 0.2)) {
                    store.deleteSubtask(sub.id, from: task.id)
                }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 12))
                    .foregroundColor(Color.lo.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Timer button
    private var timerButton: some View {
        Button {
            withAnimation(.spring(duration: 0.22)) {
                store.timerRunning ? store.pauseTimer() : store.startTimer()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: store.timerRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(store.timerRunning ? "Pause" : "Start timer")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(store.timerRunning ? Color.mid : .white)
            .padding(.horizontal, 32)
            .padding(.vertical, 13)
            .background(Group {
                if store.timerRunning {
                    Color.white.opacity(0.07)
                } else {
                    LinearGradient(colors: [Color.primary, Color(red:0.65,green:0.33,blue:0.98)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            })
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(
                store.timerRunning ? Color.white.opacity(0.10) : Color.clear, lineWidth: 1))
            .shadow(color: store.timerRunning ? .clear : Color.primary.opacity(0.45), radius: 16, y: 5)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.22), value: store.timerRunning)
    }

    private func actionPill(label: String, icon: String,
                            fg: Color, bg: Color, border: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(fg)
            .padding(.horizontal, 28).padding(.vertical, 11)
            .background(bg)
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 60)
            Text("✦").font(.system(size: 44)).opacity(0.08)
            Text("Nothing here yet")
                .font(.system(size: 20, weight: .semibold)).foregroundColor(Color.mid)
            Text("Type below and press Enter")
                .font(.system(size: 14)).foregroundColor(Color.lo)
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Add bar
    private func addBar(geo: GeometryProxy) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "plus").font(.system(size: 13, weight: .medium)).foregroundColor(Color.lo)
            TextField("Add a task and press Enter", text: $addText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(Color.hi)
                .focused($inputFocused)
                .onSubmit {
                    let t = addText.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return }
                    withAnimation(.spring(duration: 0.3)) { store.add(t) }
                    addText = ""
                }
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
        )
        .padding(.horizontal, max(32, geo.size.width * 0.20))
        .padding(.bottom, 32)
    }

    // MARK: Queue screen
    private func queueContent(geo: GeometryProxy) -> some View {
        Group {
            if store.tasks.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Text("No tasks in queue.")
                        .font(.system(size: 16)).foregroundColor(Color.lo)
                    Text("Add one from the focus screen.")
                        .font(.system(size: 13)).foregroundColor(Color.lo.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(Array(store.tasks.enumerated()), id: \.element.id) { i, task in
                            queueRow(task: task, index: i)
                        }
                    }
                    .padding(.horizontal, max(32, geo.size.width * 0.18))
                    .padding(.vertical, 16)
                }
            }
        }
    }

    private func queueRow(task: Task, index: Int) -> some View {
        let isActive = index == store.activeIndex
        return Button {
            withAnimation(.spring(duration: 0.3)) {
                store.switchTo(index: index)
                screen = .focus
            }
        } label: {
            HStack(spacing: 14) {
                // Active / index indicator
                ZStack {
                    Circle()
                        .fill(isActive ? Color.primary : Color.white.opacity(0.06))
                        .frame(width: 32, height: 32)
                    if isActive {
                        Image(systemName: store.timerRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.lo)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(task.text)
                        .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? Color.hi : Color.mid)
                        .lineLimit(1)

                    if !task.subtasks.isEmpty {
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08)).frame(width: 64, height: 3)
                                Capsule()
                                    .fill(isActive ? Color.primary : Color.lo)
                                    .frame(width: 64 * task.subtaskProgress, height: 3)
                            }
                            Text("\(task.subtasksDone)/\(task.subtasks.count) subtasks")
                                .font(.system(size: 10))
                                .foregroundColor(Color.lo)
                        }
                    }
                }

                Spacer()

                // Elapsed time
                let t = isActive ? store.elapsed : task.elapsed
                if t > 0 {
                    Text(durFmt(t))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(isActive ? Color.soft : Color.lo)
                }

                // Delete
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        store.deleteTask(at: index)
                        if store.tasks.isEmpty { screen = .focus }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(Color.lo.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? Color.primary.opacity(0.10) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isActive ? Color.primary.opacity(0.28) : Color.white.opacity(0.06),
                                lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: History screen
    private func historyContent(geo: GeometryProxy) -> some View {
        Group {
            if store.history.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Text("Nothing completed yet.")
                        .font(.system(size: 16)).foregroundColor(Color.lo)
                    Text("Finish your first task ✦")
                        .font(.system(size: 13)).foregroundColor(Color.lo.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let groups: [HistGroup] = groupHistory()
                        ForEach(groups, id: \.label) { g in
                            Text(g.label)
                                .font(.system(size: 10, weight: .bold)).tracking(1.6)
                                .textCase(.uppercase).foregroundColor(Color.lo)
                                .padding(.horizontal, max(40, geo.size.width * 0.18))
                                .padding(.top, 20).padding(.bottom, 8)
                            ForEach(g.items) { item in histRow(item, geo: geo) }
                        }
                        let total = store.history.reduce(0) { $0 + $1.timeSpent }
                        if total > 0 {
                            Divider().background(Color.line)
                                .padding(.horizontal, max(40, geo.size.width * 0.18)).padding(.top, 10)
                            Text("Total focused time: \(durFmt(total))")
                                .font(.system(size: 12)).foregroundColor(Color.lo)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                        }
                    }
                }
            }
        }
    }

    private func histRow(_ item: Done, geo: GeometryProxy) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.success.opacity(0.10)).frame(width: 22, height: 22)
                Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundColor(Color.success)
            }
            Text(item.text).font(.system(size: 14)).foregroundColor(Color.mid).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if item.timeSpent > 0 {
                Text(durFmt(item.timeSpent))
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(Color.lo)
            }
        }
        .padding(.horizontal, max(40, geo.size.width * 0.18)).padding(.vertical, 11)
    }

    // MARK: Confetti
    private func spawnConfetti(at center: CGPoint) {
        confetti = (0..<40).map { _ in
            Confetti(color: confettiColors.randomElement()!, size: CGFloat.random(in: 5...12),
                     x: center.x, y: center.y, rotation: Double.random(in: 0...360))
        }
        for i in confetti.indices {
            let angle = Double.random(in: 0..<(2 * .pi))
            let dist  = CGFloat.random(in: 80...320)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
                confetti[i].x = center.x + dist * CGFloat(cos(angle))
                confetti[i].y = center.y + dist * CGFloat(sin(angle))
                confetti[i].rotation += Double.random(in: 200...560)
            }
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.55)) {
            for i in confetti.indices { confetti[i].opacity = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { confetti = [] }
    }

    // MARK: Helpers
    private func close() { NotificationCenter.default.post(name: .closeMonoPanel, object: nil) }

    private func fmt(_ t: TimeInterval) -> String {
        let s = Int(t); let h = s/3600; let m = (s%3600)/60; let sc = s%60
        return h > 0 ? String(format:"%d:%02d:%02d",h,m,sc) : String(format:"%02d:%02d",m,sc)
    }

    private func durFmt(_ t: TimeInterval) -> String {
        let s = Int(t); let h = s/3600; let m = (s%3600)/60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }

    private struct HistGroup { let label: String; let items: [Done] }

    private func groupHistory() -> [HistGroup] {
        let cal = Calendar.current
        var map: [String: [Done]] = [:]; var order: [String] = []
        for item in store.history {
            let lbl: String
            if cal.isDateInToday(item.completedAt)          { lbl = "Today" }
            else if cal.isDateInYesterday(item.completedAt) { lbl = "Yesterday" }
            else { let f = DateFormatter(); f.dateFormat = "MMMM d"; lbl = f.string(from: item.completedAt) }
            if map[lbl] == nil { order.append(lbl) }
            map[lbl, default: []].append(item)
        }
        return order.map { HistGroup(label: $0, items: map[$0] ?? []) }
    }
}
