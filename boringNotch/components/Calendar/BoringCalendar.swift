//
//  BoringCalendar.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 08/09/24.
//

import Defaults
import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var calendarManager = CalendarManager.shared

    var body: some View {
        AgendaView(events: calendarManager.events)
            .onChange(of: vm.notchState) { _, _ in
                Task { await calendarManager.updateUpcomingEvents() }
            }
            .onAppear {
                Task { await calendarManager.updateUpcomingEvents() }
            }
    }
}

// MARK: - Agenda

/// Shows upcoming events for the next several days, grouped by day. The user no
/// longer picks a day; days with no events are simply skipped.
struct AgendaView: View {
    let events: [EventModel]

    /// Apply the user's visibility settings (completed reminders / all-day events).
    static func filtered(_ events: [EventModel]) -> [EventModel] {
        events.filter { event in
            if event.type.isReminder {
                if case .reminder(let completed) = event.type {
                    return !completed || !Defaults[.hideCompletedReminders]
                }
            }
            if event.isAllDay && Defaults[.hideAllDayEvents] {
                return false
            }
            return true
        }
    }

    /// Upcoming events only: drop anything that has already ended.
    private var upcoming: [EventModel] {
        let now = Date()
        return Self.filtered(events)
            .filter { $0.end >= now }
            .sorted { $0.start < $1.start }
    }

    /// Events grouped by calendar day, days sorted ascending.
    private var sections: [(day: Date, events: [EventModel])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: upcoming) { cal.startOfDay(for: $0.start) }
        return groups.keys.sorted().map { day in
            (day: day, events: groups[day]!.sorted(by: Self.sortWithinDay))
        }
    }

    /// All-day events first, then by start time.
    private static func sortWithinDay(_ a: EventModel, _ b: EventModel) -> Bool {
        if a.isAllDay != b.isAllDay { return a.isAllDay && !b.isAllDay }
        return a.start < b.start
    }

    var body: some View {
        if sections.isEmpty {
            VStack {
                EmptyEventsView()
                Spacer(minLength: 0)
            }
        } else {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(sections, id: \.day) { section in
                        DayHeader(day: section.day)
                        ForEach(section.events) { event in
                            EventRowView(event: event)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.never)
            .scrollContentBackground(.hidden)
        }
    }
}

struct DayHeader: View {
    let day: Date

    private var label: String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var body: some View {
        Text(label.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(Color(white: 0.55))
            .padding(.top, 6)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyEventsView: View {
    var body: some View {
        VStack {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title)
                .foregroundColor(Color(white: 0.65))
            Text("No upcoming events")
                .font(.subheadline)
                .foregroundColor(.white)
            Text("Nothing on your plate this week!")
                .font(.caption)
                .foregroundColor(Color(white: 0.65))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Event row

struct EventRowView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.showFullEventTitles) private var showFullEventTitles
    let event: EventModel

    var body: some View {
        Button(action: {
            if let url = event.calendarAppURL() {
                openURL(url)
            }
        }) {
            rowContent
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.leading, -5)
    }

    @ViewBuilder
    private var rowContent: some View {
        if event.type.isReminder {
            let isCompleted: Bool = {
                if case .reminder(let completed) = event.type { return completed }
                return false
            }()
            HStack(spacing: 8) {
                ReminderToggle(
                    isOn: Binding(
                        get: { isCompleted },
                        set: { newValue in
                            Task {
                                await calendarManager.setReminderCompleted(
                                    reminderID: event.id, completed: newValue
                                )
                            }
                        }
                    ),
                    color: Color(event.calendar.color)
                )
                .opacity(1.0)  // Ensure the toggle is always fully opaque
                HStack {
                    Text(event.title)
                        .font(.callout)
                        .foregroundColor(.white)
                        .lineLimit(showFullEventTitles ? nil : 1)
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        if event.isAllDay {
                            Text("All-day")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        } else {
                            Text(event.start, style: .time)
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                    }
                }
                .opacity(isCompleted ? 0.4 : 1.0)
            }
            .padding(.vertical, 4)
        } else {
            HStack(alignment: .top, spacing: 4) {
                Rectangle()
                    .fill(Color(event.calendar.color))
                    .frame(width: 3)
                    .cornerRadius(1.5)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(showFullEventTitles ? nil : 2)

                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.caption)
                            .foregroundColor(Color(white: 0.65))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    if event.isAllDay {
                        Text("All-day")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    } else {
                        Text(event.start, style: .time)
                            .foregroundColor(.white)
                        Text(event.end, style: .time)
                            .foregroundColor(Color(white: 0.65))
                    }
                }
                .font(.caption)
                .frame(minWidth: 44, alignment: .trailing)
            }
            .padding(.vertical, 2)
        }
    }
}

struct ReminderToggle: View {
    @Binding var isOn: Bool
    var color: Color

    var body: some View {
        Button(action: {
            isOn.toggle()
        }) {
            ZStack {
                // Outer ring
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: 14, height: 14)
                // Inner fill
                if isOn {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Circle()
                    .fill(Color.black.opacity(0.001))
                    .frame(width: 14, height: 14)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(0)
        .accessibilityLabel(isOn ? "Mark as incomplete" : "Mark as complete")
    }
}

#Preview {
    CalendarView()
        .frame(width: 215, height: 130)
        .background(.black)
        .environmentObject(BoringViewModel())
}
