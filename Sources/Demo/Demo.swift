import MetalEngine

@main
struct Main {
    static func main() {
        print(Engine().text)
    }
}

import SwiftUI

struct ContentView: View {
    var body: some View {
        Text(Engine().text)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
