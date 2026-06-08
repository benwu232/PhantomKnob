import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("PhantomKnob")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("检测您的触控板是否支持 Knob 手势操作")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("开始检测") {
                appViewModel.startDetection()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}