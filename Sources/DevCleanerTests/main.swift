import Foundation
import DevCleanerLib
import TestKit

let fm = FileManager.default

func makeTempDir() -> URL {
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! fm.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

func cleanUp(_ url: URL) {
    try? fm.removeItem(at: url)
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DirectoryScanner Tests
// ═══════════════════════════════════════════════════════════════
print("\n📂 DirectoryScanner Tests")
print("─────────────────────────────────")

TestRunner.run("isProject: package.json → true") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("my-node-app")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("package.json").path, contents: nil)

    let scanner = DirectoryScanner()
    try assertTrue(scanner.isProject(at: proj))
}

TestRunner.run("isProject: Cargo.toml → true") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("my-rust-app")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("Cargo.toml").path, contents: nil)

    let scanner = DirectoryScanner()
    try assertTrue(scanner.isProject(at: proj))
}

TestRunner.run("isProject: requirements.txt → true") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("my-py-app")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("requirements.txt").path, contents: nil)

    let scanner = DirectoryScanner()
    try assertTrue(scanner.isProject(at: proj))
}

TestRunner.run("isProject: pyproject.toml → true") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("modern-py")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("pyproject.toml").path, contents: nil)

    let scanner = DirectoryScanner()
    try assertTrue(scanner.isProject(at: proj))
}

TestRunner.run("isProject: go.mod → true") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("go-app")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("go.mod").path, contents: nil)

    let scanner = DirectoryScanner()
    try assertTrue(scanner.isProject(at: proj))
}

TestRunner.run("isProject: .git dir → true") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("generic")
    try fm.createDirectory(at: proj.appendingPathComponent(".git"), withIntermediateDirectories: true)

    let scanner = DirectoryScanner()
    try assertTrue(scanner.isProject(at: proj))
}

TestRunner.run("isProject: empty dir → false") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("empty")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)

    let scanner = DirectoryScanner()
    try assertFalse(scanner.isProject(at: proj))
}

TestRunner.run("scanDependencies: finds node_modules") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("node-proj")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("package.json").path, contents: nil)
    let nm = proj.appendingPathComponent("node_modules")
    try fm.createDirectory(at: nm, withIntermediateDirectories: true)
    fm.createFile(atPath: nm.appendingPathComponent("somefile").path, contents: Data(repeating: 0, count: 1024))

    let scanner = DirectoryScanner()
    let deps = try scanner.scanDependencies(in: proj)
    try assertEqual(deps.count, 1)
    try assertEqual(deps.first!.type, .nodeModules)
}

TestRunner.run("scanDependencies: finds multiple deps") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("multi")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("package.json").path, contents: nil)
    for name in ["node_modules", "dist", ".next"] {
        try fm.createDirectory(at: proj.appendingPathComponent(name), withIntermediateDirectories: true)
    }

    let scanner = DirectoryScanner()
    let deps = try scanner.scanDependencies(in: proj)
    let types = Set(deps.map(\.type))
    try assertTrue(types.contains(.nodeModules))
    try assertTrue(types.contains(.dist))
    try assertTrue(types.contains(.nextjs))
    try assertEqual(deps.count, 3)
}

TestRunner.run("scanDependencies: finds compiler outputs and test caches") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("build-heavy")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("package.json").path, contents: nil)
    for name in [".build", ".pytest_cache", "coverage", "out", "cmake-build-debug",
                 "cmake-build-custom", ".cxx", ".externalNativeBuild", "bazel-bin"] {
        try fm.createDirectory(at: proj.appendingPathComponent(name), withIntermediateDirectories: true)
    }

    let scanner = DirectoryScanner()
    let types = Set(try scanner.scanDependencies(in: proj).map(\.type))
    try assertTrue(types.contains(.swiftBuild))
    try assertTrue(types.contains(.pytestCache))
    try assertTrue(types.contains(.coverage))
    try assertTrue(types.contains(.out))
    try assertTrue(types.contains(.cmakeBuildDebug))
    try assertTrue(types.contains(.cmakeBuild))
    try assertTrue(types.contains(.cxx))
    try assertTrue(types.contains(.externalNativeBuild))
    try assertTrue(types.contains(.bazelBin))
}

