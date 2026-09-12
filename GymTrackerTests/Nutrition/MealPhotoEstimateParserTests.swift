import XCTest
@testable import GymTracker

final class MealPhotoEstimateParserTests: XCTestCase {
    func testParsesCamelCasePayloadAndDropsBlankNames() throws {
        let raw = """
        {"unclear": false, "items": [
          {"name": "Chicken", "grams": 180, "calories": 280, "proteinGrams": 40, "carbohydrateGrams": 0, "fatGrams": 8},
          {"name": "  ", "calories": 10}
        ]}
        """
        let draft = try MealPhotoEstimateParser.parse(raw)
        XCTAssertFalse(draft.unclear)
        XCTAssertEqual(draft.items.count, 1)
        XCTAssertEqual(draft.items[0].name, "Chicken")
        XCTAssertEqual(draft.items[0].grams, 180)
        XCTAssertEqual(draft.items[0].proteinGrams, 40)
        XCTAssertEqual(draft.items[0].loggingName, "Chicken (180 g)")
    }

    func testParsesSnakeCaseAndMarkdownFences() throws {
        let raw = """
        ```json
        {"unclear": true, "items": [{"name": "Rice", "protein_grams": 5, "carbohydrate_grams": 56, "fat_grams": 1}]}
        ```
        """
        let draft = try MealPhotoEstimateParser.parse(raw)
        XCTAssertTrue(draft.unclear)
        XCTAssertEqual(draft.items.count, 1)
        XCTAssertEqual(draft.items[0].name, "Rice")
        XCTAssertEqual(draft.items[0].proteinGrams, 5)
        XCTAssertEqual(draft.items[0].carbohydrateGrams, 56)
        XCTAssertNil(draft.items[0].calories)
    }

    func testNullNutrientsStayUnknown() throws {
        let draft = try MealPhotoEstimateParser.parse(
            #"{"unclear":false,"items":[{"name":"Oats","grams":null,"calories":null,"proteinGrams":12}]}"#
        )
        XCTAssertEqual(draft.items[0].name, "Oats")
        XCTAssertNil(draft.items[0].grams)
        XCTAssertNil(draft.items[0].calories)
        XCTAssertEqual(draft.items[0].proteinGrams, 12)
        XCTAssertEqual(draft.items[0].loggingName, "Oats")
    }

    func testInvalidPayloadThrows() {
        XCTAssertThrowsError(try MealPhotoEstimateParser.parse("not json"))
    }

    @MainActor
    func testLibraryHintMatchesLocalNameWithoutInventingAFood() {
        let chicken = FoodItem(name: "Chicken breast")
        chicken.frenchName = "Poitrine de poulet"
        chicken.searchAliases = ["poulet"]
        XCTAssertEqual(
            MealPhotoLibraryHint.matchingFoodName(for: "chicken", in: [chicken]),
            "Chicken breast"
        )
        XCTAssertNil(MealPhotoLibraryHint.matchingFoodName(for: "Mystery stew", in: [chicken]))
    }
}

final class GeminiAPIKeyStoreTests: XCTestCase {
    private var store: GeminiAPIKeyStore!

    override func setUp() {
        super.setUp()
        store = GeminiAPIKeyStore(service: "felix.GymTracker.geminiAPIKey.tests.\(UUID().uuidString)")
        store.delete()
    }

    override func tearDown() {
        store.delete()
        store = nil
        super.tearDown()
    }

    func testSaveLoadAndDeleteRoundTrip() throws {
        XCTAssertFalse(store.hasKey)
        try store.save("  test-key  ")
        XCTAssertEqual(store.load(), "test-key")
        XCTAssertTrue(store.hasKey)
        store.delete()
        XCTAssertNil(store.load())
        XCTAssertFalse(store.hasKey)
    }

    func testEmptyKeyIsRejected() {
        XCTAssertThrowsError(try store.save("   ")) { error in
            XCTAssertEqual(error as? GeminiAPIKeyStoreError, .emptyKey)
        }
        XCTAssertFalse(store.hasKey)
    }
}
