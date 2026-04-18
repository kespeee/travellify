import SwiftUI
import SwiftData

struct TripEditSheet: View {
    enum Mode {
        case create
        case edit(Trip)
    }
    let mode: Mode

    var body: some View {
        Text("Trip edit sheet — replaced in plan 04")
    }
}
