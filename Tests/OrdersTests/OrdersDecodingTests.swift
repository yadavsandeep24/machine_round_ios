import Foundation
import Testing
@testable import Orders

@Suite struct OrdersDecodingTests {
    let page = try! OrdersDecoder.shared.decode(OrdersPage.self, from: Data(SampleOrders.json.utf8))

    @Test func snakeCaseAndRenamedKeys() {
        #expect(page.nextCursor == "c_42")
        #expect(page.items.first?.id == 101)
        #expect(page.items.first?.itemsCount == 3)
    }

    @Test func oneMalformedItemIsSkippedNotFatal() {
        #expect(page.items.map(\.id) == [101, 102, 104])
        #expect(page.$items.skipped.count == 1)
    }

    @Test func datesWithAndWithoutFractionalSeconds() throws {
        let second = try #require(page.items.first { $0.id == 102 })
        #expect(second.createdAt.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) == 0.25)
    }

    @Test func moneyIsAnExactDecimal() {
        let total = page.items.reduce(Decimal.zero) { $0 + $1.amount }
        #expect(total == Decimal(string: "1350.59"))
    }

    @Test func missingVersusNullVersusDefault() throws {
        let second = try #require(page.items.first { $0.id == 102 })
        #expect(second.couponCode == nil) // explicit null
        #expect(second.itemsCount == 0) // missing → default
    }

    @Test func unknownStatusDoesNotCrash() {
        #expect(page.items.last?.status == .unknown("refunded_partial"))
    }

    @Test func aBadDateFailsThatItemOnly() throws {
        let json = #"{"items":[{"order_id":1,"created_at":"yesterday","amount":"1","currency":"INR","status":"placed"}]}"#
        let page = try OrdersDecoder.shared.decode(OrdersPage.self, from: Data(json.utf8))
        #expect(page.items.isEmpty)
        #expect(page.nextCursor == nil)
    }
}
