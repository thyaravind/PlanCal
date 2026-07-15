import SwiftData
import SwiftUI

struct EventEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppleCalendarService.self) private var calendarService

    private let event: PlannerEvent?
    @State private var title: String
    @State private var details: String
    @State private var location: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var recurrence: EventRecurrence
    @State private var syncsWithAppleCalendar: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(event: PlannerEvent? = nil, initialDate: Date = .now) {
        self.event = event
        let defaultEnd = Calendar.autoupdatingCurrent.date(byAdding: .hour, value: 1, to: initialDate) ?? initialDate
        _title = State(initialValue: event?.title ?? "")
        _details = State(initialValue: event?.details ?? "")
        _location = State(initialValue: event?.location ?? "")
        _startDate = State(initialValue: event?.startDate ?? initialDate)
        _endDate = State(initialValue: event?.endDate ?? defaultEnd)
        _isAllDay = State(initialValue: event?.isAllDay ?? true)
        _recurrence = State(initialValue: event?.recurrence ?? .none)
        _syncsWithAppleCalendar = State(initialValue: event?.syncsWithAppleCalendar ?? true)
    }

    var body: some View {
        @Bindable var calendarService = calendarService

        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Event title", text: $title)
                        .font(.title3.weight(.semibold))
                    TextField("Location (optional)", text: $location)
                    TextEditor(text: $details)
                        .frame(minHeight: 90)
                        .overlay(alignment: .topLeading) {
                            if details.isEmpty {
                                Text("Notes (optional)")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("When") {
                    Toggle("All-day", isOn: $isAllDay)
                    DatePicker("Starts", selection: $startDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                    DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                    Picker("Repeats", selection: $recurrence) {
                        ForEach(EventRecurrence.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section("Apple Calendar") {
                    Toggle(isOn: $syncsWithAppleCalendar) {
                        PlancalIconLabel(title: "Keep in Apple Calendar", icon: .calendarAccess)
                    }
                    if syncsWithAppleCalendar {
                        LabeledContent("Access", value: calendarService.authorizationTitle)
                        if !calendarService.writableCalendars.isEmpty {
                            Picker("Calendar", selection: $calendarService.selectedCalendarIdentifier) {
                                ForEach(calendarService.writableCalendars) { calendar in
                                    Text("\(calendar.title) · \(calendar.sourceTitle)")
                                        .tag(Optional(calendar.id))
                                }
                            }
                        }
                        Text("Plancal events remain editable here and in Apple Calendar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if event?.appleCalendarIdentifier != nil {
                        Text("Saving will remove the linked event from Apple Calendar while keeping it in Plancal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(event == nil ? "New event" : "Edit event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .platformEditorFrame(minWidth: 400, idealWidth: 560, minHeight: 650)
        .onChange(of: startDate) { _, newStart in
            if endDate < newStart { endDate = newStart }
        }
        .alert("Couldn’t save the calendar event", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        if syncsWithAppleCalendar && !calendarService.hasFullAccess {
            guard await calendarService.requestFullAccess() else {
                errorMessage = calendarService.lastError ?? "Full Apple Calendar access was not granted."
                return
            }
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = event ?? PlannerEvent(
            title: cleanTitle,
            details: details,
            location: location,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            recurrence: recurrence,
            syncsWithAppleCalendar: syncsWithAppleCalendar
        )

        target.title = cleanTitle
        target.details = details
        target.location = location
        target.startDate = startDate
        target.endDate = max(startDate, endDate)
        target.isAllDay = isAllDay
        target.recurrence = recurrence
        target.syncsWithAppleCalendar = syncsWithAppleCalendar
        target.updatedAt = .now

        do {
            if syncsWithAppleCalendar {
                try calendarService.save(target)
            } else if target.appleCalendarIdentifier != nil {
                try calendarService.removeFromAppleCalendar(target)
            }
            if event == nil { modelContext.insert(target) }
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
