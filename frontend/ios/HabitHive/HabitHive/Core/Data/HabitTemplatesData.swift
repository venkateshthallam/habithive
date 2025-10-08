import Foundation

struct HabitTemplatesData {
    static let allTemplates: [HabitTemplate] = [
        // MARK: - Loved Ones (Social Habits)
        HabitTemplate(
            id: "loved-1",
            category: HabitTemplateCategory.lovedOnes.rawValue,
            name: "Spend time with family",
            description: "Stay connected",
            emoji: "👨‍👩‍👧",
            colorHex: "#FF9F1C"
        ),
        HabitTemplate(
            id: "loved-2",
            category: HabitTemplateCategory.lovedOnes.rawValue,
            name: "Meet with a friend",
            description: "Make new memories",
            emoji: "💬",
            colorHex: "#4ECDC4"
        ),
        HabitTemplate(
            id: "loved-3",
            category: HabitTemplateCategory.lovedOnes.rawValue,
            name: "Call parents",
            description: "They love you",
            emoji: "📱",
            colorHex: "#A8DADC"
        ),
        HabitTemplate(
            id: "loved-4",
            category: HabitTemplateCategory.lovedOnes.rawValue,
            name: "Make a gift",
            description: "Make someone smile today",
            emoji: "🎁",
            colorHex: "#FFE66D"
        ),
        HabitTemplate(
            id: "loved-5",
            category: HabitTemplateCategory.lovedOnes.rawValue,
            name: "Hug and kiss",
            description: "Showing love and affection is easy",
            emoji: "❤️",
            colorHex: "#FF6B6B"
        ),
        HabitTemplate(
            id: "loved-6",
            category: HabitTemplateCategory.lovedOnes.rawValue,
            name: "Cuddle",
            description: "Embrace your tender side",
            emoji: "🫂",
            colorHex: "#95E77E"
        ),

        // MARK: - Morning Routine
        HabitTemplate(
            id: "morning-1",
            category: HabitTemplateCategory.morningRoutine.rawValue,
            name: "Eat a healthy meal",
            description: "Energize and stay healthy with a balanced diet",
            emoji: "🍽️",
            colorHex: "#A8DADC"
        ),
        HabitTemplate(
            id: "morning-2",
            category: HabitTemplateCategory.morningRoutine.rawValue,
            name: "Drink water",
            description: "Stay hydrated and flush out toxins",
            emoji: "💧",
            colorHex: "#34C8ED"
        ),
        HabitTemplate(
            id: "morning-3",
            category: HabitTemplateCategory.morningRoutine.rawValue,
            name: "Brush & floss",
            description: "Keep your teeth and gums healthy",
            emoji: "🦷",
            colorHex: "#FFE66D"
        ),
        HabitTemplate(
            id: "morning-4",
            category: HabitTemplateCategory.morningRoutine.rawValue,
            name: "Exercise",
            description: "Charge your batteries",
            emoji: "💪",
            colorHex: "#FF6B6B"
        ),
        HabitTemplate(
            id: "morning-5",
            category: HabitTemplateCategory.morningRoutine.rawValue,
            name: "Make my bed",
            description: "Start your day off right",
            emoji: "🛏️",
            colorHex: "#FF9F1C"
        ),
        HabitTemplate(
            id: "morning-6",
            category: HabitTemplateCategory.morningRoutine.rawValue,
            name: "Meditate",
            description: "Find inner peace",
            emoji: "☯️",
            colorHex: "#FFE66D"
        ),
        HabitTemplate(
            id: "morning-7",
            category: HabitTemplateCategory.morningRoutine.rawValue,
            name: "Wake up early",
            description: "Add some extra hours to your day",
            emoji: "⏰",
            colorHex: "#4ECDC4"
        ),
        HabitTemplate(
            id: "morning-8",
            category: HabitTemplateCategory.morningRoutine.rawValue,
            name: "Practice visualization",
            description: "Use the power of your subconscious mind",
            emoji: "🖼️",
            colorHex: "#A8DADC"
        ),
        HabitTemplate(
            id: "morning-9",
            category: HabitTemplateCategory.morningRoutine.rawValue,
            name: "Practice affirmations",
            description: "Positive thinking can transform your entire life",
            emoji: "🔺",
            colorHex: "#FF6B6B"
        ),

        // MARK: - Must-Have Habits
        HabitTemplate(
            id: "must-1",
            category: HabitTemplateCategory.mustHaveHabits.rawValue,
            name: "Drink water",
            description: "Stay hydrated and flush out toxins",
            emoji: "💧",
            colorHex: "#34C8ED"
        ),
        HabitTemplate(
            id: "must-2",
            category: HabitTemplateCategory.mustHaveHabits.rawValue,
            name: "Eat fruits and veggies",
            description: "Natural source of essential nutrients and fiber",
            emoji: "🍎",
            colorHex: "#95E77E"
        ),
        HabitTemplate(
            id: "must-3",
            category: HabitTemplateCategory.mustHaveHabits.rawValue,
            name: "Exercise",
            description: "Charge your batteries",
            emoji: "💪",
            colorHex: "#FF6B6B"
        ),
        HabitTemplate(
            id: "must-4",
            category: HabitTemplateCategory.mustHaveHabits.rawValue,
            name: "Go for a walk",
            description: "Walking strengthens your bones and improves your mood",
            emoji: "🌲",
            colorHex: "#4ECDC4"
        ),
        HabitTemplate(
            id: "must-5",
            category: HabitTemplateCategory.mustHaveHabits.rawValue,
            name: "Read",
            description: "Reading broadens the mind",
            emoji: "📖",
            colorHex: "#FF6B6B"
        ),
        HabitTemplate(
            id: "must-6",
            category: HabitTemplateCategory.mustHaveHabits.rawValue,
            name: "Sleep for 8 hours",
            description: "Your body will be grateful",
            emoji: "🌙",
            colorHex: "#A8DADC"
        ),
        HabitTemplate(
            id: "must-7",
            category: HabitTemplateCategory.mustHaveHabits.rawValue,
            name: "Make time for myself",
            description: "Stop the daily rush and listen carefully",
            emoji: "⏱️",
            colorHex: "#34C8ED"
        ),
        HabitTemplate(
            id: "must-8",
            category: HabitTemplateCategory.mustHaveHabits.rawValue,
            name: "Meditate",
            description: "Find inner peace",
            emoji: "☯️",
            colorHex: "#FFE66D"
        ),
        HabitTemplate(
            id: "must-9",
            category: HabitTemplateCategory.mustHaveHabits.rawValue,
            name: "Set goals",
            description: "Stay motivated and focused",
            emoji: "⭐",
            colorHex: "#FF9F1C"
        ),

        // MARK: - Personal Growth
        HabitTemplate(
            id: "growth-1",
            category: HabitTemplateCategory.personalGrowth.rawValue,
            name: "Journal",
            description: "Reflect on your day and your thoughts",
            emoji: "📝",
            colorHex: "#FF9F1C"
        ),
        HabitTemplate(
            id: "growth-2",
            category: HabitTemplateCategory.personalGrowth.rawValue,
            name: "Learn something new",
            description: "Expand your knowledge and skills",
            emoji: "🎓",
            colorHex: "#34C8ED"
        ),
        HabitTemplate(
            id: "growth-3",
            category: HabitTemplateCategory.personalGrowth.rawValue,
            name: "Practice gratitude",
            description: "Appreciate the good things in life",
            emoji: "🙏",
            colorHex: "#FFE66D"
        ),
        HabitTemplate(
            id: "growth-4",
            category: HabitTemplateCategory.personalGrowth.rawValue,
            name: "Listen to a podcast",
            description: "Learn while on the go",
            emoji: "🎧",
            colorHex: "#A8DADC"
        ),
        HabitTemplate(
            id: "growth-5",
            category: HabitTemplateCategory.personalGrowth.rawValue,
            name: "Practice a hobby",
            description: "Do what makes you happy",
            emoji: "🎨",
            colorHex: "#FF6B6B"
        ),

        // MARK: - Social Activities
        HabitTemplate(
            id: "social-1",
            category: HabitTemplateCategory.socialActivities.rawValue,
            name: "Host movie marathon",
            description: "May the Force be with you!",
            emoji: "📺",
            colorHex: "#A8DADC"
        ),
        HabitTemplate(
            id: "social-2",
            category: HabitTemplateCategory.socialActivities.rawValue,
            name: "Play board game",
            description: "Turn off the TV and challenge everyone to play",
            emoji: "🎲",
            colorHex: "#FFE66D"
        ),
        HabitTemplate(
            id: "social-3",
            category: HabitTemplateCategory.socialActivities.rawValue,
            name: "Do a puzzle",
            description: "Puzzles are a calming way to spend time together",
            emoji: "🧩",
            colorHex: "#FF9F1C"
        ),
        HabitTemplate(
            id: "social-4",
            category: HabitTemplateCategory.socialActivities.rawValue,
            name: "Study online",
            description: "A world of new discoveries awaits",
            emoji: "💻",
            colorHex: "#34C8ED"
        ),
        HabitTemplate(
            id: "social-5",
            category: HabitTemplateCategory.socialActivities.rawValue,
            name: "Work out together",
            description: "Turn on your favorite music and get your blood pumping",
            emoji: "🏋️",
            colorHex: "#FF6B6B"
        ),
        HabitTemplate(
            id: "social-6",
            category: HabitTemplateCategory.socialActivities.rawValue,
            name: "Cook a meal together",
            description: "Bond over food preparation and sharing",
            emoji: "👨‍🍳",
            colorHex: "#95E77E"
        ),
        HabitTemplate(
            id: "social-7",
            category: HabitTemplateCategory.socialActivities.rawValue,
            name: "Plan a group challenge",
            description: "Achieve goals together with your hive",
            emoji: "🎯",
            colorHex: "#4ECDC4"
        )
    ]

    static func templates(for category: HabitTemplateCategory) -> [HabitTemplate] {
        allTemplates.filter { $0.category == category.rawValue }
    }

    static func templates(for categoryString: String) -> [HabitTemplate] {
        allTemplates.filter { $0.category == categoryString }
    }

    static var templatesByCategory: [String: [HabitTemplate]] {
        Dictionary(grouping: allTemplates) { $0.category }
    }
}
