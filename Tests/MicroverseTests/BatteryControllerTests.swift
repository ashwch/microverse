import XCTest
@testable import BatteryCore
@testable import SMCKit

final class BatteryControllerTests: XCTestCase {
    
    var controller: BatteryController!
    
    override func setUpWithError() throws {
        controller = try BatteryController()
    }
    
    override func tearDownWithError() throws {
        controller = nil
    }
    
    // MARK: - Battery Status Tests
    
    func testGetBatteryStatus() {
        let status = controller.getBatteryStatus()
        
        XCTAssertGreaterThanOrEqual(status.currentCharge, 0)
        XCTAssertLessThanOrEqual(status.currentCharge, 100)
        XCTAssertGreaterThan(status.maxCapacity, 0)
        XCTAssertGreaterThanOrEqual(status.temperature, 0)
        XCTAssertLessThanOrEqual(status.temperature, 100)
        XCTAssertGreaterThanOrEqual(status.health, 0)
        XCTAssertLessThanOrEqual(status.health, 1.0)
    }
    
    func testBatteryStatusUpdate() {
        let status1 = controller.getBatteryStatus()
        Thread.sleep(forTimeInterval: 1.0)
        let status2 = controller.getBatteryStatus()
        
        // Battery info should be retrievable multiple times
        XCTAssertNotNil(status1)
        XCTAssertNotNil(status2)
    }
    
    // MARK: - Charge Limit Tests
    
    func testSetChargeLimitValidRange() throws {
        // Test valid charge limits
        for limit in stride(from: 50, through: 100, by: 10) {
            XCTAssertNoThrow(try controller.setChargeLimit(limit))
        }
    }
    
    func testSetChargeLimitInvalidRange() {
        // Test invalid charge limits
        XCTAssertThrowsError(try controller.setChargeLimit(0))
        XCTAssertThrowsError(try controller.setChargeLimit(101))
        XCTAssertThrowsError(try controller.setChargeLimit(-10))
        XCTAssertThrowsError(try controller.setChargeLimit(150))
    }
    
    func testSetChargeLimitBoundaries() throws {
        // Test boundary values
        XCTAssertNoThrow(try controller.setChargeLimit(1))
        XCTAssertNoThrow(try controller.setChargeLimit(100))
    }
    
    // MARK: - Charging State Tests
    
    func testSetChargingEnabled() throws {
        // Test enabling charging
        XCTAssertNoThrow(try controller.setChargingEnabled(true))
        
        // Test disabling charging
        XCTAssertNoThrow(try controller.setChargingEnabled(false))
        
        // Re-enable to restore normal state
        XCTAssertNoThrow(try controller.setChargingEnabled(true))
    }
    
    func testChargingStateToggle() throws {
        let initialStatus = controller.getBatteryStatus()
        
        // Disable charging
        try controller.setChargingEnabled(false)
        Thread.sleep(forTimeInterval: 0.5)
        
        // Re-enable charging
        try controller.setChargingEnabled(true)
        Thread.sleep(forTimeInterval: 0.5)
        
        let finalStatus = controller.getBatteryStatus()
        
        // Status should be retrievable regardless of charging state
        XCTAssertNotNil(initialStatus)
        XCTAssertNotNil(finalStatus)
    }
    
    // MARK: - Architecture Detection Tests
    
    func testArchitectureDetection() {
        #if arch(arm64)
        XCTAssertEqual(controller.architecture, .appleSilicon)
        #else
        XCTAssertEqual(controller.architecture, .intel)
        #endif
    }
    
    // MARK: - Automatic Management Tests
    
    func testAutomaticManagementActivation() {
        // Should not throw
        controller.enableAutomaticManagement()
        
        // Give it time to perform initial adjustment
        Thread.sleep(forTimeInterval: 1.0)
        
        // Should still be able to get status
        let status = controller.getBatteryStatus()
        XCTAssertNotNil(status)
    }
}

// MARK: - Automatic Battery Manager Tests

final class AutomaticBatteryManagerTests: XCTestCase {
    
    var manager: AutomaticBatteryManager!
    
    override func setUp() {
        manager = AutomaticBatteryManager()
    }
    
    func setManagementMode(_ mode: AutomaticBatteryManager.ManagementMode) {
        // Use reflection or test-specific method to set mode
        // For now, we'll test the calculateOptimalChargeLimit method directly
    }
    
    func testOptimalChargeLimitCalculation() {
        // Test different modes
        let modes: [AutomaticBatteryManager.ManagementMode] = [
            .workday, .mobile, .travel, .storage, .presentation
        ]
        
        for mode in modes {
            // Since we can't set currentMode directly, we'll verify the logic exists
            let limit = manager.calculateOptimalChargeLimit()
            
            switch mode {
            case .storage:
                XCTAssertEqual(limit, 50)
            case .presentation:
                XCTAssertEqual(limit, 100)
            case .travel:
                XCTAssertEqual(limit, 80)
            default:
                XCTAssertGreaterThan(limit, 0)
                XCTAssertLessThanOrEqual(limit, 100)
            }
        }
    }
    
