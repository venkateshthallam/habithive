import SwiftUI
import Combine

struct CreateHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateHabitViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    
    let onComplete: (Habit) -> Void
    
    @State private var selectedEmoji = "🎯"
    @State private var selectedColor = HiveColors.habitColors[0]
    @State private var showEmojiPicker = false
    @FocusState private var isNameFieldFocused: Bool
    
    init(onComplete: @escaping (Habit) -> Void) {
        self.onComplete = onComplete
    }
    
    private let emojis = ["🎯", "💧", "📚", "🏃", "🧘", "💪", "🎨", "✍️", "🎵", "🍎", "😴", "💊", "🦷", "📱", "💰", "🌱"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.backgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: HiveSpacing.lg) {
                        // Emoji & Color Selection
                        emojiColorSection
                        
                        // Name Input
                        nameSection
                        
                        // Habit Type
                        typeSection
                        
                        // Schedule
                        scheduleSection
                        
                        // Reminder (optional)
                        reminderSection
                        
                        // Create Button
                        createButton
                    }
                    .padding(HiveSpacing.lg)
                }
            }
            .navigationTitle("Create Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Auto-focus the name field after a slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNameFieldFocused = true
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var emojiColorSection: some View {
        VStack(spacing: HiveSpacing.md) {
            // Emoji selector
            ZStack {
                Circle()
                    .fill(selectedColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Text(selectedEmoji)
                    .font(.system(size: 50))
            }
            .onTapGesture {
                showEmojiPicker.toggle()
            }
            
            // Emoji grid
            if showEmojiPicker {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: HiveSpacing.sm) {
                    ForEach(emojis, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 30))
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: HiveRadius.small)
                                    .fill(selectedEmoji == emoji ? selectedColor.opacity(0.2) : Color.clear)
                            )
                            .onTapGesture {
                                selectedEmoji = emoji
                                viewModel.emoji = emoji
                                withAnimation {
                                    showEmojiPicker = false
                                }
                            }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.medium)
                        .fill(Color.white)
                        .shadow(radius: 5)
                )
            }
            
            // Color picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HiveSpacing.sm) {
                    ForEach(HiveColors.habitColors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .opacity(selectedColor == color ? 1 : 0)
                            )
                            .onTapGesture {
                                selectedColor = color
                                viewModel.colorHex = color.toHex() ?? "#FF9F1C"
                            }
                    }
                }
            }
        }
    }
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.xs) {
            Text("Habit Name")
                .font(HiveTypography.caption)
                .foregroundColor(HiveColors.slateText.opacity(0.7))
            
            TextField("e.g., Drink Water", text: $viewModel.name)
                .font(HiveTypography.body)
                .foregroundColor(HiveColors.slateText)
                .padding(HiveSpacing.sm)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(HiveRadius.medium)
                .focused($isNameFieldFocused)
        }
    }
    
    private var typeSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.xs) {
            Text("Type")
                .font(HiveTypography.caption)
                .foregroundColor(HiveColors.slateText.opacity(0.7))
            
            HStack(spacing: HiveSpacing.sm) {
                // Checkbox button
                Button(action: {
                    viewModel.type = .checkbox
                }) {
                    HStack {
                        Image(systemName: "checkmark.square")
                        Text("Checkbox")
                    }
                    .font(HiveTypography.callout)
                    .foregroundColor(viewModel.type == .checkbox ? .white : HiveColors.slateText)
                    .padding(.horizontal, HiveSpacing.md)
                    .padding(.vertical, HiveSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.medium)
                            .fill(viewModel.type == .checkbox ? 
                                  LinearGradient(colors: [HiveColors.honeyGradientStart, HiveColors.honeyGradientEnd], startPoint: .leading, endPoint: .trailing) : 
                                  LinearGradient(colors: [Color.gray.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
                    )
                }
                
                // Counter button
                Button(action: {
                    viewModel.type = .counter
                }) {
                    HStack {
                        Image(systemName: "number.square")
                        Text("Counter")
                    }
                    .font(HiveTypography.callout)
                    .foregroundColor(viewModel.type == .counter ? .white : HiveColors.slateText)
                    .padding(.horizontal, HiveSpacing.md)
                    .padding(.vertical, HiveSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.medium)
                            .fill(viewModel.type == .counter ? 
                                  LinearGradient(colors: [HiveColors.honeyGradientStart, HiveColors.honeyGradientEnd], startPoint: .leading, endPoint: .trailing) : 
                                  LinearGradient(colors: [Color.gray.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
                    )
                }
            }
            
            // Target for counter type
            if viewModel.type == .counter {
                HStack {
                    Text("Daily Target:")
                        .font(HiveTypography.body)
                        .foregroundColor(HiveColors.slateText)
                    
                    Stepper("\(viewModel.targetPerDay)", value: $viewModel.targetPerDay, in: 1...100)
                        .font(HiveTypography.body)
                        .foregroundColor(HiveColors.slateText)
                }
                .padding(.top, HiveSpacing.sm)
            }
        }
    }
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.xs) {
            Text("Schedule")
                .font(HiveTypography.caption)
                .foregroundColor(HiveColors.slateText.opacity(0.7))
            
            Toggle("Daily", isOn: $viewModel.scheduleDaily)
                .font(HiveTypography.body)
                .foregroundColor(HiveColors.slateText)
            
            if !viewModel.scheduleDaily {
                // Week day selector
                HStack {
                    ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                        Text(day)
                            .font(HiveTypography.caption)
                            .frame(width: 35, height: 35)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                            )
                    }
                }
            }
        }
    }
    
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.xs) {
            HStack {
                Image(systemName: "bell")
                Text("Reminder (Optional)")
            }
            .font(HiveTypography.caption)
            .foregroundColor(HiveColors.slateText.opacity(0.7))
            
            if viewModel.reminderEnabled {
                DatePicker("Time", selection: $viewModel.reminderTime, displayedComponents: .hourAndMinute)
                    .font(HiveTypography.body)
                    .foregroundColor(HiveColors.slateText)
            }
            
            Toggle("Enable Reminder", isOn: $viewModel.reminderEnabled)
                .font(HiveTypography.body)
                .foregroundColor(HiveColors.slateText)
        }
    }
    
    private var createButton: some View {
        Button(action: {
            viewModel.createHabit { habit in
                onComplete(habit)
                dismiss()
            }
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Create Habit")
                    Image(systemName: "plus.circle.fill")
                }
            }
            .font(HiveTypography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, HiveSpacing.md)
            .background(
                themeManager.currentTheme.primaryGradient
                    .opacity(viewModel.canCreate ? 1 : 0.5)
            )
            .cornerRadius(HiveRadius.large)
        }
        .disabled(!viewModel.canCreate || viewModel.isLoading)
        
    }
}

