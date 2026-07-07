// PhantomKnob/PhantomKnobTests/StatusBarControllerTests.swift
import XCTest
@testable import PhantomKnob

final class StatusBarControllerTests: XCTestCase {
    
    func testStatusBarDoubleCickTogglesPanel() {
        let controller = StatusBarController()
        let panelController = KnobPanelWindowController.shared
        
        // Ensure window is hidden initially
        if panelController.isVisible {
            panelController.hide()
        }
        XCTAssertFalse(panelController.isVisible)
        
        let doubleClickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 2,
            pressure: 0
        )
        
        let expectation = XCTestExpectation(description: "Toggle on double click")
        DispatchQueue.main.async {
            controller.handleStatusItemClick(event: doubleClickEvent)
            XCTAssertTrue(panelController.isVisible)
            
            // Clean up
            panelController.hide()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testStatusBarSingleClickDoesNotToggleImmediately() {
        let controller = StatusBarController()
        let panelController = KnobPanelWindowController.shared
        
        // Ensure window is hidden initially
        if panelController.isVisible {
            panelController.hide()
        }
        XCTAssertFalse(panelController.isVisible)
        
        let singleClickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        )
        
        let expectation = XCTestExpectation(description: "No toggle on single click")
        DispatchQueue.main.async {
            controller.handleStatusItemClick(event: singleClickEvent)
            // It should not toggle immediately
            XCTAssertFalse(panelController.isVisible)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testOpenSettingsElevatesActivationPolicy() {
        let controller = StatusBarController()
        
        // Setup initial policy
        NSApp.setActivationPolicy(.accessory)
        XCTAssertEqual(NSApp.activationPolicy(), .accessory)
        
        // Trigger opening of settings
        controller.openSettings()
        
        // Verify policy changed to .regular and settings is visible
        XCTAssertEqual(NSApp.activationPolicy(), .regular)
        XCTAssertTrue(SettingsWindowController.shared.isVisible)
        
        // Clean up: hide the settings window which should restore activation policy to .accessory
        SettingsWindowController.shared.hide()
        
        XCTAssertEqual(NSApp.activationPolicy(), .accessory)
        XCTAssertFalse(SettingsWindowController.shared.isVisible)
    }
    
    func testStatusBarIconColorAndTemplate() {
        let controller = StatusBarController()
        let dummyTarget = DetectedTarget(bundleID: "com.test.app", axRole: "AXSlider", identifier: nil, displayName: "Test", element: nil, parentChain: [])
        
        // Test inactive state
        controller.updateState(.inactive)
        if let button = controller.statusItem?.button {
            XCTAssertTrue(button.image?.isTemplate ?? false)
            XCTAssertEqual(button.contentTintColor, .systemGray)
        }
        
        // Test activated state
        controller.updateState(.activated)
        if let button = controller.statusItem?.button {
            XCTAssertTrue(button.image?.isTemplate ?? false)
            XCTAssertEqual(button.contentTintColor, .systemCyan)
        }
        
        // Test knobing state
        controller.updateState(.knobing(target: dummyTarget))
        if let button = controller.statusItem?.button {
            XCTAssertTrue(button.image?.isTemplate ?? false)
            XCTAssertEqual(button.contentTintColor, .systemGreen)
        }
    }
}
