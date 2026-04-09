import SwiftUI

/// Optional on-screen debug HUD showing live events.
/// Useful for in-headset debugging on visionOS and mobile devices.
struct DebugHUD: View {
    @ObservedObject var debugBus: DebugEventBus
    @State private var selectedCategory: DebugCategory? = nil
    @State private var selectedSeverity: DebugSeverity? = nil
    @State private var searchText = ""
    @State private var isExpanded = false
    @State private var autoScroll = true
    
    var filteredEvents: [DebugEvent] {
        debugBus.events.filter { event in
            let categoryMatch = selectedCategory == nil || event.category == selectedCategory
            let severityMatch = selectedSeverity == nil || event.severity == selectedSeverity
            let searchMatch = searchText.isEmpty || 
                event.message.localizedCaseInsensitiveContains(searchText) ||
                event.category.rawValue.localizedCaseInsensitiveContains(searchText)
            
            return categoryMatch && severityMatch && searchMatch
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption)
                }
                
                Text("Debug Console")
                    .font(.caption.weight(.semibold))
                
                Spacer()
                
                Button(action: { debugBus.clearEvents() }) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                
                Button(action: { autoScroll.toggle() }) {
                    Image(systemName: autoScroll ? "arrow.down" : "arrow.up")
                        .font(.caption)
                        .foregroundStyle(autoScroll ? .green : .gray)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.8))
            .foregroundStyle(.white)
            
            if isExpanded {
                VStack(spacing: 0) {
                    // Filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Menu {
                                Button("All") { selectedCategory = nil }
                                Divider()
                                ForEach(DebugCategory.allCases, id: \.rawValue) { cat in
                                    Button(cat.displayName) { selectedCategory = cat }
                                }
                            } label: {
                                Text("Category: \(selectedCategory?.displayName ?? "All")")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.3))
                                    .cornerRadius(4)
                            }
                            
                            Menu {
                                Button("All") { selectedSeverity = nil }
                                Divider()
                                ForEach(DebugSeverity.allCases, id: \.rawValue) { sev in
                                    Button(sev.displayName) { selectedSeverity = sev }
                                }
                            } label: {
                                Text("Severity: \(selectedSeverity?.displayName ?? "All")")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.3))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            Text("Events: \(filteredEvents.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                    }
                    .background(Color.black.opacity(0.6))
                    
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                        TextField("Search...", text: $searchText)
                            .font(.caption)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
                    .padding(8)
                    
                    // Event list
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(filteredEvents, id: \.id) { event in
                                    eventRow(event)
                                        .id(event.id)
                                }
                            }
                            .padding(8)
                        }
                        .onChange(of: filteredEvents.count) { _, _ in
                            if autoScroll, let lastEvent = filteredEvents.last {
                                withAnimation {
                                    proxy.scrollTo(lastEvent.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    .background(Color.black.opacity(0.9))
                }
                .foregroundStyle(.white)
            }
        }
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
        .padding(8)
    }
    
    @ViewBuilder
    private func eventRow(_ event: DebugEvent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(event.severity.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(hex: event.severity.hexColor))
                    .frame(width: 50, alignment: .leading)
                
                Text(event.category.displayName)
                    .font(.caption2)
                    .foregroundStyle(.cyan)
                    .frame(width: 80, alignment: .leading)
                
                Text(String(format: "%.2f", event.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Text(event.message)
                .font(.caption2)
                .lineLimit(2)
                .foregroundStyle(.white)
            
            if !event.context.isEmpty {
                HStack(spacing: 4) {
                    ForEach(event.context.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        Text("\(key): \(value)")
                            .font(.system(size: 8, weight: .regular, design: .monospaced))
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
        .padding(6)
        .background(Color.black.opacity(0.5))
        .cornerRadius(4)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var hexNumber: UInt64 = 0
        
        if scanner.scanHexInt64(&hexNumber) {
            let r = Double((hexNumber & 0xFF0000) >> 16) / 255
            let g = Double((hexNumber & 0x00FF00) >> 8) / 255
            let b = Double(hexNumber & 0x0000FF) / 255
            
            self.init(red: r, green: g, blue: b)
        } else {
            self.init(white: 0.5)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            
            DebugHUD(debugBus: DebugEventBus.shared)
        }
    }
}
