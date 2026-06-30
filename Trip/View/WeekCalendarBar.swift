import SwiftUI

// MARK: - Week calendar bar
//
// A paging Mon–Sun week strip pinned to the top of the itinerary sheet. Each
// page is one calendar week; tapping a day selects it and filters the itinerary
// (and the map) to that day. The selected day is a filled red circle; weekends
// and out-of-trip days are dimmed; today (when not selected) is red.
//
// Native paging comes from a page-style TabView — the only custom part is the
// day cell, which is just two Texts in a VStack.

struct WeekCalendarBar: View {
    let days: [TripDay]
    @Binding var selectedDay: String?

    @State private var weekIndex = 0

    /// Fixed Monday-first column headers — every page is a Mon–Sun week.
    private let weekdayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2   // Monday
        return c
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $weekIndex) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                    HStack(spacing: 0) {
                        ForEach(Array(week.enumerated()), id: \.element.id) { column, day in
                            cell(day, column: column)
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 76)
        }
        .padding(.top, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) { Divider() }
        .onAppear { ensureSelection() }
        .onChange(of: days.map(\.date)) { ensureSelection() }
        .onChange(of: selectedDay) { syncWeekIndex() }
    }

    // MARK: Day cell

    private func cell(_ day: DayInfo, column: Int) -> some View {
        let selected = day.key == selectedDay
        let weekend = column >= 5
        return VStack(spacing: 6) {
            Text(weekdayLetters[column])
                .font(.subheadline)
                .foregroundStyle(letterColor(isTripDay: day.isTripDay, weekend: weekend))
            ZStack {
                if selected {
                    Circle().fill(.red).frame(width: 40, height: 40)
                }
                Text("\(day.number)")
                    .font(.title2)
                    .fontWeight(selected ? .semibold : .regular)
                    .foregroundStyle(numberColor(day, weekend: weekend, selected: selected))
            }
            .frame(height: 40)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard day.isTripDay else { return }
            withAnimation(.snappy) { selectedDay = day.key }
        }
        .disabled(!day.isTripDay)
        .accessibilityLabel(Text(day.key))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func letterColor(isTripDay: Bool, weekend: Bool) -> Color {
        if !isTripDay { return Color(.quaternaryLabel) }
        return weekend ? Color(.tertiaryLabel) : Color(.secondaryLabel)
    }

    private func numberColor(_ day: DayInfo, weekend: Bool, selected: Bool) -> Color {
        if selected { return .white }
        if !day.isTripDay { return Color(.quaternaryLabel) }
        if day.isToday { return .red }
        return weekend ? Color(.tertiaryLabel) : Color(.label)
    }

    // MARK: Weeks model

    private struct DayInfo: Identifiable {
        let key: String       // "yyyy-MM-dd"
        let number: Int
        let isTripDay: Bool
        let isToday: Bool
        var id: String { key }
    }

    /// The trip's days grouped into Mon–Sun calendar weeks. Weeks with no trip
    /// day are never produced; non-trip days inside a covered week are dimmed.
    private var weeks: [[DayInfo]] {
        let tripDates = days.compactMap { DateText.day($0.date) }
        guard !tripDates.isEmpty else { return [] }
        let tripKeys = Set(days.map(\.date))
        let today = DateText.dayKey(Date())

        var starts: [Date] = []
        var seen = Set<Date>()
        for date in tripDates {
            guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { continue }
            if seen.insert(start).inserted { starts.append(start) }
        }
        starts.sort()

        return starts.map { start in
            (0..<7).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
                let key = DateText.dayKey(date)
                return DayInfo(key: key,
                               number: calendar.component(.day, from: date),
                               isTripDay: tripKeys.contains(key),
                               isToday: key == today)
            }
        }
    }

    // MARK: Selection

    /// Make sure a valid day is selected, defaulting to today if it's in the
    /// trip, otherwise the first trip day.
    private func ensureSelection() {
        let keys = days.map(\.date)
        guard !keys.isEmpty else { return }
        if let selectedDay, keys.contains(selectedDay) { syncWeekIndex(); return }
        let today = DateText.dayKey(Date())
        selectedDay = keys.contains(today) ? today : keys.first
        syncWeekIndex()
    }

    /// Page to the week that holds the selected day.
    private func syncWeekIndex() {
        guard let selectedDay,
              let index = weeks.firstIndex(where: { week in week.contains { $0.key == selectedDay } })
        else { return }
        if index != weekIndex { weekIndex = index }
    }
}

#Preview {
    @Previewable @State var selected: String? = "2026-06-30"
    return VStack {
        WeekCalendarBar(days: PreviewData.days, selectedDay: $selected)
        Spacer()
    }
}