TestRunner.run("scanDependencies: finds release and Library/Caches outputs") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("release-project")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("package.json").path, contents: nil)
    try fm.createDirectory(at: proj.appendingPathComponent("release/mac-arm64"), withIntermediateDirectories: true)
    try fm.createDirectory(at: proj.appendingPathComponent("Library/Caches"), withIntermediateDirectories: true)

    let scanner = DirectoryScanner()
    let deps = try scanner.scanDependencies(in: proj)
    let paths = Set(deps.map(\.relativePath))
    try assertTrue(paths.contains("release"))
    try assertTrue(paths.contains("Library/Caches"))
}

TestRunner.run("scanDependencies: does not treat source bin as build output") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("source-bin-project")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("Cargo.toml").path, contents: nil)
    try fm.createDirectory(at: proj.appendingPathComponent("submodules/flutter/bin"), withIntermediateDirectories: true)

    let scanner = DirectoryScanner()
    let deps = try scanner.scanDependencies(in: proj)
    try assertFalse(deps.contains { $0.relativePath == "submodules/flutter/bin" })
}

TestRunner.run("scanDependencies: reaches outputs below common wrapper directories") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("wrapped-outputs")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("package.json").path, contents: nil)
    try fm.createDirectory(at: proj.appendingPathComponent("android/app/build"), withIntermediateDirectories: true)
    try fm.createDirectory(at: proj.appendingPathComponent("resources/embedded/node_modules"), withIntermediateDirectories: true)
    try fm.createDirectory(at: proj.appendingPathComponent("Carthage/Build"), withIntermediateDirectories: true)

    let scanner = DirectoryScanner()
    let deps = try scanner.scanDependencies(in: proj)
    let paths = Set(deps.map(\.relativePath))
    try assertTrue(paths.contains("android/app/build"))
    try assertTrue(paths.contains("resources/embedded/node_modules"))
    try assertTrue(paths.contains("Carthage/Build"))
}

TestRunner.run("scanDependencies: finds known directories below hidden parents") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("hidden-parent")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("pyproject.toml").path, contents: nil)
    let venv = proj.appendingPathComponent(".claude/skills/example/.venv")
    try fm.createDirectory(at: venv, withIntermediateDirectories: true)

    let scanner = DirectoryScanner()
    let deps = try scanner.scanDependencies(in: proj)
    try assertEqual(deps.count, 1)
    try assertEqual(deps.first?.relativePath, ".claude/skills/example/.venv")
}

TestRunner.run("scanDependencies: finds local history snapshots") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("history-project")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("package.json").path, contents: nil)
    try fm.createDirectory(at: proj.appendingPathComponent(".history"), withIntermediateDirectories: true)

    let scanner = DirectoryScanner()
    let deps = try scanner.scanDependencies(in: proj)
    try assertEqual(deps.count, 1)
    try assertEqual(deps.first?.type, .history)
}

TestRunner.run("scanDependencies: ignores symlinked dependency directories") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("symlink-project")
    let external = tmp.appendingPathComponent("external-node-modules")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    try fm.createDirectory(at: external, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("package.json").path, contents: nil)
    try fm.createSymbolicLink(at: proj.appendingPathComponent("node_modules"), withDestinationURL: external)

    let scanner = DirectoryScanner()
    try assertTrue(scanner.scanDependencies(in: proj).isEmpty)
}

TestRunner.run("scanDependencies: RECURSIVE finds nested node_modules") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("monorepo")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("package.json").path, contents: nil)

    // Top-level node_modules
    try fm.createDirectory(at: proj.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
    // Nested: packages/app1/node_modules
    let nested = proj.appendingPathComponent("packages/app1/node_modules")
    try fm.createDirectory(at: nested, withIntermediateDirectories: true)
    // Nested: packages/app2/dist
    let nestedDist = proj.appendingPathComponent("packages/app2/dist")
    try fm.createDirectory(at: nestedDist, withIntermediateDirectories: true)

    let scanner = DirectoryScanner()
    let deps = try scanner.scanDependencies(in: proj)
    try assertEqual(deps.count, 3)

    let paths = Set(deps.map(\.relativePath))
    try assertTrue(paths.contains("node_modules"))
    try assertTrue(paths.contains("packages/app1/node_modules"))
    try assertTrue(paths.contains("packages/app2/dist"))
}

