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
            // Poultry, Meat & Eggs
            FoodSeed(name: "Chicken breast", categoryName: "Poultry, Meat & Eggs", calories: 120.0, protein: 22.5, carbs: 0.0, fat: 2.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chicken thighs", categoryName: "Poultry, Meat & Eggs", calories: 177.0, protein: 20.0, carbs: 0.0, fat: 10.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chicken drumsticks", categoryName: "Poultry, Meat & Eggs", calories: 161.0, protein: 19.2, carbs: 0.0, fat: 9.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole chicken", categoryName: "Poultry, Meat & Eggs", calories: 215.0, protein: 18.6, carbs: 0.0, fat: 15.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ground chicken", categoryName: "Poultry, Meat & Eggs", calories: 143.0, protein: 17.4, carbs: 0.0, fat: 8.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Turkey breast", categoryName: "Poultry, Meat & Eggs", calories: 135.0, protein: 30.0, carbs: 0.0, fat: 0.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ground turkey", categoryName: "Poultry, Meat & Eggs", calories: 148.0, protein: 19.7, carbs: 0.0, fat: 7.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Turkey thighs", categoryName: "Poultry, Meat & Eggs", calories: 158.0, protein: 19.4, carbs: 0.0, fat: 8.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lean ground beef", categoryName: "Poultry, Meat & Eggs", calories: 176.0, protein: 20.0, carbs: 0.0, fat: 10.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Extra-lean ground beef", categoryName: "Poultry, Meat & Eggs", calories: 137.0, protein: 21.4, carbs: 0.0, fat: 5.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Beef sirloin", categoryName: "Poultry, Meat & Eggs", calories: 183.0, protein: 20.7, carbs: 0.0, fat: 10.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Beef tenderloin", categoryName: "Poultry, Meat & Eggs", calories: 168.0, protein: 21.8, carbs: 0.0, fat: 8.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Beef round roast", categoryName: "Poultry, Meat & Eggs", calories: 151.0, protein: 21.7, carbs: 0.0, fat: 6.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Beef chuck roast", categoryName: "Poultry, Meat & Eggs", calories: 205.0, protein: 19.5, carbs: 0.0, fat: 13.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Stewing beef", categoryName: "Poultry, Meat & Eggs", calories: 190.0, protein: 20.0, carbs: 0.0, fat: 12.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Flank steak", categoryName: "Poultry, Meat & Eggs", calories: 165.0, protein: 21.4, carbs: 0.0, fat: 8.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Skirt steak", categoryName: "Poultry, Meat & Eggs", calories: 205.0, protein: 20.0, carbs: 0.0, fat: 13.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pork tenderloin", categoryName: "Poultry, Meat & Eggs", calories: 120.0, protein: 20.7, carbs: 0.0, fat: 3.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pork loin", categoryName: "Poultry, Meat & Eggs", calories: 164.0, protein: 21.8, carbs: 0.0, fat: 8.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pork chops", categoryName: "Poultry, Meat & Eggs", calories: 178.0, protein: 21.3, carbs: 0.0, fat: 9.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lean ground pork", categoryName: "Poultry, Meat & Eggs", calories: 180.0, protein: 19.0, carbs: 0.0, fat: 11.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ham", categoryName: "Poultry, Meat & Eggs", calories: 145.0, protein: 21.0, carbs: 1.5, fat: 5.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lamb leg", categoryName: "Poultry, Meat & Eggs", calories: 191.0, protein: 20.8, carbs: 0.0, fat: 11.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lamb loin", categoryName: "Poultry, Meat & Eggs", calories: 216.0, protein: 19.8, carbs: 0.0, fat: 14.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lean ground lamb", categoryName: "Poultry, Meat & Eggs", calories: 212.0, protein: 18.5, carbs: 0.0, fat: 15.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Veal cutlets", categoryName: "Poultry, Meat & Eggs", calories: 112.0, protein: 20.4, carbs: 0.0, fat: 2.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bison", categoryName: "Poultry, Meat & Eggs", calories: 143.0, protein: 21.6, carbs: 0.0, fat: 5.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Venison", categoryName: "Poultry, Meat & Eggs", calories: 120.0, protein: 22.9, carbs: 0.0, fat: 2.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole eggs", categoryName: "Poultry, Meat & Eggs", calories: 143.0, protein: 12.6, carbs: 0.7, fat: 9.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Egg whites", categoryName: "Poultry, Meat & Eggs", calories: 52.0, protein: 10.9, carbs: 0.7, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),

            // Fish & Seafood
            FoodSeed(name: "Canned tuna", categoryName: "Fish & Seafood", calories: 86.0, protein: 19.4, carbs: 0.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fresh tuna", categoryName: "Fish & Seafood", calories: 130.0, protein: 28.0, carbs: 0.0, fat: 1.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Canned salmon", categoryName: "Fish & Seafood", calories: 136.0, protein: 20.0, carbs: 0.0, fat: 5.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fresh salmon", categoryName: "Fish & Seafood", calories: 208.0, protein: 20.4, carbs: 0.0, fat: 13.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Smoked salmon", categoryName: "Fish & Seafood", calories: 117.0, protein: 18.3, carbs: 0.0, fat: 4.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sardines", categoryName: "Fish & Seafood", calories: 208.0, protein: 24.6, carbs: 0.0, fat: 11.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mackerel", categoryName: "Fish & Seafood", calories: 205.0, protein: 18.6, carbs: 0.0, fat: 13.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Trout", categoryName: "Fish & Seafood", calories: 148.0, protein: 20.8, carbs: 0.0, fat: 6.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cod", categoryName: "Fish & Seafood", calories: 82.0, protein: 17.8, carbs: 0.0, fat: 0.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Haddock", categoryName: "Fish & Seafood", calories: 90.0, protein: 20.0, carbs: 0.0, fat: 0.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pollock", categoryName: "Fish & Seafood", calories: 92.0, protein: 19.4, carbs: 0.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Tilapia", categoryName: "Fish & Seafood", calories: 96.0, protein: 20.1, carbs: 0.0, fat: 1.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Halibut", categoryName: "Fish & Seafood", calories: 111.0, protein: 22.5, carbs: 0.0, fat: 2.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sole", categoryName: "Fish & Seafood", calories: 91.0, protein: 18.8, carbs: 0.0, fat: 1.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Herring", categoryName: "Fish & Seafood", calories: 158.0, protein: 18.0, carbs: 0.0, fat: 9.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Anchovies", categoryName: "Fish & Seafood", calories: 131.0, protein: 20.4, carbs: 0.0, fat: 4.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Shrimp", categoryName: "Fish & Seafood", calories: 85.0, protein: 20.1, carbs: 0.2, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Prawns", categoryName: "Fish & Seafood", calories: 85.0, protein: 20.1, carbs: 0.2, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Scallops", categoryName: "Fish & Seafood", calories: 88.0, protein: 16.8, carbs: 2.4, fat: 0.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mussels", categoryName: "Fish & Seafood", calories: 86.0, protein: 11.9, carbs: 3.7, fat: 2.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Clams", categoryName: "Fish & Seafood", calories: 74.0, protein: 12.8, carbs: 2.6, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Oysters", categoryName: "Fish & Seafood", calories: 68.0, protein: 7.0, carbs: 3.9, fat: 2.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Crab", categoryName: "Fish & Seafood", calories: 87.0, protein: 18.1, carbs: 0.0, fat: 1.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lobster", categoryName: "Fish & Seafood", calories: 89.0, protein: 19.0, carbs: 0.0, fat: 0.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Squid", categoryName: "Fish & Seafood", calories: 92.0, protein: 15.6, carbs: 3.1, fat: 1.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Octopus", categoryName: "Fish & Seafood", calories: 82.0, protein: 14.9, carbs: 2.2, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Arctic char", categoryName: "Fish & Seafood", calories: 143.0, protein: 20.1, carbs: 0.0, fat: 6.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sea bass", categoryName: "Fish & Seafood", calories: 97.0, protein: 18.4, carbs: 0.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Canned crab", categoryName: "Fish & Seafood", calories: 84.0, protein: 17.5, carbs: 0.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Canned mussels", categoryName: "Fish & Seafood", calories: 98.0, protein: 13.0, carbs: 4.0, fat: 2.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),

            // Dairy & Alternatives
            FoodSeed(name: "Milk", categoryName: "Dairy & Alternatives", calories: 61.0, protein: 3.2, carbs: 4.8, fat: 3.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lactose-free milk", categoryName: "Dairy & Alternatives", calories: 61.0, protein: 3.2, carbs: 4.8, fat: 3.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Skim milk", categoryName: "Dairy & Alternatives", calories: 34.0, protein: 3.4, carbs: 5.0, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Two-percent milk", categoryName: "Dairy & Alternatives", calories: 50.0, protein: 3.3, carbs: 4.8, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole milk", categoryName: "Dairy & Alternatives", calories: 61.0, protein: 3.2, carbs: 4.8, fat: 3.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chocolate milk", categoryName: "Dairy & Alternatives", calories: 83.0, protein: 3.4, carbs: 10.3, fat: 2.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Greek yogurt", categoryName: "Dairy & Alternatives", calories: 59.0, protein: 10.0, carbs: 3.6, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Plain yogurt", categoryName: "Dairy & Alternatives", calories: 61.0, protein: 3.5, carbs: 4.7, fat: 3.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Skyr", categoryName: "Dairy & Alternatives", calories: 63.0, protein: 11.0, carbs: 4.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cottage cheese", categoryName: "Dairy & Alternatives", calories: 81.0, protein: 11.0, carbs: 4.7, fat: 2.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ricotta cheese", categoryName: "Dairy & Alternatives", calories: 138.0, protein: 11.4, carbs: 3.0, fat: 8.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cheddar cheese", categoryName: "Dairy & Alternatives", calories: 403.0, protein: 24.9, carbs: 1.3, fat: 33.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mozzarella", categoryName: "Dairy & Alternatives", calories: 280.0, protein: 22.2, carbs: 2.2, fat: 20.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Parmesan", categoryName: "Dairy & Alternatives", calories: 431.0, protein: 38.4, carbs: 4.1, fat: 28.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Feta", categoryName: "Dairy & Alternatives", calories: 264.0, protein: 14.2, carbs: 4.1, fat: 21.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Swiss cheese", categoryName: "Dairy & Alternatives", calories: 380.0, protein: 27.0, carbs: 1.5, fat: 27.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Gouda", categoryName: "Dairy & Alternatives", calories: 356.0, protein: 25.0, carbs: 2.2, fat: 27.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cream cheese", categoryName: "Dairy & Alternatives", calories: 342.0, protein: 5.9, carbs: 4.1, fat: 34.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Kefir", categoryName: "Dairy & Alternatives", calories: 61.0, protein: 3.3, carbs: 4.8, fat: 3.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Buttermilk", categoryName: "Dairy & Alternatives", calories: 40.0, protein: 3.3, carbs: 4.8, fat: 0.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sour cream", categoryName: "Dairy & Alternatives", calories: 198.0, protein: 2.4, carbs: 4.6, fat: 19.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Light sour cream", categoryName: "Dairy & Alternatives", calories: 136.0, protein: 3.2, carbs: 7.1, fat: 10.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fortified soy milk", categoryName: "Dairy & Alternatives", calories: 54.0, protein: 3.3, carbs: 6.0, fat: 1.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fortified oat milk", categoryName: "Dairy & Alternatives", calories: 48.0, protein: 1.0, carbs: 7.0, fat: 1.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fortified almond milk", categoryName: "Dairy & Alternatives", calories: 15.0, protein: 0.5, carbs: 0.6, fat: 1.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Coconut milk beverage", categoryName: "Dairy & Alternatives", calories: 20.0, protein: 0.2, carbs: 1.0, fat: 1.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Evaporated milk", categoryName: "Dairy & Alternatives", calories: 134.0, protein: 6.8, carbs: 10.0, fat: 7.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Powdered milk", categoryName: "Dairy & Alternatives", calories: 362.0, protein: 26.3, carbs: 38.4, fat: 26.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Plain protein yogurt", categoryName: "Dairy & Alternatives", calories: 65.0, protein: 12.0, carbs: 3.8, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Quark", categoryName: "Dairy & Alternatives", calories: 68.0, protein: 12.0, carbs: 3.5, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),

            // Legumes & Plant Proteins
            FoodSeed(name: "Black beans", categoryName: "Legumes & Plant Proteins", calories: 132.0, protein: 8.9, carbs: 23.7, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Kidney beans", categoryName: "Legumes & Plant Proteins", calories: 127.0, protein: 8.7, carbs: 22.8, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pinto beans", categoryName: "Legumes & Plant Proteins", calories: 143.0, protein: 9.0, carbs: 26.2, fat: 0.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Navy beans", categoryName: "Legumes & Plant Proteins", calories: 140.0, protein: 8.2, carbs: 26.1, fat: 0.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cannellini beans", categoryName: "Legumes & Plant Proteins", calories: 139.0, protein: 9.7, carbs: 25.1, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Great northern beans", categoryName: "Legumes & Plant Proteins", calories: 118.0, protein: 8.3, carbs: 21.1, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lima beans", categoryName: "Legumes & Plant Proteins", calories: 115.0, protein: 7.8, carbs: 20.9, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Adzuki beans", categoryName: "Legumes & Plant Proteins", calories: 128.0, protein: 7.5, carbs: 24.8, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mung beans", categoryName: "Legumes & Plant Proteins", calories: 105.0, protein: 7.0, carbs: 19.2, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chickpeas", categoryName: "Legumes & Plant Proteins", calories: 164.0, protein: 8.9, carbs: 27.4, fat: 2.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Green lentils", categoryName: "Legumes & Plant Proteins", calories: 116.0, protein: 9.0, carbs: 20.1, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Brown lentils", categoryName: "Legumes & Plant Proteins", calories: 116.0, protein: 9.0, carbs: 20.1, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Red lentils", categoryName: "Legumes & Plant Proteins", calories: 116.0, protein: 9.0, carbs: 20.1, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Black lentils", categoryName: "Legumes & Plant Proteins", calories: 116.0, protein: 9.0, carbs: 20.1, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Yellow split peas", categoryName: "Legumes & Plant Proteins", calories: 118.0, protein: 8.3, carbs: 21.1, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Green split peas", categoryName: "Legumes & Plant Proteins", calories: 118.0, protein: 8.3, carbs: 21.1, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Edamame", categoryName: "Legumes & Plant Proteins", calories: 122.0, protein: 11.9, carbs: 8.9, fat: 5.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Tofu", categoryName: "Legumes & Plant Proteins", calories: 83.0, protein: 10.0, carbs: 1.9, fat: 5.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Firm tofu", categoryName: "Legumes & Plant Proteins", calories: 83.0, protein: 10.0, carbs: 1.9, fat: 5.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Silken tofu", categoryName: "Legumes & Plant Proteins", calories: 55.0, protein: 4.8, carbs: 2.1, fat: 2.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Tempeh", categoryName: "Legumes & Plant Proteins", calories: 192.0, protein: 20.3, carbs: 7.6, fat: 10.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Textured vegetable protein", categoryName: "Legumes & Plant Proteins", calories: 330.0, protein: 52.0, carbs: 32.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Seitan", categoryName: "Legumes & Plant Proteins", calories: 370.0, protein: 75.0, carbs: 14.0, fat: 1.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Soybeans", categoryName: "Legumes & Plant Proteins", calories: 172.0, protein: 16.6, carbs: 9.9, fat: 9.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Refried beans", categoryName: "Legumes & Plant Proteins", calories: 91.0, protein: 5.4, carbs: 15.3, fat: 1.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bean pasta", categoryName: "Legumes & Plant Proteins", calories: 340.0, protein: 25.0, carbs: 55.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lentil pasta", categoryName: "Legumes & Plant Proteins", calories: 345.0, protein: 25.0, carbs: 56.0, fat: 1.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chickpea pasta", categoryName: "Legumes & Plant Proteins", calories: 350.0, protein: 21.0, carbs: 58.0, fat: 3.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Hummus", categoryName: "Legumes & Plant Proteins", calories: 166.0, protein: 7.9, carbs: 14.3, fat: 9.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Roasted chickpeas", categoryName: "Legumes & Plant Proteins", calories: 180.0, protein: 9.0, carbs: 29.0, fat: 4.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),

            // Grains & Starches
            FoodSeed(name: "White rice", categoryName: "Grains & Starches", calories: 130.0, protein: 2.7, carbs: 28.0, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Brown rice", categoryName: "Grains & Starches", calories: 123.0, protein: 2.7, carbs: 25.6, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Basmati rice", categoryName: "Grains & Starches", calories: 130.0, protein: 3.0, carbs: 28.0, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Jasmine rice", categoryName: "Grains & Starches", calories: 129.0, protein: 2.4, carbs: 28.3, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Wild rice", categoryName: "Grains & Starches", calories: 101.0, protein: 4.0, carbs: 21.3, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Arborio rice", categoryName: "Grains & Starches", calories: 130.0, protein: 2.5, carbs: 29.0, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Parboiled rice", categoryName: "Grains & Starches", calories: 123.0, protein: 2.4, carbs: 27.2, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Quinoa", categoryName: "Grains & Starches", calories: 120.0, protein: 4.4, carbs: 21.3, fat: 1.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Barley", categoryName: "Grains & Starches", calories: 123.0, protein: 2.3, carbs: 28.2, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pearl barley", categoryName: "Grains & Starches", calories: 123.0, protein: 2.3, carbs: 28.2, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bulgur", categoryName: "Grains & Starches", calories: 83.0, protein: 3.1, carbs: 18.6, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Couscous", categoryName: "Grains & Starches", calories: 112.0, protein: 3.8, carbs: 23.2, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole-wheat couscous", categoryName: "Grains & Starches", calories: 112.0, protein: 4.5, carbs: 22.0, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Farro", categoryName: "Grains & Starches", calories: 120.0, protein: 5.0, carbs: 24.0, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Millet", categoryName: "Grains & Starches", calories: 119.0, protein: 3.5, carbs: 23.7, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Buckwheat", categoryName: "Grains & Starches", calories: 92.0, protein: 3.4, carbs: 19.9, fat: 0.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Amaranth", categoryName: "Grains & Starches", calories: 102.0, protein: 3.8, carbs: 18.7, fat: 1.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sorghum", categoryName: "Grains & Starches", calories: 115.0, protein: 3.5, carbs: 25.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Rye berries", categoryName: "Grains & Starches", calories: 125.0, protein: 4.0, carbs: 27.0, fat: 0.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Wheat berries", categoryName: "Grains & Starches", calories: 130.0, protein: 5.0, carbs: 28.0, fat: 0.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cornmeal", categoryName: "Grains & Starches", calories: 365.0, protein: 8.1, carbs: 76.9, fat: 3.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Polenta", categoryName: "Grains & Starches", calories: 70.0, protein: 1.5, carbs: 15.0, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Rolled oats", categoryName: "Grains & Starches", calories: 389.0, protein: 16.9, carbs: 66.3, fat: 6.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Quick oats", categoryName: "Grains & Starches", calories: 389.0, protein: 16.9, carbs: 66.3, fat: 6.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Steel-cut oats", categoryName: "Grains & Starches", calories: 389.0, protein: 16.9, carbs: 66.3, fat: 6.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Oat bran", categoryName: "Grains & Starches", calories: 246.0, protein: 17.3, carbs: 66.2, fat: 7.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bran cereal", categoryName: "Grains & Starches", calories: 260.0, protein: 10.0, carbs: 78.0, fat: 2.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole-grain cereal", categoryName: "Grains & Starches", calories: 360.0, protein: 10.0, carbs: 75.0, fat: 3.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Unsweetened muesli", categoryName: "Grains & Starches", calories: 370.0, protein: 12.0, carbs: 64.0, fat: 6.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Low-sugar granola", categoryName: "Grains & Starches", calories: 420.0, protein: 12.0, carbs: 60.0, fat: 14.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),

            // Breads & Baked Goods
            FoodSeed(name: "Whole-grain bread", categoryName: "Breads & Baked Goods", calories: 247.0, protein: 13.0, carbs: 41.0, fat: 3.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sourdough bread", categoryName: "Breads & Baked Goods", calories: 250.0, protein: 9.0, carbs: 48.0, fat: 1.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Rye bread", categoryName: "Breads & Baked Goods", calories: 259.0, protein: 8.5, carbs: 48.3, fat: 3.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Multigrain bread", categoryName: "Breads & Baked Goods", calories: 265.0, protein: 13.4, carbs: 43.3, fat: 4.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole-wheat pita", categoryName: "Breads & Baked Goods", calories: 247.0, protein: 9.8, carbs: 47.5, fat: 1.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole-wheat tortillas", categoryName: "Breads & Baked Goods", calories: 304.0, protein: 9.8, carbs: 47.7, fat: 7.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Corn tortillas", categoryName: "Breads & Baked Goods", calories: 218.0, protein: 5.7, carbs: 45.0, fat: 2.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "English muffins", categoryName: "Breads & Baked Goods", calories: 235.0, protein: 8.0, carbs: 46.0, fat: 1.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bagels", categoryName: "Breads & Baked Goods", calories: 270.0, protein: 10.0, carbs: 53.0, fat: 1.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Flatbread", categoryName: "Breads & Baked Goods", calories: 290.0, protein: 9.0, carbs: 52.0, fat: 5.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Naan", categoryName: "Breads & Baked Goods", calories: 310.0, protein: 9.0, carbs: 50.0, fat: 8.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),

            // Pasta, Noodles & Flours
            FoodSeed(name: "Whole-wheat pasta", categoryName: "Pasta, Noodles & Flours", calories: 150.0, protein: 7.5, carbs: 30.0, fat: 0.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Regular pasta", categoryName: "Pasta, Noodles & Flours", calories: 158.0, protein: 5.8, carbs: 31.0, fat: 0.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Spaghetti", categoryName: "Pasta, Noodles & Flours", calories: 158.0, protein: 5.8, carbs: 31.0, fat: 0.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Penne", categoryName: "Pasta, Noodles & Flours", calories: 158.0, protein: 5.8, carbs: 31.0, fat: 0.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fusilli", categoryName: "Pasta, Noodles & Flours", calories: 158.0, protein: 5.8, carbs: 31.0, fat: 0.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Macaroni", categoryName: "Pasta, Noodles & Flours", calories: 158.0, protein: 5.8, carbs: 31.0, fat: 0.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lasagna noodles", categoryName: "Pasta, Noodles & Flours", calories: 158.0, protein: 5.8, carbs: 31.0, fat: 0.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Rice noodles", categoryName: "Pasta, Noodles & Flours", calories: 109.0, protein: 0.9, carbs: 24.9, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Egg noodles", categoryName: "Pasta, Noodles & Flours", calories: 138.0, protein: 4.5, carbs: 25.0, fat: 2.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Soba noodles", categoryName: "Pasta, Noodles & Flours", calories: 99.0, protein: 5.1, carbs: 21.4, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Udon noodles", categoryName: "Pasta, Noodles & Flours", calories: 100.0, protein: 2.7, carbs: 21.0, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Whole-wheat flour", categoryName: "Pasta, Noodles & Flours", calories: 340.0, protein: 13.2, carbs: 72.0, fat: 2.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "All-purpose flour", categoryName: "Pasta, Noodles & Flours", calories: 364.0, protein: 10.3, carbs: 76.3, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bread flour", categoryName: "Pasta, Noodles & Flours", calories: 361.0, protein: 12.0, carbs: 75.4, fat: 1.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Oat flour", categoryName: "Pasta, Noodles & Flours", calories: 404.0, protein: 14.7, carbs: 65.7, fat: 9.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Corn flour", categoryName: "Pasta, Noodles & Flours", calories: 361.0, protein: 6.9, carbs: 76.8, fat: 3.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chickpea flour", categoryName: "Pasta, Noodles & Flours", calories: 387.0, protein: 22.4, carbs: 57.8, fat: 6.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Almond flour", categoryName: "Pasta, Noodles & Flours", calories: 590.0, protein: 21.4, carbs: 18.7, fat: 50.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Breadcrumbs", categoryName: "Pasta, Noodles & Flours", calories: 395.0, protein: 13.0, carbs: 72.0, fat: 5.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),

            // Starchy Vegetables
            FoodSeed(name: "Russet potatoes", categoryName: "Starchy Vegetables", calories: 77.0, protein: 2.0, carbs: 17.5, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Red potatoes", categoryName: "Starchy Vegetables", calories: 70.0, protein: 1.9, carbs: 15.9, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Yellow potatoes", categoryName: "Starchy Vegetables", calories: 77.0, protein: 2.0, carbs: 17.5, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Baby potatoes", categoryName: "Starchy Vegetables", calories: 75.0, protein: 2.0, carbs: 17.0, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sweet potatoes", categoryName: "Starchy Vegetables", calories: 86.0, protein: 1.6, carbs: 20.1, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Yams", categoryName: "Starchy Vegetables", calories: 118.0, protein: 1.5, carbs: 27.9, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cassava", categoryName: "Starchy Vegetables", calories: 160.0, protein: 1.4, carbs: 38.1, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Plantains", categoryName: "Starchy Vegetables", calories: 122.0, protein: 1.3, carbs: 31.9, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Green peas", categoryName: "Starchy Vegetables", calories: 81.0, protein: 5.4, carbs: 14.5, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Corn", categoryName: "Starchy Vegetables", calories: 86.0, protein: 3.3, carbs: 19.0, fat: 1.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Butternut squash", categoryName: "Starchy Vegetables", calories: 45.0, protein: 1.0, carbs: 11.7, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Acorn squash", categoryName: "Starchy Vegetables", calories: 40.0, protein: 0.8, carbs: 10.4, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Spaghetti squash", categoryName: "Starchy Vegetables", calories: 31.0, protein: 0.6, carbs: 7.0, fat: 0.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pumpkin", categoryName: "Starchy Vegetables", calories: 26.0, protein: 1.0, carbs: 6.5, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Delicata squash", categoryName: "Starchy Vegetables", calories: 34.0, protein: 0.9, carbs: 8.7, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Turnips", categoryName: "Starchy Vegetables", calories: 28.0, protein: 0.9, carbs: 6.4, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Rutabaga", categoryName: "Starchy Vegetables", calories: 37.0, protein: 1.2, carbs: 8.6, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Parsnips", categoryName: "Starchy Vegetables", calories: 75.0, protein: 1.2, carbs: 18.0, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Taro", categoryName: "Starchy Vegetables", calories: 112.0, protein: 1.5, carbs: 26.5, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Breadfruit", categoryName: "Starchy Vegetables", calories: 103.0, protein: 1.1, carbs: 27.1, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),

            // Leafy Greens & Brassicas
            FoodSeed(name: "Spinach", categoryName: "Leafy Greens & Brassicas", calories: 23.0, protein: 2.9, carbs: 3.6, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Kale", categoryName: "Leafy Greens & Brassicas", calories: 35.0, protein: 2.9, carbs: 4.4, fat: 1.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Romaine lettuce", categoryName: "Leafy Greens & Brassicas", calories: 17.0, protein: 1.2, carbs: 3.3, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Iceberg lettuce", categoryName: "Leafy Greens & Brassicas", calories: 14.0, protein: 0.9, carbs: 3.0, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Arugula", categoryName: "Leafy Greens & Brassicas", calories: 25.0, protein: 2.6, carbs: 3.7, fat: 0.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Swiss chard", categoryName: "Leafy Greens & Brassicas", calories: 19.0, protein: 1.8, carbs: 3.7, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Collard greens", categoryName: "Leafy Greens & Brassicas", calories: 32.0, protein: 3.0, carbs: 5.4, fat: 0.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mustard greens", categoryName: "Leafy Greens & Brassicas", calories: 27.0, protein: 2.9, carbs: 4.7, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Beet greens", categoryName: "Leafy Greens & Brassicas", calories: 22.0, protein: 2.2, carbs: 4.3, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bok choy", categoryName: "Leafy Greens & Brassicas", calories: 13.0, protein: 1.5, carbs: 2.2, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Napa cabbage", categoryName: "Leafy Greens & Brassicas", calories: 16.0, protein: 1.2, carbs: 3.2, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Green cabbage", categoryName: "Leafy Greens & Brassicas", calories: 25.0, protein: 1.3, carbs: 5.8, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Red cabbage", categoryName: "Leafy Greens & Brassicas", calories: 31.0, protein: 1.4, carbs: 7.4, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Savoy cabbage", categoryName: "Leafy Greens & Brassicas", calories: 27.0, protein: 2.0, carbs: 6.1, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Watercress", categoryName: "Leafy Greens & Brassicas", calories: 11.0, protein: 2.3, carbs: 1.3, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Endive", categoryName: "Leafy Greens & Brassicas", calories: 17.0, protein: 1.3, carbs: 3.4, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Radicchio", categoryName: "Leafy Greens & Brassicas", calories: 23.0, protein: 1.4, carbs: 4.5, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Spring mix", categoryName: "Leafy Greens & Brassicas", calories: 20.0, protein: 1.5, carbs: 3.5, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Microgreens", categoryName: "Leafy Greens & Brassicas", calories: 29.0, protein: 2.5, carbs: 4.0, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Dandelion greens", categoryName: "Leafy Greens & Brassicas", calories: 45.0, protein: 2.7, carbs: 9.2, fat: 0.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Broccoli", categoryName: "Leafy Greens & Brassicas", calories: 34.0, protein: 2.8, carbs: 6.6, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cauliflower", categoryName: "Leafy Greens & Brassicas", calories: 25.0, protein: 1.9, carbs: 5.0, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),

            // Other Vegetables
            FoodSeed(name: "Carrots", categoryName: "Other Vegetables", calories: 41.0, protein: 0.9, carbs: 9.6, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Bell peppers", categoryName: "Other Vegetables", calories: 26.0, protein: 1.0, carbs: 6.0, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Jalapeños", categoryName: "Other Vegetables", calories: 29.0, protein: 0.9, carbs: 6.5, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Onions", categoryName: "Other Vegetables", calories: 40.0, protein: 1.1, carbs: 9.3, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Red onions", categoryName: "Other Vegetables", calories: 40.0, protein: 1.1, carbs: 9.3, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Green onions", categoryName: "Other Vegetables", calories: 32.0, protein: 1.8, carbs: 7.3, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Garlic", categoryName: "Other Vegetables", calories: 149.0, protein: 6.4, carbs: 33.1, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Tomatoes", categoryName: "Other Vegetables", calories: 18.0, protein: 0.9, carbs: 3.9, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cherry tomatoes", categoryName: "Other Vegetables", calories: 18.0, protein: 0.9, carbs: 3.9, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cucumbers", categoryName: "Other Vegetables", calories: 15.0, protein: 0.7, carbs: 3.6, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Zucchini", categoryName: "Other Vegetables", calories: 17.0, protein: 1.2, carbs: 3.1, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Eggplant", categoryName: "Other Vegetables", calories: 25.0, protein: 1.0, carbs: 5.9, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Green beans", categoryName: "Other Vegetables", calories: 31.0, protein: 1.8, carbs: 7.0, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Asparagus", categoryName: "Other Vegetables", calories: 20.0, protein: 2.2, carbs: 3.9, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Brussels sprouts", categoryName: "Other Vegetables", calories: 43.0, protein: 3.4, carbs: 9.0, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Celery", categoryName: "Other Vegetables", calories: 14.0, protein: 0.7, carbs: 3.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mushrooms", categoryName: "Other Vegetables", calories: 22.0, protein: 3.1, carbs: 3.3, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Portobello mushrooms", categoryName: "Other Vegetables", calories: 22.0, protein: 2.1, carbs: 3.9, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Shiitake mushrooms", categoryName: "Other Vegetables", calories: 34.0, protein: 2.2, carbs: 6.8, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Beets", categoryName: "Other Vegetables", calories: 43.0, protein: 1.6, carbs: 9.6, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Radishes", categoryName: "Other Vegetables", calories: 16.0, protein: 0.7, carbs: 3.4, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Leeks", categoryName: "Other Vegetables", calories: 61.0, protein: 1.5, carbs: 14.2, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Fennel", categoryName: "Other Vegetables", calories: 31.0, protein: 1.2, carbs: 7.3, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Artichokes", categoryName: "Other Vegetables", calories: 47.0, protein: 3.3, carbs: 10.5, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Okra", categoryName: "Other Vegetables", calories: 33.0, protein: 1.9, carbs: 7.5, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Snap peas", categoryName: "Other Vegetables", calories: 42.0, protein: 2.8, carbs: 7.5, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Snow peas", categoryName: "Other Vegetables", calories: 42.0, protein: 2.8, carbs: 7.5, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Frozen mixed vegetables", categoryName: "Other Vegetables", calories: 65.0, protein: 2.6, carbs: 13.0, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),

            // Fruits
            FoodSeed(name: "Bananas", categoryName: "Fruit", calories: 89.0, protein: 1.1, carbs: 22.8, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Apples", categoryName: "Fruit", calories: 52.0, protein: 0.3, carbs: 13.8, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Oranges", categoryName: "Fruit", calories: 47.0, protein: 0.9, carbs: 11.8, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mandarins", categoryName: "Fruit", calories: 53.0, protein: 0.8, carbs: 13.3, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Grapefruit", categoryName: "Fruit", calories: 42.0, protein: 0.8, carbs: 10.7, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Lemons", categoryName: "Fruit", calories: 29.0, protein: 1.1, carbs: 9.3, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Limes", categoryName: "Fruit", calories: 30.0, protein: 0.7, carbs: 10.5, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Strawberries", categoryName: "Fruit", calories: 32.0, protein: 0.7, carbs: 7.7, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Blueberries", categoryName: "Fruit", calories: 57.0, protein: 0.7, carbs: 14.5, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Raspberries", categoryName: "Fruit", calories: 52.0, protein: 1.2, carbs: 11.9, fat: 0.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Blackberries", categoryName: "Fruit", calories: 43.0, protein: 1.4, carbs: 9.6, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cranberries", categoryName: "Fruit", calories: 46.0, protein: 0.4, carbs: 12.2, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Grapes", categoryName: "Fruit", calories: 69.0, protein: 0.7, carbs: 18.1, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Watermelon", categoryName: "Fruit", calories: 30.0, protein: 0.6, carbs: 7.6, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cantaloupe", categoryName: "Fruit", calories: 34.0, protein: 0.8, carbs: 8.2, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Honeydew melon", categoryName: "Fruit", calories: 36.0, protein: 0.5, carbs: 9.1, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pineapple", categoryName: "Fruit", calories: 50.0, protein: 0.5, carbs: 13.1, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mangoes", categoryName: "Fruit", calories: 60.0, protein: 0.8, carbs: 15.0, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Papaya", categoryName: "Fruit", calories: 43.0, protein: 0.5, carbs: 10.8, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Peaches", categoryName: "Fruit", calories: 39.0, protein: 0.9, carbs: 9.5, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Nectarines", categoryName: "Fruit", calories: 44.0, protein: 1.1, carbs: 10.6, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Plums", categoryName: "Fruit", calories: 46.0, protein: 0.7, carbs: 11.4, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pears", categoryName: "Fruit", calories: 57.0, protein: 0.4, carbs: 15.2, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cherries", categoryName: "Fruit", calories: 63.0, protein: 1.1, carbs: 16.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Kiwi", categoryName: "Fruit", calories: 61.0, protein: 1.1, carbs: 14.7, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pomegranate", categoryName: "Fruit", calories: 83.0, protein: 1.7, carbs: 18.7, fat: 1.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Avocado", categoryName: "Fruit", calories: 160.0, protein: 2.0, carbs: 8.5, fat: 14.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Dates", categoryName: "Fruit", calories: 277.0, protein: 1.8, carbs: 75.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Figs", categoryName: "Fruit", calories: 74.0, protein: 0.8, carbs: 19.2, fat: 0.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Apricots", categoryName: "Fruit", calories: 48.0, protein: 1.4, carbs: 11.1, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Passion fruit", categoryName: "Fruit", calories: 97.0, protein: 2.2, carbs: 23.4, fat: 0.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Guava", categoryName: "Fruit", calories: 68.0, protein: 2.6, carbs: 14.3, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Dragon fruit", categoryName: "Fruit", calories: 60.0, protein: 1.2, carbs: 13.0, fat: 0.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Coconut", categoryName: "Fruit", calories: 354.0, protein: 3.3, carbs: 15.2, fat: 33.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Unsweetened applesauce", categoryName: "Fruit", calories: 42.0, protein: 0.2, carbs: 11.3, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Frozen berries", categoryName: "Fruit", calories: 50.0, protein: 0.8, carbs: 12.0, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Frozen mango", categoryName: "Fruit", calories: 60.0, protein: 0.8, carbs: 15.0, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Raisins", categoryName: "Fruit", calories: 299.0, protein: 3.1, carbs: 79.2, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Dried cranberries", categoryName: "Fruit", calories: 308.0, protein: 0.1, carbs: 82.8, fat: 1.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Prunes", categoryName: "Fruit", calories: 240.0, protein: 2.2, carbs: 63.9, fat: 0.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),

            // Nuts & Seeds
            FoodSeed(name: "Almonds", categoryName: "Nuts & Seeds", calories: 579.0, protein: 21.2, carbs: 21.6, fat: 49.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Walnuts", categoryName: "Nuts & Seeds", calories: 654.0, protein: 15.2, carbs: 13.7, fat: 65.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cashews", categoryName: "Nuts & Seeds", calories: 553.0, protein: 18.2, carbs: 30.2, fat: 43.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pistachios", categoryName: "Nuts & Seeds", calories: 560.0, protein: 20.2, carbs: 27.2, fat: 45.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pecans", categoryName: "Nuts & Seeds", calories: 691.0, protein: 9.2, carbs: 13.9, fat: 72.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Hazelnuts", categoryName: "Nuts & Seeds", calories: 628.0, protein: 15.0, carbs: 16.7, fat: 60.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Brazil nuts", categoryName: "Nuts & Seeds", calories: 659.0, protein: 14.3, carbs: 12.3, fat: 67.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Peanuts", categoryName: "Nuts & Seeds", calories: 567.0, protein: 25.8, carbs: 16.1, fat: 49.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Macadamia nuts", categoryName: "Nuts & Seeds", calories: 718.0, protein: 7.9, carbs: 13.8, fat: 75.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pine nuts", categoryName: "Nuts & Seeds", calories: 673.0, protein: 13.7, carbs: 13.1, fat: 68.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Pumpkin seeds", categoryName: "Nuts & Seeds", calories: 559.0, protein: 30.2, carbs: 10.7, fat: 49.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sunflower seeds", categoryName: "Nuts & Seeds", calories: 584.0, protein: 20.8, carbs: 20.0, fat: 51.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chia seeds", categoryName: "Nuts & Seeds", calories: 486.0, protein: 16.5, carbs: 42.1, fat: 30.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ground flaxseed", categoryName: "Nuts & Seeds", calories: 534.0, protein: 18.3, carbs: 28.9, fat: 42.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sesame seeds", categoryName: "Nuts & Seeds", calories: 573.0, protein: 17.7, carbs: 23.4, fat: 49.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Hemp seeds", categoryName: "Nuts & Seeds", calories: 553.0, protein: 31.6, carbs: 8.7, fat: 48.8, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Poppy seeds", categoryName: "Nuts & Seeds", calories: 525.0, protein: 18.0, carbs: 28.1, fat: 41.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Peanut butter", categoryName: "Nuts & Seeds", calories: 588.0, protein: 25.1, carbs: 20.0, fat: 50.4, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Almond butter", categoryName: "Nuts & Seeds", calories: 614.0, protein: 21.0, carbs: 18.8, fat: 55.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Tahini", categoryName: "Nuts & Seeds", calories: 595.0, protein: 17.0, carbs: 21.2, fat: 53.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),

            // Fats & Oils
            FoodSeed(name: "Extra-virgin olive oil", categoryName: "Fats & Oils", calories: 884.0, protein: 0.0, carbs: 0.0, fat: 100.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Light olive oil", categoryName: "Fats & Oils", calories: 884.0, protein: 0.0, carbs: 0.0, fat: 100.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Avocado oil", categoryName: "Fats & Oils", calories: 884.0, protein: 0.0, carbs: 0.0, fat: 100.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Canola oil", categoryName: "Fats & Oils", calories: 884.0, protein: 0.0, carbs: 0.0, fat: 100.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sesame oil", categoryName: "Fats & Oils", calories: 884.0, protein: 0.0, carbs: 0.0, fat: 100.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Peanut oil", categoryName: "Fats & Oils", calories: 884.0, protein: 0.0, carbs: 0.0, fat: 100.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sunflower oil", categoryName: "Fats & Oils", calories: 884.0, protein: 0.0, carbs: 0.0, fat: 100.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Coconut oil", categoryName: "Fats & Oils", calories: 862.0, protein: 0.0, carbs: 0.0, fat: 100.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Butter", categoryName: "Fats & Oils", calories: 717.0, protein: 0.9, carbs: 0.1, fat: 81.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ghee", categoryName: "Fats & Oils", calories: 876.0, protein: 0.3, carbs: 0.0, fat: 99.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),

            // Condiments & Sauces
            FoodSeed(name: "Tomato paste", categoryName: "Condiments & Sauces", calories: 82.0, protein: 4.3, carbs: 18.9, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Tomato sauce", categoryName: "Condiments & Sauces", calories: 29.0, protein: 1.3, carbs: 6.6, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Canned diced tomatoes", categoryName: "Condiments & Sauces", calories: 17.0, protein: 0.8, carbs: 3.8, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Crushed tomatoes", categoryName: "Condiments & Sauces", calories: 32.0, protein: 1.6, carbs: 7.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Salsa", categoryName: "Condiments & Sauces", calories: 36.0, protein: 1.5, carbs: 7.0, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Soy sauce", categoryName: "Condiments & Sauces", calories: 53.0, protein: 8.1, carbs: 4.9, fat: 0.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Low-sodium soy sauce", categoryName: "Condiments & Sauces", calories: 53.0, protein: 8.1, carbs: 4.9, fat: 0.6, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Dijon mustard", categoryName: "Condiments & Sauces", calories: 66.0, protein: 4.4, carbs: 5.8, fat: 3.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Yellow mustard", categoryName: "Condiments & Sauces", calories: 60.0, protein: 3.7, carbs: 5.0, fat: 3.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Mayonnaise", categoryName: "Condiments & Sauces", calories: 680.0, protein: 1.0, carbs: 0.6, fat: 75.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Greek-yogurt dressing", categoryName: "Condiments & Sauces", calories: 120.0, protein: 3.0, carbs: 5.0, fat: 10.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Hot sauce", categoryName: "Condiments & Sauces", calories: 11.0, protein: 0.5, carbs: 1.8, fat: 0.2, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Sriracha", categoryName: "Condiments & Sauces", calories: 90.0, protein: 1.8, carbs: 18.0, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Worcestershire sauce", categoryName: "Condiments & Sauces", calories: 78.0, protein: 0.0, carbs: 19.0, fat: 0.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Balsamic vinegar", categoryName: "Condiments & Sauces", calories: 88.0, protein: 0.5, carbs: 17.0, fat: 0.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Apple cider vinegar", categoryName: "Condiments & Sauces", calories: 21.0, protein: 0.0, carbs: 0.9, fat: 0.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Rice vinegar", categoryName: "Condiments & Sauces", calories: 18.0, protein: 0.0, carbs: 0.0, fat: 0.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Red-wine vinegar", categoryName: "Condiments & Sauces", calories: 19.0, protein: 0.1, carbs: 0.3, fat: 0.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Vegetable broth", categoryName: "Condiments & Sauces", calories: 12.0, protein: 0.4, carbs: 2.4, fat: 0.1, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chicken broth", categoryName: "Condiments & Sauces", calories: 15.0, protein: 1.6, carbs: 0.7, fat: 0.5, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Salt", categoryName: "Condiments & Sauces", calories: 0.0, protein: 0.0, carbs: 0.0, fat: 0.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Black pepper", categoryName: "Condiments & Sauces", calories: 251.0, protein: 10.4, carbs: 64.0, fat: 3.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Paprika", categoryName: "Condiments & Sauces", calories: 282.0, protein: 14.1, carbs: 54.0, fat: 12.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Smoked paprika", categoryName: "Condiments & Sauces", calories: 282.0, protein: 14.1, carbs: 54.0, fat: 12.9, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Garlic powder", categoryName: "Condiments & Sauces", calories: 331.0, protein: 16.6, carbs: 72.7, fat: 0.7, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Onion powder", categoryName: "Condiments & Sauces", calories: 341.0, protein: 10.1, carbs: 79.1, fat: 1.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Chili powder", categoryName: "Condiments & Sauces", calories: 282.0, protein: 13.5, carbs: 49.7, fat: 14.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Ground cumin", categoryName: "Condiments & Sauces", calories: 375.0, protein: 17.8, carbs: 44.2, fat: 22.3, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Italian seasoning", categoryName: "Condiments & Sauces", calories: 260.0, protein: 10.0, carbs: 50.0, fat: 8.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Curry powder", categoryName: "Condiments & Sauces", calories: 325.0, protein: 14.3, carbs: 55.8, fat: 14.0, servingName: "100 g portion", servingAmount: 100, equivalentRefAmount: 100)
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
