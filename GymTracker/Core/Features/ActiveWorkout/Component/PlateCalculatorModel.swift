import Foundation

#if !GYMTRACKER_EXTENSION

struct DiagramPlate: Identifiable, Equatable {
    let weight: Float
    let occurrence: Int

    var id: String { "\(weight)-\(occurrence)" }
}

struct PlateEquipment {
    let barWeight: Float
    let plates: [Float]
    let unitLabel: String

    init(unitSystem: UnitSystem, selectedBarID: String, usesBarbell: Bool) {
        let selectedBar = BarKind.allCases.first { $0.id == selectedBarID } ?? .mensOlympic

        switch unitSystem {
        case .metric:
            barWeight = usesBarbell ? selectedBar.metricWeight : 0
            plates = Constants.Barbell.metricPlates
            unitLabel = "kg"
        case .imperial:
            barWeight = usesBarbell ? selectedBar.imperialWeight : 0
            plates = Constants.Barbell.imperialPlates
            unitLabel = "lbs"
        }
    }
}

enum BarKind: String, CaseIterable, Identifiable {
    case mensOlympic
    case womensOlympic
    case juniorTechnique
    case ezCurl
    case shortStudio
    case safetySquat
    case trapHex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mensOlympic: "Men's Olympic"
        case .womensOlympic: "Women's Olympic"
        case .juniorTechnique: "Junior / Technique"
        case .ezCurl: "EZ Curl"
        case .shortStudio: "Short / Studio"
        case .safetySquat: "Safety Squat"
        case .trapHex: "Trap / Hex"
        }
    }

    var metricWeight: Float {
        switch self {
        case .mensOlympic: 20
        case .womensOlympic: 15
        case .juniorTechnique, .ezCurl: 10
        case .shortStudio: 7
        case .safetySquat, .trapHex: 25
        }
    }

    var imperialWeight: Float {
        switch self {
        case .mensOlympic: 45
        case .womensOlympic: 33
        case .juniorTechnique, .ezCurl: 22
        case .shortStudio: 15
        case .safetySquat, .trapHex: 55
        }
    }

    func weight(for unitSystem: UnitSystem) -> Float {
        unitSystem == .metric ? metricWeight : imperialWeight
    }
}

struct PlateCalculation {
    let plates: [Float]
    let remainingWeight: Float
    let totalWeight: Float
    let perSideWeight: Float

    init(target: Float, barWeight: Float, plates availablePlates: [Float]) {
        guard target >= barWeight else {
            plates = []
            remainingWeight = 0
            totalWeight = 0
            perSideWeight = 0
            return
        }

        var remainingPerSide = (target - barWeight) / 2
        var selectedPlates: [Float] = []

        for plate in availablePlates.sorted(by: >) {
            while remainingPerSide + 0.001 >= plate {
                selectedPlates.append(plate)
                remainingPerSide -= plate
            }
        }

        plates = selectedPlates
        remainingWeight = remainingPerSide * 2
        perSideWeight = barWeight / 2 + selectedPlates.reduce(0, +)
        totalWeight = barWeight + selectedPlates.reduce(0, +) * 2
    }
}

#endif