TestRunner.run("scanDependencies: includes relativePath") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("proj")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("package.json").path, contents: nil)
    try fm.createDirectory(at: proj.appendingPathComponent("sub/node_modules"), withIntermediateDirectories: true)

    let scanner = DirectoryScanner()
    let deps = try scanner.scanDependencies(in: proj)
    try assertEqual(deps.count, 1)
    try assertEqual(deps.first!.relativePath, "sub/node_modules")
}

TestRunner.run("scanDependencies: ignores non-dep dirs") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let proj = tmp.appendingPathComponent("clean")
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    fm.createFile(atPath: proj.appendingPathComponent("package.json").path, contents: nil)
    try fm.createDirectory(at: proj.appendingPathComponent("src"), withIntermediateDirectories: true)
    try fm.createDirectory(at: proj.appendingPathComponent("docs"), withIntermediateDirectories: true)

    let scanner = DirectoryScanner()
    let deps = try scanner.scanDependencies(in: proj)
    try assertTrue(deps.isEmpty)
}

TestRunner.run("scanProjects: returns projects with deps") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }

    let p1 = tmp.appendingPathComponent("app1")
    try fm.createDirectory(at: p1, withIntermediateDirectories: true)
    fm.createFile(atPath: p1.appendingPathComponent("package.json").path, contents: nil)
    try fm.createDirectory(at: p1.appendingPathComponent("node_modules"), withIntermediateDirectories: true)

    let p2 = tmp.appendingPathComponent("app2")
    try fm.createDirectory(at: p2, withIntermediateDirectories: true)
    fm.createFile(atPath: p2.appendingPathComponent("requirements.txt").path, contents: nil)
    try fm.createDirectory(at: p2.appendingPathComponent(".venv"), withIntermediateDirectories: true)

    let scanner = DirectoryScanner()
    let projects = try scanner.scanProjects(at: tmp)
    try assertEqual(projects.count, 2)
    let names = Set(projects.map(\.name))
    try assertTrue(names.contains("app1"))
    try assertTrue(names.contains("app2"))
}

TestRunner.run("scanProjects: discovers projects below workspace grouping directories") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }

    let project = tmp.appendingPathComponent("group/app")
    try fm.createDirectory(at: project, withIntermediateDirectories: true)
    fm.createFile(atPath: project.appendingPathComponent("package.json").path, contents: nil)
    try fm.createDirectory(at: project.appendingPathComponent("node_modules"), withIntermediateDirectories: true)

    let scanner = DirectoryScanner()
    let projects = try scanner.scanProjects(at: tmp)
    try assertEqual(projects.count, 1)
    try assertTrue(projects.first?.path.path.hasSuffix("/group/app") == true)
}

TestRunner.run("scanProjects: skips projects without deps") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }

    let p1 = tmp.appendingPathComponent("has-deps")
    try fm.createDirectory(at: p1, withIntermediateDirectories: true)
    fm.createFile(atPath: p1.appendingPathComponent("package.json").path, contents: nil)
    try fm.createDirectory(at: p1.appendingPathComponent("node_modules"), withIntermediateDirectories: true)

    let p2 = tmp.appendingPathComponent("no-deps")
    try fm.createDirectory(at: p2, withIntermediateDirectories: true)
    fm.createFile(atPath: p2.appendingPathComponent("package.json").path, contents: nil)

    let scanner = DirectoryScanner()
    let projects = try scanner.scanProjects(at: tmp)
    try assertEqual(projects.count, 1)
    try assertEqual(projects.first!.name, "has-deps")
}

