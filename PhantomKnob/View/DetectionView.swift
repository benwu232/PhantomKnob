import SwiftUI

struct DetectionView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var viewModel = DetectionViewModel()
    
    var body: some View {
        ZStack {
            TouchpadViewWrapper(delegate: TouchDelegate(viewModel: viewModel))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack(spacing: 30) {
                Text("正在检测...")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text(viewModel.statusMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index < viewModel.progress ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }
                
                Text("剩余时间: \(viewModel.remainingTime)秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("取消") {
                    viewModel.cancelDetection()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
        }
        .onAppear {
            viewModel.startDetection()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DetectionComplete"))) { notification in
            if let result = notification.userInfo?["result"] as? DetectionResult {
                appViewModel.completeDetection(result)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DetectionCancelled"))) { _ in
            appViewModel.goToWelcome()
        }
    }
}

class TouchDelegate: TouchpadEventDelegate {
    private let viewModel: DetectionViewModel
    
    init(viewModel: DetectionViewModel) {
        self.viewModel = viewModel
    }
    
    func onTouchesBegan(_ touches: Set<NSTouch>) {
        viewModel.handleTouchesBegan(touches)
    }
    
    func onTouchesMoved(_ touches: Set<NSTouch>) {
        viewModel.handleTouchesMoved(touches)
    }
    
    func onTouchesEnded(_ touches: Set<NSTouch>) {
        viewModel.handleTouchesEnded(touches)
    }
}