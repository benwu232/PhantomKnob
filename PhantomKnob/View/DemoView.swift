import SwiftUI

struct DemoView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var viewModel = DemoViewModel()
    
    var body: some View {
        ZStack {
            TouchpadViewWrapper(delegate: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack(spacing: 30) {
                Text("✅ 支持检测通过")
                    .font(.headline)
                    .foregroundColor(.green)
                
                KnobCircleView(angle: viewModel.knobAngle)
                
                Text("\(viewModel.displayValue, specifier: "%.1f")")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("在触控板上双指旋转以调整数值")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("重新检测") {
                    appViewModel.reset()
                    appViewModel.startDetection()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding()
        }
    }
}

struct DemoView_Previews: PreviewProvider {
    static var previews: some View {
        DemoView()
            .environmentObject(AppViewModel(cache: DetectionCache()))
    }
}