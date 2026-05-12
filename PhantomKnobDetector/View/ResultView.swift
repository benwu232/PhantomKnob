import SwiftUI

struct ResultView: View {
    let result: DetectionResult
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: result.isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(result.isSupported ? .green : .red)
            
            Text(result.isSupported ? "✅ 支持" : "❌ 不支持")
                .font(.title)
                .fontWeight(.bold)
            
            Text(result.isSupported ?
                 "您的触控板支持 Knob 手势" :
                 "您的触控板不支持 Knob 手势")
                .font(.body)
                .foregroundColor(.secondary)
            
            if !result.isSupported {
                VStack(alignment: .leading, spacing: 10) {
                    Text("详情:")
                        .font(.headline)
                    
                    Text("• 设备: \(result.deviceModel)")
                        .font(.caption)
                    Text("• 系统: \(result.macOSVersion)")
                        .font(.caption)
                    if let error = result.details.errorMessage {
                        Text("• 原因: \(error)")
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                if !result.isSupported {
                    Button("导出报告") {
                        exportReport()
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("重新检测") {
                    appViewModel.startDetection()
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding()
    }
    
    private func exportReport() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(result),
           let json = String(data: data, encoding: .utf8) {
            let savePanel = NSSavePanel()
            savePanel.title = "导出检测报告"
            savePanel.nameFieldStringValue = "compatibility_report.json"
            savePanel.allowedContentTypes = [.json]
            
            if savePanel.runModal() == .OK {
                try? json.write(to: savePanel.url!, atomically: true, encoding: .utf8)
            }
        }
    }
}

#Preview {
    ResultView(result: DetectionResult(
        isSupported: false,
        timestamp: Date(),
        deviceModel: "MacBookPro18,3",
        macOSVersion: "macOS 14.0",
        details: DetectionResult.DetectionDetails(
            normalizedPositionAvailable: false,
            sampleCount: 0,
            errorMessage: "无法获取触摸绝对坐标"
        )
    ))
    .environmentObject(AppViewModel(cache: DetectionCache()))
}