// MARK: - View Model
class CreateHabitViewModel: ObservableObject {
    @Published var name = ""
    @Published var emoji = "🎯"
    @Published var colorHex = "#FF9F1C"
    @Published var type = HabitType.checkbox
    @Published var targetPerDay = 1
    @Published var scheduleDaily = true
    @Published var scheduleWeekmask = 127
    @Published var reminderEnabled = false
    @Published var reminderTime = Date()
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize with default values
        self.emoji = "🎯"
        self.colorHex = "#FF9F1C"
    }
    
    var canCreate: Bool {
        !name.isEmpty
    }
    
    func createHabit(completion: @escaping (Habit) -> Void) {
        isLoading = true
        errorMessage = ""
        
        // Ensure we have valid color hex
        if colorHex.isEmpty {
            colorHex = "#FF9F1C"
        }
        
        // Ensure we have an emoji
        if emoji.isEmpty {
            emoji = "🎯"
        }
        
        let request = CreateHabitRequest(
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            type: type,
            targetPerDay: targetPerDay,
            scheduleDaily: scheduleDaily,
            scheduleWeekmask: scheduleWeekmask
        )
        
        print("📝 Creating habit: \(name) with emoji: \(emoji) and color: \(colorHex)")
        
        apiClient.createHabit(request)
            .sink(
                receiveCompletion: { result in
                    self.isLoading = false
                    if case .failure(let error) = result {
                        print("❌ Failed to create habit: \(error)")
                        self.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { habit in
                    print("✅ Habit created successfully: \(habit.name)")
                    completion(habit)
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Color Extension
extension Color {
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
}

#Preview {
    CreateHabitView { _ in }
}