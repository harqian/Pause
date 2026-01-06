//
//  DayPicker.swift
//  Pause
//
//  Shared day picker for repeat days (Apple Clock-style)
//

import SwiftUI

struct DayPicker: View {
    @Binding var selectedDays: Set<Int>

    // Days: 1=Sunday, 2=Monday, ..., 7=Saturday
    private let days = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.0) { day, label in
                Button(action: {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                }) {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 24)
                        .background(selectedDays.contains(day) ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

func formatRepeatDays(_ days: Set<Int>) -> String {
    if days.isEmpty {
        return "Once (won't repeat)"
    }
    if days == Set(1...7) {
        return "Every day"
    }
    if days == Set([2, 3, 4, 5, 6]) {
        return "Weekdays"
    }
    if days == Set([1, 7]) {
        return "Weekends"
    }
    let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    return days.sorted().map { dayNames[$0] }.joined(separator: ", ")
}
