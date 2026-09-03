import Foundation

struct EquipmentPreset: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let frenchName: String
    let defaultWeightKg: Double
    let defaultWeightLbs: Double
    let category: EquipmentPresetCategory

    enum EquipmentPresetCategory: String, CaseIterable, Identifiable {
        case barbell = "Barbell"
        case plates = "Plate Pairs"

        var id: String { rawValue }
    }
}

enum EquipmentPresets {
    static let barbells: [EquipmentPreset] = [
        EquipmentPreset(
            id: "olympic_barbell",
            name: "Olympic Barbell",
            frenchName: "Barre olympique",
            defaultWeightKg: 20.0,
            defaultWeightLbs: 45.0,
            category: .barbell
        ),
        EquipmentPreset(
            id: "women_olympic_barbell",
            name: "Women's Olympic Barbell",
            frenchName: "Barre olympique féminine",
            defaultWeightKg: 15.0,
            defaultWeightLbs: 35.0,
            category: .barbell
        ),
        EquipmentPreset(
            id: "ez_curl_bar",
            name: "EZ-Curl Bar",
            frenchName: "Barre EZ",
            defaultWeightKg: 10.0,
            defaultWeightLbs: 25.0,
            category: .barbell
        ),
        EquipmentPreset(
            id: "trap_bar",
            name: "Trap / Hex Bar",
            frenchName: "Barre hexagonale (Trap Bar)",
            defaultWeightKg: 25.0,
            defaultWeightLbs: 55.0,
            category: .barbell
        ),
        EquipmentPreset(
            id: "swiss_bar",
            name: "Swiss / Multi-Grip Bar",
            frenchName: "Barre neutre / Swiss Bar",
            defaultWeightKg: 20.0,
            defaultWeightLbs: 45.0,
            category: .barbell
        )
    ]

    static let standardMetricPlatePairsKg: [Double] = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25]
    static let standardImperialPlatePairsLbs: [Double] = [55.0, 45.0, 35.0, 25.0, 10.0, 5.0, 2.5, 1.0]

    static func defaultBarWeight(for equipment: EquipmentType?, isMetric: Bool = true) -> Double {
        guard let equipment = equipment else { return 0 }
        switch equipment {
        case .barbell:
            return isMetric ? 20.0 : 45.0
        default:
            return 0
        }
    }
}