TestRunner.run("scanProjects: empty root → empty result") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let scanner = DirectoryScanner()
    let projects = try scanner.scanProjects(at: tmp)
    try assertTrue(projects.isEmpty)
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SizeCalculator Tests
// ═══════════════════════════════════════════════════════════════
print("\n📏 SizeCalculator Tests")
print("─────────────────────────────────")

TestRunner.run("directorySize: single file") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let data = Data(repeating: 65, count: 4096)
    fm.createFile(atPath: tmp.appendingPathComponent("file.bin").path, contents: data)

    let calc = SizeCalculator()
    let size = try calc.directorySize(at: tmp)
    try assertTrue(size >= 4096, "size should be >= 4096, got \(size)")
}

TestRunner.run("directorySize: nested files") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let sub = tmp.appendingPathComponent("sub")
    try fm.createDirectory(at: sub, withIntermediateDirectories: true)
    let data = Data(repeating: 65, count: 1000)
    fm.createFile(atPath: tmp.appendingPathComponent("a.txt").path, contents: data)
    fm.createFile(atPath: sub.appendingPathComponent("b.txt").path, contents: data)

    let calc = SizeCalculator()
    let size = try calc.directorySize(at: tmp)
    try assertTrue(size >= 2000, "size should be >= 2000, got \(size)")
}

TestRunner.run("directorySize: counts HIDDEN files (fixed pnpm issue)") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }
    let hidden = tmp.appendingPathComponent(".pnpm")
    try fm.createDirectory(at: hidden, withIntermediateDirectories: true)
    let data = Data(repeating: 65, count: 8192)
    fm.createFile(atPath: hidden.appendingPathComponent("package.js").path, contents: data)
    fm.createFile(atPath: tmp.appendingPathComponent(".hidden-file").path, contents: data)

    let calc = SizeCalculator()
    let size = try calc.directorySize(at: tmp)
    try assertTrue(size >= 16384, "size should be >= 16384 (includes hidden), got \(size)")
}

TestRunner.run("directorySize: empty dir → 0") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }

    let calc = SizeCalculator()
    let size = try calc.directorySize(at: tmp)
    try assertEqual(size, 0)
}

TestRunner.run("modificationDate: returns date for existing dir") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }

    let calc = SizeCalculator()
    let date = calc.modificationDate(at: tmp)
    try assertTrue(date != nil, "should have a modification date")
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DirectorySizeCache Tests
// ═══════════════════════════════════════════════════════════════
print("\n💾 DirectorySizeCache Tests")
print("─────────────────────────────────")

