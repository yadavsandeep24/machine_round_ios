import Foundation

public enum SampleOrders {
    public static let json = """
    {
      "next_cursor": "c_42",
      "items": [
        {"order_id": 101, "created_at": "2026-11-20T10:15:30Z", "amount": "1250.50", "currency": "INR",
         "status": "delivered", "coupon_code": "SAVE10", "items_count": 3},
        {"order_id": 102, "created_at": "2026-11-20T11:00:00.250Z", "amount": "99.99", "currency": "INR",
         "status": "placed", "coupon_code": null},
        {"created_at": "2026-11-20T12:00:00Z", "amount": "10.00", "currency": "INR", "status": "placed"},
        {"order_id": 104, "created_at": "2026-11-21T09:30:00Z", "amount": "0.10", "currency": "INR",
         "status": "refunded_partial", "items_count": 1}
      ]
    }
    """
}
