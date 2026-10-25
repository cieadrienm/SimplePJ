import Foundation
import SimplePJMCPCore

let base = apiBaseURL()
let server = SimplePJMCPServer(transport: urlSessionTransport(base: base), apiBase: base)
server.run()
