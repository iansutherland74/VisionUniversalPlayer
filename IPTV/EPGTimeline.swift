import Foundation

struct EPGTimeline {
    let channels: [IPTVChannel]
    let programs: [EPGProgram]

    func programs(for channel: IPTVChannel, at date: Date = Date()) -> [EPGProgram] {
        let channelIds = [channel.tvgID, channel.id, channel.tvgName].compactMap { $0 }
        return programs
            .filter { channelIds.contains($0.channelId) }
            .sorted { $0.startDate < $1.startDate }
    }

    func currentProgram(for channel: IPTVChannel, at date: Date = Date()) -> EPGProgram? {
        programs(for: channel, at: date).first(where: { $0.startDate <= date && $0.endDate > date })
    }

    func upcomingPrograms(for channel: IPTVChannel, count: Int = 6, from date: Date = Date()) -> [EPGProgram] {
        programs(for: channel, at: date)
            .filter { $0.startDate >= date }
            .prefix(count)
            .map { $0 }
    }

    func recentPrograms(for channel: IPTVChannel, count: Int = 8, before date: Date = Date()) -> [EPGProgram] {
        programs(for: channel, at: date)
            .filter { $0.endDate <= date }
            .suffix(count)
            .reversed()
            .map { $0 }
    }

    func gridWindow(start: Date = Date(), hours: Int = 4) -> DateInterval {
        let end = Calendar.current.date(byAdding: .hour, value: hours, to: start) ?? start.addingTimeInterval(Double(hours) * 3600)
        return DateInterval(start: start, end: end)
    }
}
