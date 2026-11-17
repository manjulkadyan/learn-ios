import WorkshopKit

let catalog = try Catalog.bundled()
precondition(catalog.cards.count == 2)
precondition(catalog.totalMinutes() == 40)
print("consumer: \(catalog.cards.count) cards, \(catalog.totalMinutes()) minutes")
print(catalog.card(id: "blue")?.title ?? "missing")
