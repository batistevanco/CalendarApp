//
//  EventEditor.swift
//  CalenderApp
//
//  One editor for both creating and editing an event. Deliberately not a stock
//  `Form`: a large title, calm grouped sections, and a single explicit Save.
//  Edits live in an `EventDraft` so Cancel is instant and free.
//

import SwiftUI

enum EditorMode {
    case create(EventDraft)
    case edit(CalendarEvent)
}

struct EventEditor: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: EventDraft
    @State private var quickText = ""
    @State private var parsed: ParsedEvent?
    @State private var showingSaveOptions = false
    private let original: CalendarEvent?

    private var isNew: Bool { original == nil }

    init(mode: EditorMode) {
        switch mode {
        case .create(let draft):
            _draft = State(initialValue: draft)
            original = nil
        case .edit(let event):
            _draft = State(initialValue: EventDraft(from: event))
            original = event
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CalSpacing.xl) {
                    if isNew { quickAddSection }
                    titleField
                    timeSection
                    calendarSection
                    detailsSection
                }
                .padding(CalSpacing.screen)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(CalColor.canvas)
            .navigationTitle(original == nil ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: savePressed)
                        .fontWeight(.semibold)
                        .disabled(!draft.isValid)
                }
            }
            .task {
                await store.loadCalendarsIfNeeded()
                if draft.calendarID == nil {
                    draft.calendarID = store.defaultCalendarID
                }
            }
            .onChange(of: draft.start) { _, newStart in
                if !draft.isAllDay, draft.end < newStart {
                    draft.end = newStart.addingTimeInterval(3600)
                }
            }
            .confirmationDialog(
                "This is a repeating event.",
                isPresented: $showingSaveOptions,
                titleVisibility: .visible
            ) {
                Button("Save for this event only") {
                    save(scope: .thisEvent)
                }
                Button("Save for all future events") {
                    save(scope: .futureEvents)
                }
            }
        }
    }

    // MARK: Sections

    /// Natural-language quick add: type a phrase, watch it become an event.
    private var quickAddSection: some View {
        EditorSection {
            HStack(spacing: CalSpacing.s) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(CalColor.accent)
                TextField("Try “Tomorrow 2pm Dentist”", text: $quickText)
                    .font(CalFont.body)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
            }

            if let parsed, parsed.matchedDate {
                Divider()
                HStack(spacing: CalSpacing.s) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(CalColor.accent)
                    Text(previewText(parsed))
                        .font(CalFont.caption)
                        .foregroundStyle(CalColor.secondaryText)
                    Spacer(minLength: 0)
                }
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.25), value: parsed)
        .onChange(of: quickText) { _, text in applyQuickAdd(text) }
    }

    private func applyQuickAdd(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            parsed = nil
            return
        }
        let result = NaturalLanguageEventParser.parse(text)
        parsed = result
        draft.title = result.title
        draft.start = result.start
        draft.end = result.end
        draft.isAllDay = result.isAllDay
    }

    private func previewText(_ parsed: ParsedEvent) -> String {
        let day = parsed.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        if parsed.isAllDay { return "All-day · \(day)" }
        return "\(day) · \(parsed.start.formatted(.dateTime.hour().minute()))"
    }

    private var titleField: some View {
        TextField("Title", text: $draft.title)
            .font(CalFont.title)
            .textInputAutocapitalization(.sentences)
            .padding(CalSpacing.l)
            .surfaceCard()
    }

    private var timeSection: some View {
        EditorSection {
            Toggle(isOn: $draft.isAllDay.animation(.smooth)) {
                Label("All-day", systemImage: "sun.max")
                    .font(CalFont.body)
            }
            .tint(CalColor.accent)

            Divider()

            DatePicker(
                "Starts",
                selection: $draft.start,
                displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .font(CalFont.body)

            DatePicker(
                "Ends",
                selection: $draft.end,
                in: draft.start...,
                displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .font(CalFont.body)

            Divider()

            Picker(selection: $draft.recurrence) {
                ForEach(Recurrence.allCases) { option in
                    Text(option.label).tag(option)
                }
            } label: {
                Label("Repeat", systemImage: "repeat")
                    .font(CalFont.body)
            }
            .tint(CalColor.secondaryText)
        }
    }

    private var calendarSection: some View {
        EditorSection {
            Menu {
                ForEach(store.calendars) { calendar in
                    Button {
                        draft.calendarID = calendar.id
                    } label: {
                        Label(calendar.title, systemImage: draft.calendarID == calendar.id
                              ? "checkmark.circle.fill" : "circle.fill")
                    }
                }
            } label: {
                HStack(spacing: CalSpacing.s) {
                    Circle()
                        .fill(store.calendar(id: draft.calendarID)?.color ?? CalColor.accent)
                        .frame(width: 12, height: 12)
                    Text(store.calendar(id: draft.calendarID)?.title ?? "Calendar")
                        .font(CalFont.body)
                        .foregroundStyle(CalColor.primaryText)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(CalColor.secondaryText)
                }
            }
        }
    }

    private var detailsSection: some View {
        EditorSection {
            HStack(spacing: CalSpacing.s) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(CalColor.secondaryText)
                TextField("Location", text: $draft.location)
                    .font(CalFont.body)
            }

            Divider()

            HStack(alignment: .top, spacing: CalSpacing.s) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(CalColor.secondaryText)
                    .padding(.top, 2)
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .font(CalFont.body)
                    .lineLimit(1...6)
            }
        }
    }

    // MARK: Save

    private func savePressed() {
        if let original, original.isRecurring || original.recurrence.isRepeating {
            showingSaveOptions = true
        } else {
            save(scope: .futureEvents)
        }
    }

    private func save(scope: RecurrenceScope) {
        Haptics.commit()
        let draft = draft
        let original = original
        Task {
            if let original {
                await store.saveEdit(draft, original: original, scope: scope)
            } else {
                await store.create(draft)
            }
        }
        dismiss()
    }
}

/// A calm grouped container for editor rows.
private struct EditorSection<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: CalSpacing.m) {
            content
        }
        .padding(CalSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}
