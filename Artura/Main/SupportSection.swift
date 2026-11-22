import StoreKit
import SwiftUI

/// Profile rows added under the settings: library, widget, reminder time, language, and ways to support the app.
struct SupportSection: View {
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var user: UserStore
    @State private var showLibrary = false
    @State private var showWidget = AppDebug.string("profileSheet") == "widget"

    private var shareText: String {
        var text = L("I'm learning art with Artura: one masterpiece a day, and the story behind it.")
        if let url = AppLinks.appStore { text += " \(url.absoluteString)" }
        return text
    }

    /// The reminder time as a date, for the time picker.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                let minutes = user.profile.reminderMinutes
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                let minutes = (parts.hour ?? 8) * 60 + (parts.minute ?? 30)
                user.profile.reminderMinutes = minutes
                if user.profile.reminderOn { Reminder.scheduleDaily(atMinutes: minutes) }
            }
        )
    }

    private func mail(subject: String) -> URL? {
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(AppLinks.supportEmail)?subject=\(encoded)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Settings")).font(.aHeading).foregroundStyle(Palette.ink).padding(.top, 4)

            VStack(spacing: 0) {
                Button {
                    Haptics.tap()
                    showLibrary = true
                } label: {
                    row("books.vertical.fill", L("My library"), detail: L("Favorites, saved and history"))
                }
                .buttonStyle(.pressable)
                Divider()
                Button {
                    Haptics.tap()
                    showWidget = true
                } label: {
                    row("square.grid.2x2.fill", L("Widget"), detail: L("The artwork of the day on your Home Screen"))
                }
                .buttonStyle(.pressable)
                Divider()
                DatePicker(selection: reminderTime, displayedComponents: .hourAndMinute) {
                    rowLabel("bell.fill", L("Reminder time"),
                             detail: user.profile.reminderOn ? L("Every day") : L("Reminder is off"))
                }
                .tint(Palette.blue)
                .frame(minHeight: 56)
                Divider()
                Button {
                    Haptics.tap()
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    row("globe", L("Language"), detail: AppLanguage.locale.localizedString(forIdentifier: AppLanguage.code)?.capitalized(with: AppLanguage.locale) ?? "English", trailing: "arrow.up.right")
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))

            Text(L("Support Artura")).font(.aHeading).foregroundStyle(Palette.ink).padding(.top, 4)

            VStack(spacing: 0) {
                ShareLink(item: shareText) {
                    row("square.and.arrow.up", L("Share Artura"), detail: L("Learn art with your friends"))
                }
                .buttonStyle(.pressable)
                Divider()
                Button {
                    Haptics.tap()
                    requestReview()
                } label: {
                    row("star.fill", L("Rate the app"), detail: L("It really helps"))
                }
                .buttonStyle(.pressable)
                if !AppLinks.supportEmail.isEmpty {
                    Divider()
                    Button {
                        Haptics.tap()
                        if let url = mail(subject: L("A feature idea for Artura")) { openURL(url) }
                    } label: {
                        row("lightbulb.fill", L("Request a feature"), detail: L("Tell us what you'd like to see"))
                    }
                    .buttonStyle(.pressable)
                    Divider()
                    Button {
                        Haptics.tap()
                        if let url = mail(subject: L("Artura support")) { openURL(url) }
                    } label: {
                        row("envelope.fill", L("Support"), detail: AppLinks.supportEmail)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
        }
        .sheet(isPresented: $showWidget) {
            WidgetGuideView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLibrary) {
            LibraryView(tab: .favorites)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func rowLabel(_ symbol: String, _ title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.blue)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Palette.mist))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(.aCaption).foregroundStyle(Palette.muted)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
        }
    }

    private func row(_ symbol: String, _ title: String, detail: String, trailing: String = "chevron.right") -> some View {
        HStack(spacing: 12) {
            rowLabel(symbol, title, detail: detail)
            Spacer()
            Image(systemName: trailing)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.muted)
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}
