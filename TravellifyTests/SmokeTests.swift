import Testing

@Suite("Smoke")
struct SmokeTests {
    @Test func scaffoldBuilds() {
        #expect(1 + 1 == 2)
    }
}
