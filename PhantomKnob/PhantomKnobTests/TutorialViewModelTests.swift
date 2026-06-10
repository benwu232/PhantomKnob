import XCTest
@testable import PhantomKnob

class TutorialViewModelTests: XCTestCase {
    func testTutorialFlow() {
        let vm = TutorialViewModel()
        XCTAssertEqual(vm.currentStep, 1)
        
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 2)
        XCTAssertFalse(vm.isStep2Unlocked)
        
        // Rotate 200 degrees
        vm.registerRotation(200.0)
        XCTAssertFalse(vm.isStep2Unlocked)
        
        // Rotate another 200 degrees (total 400, > 360)
        vm.registerRotation(200.0)
        XCTAssertTrue(vm.isStep2Unlocked)
        
        // Advance to step 3
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 3)
    }
}
