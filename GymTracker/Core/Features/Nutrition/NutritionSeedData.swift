import Foundation
import SwiftData

enum NutritionSeedData {
    static func seedIfNeeded(using context: ModelContext) {
        do {
            try stage(using: context, registry: SystemSeedRegistry(context: context))
            try context.save()
        } catch {
            context.rollback()
            print("Failed to seed nutrition data: \(error)")
        }
    }

    static func stage(using context: ModelContext, registry: SystemSeedRegistry) throws {
        var existing = try context.fetch(FetchDescriptor<FoodItem>())


        struct FoodSeed {
            let name: String
            let frenchName: String?
            let searchAliases: [String]
            let categoryName: String
            let refAmount: Double
            let refUnit: NutritionServingUnit
            let calories: Double
            let protein: Double
            let carbs: Double
            let fat: Double
            let prep: FoodPreparationState
            let servingName: String
            let servingAmount: Double
            let servingUnit: NutritionServingUnit
            let equivalentRefAmount: Double

            init(
                name: String,
                frenchName: String? = nil,
                searchAliases: [String] = [],
                categoryName: String = "Other",
                refAmount: Double = 100,
                refUnit: NutritionServingUnit = .grams,
                calories: Double,
                protein: Double,
                carbs: Double,
                fat: Double,
                prep: FoodPreparationState = .raw,
                servingName: String,
                servingAmount: Double,
                servingUnit: NutritionServingUnit = .grams,
                equivalentRefAmount: Double
            ) {
                self.name = name
                self.frenchName = frenchName
                self.searchAliases = searchAliases
                self.categoryName = categoryName
                self.refAmount = refAmount
                self.refUnit = refUnit
                self.calories = calories
                self.protein = protein
                self.carbs = carbs
                self.fat = fat
                self.prep = prep
                self.servingName = servingName
                self.servingAmount = servingAmount
                self.servingUnit = servingUnit
                self.equivalentRefAmount = equivalentRefAmount
            }
        }

        let seedList: [FoodSeed] = [
            FoodSeed(name: "Chicken breast", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chicken thighs", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chicken drumsticks", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole chicken", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ground chicken", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Turkey breast", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ground turkey", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Turkey thighs", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lean ground beef", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Extra-lean ground beef", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Beef sirloin", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Beef tenderloin", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Beef round roast", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Beef chuck roast", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Stewing beef", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Flank steak", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Skirt steak", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pork tenderloin", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pork loin", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pork chops", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lean ground pork", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ham", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lamb leg", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lamb loin", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lean ground lamb", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Veal cutlets", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bison", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Venison", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole eggs", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Egg whites", categoryName: "Protein", calories: 140.0, protein: 24.0, carbs: 0.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Canned tuna", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fresh tuna", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Canned salmon", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fresh salmon", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Smoked salmon", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sardines", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mackerel", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Trout", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cod", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Haddock", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pollock", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Tilapia", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Halibut", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sole", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Herring", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Anchovies", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Shrimp", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Prawns", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Scallops", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mussels", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Clams", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Oysters", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Crab", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lobster", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Squid", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Octopus", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Arctic char", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sea bass", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Canned crab", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Canned mussels", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Milk", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lactose-free milk", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Skim milk", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Two-percent milk", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole milk", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chocolate milk", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Greek yogurt", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Plain yogurt", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Skyr", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cottage cheese", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ricotta cheese", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cheddar cheese", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mozzarella", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Parmesan", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Feta", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Swiss cheese", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Gouda", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cream cheese", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Kefir", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Buttermilk", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sour cream", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Light sour cream", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fortified soy milk", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fortified oat milk", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fortified almond milk", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Coconut milk beverage", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Evaporated milk", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Powdered milk", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Plain protein yogurt", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Quark", categoryName: "Other", calories: 90.0, protein: 8.0, carbs: 6.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Black beans", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Kidney beans", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pinto beans", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Navy beans", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cannellini beans", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Great northern beans", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lima beans", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Adzuki beans", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mung beans", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chickpeas", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Green lentils", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Brown lentils", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Red lentils", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Black lentils", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Yellow split peas", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Green split peas", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Edamame", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Tofu", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Firm tofu", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Silken tofu", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Tempeh", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Textured vegetable protein", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Seitan", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Soybeans", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Refried beans", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bean pasta", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lentil pasta", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chickpea pasta", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Hummus", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Roasted chickpeas", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "White rice", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Brown rice", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Basmati rice", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Jasmine rice", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Wild rice", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Arborio rice", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Parboiled rice", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Quinoa", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Barley", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pearl barley", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bulgur", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Couscous", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole-wheat couscous", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Farro", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Millet", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Buckwheat", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Amaranth", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sorghum", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Rye berries", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Wheat berries", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cornmeal", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Polenta", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Rolled oats", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Quick oats", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Steel-cut oats", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Oat bran", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bran cereal", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole-grain cereal", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Unsweetened muesli", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Low-sugar granola", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole-grain bread", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sourdough bread", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Rye bread", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Multigrain bread", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole-wheat pita", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole-wheat tortillas", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Corn tortillas", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "English muffins", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bagels", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Flatbread", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Naan", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole-wheat pasta", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Regular pasta", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Spaghetti", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Penne", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fusilli", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Macaroni", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lasagna noodles", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Rice noodles", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Egg noodles", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Soba noodles", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Udon noodles", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole-wheat flour", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "All-purpose flour", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bread flour", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Oat flour", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Corn flour", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chickpea flour", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Almond flour", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Breadcrumbs", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Russet potatoes", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Red potatoes", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Yellow potatoes", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Baby potatoes", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sweet potatoes", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Yams", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cassava", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Plantains", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Green peas", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Corn", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Butternut squash", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Acorn squash", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Spaghetti squash", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pumpkin", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Delicata squash", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Turnips", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Rutabaga", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Parsnips", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Taro", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Breadfruit", categoryName: "Other", calories: 130.0, protein: 3.0, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Spinach", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Kale", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Romaine lettuce", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Iceberg lettuce", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Arugula", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Swiss chard", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Collard greens", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mustard greens", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Beet greens", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bok choy", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Napa cabbage", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Green cabbage", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Red cabbage", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Savoy cabbage", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Watercress", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Endive", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Radicchio", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Spring mix", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Microgreens", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Dandelion greens", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Broccoli", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cauliflower", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Carrots", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bell peppers", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Jalapeños", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Onions", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Red onions", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Green onions", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Garlic", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Tomatoes", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cherry tomatoes", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cucumbers", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Zucchini", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Eggplant", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Green beans", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Asparagus", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Brussels sprouts", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Celery", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mushrooms", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Portobello mushrooms", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Shiitake mushrooms", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Beets", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Radishes", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Leeks", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fennel", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Artichokes", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Okra", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Snap peas", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Snow peas", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Frozen mixed vegetables", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bananas", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Apples", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Oranges", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mandarins", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Grapefruit", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lemons", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Limes", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Strawberries", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Blueberries", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Raspberries", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Blackberries", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cranberries", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Grapes", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Watermelon", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cantaloupe", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Honeydew melon", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pineapple", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mangoes", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Papaya", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Peaches", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Nectarines", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Plums", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pears", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cherries", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Kiwi", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pomegranate", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Avocado", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Dates", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Figs", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Apricots", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Passion fruit", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Guava", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Dragon fruit", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Coconut", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Unsweetened applesauce", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Frozen berries", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Frozen mango", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Raisins", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Dried cranberries", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Prunes", categoryName: "Fruit", calories: 60.0, protein: 0.5, carbs: 14.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Almonds", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Walnuts", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cashews", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pistachios", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pecans", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Hazelnuts", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Brazil nuts", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Peanuts", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Macadamia nuts", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pine nuts", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pumpkin seeds", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sunflower seeds", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chia seeds", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ground flaxseed", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sesame seeds", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Hemp seeds", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Poppy seeds", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Peanut butter", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Almond butter", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Tahini", categoryName: "Other", calories: 550.0, protein: 15.0, carbs: 15.0, fat: 45.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Extra-virgin olive oil", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Light olive oil", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Avocado oil", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Canola oil", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sesame oil", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Peanut oil", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sunflower oil", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Coconut oil", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Butter", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ghee", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Tomato paste", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Tomato sauce", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Canned diced tomatoes", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Crushed tomatoes", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Salsa", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Soy sauce", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Low-sodium soy sauce", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Dijon mustard", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Yellow mustard", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mayonnaise", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Greek-yogurt dressing", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Hot sauce", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sriracha", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Worcestershire sauce", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Balsamic vinegar", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Apple cider vinegar", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Rice vinegar", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Red-wine vinegar", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Vegetable broth", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chicken broth", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Salt", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Black pepper", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Paprika", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Smoked paprika", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Garlic powder", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Onion powder", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chili powder", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ground cumin", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Italian seasoning", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Curry powder", categoryName: "Other", calories: 100.0, protein: 5.0, carbs: 15.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100)
        ]

        var didInsert = false
        for seed in seedList {
            let key = SystemSeedKey.make(namespace: "food", legacyName: seed.name)
            let food: FoodItem
            let ownsSystemFields: Bool
            if let record = try registry.record(for: key, expectedKind: .foodItem) {
                guard let matched = existing.first(where: { $0.id == record.entityID }) else {
                    throw SystemSeedError.danglingEntity(key: key, entityID: record.entityID)
                }
                food = matched
                ownsSystemFields = record.isSystemProvided
            } else if let matched = existing.first(where: {
                $0.name.compare(seed.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }) {
                food = matched
                ownsSystemFields = matched.sourceKind == .curated
                try registry.register(
                    key: key,
                    kind: .foodItem,
                    entityID: matched.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .migratedLegacy,
                    isSystemProvided: ownsSystemFields
                )
            } else {
                food = FoodItem(name: seed.name, sourceKind: .curated, confidence: .verified)
                context.insert(food)
                existing.append(food)
                ownsSystemFields = true
                try registry.register(
                    key: key,
                    kind: .foodItem,
                    entityID: food.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .bundled
                )
                didInsert = true
            }
            guard ownsSystemFields else { continue }
            food.name = seed.name
            food.frenchName = seed.frenchName
            food.searchAliases = seed.searchAliases
            food.categoryName = seed.categoryName
            food.referenceAmount = seed.refAmount
            food.referenceUnit = seed.refUnit
            food.calories = seed.calories
            food.proteinGrams = seed.protein
            food.carbohydrateGrams = seed.carbs
            food.fatGrams = seed.fat
            food.sourceKind = .curated
            food.confidence = .verified
            food.preparationState = seed.prep
            food.updatedAt = .now
            // isFavorite and isArchived are user-owned.

            let servingKey = "food-serving.\(key.dropFirst("food.".count)).primary"
            let serving: FoodServing
            if let record = try registry.record(for: servingKey, expectedKind: .foodServing) {
                guard let matched = food.servings.first(where: { $0.id == record.entityID }) else {
                    throw SystemSeedError.danglingEntity(key: servingKey, entityID: record.entityID)
                }
                serving = matched
            } else if let existingServing = food.servings.first {
                serving = existingServing
                try registry.register(
                    key: servingKey,
                    kind: .foodServing,
                    entityID: serving.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .migratedLegacy
                )
            } else {
                serving = FoodServing(
                    name: seed.servingName,
                    amount: seed.servingAmount,
                    unit: seed.servingUnit,
                    equivalentReferenceAmount: seed.equivalentRefAmount
                )
                food.servings.append(serving)
                try registry.register(
                    key: servingKey,
                    kind: .foodServing,
                    entityID: serving.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .bundled
                )
            }
            serving.name = seed.servingName
            serving.amount = seed.servingAmount
            serving.unit = seed.servingUnit
            serving.equivalentReferenceAmount = seed.equivalentRefAmount
        }

        _ = didInsert

        let existingTemplates = try context.fetch(FetchDescriptor<MealTemplate>())
        let allFoods = try context.fetch(FetchDescriptor<FoodItem>())
        let foodByName: [String: FoodItem] = Dictionary(uniqueKeysWithValues: allFoods.map { ($0.name.lowercased(), $0) })


        struct RecipeSeed {
            let name: String
            let prepState: FoodPreparationState
            let finalWeight: Double?
            let items: [(foodName: String, qty: Double)]
        }

        let recipeList: [RecipeSeed] = [
            RecipeSeed(
                name: "Chicken, Rice & Broccoli Bowl",
                prepState: .cooked,
                finalWeight: nil,
                items: [
                    ("Cooked chicken breast", 1.5),
                    ("Cooked rice", 1.25),
                    ("Cooked broccoli", 1.0)
                ]
            ),
            RecipeSeed(
                name: "High-Protein Oatmeal Bowl",
                prepState: .raw,
                finalWeight: nil,
                items: [
                    ("Dry rolled oats", 2.0),
                    ("Whey protein powder", 1.0),
                    ("Banana", 1.0),
                    ("Peanut butter", 1.0)
                ]
            ),
            RecipeSeed(
                name: "Steak & Sweet Potato Recovery Meal",
                prepState: .cooked,
                finalWeight: nil,
                items: [
                    ("Cooked sirloin steak", 1.0),
                    ("Cooked sweet potato", 1.5),
                    ("Cooked green beans", 1.0)
                ]
            ),
            RecipeSeed(
                name: "Greek Yogurt & Berry Bowl",
                prepState: .raw,
                finalWeight: nil,
                items: [
                    ("Greek yogurt", 1.2),
                    ("Blueberries", 0.7),
                    ("Chia seeds", 1.0),
                    ("Whey protein powder", 0.5)
                ]
            ),
            RecipeSeed(
                name: "Egg White & Avocado Wrap",
                prepState: .cooked,
                finalWeight: nil,
                items: [
                    ("Whole wheat tortilla", 1.0),
                    ("Liquid egg whites", 1.25),
                    ("Whole egg", 1.0),
                    ("Avocado", 0.5)
                ]
            ),
            RecipeSeed(
                name: "Salmon & Quinoa Bowl",
                prepState: .cooked,
                finalWeight: nil,
                items: [
                    ("Cooked salmon fillet", 1.0),
                    ("Cooked quinoa", 1.0),
                    ("Raw spinach", 1.0)
                ]
            )
        ]

        var didInsertRecipe = false
        for recipe in recipeList {
            var templateItems: [MealTemplateItem] = []
            for (idx, item) in recipe.items.enumerated() {
                if let food = foodByName[item.foodName.lowercased()] {
                    let servingID = food.servings.first?.id
                    templateItems.append(MealTemplateItem(food: food, orderIndex: idx, servingID: servingID, quantity: item.qty))
                }
            }
            guard !templateItems.isEmpty else { continue }
            let key = SystemSeedKey.make(namespace: "meal-template", legacyName: recipe.name)
            if let record = try registry.record(for: key, expectedKind: .mealTemplate) {
                guard existingTemplates.contains(where: { $0.id == record.entityID }) else {
                    throw SystemSeedError.danglingEntity(key: key, entityID: record.entityID)
                }
                continue
            }
            let expectedFoodIDs = templateItems.map { $0.food.id }
            let candidates = existingTemplates.filter {
                $0.name == recipe.name && $0.orderedItems.map { $0.food.id } == expectedFoodIDs
            }
            guard candidates.count <= 1 else {
                throw SystemSeedError.ambiguousLegacyMatch(key: key, count: candidates.count)
            }
            if let adopted = candidates.first {
                try registry.register(
                    key: key,
                    kind: .mealTemplate,
                    entityID: adopted.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .migratedLegacy
                )
            } else {
                let template = MealTemplate(name: recipe.name, preparationState: recipe.prepState, finalCookedWeightGrams: recipe.finalWeight)
                template.items = templateItems
                context.insert(template)
                try registry.register(
                    key: key,
                    kind: .mealTemplate,
                    entityID: template.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .bundled
                )
                didInsertRecipe = true
            }
        }

        _ = didInsertRecipe
    }
}
