import Foundation

public struct DirectoryScanner: @unchecked Sendable {
    private let fileManager: FileManager
    private let maxDependencyDepth = 20
    private let maxProjectDiscoveryDepth = 8

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public static let projectFileIndicators: Set<String> = [
        // JavaScript / TypeScript
        "package.json",
        // Rust
        "Cargo.toml",
        // Python
        "requirements.txt", "setup.py", "pyproject.toml", "Pipfile", "setup.cfg",
        // Go
        "go.mod",
        // Ruby
        "Gemfile",
        // Java / Kotlin
        "pom.xml", "build.gradle", "build.gradle.kts",
        // iOS / macOS
        "Podfile", "Package.swift",
        // Dart / Flutter
        "pubspec.yaml",
        // C / C++
        "Makefile", "CMakeLists.txt", "meson.build",
        // PHP
        "composer.json",
        // C# / .NET
        "*.sln", "*.csproj",
        // Elixir
        "mix.exs",
        // Haskell
        "stack.yaml", "cabal.project",
    ]

    public static let projectDirIndicators: Set<String> = [".git", ".svn", ".hg"]

    public func isProject(at url: URL) -> Bool {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil,
            options: [.skipsSubdirectoryDescendants]
        ) else { return false }

        for item in contents {
            let name = item.lastPathComponent
            if Self.projectFileIndicators.contains(name) { return true }
            if name.hasSuffix(".sln") || name.hasSuffix(".csproj") { return true }
            if Self.projectDirIndicators.contains(name) {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    return true
                }
            }
        }
        return false
    }

    /// Recursively scan a project directory for dependency directories.
    public func scanDependencies(in projectURL: URL) throws -> [DependencyItem] {
        var items: [DependencyItem] = []
        let resolvedRoot = projectURL.standardizedFileURL.resolvingSymlinksInPath()
        try scanDependenciesRecursive(
            in: resolvedRoot,
            projectRoot: resolvedRoot,
            items: &items,
            depth: 0,
            maxDepth: maxDependencyDepth
        )
        return items
    }

    private func scanDependenciesRecursive(
        in directoryURL: URL,
        projectRoot: URL,
        items: inout [DependencyItem],
        depth: Int,
        maxDepth: Int
    ) throws {
        guard depth <= maxDepth else { return }

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsSubdirectoryDescendants]
            )
        } catch {
            return
        }

        for item in contents {
            let name = item.lastPathComponent
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDir),
                  isDir.boolValue,
                  !isSymbolicLink(item) else { continue }

            if let type = dependencyType(for: item) {
                let resolvedItem = item.resolvingSymlinksInPath()
                let relativePath = computeRelativePath(from: projectRoot, to: resolvedItem)
                let modDate = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                items.append(DependencyItem(
                    path: resolvedItem, type: type,
                    relativePath: relativePath,
                    modificationDate: modDate
                ))
            } else {
                // Do not walk VCS internals, but allow hidden parent directories such as
                // .claude to contain a discoverable virtual environment or build directory.
                if Self.projectDirIndicators.contains(name) { continue }
                // Recurse into subdirectories (e.g. packages/xxx/node_modules in monorepo)
                try scanDependenciesRecursive(
                    in: item, projectRoot: projectRoot,
                    items: &items, depth: depth + 1, maxDepth: maxDepth
                )
            }
        }
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
    }

    private func dependencyType(for url: URL) -> DependencyType? {
        let name = url.lastPathComponent
        if let type = DependencyType(rawValue: name) {
            if type == .bin && !isBuildBinDirectory(url) {
                return nil
            }
            return type
        }

        if name.hasPrefix("cmake-build-") {
            return .cmakeBuild
        }

        let parentName = url.deletingLastPathComponent().lastPathComponent
        if parentName == "Carthage", name == "Build" {
            return .carthageBuild
        }
        if parentName == "Library", name == "Caches" {
            return .libraryCaches
        }

        return nil
    }

    private func isBuildBinDirectory(_ url: URL) -> Bool {
        let parentName = url.deletingLastPathComponent().lastPathComponent
        if parentName.hasPrefix("cmake-build-") {
            return true
        }

        let buildParents: Set<String> = [
            "build", ".build", "out", "target", "dist", "DerivedData",
            "bazel-bin", "bazel-out", ".cxx", ".externalNativeBuild"
        ]
        return buildParents.contains(parentName)
    }

    private func computeRelativePath(from root: URL, to target: URL) -> String {
        let rootComponents = root.pathComponents
        let targetComponents = target.pathComponents
        guard targetComponents.count > rootComponents.count else { return target.lastPathComponent }
        return targetComponents[rootComponents.count...].joined(separator: "/")
    }

    public func scanProjects(at rootURL: URL) throws -> [ProjectInfo] {
        var projects: [ProjectInfo] = []
        try discoverProjects(
            in: rootURL.standardizedFileURL,
            projects: &projects,
            depth: 0
        )
        return projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func discoverProjects(
        in directoryURL: URL,
        projects: inout [ProjectInfo],
        depth: Int
    ) throws {
        guard depth <= maxProjectDiscoveryDepth else { return }

        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsSubdirectoryDescendants]
        )

        for item in contents {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDir),
                  isDir.boolValue,
                  !isSymbolicLink(item) else { continue }

            let name = item.lastPathComponent
            if dependencyType(for: item) != nil {
                continue
            }
            if Self.projectDirIndicators.contains(name) { continue }

            if isProject(at: item) {
                let deps = try scanDependencies(in: item)
                if !deps.isEmpty {
                    projects.append(ProjectInfo(path: item, dependencies: deps))
                }
                continue
            }

            try discoverProjects(in: item, projects: &projects, depth: depth + 1)
        }
    }
}
