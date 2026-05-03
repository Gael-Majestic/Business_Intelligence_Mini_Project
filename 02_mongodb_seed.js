// ============================================================
// DMS580S Mini Project 2026
// Domain: Online Electronics Retail
// OLTP Behavioral System: MongoDB
// Collection: customer_activity
// ============================================================
//
// Run in mongosh:
//   use electronics_retail_behavior
//   load("02_mongodb_seed.js")
//
// Or via mongoimport (after exporting the array to JSON):
//   mongoimport --db electronics_retail_behavior \
//               --collection customer_activity    \
//               --file activities.json --jsonArray

db = db.getSiblingDB("electronics_retail_behavior");
db.customer_activity.drop();

db.customer_activity.insertMany([
    // --- Alice Dlamini: iPhone 15 Pro journey ---
    {
        session_id:    "sess-001",
        customer_name: "Alice Dlamini",
        product:       "iPhone 15 Pro",
        activity:      "Viewed",
        device:        "Mobile",
        timestamp:     ISODate("2026-01-03T10:15:00Z")
    },
    {
        session_id:    "sess-001",
        customer_name: "Alice Dlamini",
        product:       "iPhone 15 Pro",
        activity:      "Added to Cart",
        device:        "Mobile",
        timestamp:     ISODate("2026-01-04T14:30:00Z")
    },
    // --- Bob Sithole: Samsung Galaxy S24 journey ---
    {
        session_id:    "sess-002",
        customer_name: "Bob Sithole",
        product:       "Samsung Galaxy S24",
        activity:      "Viewed",
        device:        "Desktop",
        timestamp:     ISODate("2026-01-07T09:00:00Z")
    },
    {
        session_id:    "sess-002",
        customer_name: "Bob Sithole",
        product:       "Samsung Galaxy S24",
        activity:      "Added to Cart",
        device:        "Desktop",
        timestamp:     ISODate("2026-01-07T11:30:00Z")
    },
    // --- Claire Nkosi: MacBook Pro 14" ---
    {
        session_id:    "sess-003",
        customer_name: "Claire Nkosi",
        product:       "MacBook Pro 14\"",
        activity:      "Viewed",
        device:        "Desktop",
        timestamp:     ISODate("2026-01-09T16:00:00Z")
    },
    // --- David Molefe: AirPods Pro ---
    {
        session_id:    "sess-004",
        customer_name: "David Molefe",
        product:       "AirPods Pro",
        activity:      "Viewed",
        device:        "Mobile",
        timestamp:     ISODate("2026-01-11T13:00:00Z")
    },
    {
        session_id:    "sess-004",
        customer_name: "David Molefe",
        product:       "AirPods Pro",
        activity:      "Added to Cart",
        device:        "Mobile",
        timestamp:     ISODate("2026-01-11T15:00:00Z")
    },
    // --- Emma Kamau: Dell XPS 15 ---
    {
        session_id:    "sess-005",
        customer_name: "Emma Kamau",
        product:       "Dell XPS 15",
        activity:      "Viewed",
        device:        "Tablet",
        timestamp:     ISODate("2026-01-14T10:00:00Z")
    },
    {
        session_id:    "sess-005",
        customer_name: "Emma Kamau",
        product:       "Dell XPS 15",
        activity:      "Purchased",
        device:        "Tablet",
        timestamp:     ISODate("2026-01-15T09:00:00Z")
    },
    // --- Frank Osei: Sony WH-1000XM5 ---
    {
        session_id:    "sess-006",
        customer_name: "Frank Osei",
        product:       "Sony WH-1000XM5",
        activity:      "Viewed",
        device:        "Desktop",
        timestamp:     ISODate("2026-01-17T11:00:00Z")
    },
    // --- Grace Mbeki: Samsung 4K Monitor ---
    {
        session_id:    "sess-007",
        customer_name: "Grace Mbeki",
        product:       "Samsung 4K Monitor",
        activity:      "Viewed",
        device:        "Desktop",
        timestamp:     ISODate("2026-01-19T14:00:00Z")
    },
    {
        session_id:    "sess-007",
        customer_name: "Grace Mbeki",
        product:       "Samsung 4K Monitor",
        activity:      "Purchased",
        device:        "Desktop",
        timestamp:     ISODate("2026-01-20T10:30:00Z")
    },
    // --- Henri van Wyk: iPhone 15 Pro ---
    {
        session_id:    "sess-008",
        customer_name: "Henri van Wyk",
        product:       "iPhone 15 Pro",
        activity:      "Viewed",
        device:        "Mobile",
        timestamp:     ISODate("2026-01-21T16:00:00Z")
    },
    // --- Isabelle Botha: Google Pixel 8 Pro ---
    {
        session_id:    "sess-009",
        customer_name: "Isabelle Botha",
        product:       "Google Pixel 8 Pro",
        activity:      "Viewed",
        device:        "Mobile",
        timestamp:     ISODate("2026-01-24T09:30:00Z")
    },
    {
        session_id:    "sess-009",
        customer_name: "Isabelle Botha",
        product:       "Google Pixel 8 Pro",
        activity:      "Added to Cart",
        device:        "Mobile",
        timestamp:     ISODate("2026-01-24T12:00:00Z")
    },
    // --- James Khumalo: Logitech MX Master 3 ---
    {
        session_id:    "sess-010",
        customer_name: "James Khumalo",
        product:       "Logitech MX Master 3",
        activity:      "Viewed",
        device:        "Desktop",
        timestamp:     ISODate("2026-01-27T10:00:00Z")
    },
    // --- Karen Pietersen: LG UltraWide Monitor ---
    {
        session_id:    "sess-011",
        customer_name: "Karen Pietersen",
        product:       "LG UltraWide Monitor",
        activity:      "Viewed",
        device:        "Desktop",
        timestamp:     ISODate("2026-01-30T15:00:00Z")
    },
    {
        session_id:    "sess-011",
        customer_name: "Karen Pietersen",
        product:       "LG UltraWide Monitor",
        activity:      "Added to Cart",
        device:        "Desktop",
        timestamp:     ISODate("2026-02-01T09:00:00Z")
    },
    // --- Louis Ferreira: HP Spectre x360 (full funnel) ---
    {
        session_id:    "sess-012",
        customer_name: "Louis Ferreira",
        product:       "HP Spectre x360",
        activity:      "Viewed",
        device:        "Tablet",
        timestamp:     ISODate("2026-02-02T11:00:00Z")
    },
    {
        session_id:    "sess-012",
        customer_name: "Louis Ferreira",
        product:       "HP Spectre x360",
        activity:      "Purchased",
        device:        "Tablet",
        timestamp:     ISODate("2026-02-03T10:00:00Z")
    }
]);

print("Inserted " + db.customer_activity.countDocuments() + " activity records.");
print("Activity breakdown:");
db.customer_activity.aggregate([
    { $group: { _id: "$activity", count: { $sum: 1 } } },
    { $sort:  { count: -1 } }
]).forEach(printjson);