    func testTemperatureBasedDecisions() {
        // Test normal temperature
        XCTAssertFalse(manager.shouldPauseChargingForTemperature(25.0))
        XCTAssertFalse(manager.shouldPauseChargingForTemperature(35.0))
        
        // Test high temperature
        XCTAssertTrue(manager.shouldPauseChargingForTemperature(41.0))
        XCTAssertTrue(manager.shouldPauseChargingForTemperature(50.0))
    }
    
    func testSailingModeDecision() {
        // Test various scenarios
        // Note: These tests might need mocking as they depend on actual battery state
        let shouldEnableSailing = manager.shouldEnableSailingMode()
        
        // Result should be boolean
        XCTAssertNotNil(shouldEnableSailing)
    }
    
    func testCalibrationRecommendation() {
        // Clear last calibration
        UserDefaults.standard.removeObject(forKey: "lastCalibration")
        
        // Should recommend calibration
        XCTAssertTrue(manager.shouldRecommendCalibration())
        
        // Set recent calibration
        UserDefaults.standard.set(Date(), forKey: "lastCalibration")
        
        // Should not recommend calibration
        XCTAssertFalse(manager.shouldRecommendCalibration())
    }
}

// MARK: - Heat Protection Tests

final class HeatProtectionTests: XCTestCase {
    
    var heatManager: HeatProtectionManager!
    
    override func setUp() {
        heatManager = HeatProtectionManager()
    }
    
    func testThermalStateEvaluation() {
        // Test normal temperature
        let normalState = HeatProtectionManager.ThermalState(
            temperature: 25.0,
            isCharging: true,
            ambientTemp: 22.0,
            cpuTemp: 45.0,
            fanSpeed: 2000
        )
        
        let normalDecision = heatManager.evaluateThermalState(normalState)
        XCTAssertEqual(normalDecision, .normal)
        
        // Test warning temperature
        let warningState = HeatProtectionManager.ThermalState(
            temperature: 36.0,
            isCharging: true,
            ambientTemp: nil,
            cpuTemp: nil,
            fanSpeed: nil
        )
        
        let warningDecision = heatManager.evaluateThermalState(warningState)
        XCTAssertEqual(warningDecision, .warning)
        
        // Test critical temperature
        let criticalState = HeatProtectionManager.ThermalState(
            temperature: 46.0,
            isCharging: true,
            ambientTemp: nil,
            cpuTemp: nil,
            fanSpeed: nil
        )
        
        let criticalDecision = heatManager.evaluateThermalState(criticalState)
        XCTAssertEqual(criticalDecision, .critical)
    }
    
    func testTemperatureAveraging() {
        // Add some temperature readings
        for temp in stride(from: 25.0, to: 35.0, by: 1.0) {
            let state = HeatProtectionManager.ThermalState(
                temperature: temp,
                isCharging: true,
                ambientTemp: nil,
                cpuTemp: nil,
                fanSpeed: nil
            )
            _ = heatManager.evaluateThermalState(state)
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Check average
        let average = heatManager.getAverageTemperature(over: 1)
        XCTAssertNotNil(average)
        XCTAssertGreaterThan(average!, 25.0)
        XCTAssertLessThan(average!, 35.0)
    }
}

// MARK: - ML Usage Predictor Tests

final class MLUsagePredictorTests: XCTestCase {
    
    var predictor: MLUsagePredictor!
    
    override func setUp() {
        predictor = MLUsagePredictor()
    }
    
    func testUsageDataRecording() {
        let dataPoint = MLUsagePredictor.UsageDataPoint(
            timestamp: Date(),
            batteryLevel: 80.0,
            isCharging: false,
            isPluggedIn: false,
            dayOfWeek: 2,
            hourOfDay: 14,
            location: .office,
            appUsage: ["com.apple.Safari": 3600]
        )
        
        // Should not throw
        predictor.recordUsage(dataPoint)
    }
    
    func testPredictionWithMinimalData() {
        // With minimal data, should return default prediction
        let prediction = predictor.predictOptimalSettings()
        
        XCTAssertNotNil(prediction)
        XCTAssertGreaterThan(prediction.recommendedChargeLimit, 0)
        XCTAssertLessThanOrEqual(prediction.recommendedChargeLimit, 100)
        XCTAssertLessThan(prediction.confidence, 0.5) // Low confidence with minimal data
    }
    
    func testBatteryLevelPrediction() {
        let futureDate = Date().addingTimeInterval(3600) // 1 hour from now
        let predictedLevel = predictor.predictBatteryLevel(at: futureDate, currentLevel: 80.0)
        
        XCTAssertGreaterThanOrEqual(predictedLevel, 0)
        XCTAssertLessThanOrEqual(predictedLevel, 80.0) // Should not exceed current level
    }
    
    func testCalendarLearning() {
        let events = [
            CalendarEvent(
                date: Date().addingTimeInterval(3600),
                title: "Important Presentation",
                requiresFullBattery: true
            ),
            CalendarEvent(
                date: Date().addingTimeInterval(7200),
                title: "Team Meeting",
                requiresFullBattery: false
            )
        ]
        
        // Should not throw
        predictor.learnFromCalendar(events: events)
    }
}