func makeIsolatedDefaults() -> UserDefaults {
    let suiteName = "DevCleanerTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

TestRunner.run("DirectorySizeCache: returns cached size when modification date matches") {
    let defaults = makeIsolatedDefaults()
    let cache = DirectorySizeCache(defaults: defaults, storageKey: "sizes")
    let url = URL(fileURLWithPath: "/tmp/cache-test/node_modules")
    let date = Date(timeIntervalSince1970: 1_700_000_000)

    cache.store(sizeInBytes: 1234, for: url, modificationDate: date)

    try assertEqual(cache.cachedSize(for: url, modificationDate: date), 1234)
}

TestRunner.run("DirectorySizeCache: ignores cached size when modification date changes") {
    let defaults = makeIsolatedDefaults()
    let cache = DirectorySizeCache(defaults: defaults, storageKey: "sizes")
    let url = URL(fileURLWithPath: "/tmp/cache-test/node_modules")
    let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
    let newDate = Date(timeIntervalSince1970: 1_700_000_001)

    cache.store(sizeInBytes: 1234, for: url, modificationDate: oldDate)

    try assertEqual(cache.cachedSize(for: url, modificationDate: newDate), nil)
}

TestRunner.run("DirectorySizeCache: remove deletes selected paths") {
    let defaults = makeIsolatedDefaults()
    let cache = DirectorySizeCache(defaults: defaults, storageKey: "sizes")
    let url = URL(fileURLWithPath: "/tmp/cache-test/node_modules")
    let date = Date(timeIntervalSince1970: 1_700_000_000)

    cache.store(sizeInBytes: 1234, for: url, modificationDate: date)
    cache.remove(paths: [url.path])

    try assertEqual(cache.cachedSize(for: url, modificationDate: date), nil)
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DirectoryCollectionStore Tests
// ═══════════════════════════════════════════════════════════════
print("\n🗂️ DirectoryCollectionStore Tests")
print("─────────────────────────────────")

TestRunner.run("DirectoryCollectionStore: saves and loads named path collections") {
    let defaults = makeIsolatedDefaults()
    let store = DirectoryCollectionStore(defaults: defaults, storageKey: "collections")
    let item = DirectoryCollectionItem(
        path: "/tmp/work/app/node_modules",
        relativePath: "node_modules",
        typeName: "node_modules (Node.js)",
        sizeInBytes: 4096,
        isSelected: true
    )
    let collection = DirectoryCollection(name: "常用清理", items: [item])

    store.save([collection])
    let loaded = store.load()

    try assertEqual(loaded.count, 1)
    try assertEqual(loaded.first?.name, "常用清理")
    try assertEqual(loaded.first?.items.first?.path, "/tmp/work/app/node_modules")
    try assertEqual(loaded.first?.items.first?.isSelected, true)
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DependencyCleaner Tests
// ═══════════════════════════════════════════════════════════════
print("\n🧹 DependencyCleaner Tests")
print("─────────────────────────────────")

TestRunner.run("remove: deletes selected items") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }

    let nm = tmp.appendingPathComponent("node_modules")
    try fm.createDirectory(at: nm, withIntermediateDirectories: true)
    fm.createFile(atPath: nm.appendingPathComponent("pkg.js").path, contents: Data("hello".utf8))

    let item = DependencyItem(path: nm, type: .nodeModules, sizeInBytes: 100, isSelected: true)
    let cleaner = DependencyCleaner()
    let removed = try cleaner.remove(items: [item])
    try assertEqual(removed.count, 1)
    try assertFalse(fm.fileExists(atPath: nm.path))
}

TestRunner.run("remove: skips unselected items") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }

    let dist = tmp.appendingPathComponent("dist")
    try fm.createDirectory(at: dist, withIntermediateDirectories: true)

    let item = DependencyItem(path: dist, type: .dist, sizeInBytes: 50, isSelected: false)
    let cleaner = DependencyCleaner()
    let removed = try cleaner.remove(items: [item])
    try assertTrue(removed.isEmpty)
    try assertTrue(fm.fileExists(atPath: dist.path))
}

TestRunner.run("remove: handles nonexistent path gracefully") {
    let fake = URL(fileURLWithPath: "/tmp/\(UUID().uuidString)/nonexistent")
    let item = DependencyItem(path: fake, type: .nodeModules, sizeInBytes: 0, isSelected: true)
    let cleaner = DependencyCleaner()
    let removed = try cleaner.remove(items: [item])
    try assertTrue(removed.isEmpty)
}

TestRunner.run("remove(paths): deletes existing paths and skips missing paths") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }

    let existing = tmp.appendingPathComponent("node_modules")
    let missing = tmp.appendingPathComponent("dist")
    try fm.createDirectory(at: existing, withIntermediateDirectories: true)

    let cleaner = DependencyCleaner()
    let removed = try cleaner.remove(paths: [existing.path, missing.path])

    try assertEqual(removed.map(\.path), [existing.path])
    try assertFalse(fm.fileExists(atPath: existing.path))
}

TestRunner.run("removeWithElevatedFallback: deletes normal paths without password") {
    let tmp = makeTempDir()
    defer { cleanUp(tmp) }

    let existing = tmp.appendingPathComponent("node_modules")
    try fm.createDirectory(at: existing, withIntermediateDirectories: true)

    let cleaner = DependencyCleaner()
    let result = cleaner.removeWithElevatedFallback(paths: [existing.path], password: nil)

    try assertEqual(result.removed.map(\.path), [existing.path])
    try assertTrue(result.failed.isEmpty)
    try assertFalse(fm.fileExists(atPath: existing.path))
}

// ═══════════════════════════════════════════════════════════════
TestRunner.summary()
if !TestRunner.allPassed {
    exit(1)
}
