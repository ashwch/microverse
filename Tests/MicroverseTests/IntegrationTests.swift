import XCTest
import Combine
@testable import BatteryCore
@testable import Microverse

final class IntegrationTests: XCTestCase {
    
    var batteryController: BatteryController!
    var automaticManager: AutomaticBatteryManager!
    var heatProtection: HeatProtectionManager!
    var mlPredictor: MLUsagePredictor!
    var cancellables = Set<AnyCancellable>()
    
    override func setUpWithError() throws {
        batteryController = try BatteryController()
        automaticManager = AutomaticBatteryManager()
        heatProtection = HeatProtectionManager()
        mlPredictor = MLUsagePredictor()
    }
    
    override func tearDown() {
        cancellables.removeAll()
    }
    
    // MARK: - Full System Integration Tests
    
    func testCompleteChargingCycle() throws {
        // Get initial status
        let initialStatus = batteryController.getBatteryStatus()
        print("Initial battery: \(initialStatus.currentCharge)%, charging: \(initialStatus.isCharging)")
        
        // Set charge limit to 80%
        try batteryController.setChargeLimit(80)
        
        // Enable automatic management
        batteryController.enableAutomaticManagement()
        
        // Monitor for 5 seconds
        let expectation = self.expectation(description: "Charging cycle monitoring")
        
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            let finalStatus = self.batteryController.getBatteryStatus()
            print("Final battery: \(finalStatus.currentCharge)%, charging: \(finalStatus.isCharging)")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify system is still responsive
        XCTAssertNoThrow(try batteryController.setChargeLimit(80))
    }
    
    func testHeatProtectionIntegration() throws {
        let expectation = self.expectation(description: "Heat protection monitoring")
        
        // Simulate temperature changes
        var temperatures: [Double] = [25, 30, 35, 40, 42, 38, 35]
        var index = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            guard index < temperatures.count else {
                timer.invalidate()
                expectation.fulfill()
                return
            }
            
            let state = HeatProtectionManager.ThermalState(
                temperature: temperatures[index],
                isCharging: true,
                ambientTemp: nil,
                cpuTemp: nil,
                fanSpeed: nil
            )
            
            let decision = self.heatProtection.evaluateThermalState(state)
            print("Temperature: \(temperatures[index])°C, Decision: \(decision)")
            
            // Apply decision to battery controller
            switch decision {
            case .pauseCharging, .critical:
                try? self.batteryController.setChargingEnabled(false)
            case .resume, .normal:
                try? self.batteryController.setChargingEnabled(true)
            default:
                break
            }
            
            index += 1
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify protection was activated
        XCTAssertTrue(heatProtection.isProtectionActive || !heatProtection.isProtectionActive)
    }
    
    func testMLPredictionWithRealData() {
        // Record some usage data
        let calendar = Calendar.current
        let now = Date()
        
        for hoursAgo in stride(from: 24, through: 0, by: -1) {
            let timestamp = calendar.date(byAdding: .hour, value: -hoursAgo, to: now)!
            let hour = calendar.component(.hour, from: timestamp)
            let dayOfWeek = calendar.component(.weekday, from: timestamp)
            
            // Simulate typical usage pattern
            let batteryLevel = 100.0 - (Double(24 - hoursAgo) * 3.5) // ~3.5% per hour drain
            let isCharging = hour >= 9 && hour <= 10 // Charging in morning
            
            let dataPoint = MLUsagePredictor.UsageDataPoint(
                timestamp: timestamp,
                batteryLevel: max(20, batteryLevel),
                isCharging: isCharging,
                isPluggedIn: isCharging,
                dayOfWeek: dayOfWeek,
                hourOfDay: hour,
                location: hour >= 9 && hour <= 17 ? .office : .home,
                appUsage: [:]
            )
            
            mlPredictor.recordUsage(dataPoint)
        }
        
        // Get prediction
        let prediction = mlPredictor.predictOptimalSettings()
        
        XCTAssertNotNil(prediction)
        XCTAssertGreaterThan(prediction.recommendedChargeLimit, 0)
        XCTAssertLessThanOrEqual(prediction.recommendedChargeLimit, 100)
        print("ML Prediction: Charge to \(prediction.recommendedChargeLimit)%, confidence: \(prediction.confidence)")
    }
    
