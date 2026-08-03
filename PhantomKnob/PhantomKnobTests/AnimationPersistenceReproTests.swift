import XCTest
@testable import PhantomKnob

/// 回归测试：面板中修改进入/退出动画后，下次打开应恢复，而不是缺省值。
/// 根因：Knob.init(from:) 自定义解码器漏解码 skinID / skinOverrides，
/// 导致磁盘上的动画覆盖(animationMode/时长)每次 reload 后都丢失为 nil。
final class AnimationPersistenceReproTests: XCTestCase {
    private var originalMyKnobsURL: URL!
    private var tempMyKnobsURL: URL!

    override func setUp() {
        super.setUp()
        originalMyKnobsURL = KnobCustomizer.shared.myKnobsURL
        let tempDir = NSTemporaryDirectory()
        let filename = "my_knobs_test_\(UUID().uuidString).json"
        tempMyKnobsURL = URL(fileURLWithPath: tempDir).appendingPathComponent(filename)
        KnobCustomizer.shared.myKnobsURL = tempMyKnobsURL
        KnobCustomizer.shared.reload()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempMyKnobsURL)
        KnobCustomizer.shared.myKnobsURL = originalMyKnobsURL
        KnobCustomizer.shared.reload()
        super.tearDown()
    }

    /// 核心复现：编码后解码一次，skinOverrides 必须保留。
    func testKnobRoundTripKeepsSkinOverrides() throws {
        var knob = Knob(key: KnobKey(bundleID: "com.repro.anim", axRole: "AXSlider", identifier: nil, displayName: nil), themeColor: "#0A84FF", configType: .single)
        knob.skinOverrides = HUDSkinOverride(
            primaryColorHex: "#0A84FF",
            animationMode: .fade,
            entranceDuration: 0.3,
            exitDuration: 0.5
        )

        let data = try JSONEncoder().encode(knob)
        let decoded = try JSONDecoder().decode(Knob.self, from: data)

        XCTAssertEqual(decoded.skinOverrides?.animationMode, .fade, "解码后必须保留动画模式")
        XCTAssertEqual(decoded.skinOverrides?.entranceDuration, 0.3)
        XCTAssertEqual(decoded.skinOverrides?.exitDuration, 0.5)
    }

    /// 通过 saveKnob 持久化 -> reload -> knob(for:) 重新查回，动画仍应恢复。
    func testSaveThenReloadKeepsAnimationMode() {
        let key = KnobKey(bundleID: "com.repro.anim", axRole: "AXSlider", identifier: nil, displayName: nil)
        var knob = Knob(key: key, themeColor: "#0A84FF", configType: .single)
        knob.skinOverrides = HUDSkinOverride(
            primaryColorHex: "#0A84FF",
            animationMode: .fade,
            entranceDuration: 0.3,
            exitDuration: 0.5
        )
        KnobCustomizer.shared.saveKnob(knob)

        // 模拟面板重新打开：重新查回并读取覆盖
        let loaded = KnobCustomizer.shared.knob(for: key)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.skinOverrides?.animationMode, .fade, "重新加载后动画模式应恢复为 fade，而不是缺省值")
        XCTAssertEqual(loaded?.skinOverrides?.entranceDuration, 0.3)
        XCTAssertEqual(loaded?.skinOverrides?.exitDuration, 0.5)
    }
}