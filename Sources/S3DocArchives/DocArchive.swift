// Copyright 2020-2022 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Foundation
import Parsing
import SotoS3


public struct DocArchive: Codable, Equatable {
    public var path: Path
    public var title: String

    public init(path: Path, title: String) {
        self.path = path
        self.title = title
    }

#if DEBUG
    // for unit testing purposes only
    static func mock(_ owner: String = "foo",
                     _ repository: String = "bar",
                     _ ref: String = "ref",
                     _ product: String = "product",
                     _ title: String = "Product") -> Self {
        .init(path: .init(owner: owner, repository: repository, ref: ref, product: product),
              title: title)
    }
#endif
}


public extension DocArchive {

    static func fetchAll(prefix: String,
                         awsBucketName: String,
                         awsAccessKeyId: String,
                         awsSecretAccessKey: String,
                         verbose: Bool) async throws -> [DocArchive] {
        var requestCount = 0
        defer {
            if verbose {
                print("Total number of AWS requests: \(requestCount)")
            }
        }
        let client = AWSClient(credentialProvider: .static(accessKeyId: awsAccessKeyId,
                                                           secretAccessKey: awsSecretAccessKey),
                               httpClientProvider: .createNew)
        defer { try? client.syncShutdown() }

        let s3 = S3(client: client, region: .useast2)

        let docFolder = prefix.appendingPathSegment("documentation")
        let key = S3.StoreKey(bucket: awsBucketName, path: docFolder)
        requestCount += 1
        let paths = try await Current.listFolders(s3, key)
        if verbose {
            print("Documentation paths found (\(paths.count)):")
            for p in paths {
                print(p)
            }
        }

        let docPaths =  paths.compactMap { try? path.parse($0) }

        var archives = [DocArchive]()
        for path in docPaths {
            requestCount += 1
            let title = await getTitle(s3: s3, bucket: awsBucketName, path: path)
            archives.append(DocArchive(path: path, title: title))
        }

        return archives
    }

    static func getTitle(s3: S3, bucket: String, path: DocArchive.Path) async -> String {
        let key = S3.StoreKey(bucket: bucket,
                              path: path.s3path + "/data/documentation/\(path.product).json")
        do {
            guard let data = try await Current.getFileContent(s3, key) else { return path.product }
            return try JSONDecoder().decode(DocArchive.DocumentationData.self, from: data)
                .metadata.title
        } catch {
            return path.product
        }
    }

}


extension DocArchive {
    public struct Path: Codable, Equatable {
        public var owner: String
        public var repository: String
        public var ref: String
        public var product: String

        public init(owner: String, repository: String, ref: String, product: String) {
            self.owner = owner
            self.repository = repository
            self.ref = ref
            self.product = product
        }

        var s3path: String { "\(owner)/\(repository)/\(ref)" }
    }
}


extension DocArchive {
    struct DocumentationData: Codable, Equatable {
        var metadata: Metadata

        struct Metadata: Codable, Equatable {
            var title: String
        }
    }
}


// MARK: CustomStringConvertible

extension DocArchive: CustomStringConvertible {
    public var description: String {
        "\(path) - \(title)"
    }
}


extension DocArchive.Path: CustomStringConvertible {
    public var description: String {
        "\(owner)/\(repository) @ \(ref) - \(product)"
    }
}


// MARK: - Parsers

extension DocArchive {
    static let pathSegment = Parse {
        PrefixUpTo("/").map(.string)
        "/"
    }

    static let path = Parse(DocArchive.Path.init) {
        pathSegment
        pathSegment
        pathSegment
        "documentation/"
        pathSegment
    }
}


extension String {
    func appendingPathSegment(_ segment: String) -> String {
        self.hasSuffix("/")
        ? self + segment
        : self + "/" + segment
    }
}