//
//  SearchView.swift
//  CalenderApp
//
//  Instant search across every event — titles, locations, notes, guests and
//  calendars — with the matched text highlighted. Results are debounced as you
//  type and open straight into detail.
//

import SwiftUI

struct SearchView: View {
    @Environment(CalendarStore.self) private var store

    @State private var query = ""
    @State private var results: [CalendarEvent] = []
    @State private var isSearching = false
    @State private var selected: CalendarEvent?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .background(CalColor.canvas)
        }
        .searchable(text: $query, prompt: "Titles, places, people…")
        .task(id: query) { await runSearch() }
        .sheet(item: $selected) { EventDetailView(event: $0) }
    }

    @ViewBuilder
    private var content: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            EmptyState(symbol: "magnifyingglass",
                       title: "Search your calendar",
                       message: "Find events by title, place, notes or who's coming.")
        } else if isSearching && results.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if results.isEmpty {
            EmptyState(symbol: "calendar.badge.exclamationmark",
                       title: "No matches",
                       message: "Nothing found for “\(query)”.")
        } else {
            resultsList
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: CalSpacing.m) {
                ForEach(results) { event in
                    SearchResultRow(event: event, query: query)
                        .onTapGesture { selected = event }
                }
            }
            .padding(CalSpacing.screen)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func runSearch() async {
        // Debounce: let typing settle before hitting the store.
        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }
        isSearching = true
        defer { isSearching = false }
        results = await store.search(query)
    }
}

/// A single search hit: highlighted title, when it is, and where.
private struct SearchResultRow: View {
    let event: CalendarEvent
    let query: String

    var body: some View {
        HStack(spacing: CalSpacing.m) {
            Capsule().fill(event.color).frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(SearchHighlight.attributed(event.title, query: query))
                    .font(CalFont.headline)
                    .foregroundStyle(CalColor.primaryText)
                    .lineLimit(1)

                Text(subtitle)
                    .font(CalFont.subheadline)
                    .foregroundStyle(CalColor.secondaryText)
                    .lineLimit(1)

                if let location = event.location, !location.isEmpty {
                    Label {
                        Text(SearchHighlight.attributed(location, query: query))
                    } icon: {
                        Image(systemName: "mappin.and.ellipse")
                    }
                    .font(CalFont.caption)
                    .foregroundStyle(CalColor.secondaryText)
                    .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(CalSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
        .contentShape(.rect(cornerRadius: CalRadius.card))
    }

    private var subtitle: String {
        let day = event.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        if event.isAllDay { return "\(day) · All-day" }
        return "\(day) · \(event.start.formatted(.dateTime.hour().minute()))"
    }
}

/// Builds an `AttributedString` with the first match of `query` accented.
enum SearchHighlight {
    static func attributed(_ text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let match = text.range(of: trimmed,
                                     options: [.caseInsensitive, .diacriticInsensitive]),
              let range = Range(match, in: attributed)
        else { return attributed }

        attributed[range].foregroundColor = CalColor.accent
        attributed[range].font = CalFont.headline.bold()
        return attributed
    }
}

/// A calm centred message for empty/no-result states.
private struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: CalSpacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(CalColor.tertiaryText)
            Text(title)
                .font(CalFont.headline)
                .foregroundStyle(CalColor.primaryText)
            Text(message)
                .font(CalFont.subheadline)
                .foregroundStyle(CalColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(CalSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
