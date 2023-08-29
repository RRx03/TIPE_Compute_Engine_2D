import SwiftUI

@main
struct TIPE_Compute_Engine_2DApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().frame(width: commonVariables.width, height: commonVariables.height, alignment: .center).fixedSize()
        }.windowResizability(.contentSize)
    }
}