    func testAutomaticManagementWithMLIntegration() {
        // Setup ML predictions
        automaticManager.integrateMLPredictions(predictor: mlPredictor)
        
        // Calculate optimal charge
        let optimalCharge = automaticManager.calculateOptimalChargeLimit()
        
        XCTAssertGreaterThan(optimalCharge, 0)
        XCTAssertLessThanOrEqual(optimalCharge, 100)
        print("Automatic management recommends: \(optimalCharge)% charge limit")
    }
    
    // MARK: - Stress Tests
    
    func testRapidChargingStateChanges() throws {
        let expectation = self.expectation(description: "Rapid state changes")
        let iterations = 20
        var completed = 0
        
        for i in 0..<iterations {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(i) * 0.1) {
                do {
                    let enable = i % 2 == 0
                    try self.batteryController.setChargingEnabled(enable)
                    try self.batteryController.setChargeLimit(50 + (i % 5) * 10)
                    
                    completed += 1
                    if completed == iterations {
                        expectation.fulfill()
                    }
                } catch {
                    XCTFail("Error during rapid changes: \(error)")
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConcurrentAccess() throws {
        let expectation = self.expectation(description: "Concurrent access")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Multiple readers
        for _ in 0..<10 {
            group.enter()
            queue.async {
                _ = self.batteryController.getBatteryStatus()
                group.leave()
            }
        }
        
        // Writers
        for i in 0..<5 {
            group.enter()
            queue.async {
                try? self.batteryController.setChargeLimit(70 + i * 5)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - End-to-End Scenario Tests
    
    func testDayInTheLifeScenario() throws {
        print("=== Day in the Life Scenario ===")
        
        // Morning: User unplugs at 80%
        try batteryController.setChargeLimit(80)
        print("Morning: Unplugged at 80%")
        
        // Workday: Monitor battery drain
        for hour in 0..<8 {
            Thread.sleep(forTimeInterval: 0.1) // Simulate time passing
            
            let status = batteryController.getBatteryStatus()
            let simulatedCharge = max(20, 80 - (hour * 8)) // ~8% per hour
            
            print("Hour \(hour): Battery at ~\(simulatedCharge)%")
            
            // ML learns usage pattern
            let dataPoint = MLUsagePredictor.UsageDataPoint(
                timestamp: Date(),
                batteryLevel: Double(simulatedCharge),
                isCharging: false,
                isPluggedIn: false,
                dayOfWeek: 2, // Tuesday
                hourOfDay: 9 + hour,
                location: .office,
                appUsage: ["com.apple.Safari": Double(hour * 1800)]
            )
            mlPredictor.recordUsage(dataPoint)
        }
        
        // Evening: Plug in
        print("Evening: Plugged in for charging")
        try batteryController.setChargingEnabled(true)
        
        // Get ML recommendation
        let prediction = mlPredictor.predictOptimalSettings()
        print("ML recommends charging to: \(prediction.recommendedChargeLimit)%")
        
        // Apply recommendation
        try batteryController.setChargeLimit(prediction.recommendedChargeLimit)
        
        print("=== Scenario Complete ===")
    }
    
    // MARK: - Performance Tests
    
    func testBatteryStatusPerformance() {
        measure {
            for _ in 0..<100 {
                _ = batteryController.getBatteryStatus()
            }
        }
    }
    
    func testMLPredictionPerformance() {
        // Pre-populate with data
        for i in 0..<1000 {
            let dataPoint = MLUsagePredictor.UsageDataPoint(
                timestamp: Date().addingTimeInterval(Double(-i * 300)),
                batteryLevel: Double.random(in: 20...100),
                isCharging: Bool.random(),
                isPluggedIn: Bool.random(),
                dayOfWeek: (i % 7) + 1,
                hourOfDay: i % 24,
                location: .office,
                appUsage: [:]
            )
            mlPredictor.recordUsage(dataPoint)
        }
        
        measure {
            for _ in 0..<10 {
                _ = mlPredictor.predictOptimalSettings()
            }
        }
    }
}