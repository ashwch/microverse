import Foundation

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(max(0, places)))
        return (self * p).rounded() / p
    }
}

