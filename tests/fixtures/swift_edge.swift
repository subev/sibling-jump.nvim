struct Edge {
    func a() {
        first()
// commented out at column zero
        second()
        third()
    }

    func b() {
        let names = users
            .filter { $0.active }
            .map { $0.name }
        print(names)
    }
}
