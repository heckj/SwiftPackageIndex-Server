// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Vapor
import VaporToOpenAPI


struct User: Authenticatable {
    var name: String
}


extension User {
    static var builder: Self { .init(name: "builder") }

    struct BuilderAuthenticator: BearerAuthenticator {
        func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
            if let builderToken = Current.builderToken(),
               bearer.token == builderToken {
                request.auth.login(User.builder)
            }
            return request.eventLoop.makeSucceededFuture(())
        }
    }
}


extension AuthSchemeObject {
    static var builderBearer: Self {
        .bearer(id: "builder_token",
               description: "Builder token used for build result reporting.")
    }
}
