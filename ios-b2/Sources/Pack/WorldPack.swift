import Foundation
import CryptoKit

/// V6 基础资源包 —— iOS 版（与安卓 `WorldPack.java` 同源同语义）
///
/// `v6-base-assets.pak` 预装在 App bundle（`ios-b2/Resources/`）里，本质是一个
/// **ZIP（ZIP_STORED 无压缩）** 归档：条目路径 = `/v6/` 之后的相对路径
/// （`assets/buildings/cafe.glb`、`config/...json`、`basis/...wasm` …），126 个条目。
///
/// 首次启动把包拷进沙盒 `Application Support/v6pack/v6-assets.zip`，其后按条目随机读。
///
/// 🔴 设计原则：**任何异常都返回 nil**（→ 调用方回落网络），绝不因为包缺失/损坏/过期
/// 让页面白屏。包过期（站点资产更新）时未命中的条目自动走网络。
final class WorldPack {

    static let shared = WorldPack()

    /// 与打包器 / 安卓 APK / CI 断言一致的事实（改动必须同步 `ios-b2/ci/verify_source.py`）
    static let fileName = "v6-base-assets.pak"
    static let expectedSize: Int64 = 61_912_957          // 59.04 MiB
    static let packVersion = "186"                        // 版本锚点（写入 Info.plist `V6PackVersion`）
    static let packSHA256 = "362c889f588077b5811263fc03a721d6b7ce55295faae786b237031236e6d16e"

    private struct Entry {
        let method: UInt16        // 0 = stored（本包全部 stored；其它方法一律不读 → 回落网络）
        let dataOffset: UInt64    // 已跳过 local header 的数据起点
        let size: UInt32          // 压缩后大小（stored 时 == 原大小）
    }

    private let queue = DispatchQueue(label: "com.likeart.worldpack")
    private let fileURL: URL
    private var entries: [String: Entry] = [:]
    private var handle: FileHandle?
    private var prepared = false
    private var preparing = false
    private var served = 0
    private var missed = 0

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = base.appendingPathComponent("v6pack", isDirectory: true)
            .appendingPathComponent("v6-assets.zip")
    }

    // MARK: - 安装（首次拷贝到沙盒）

    /// 幂等：已在准备中/已完成则直接返回。**必须在非主线程调用**（首次要拷 ~59 MiB）。
    func prepare() {
        let shouldStart: Bool = queue.sync {
            if prepared || preparing { return false }
            preparing = true
            return true
        }
        guard shouldStart else { return }

        var newHandle: FileHandle?
        var newEntries: [String: Entry]?

        if let bundled = Bundle.main.url(forResource: "v6-base-assets", withExtension: "pak") {
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            if fileSize(fileURL) != Self.expectedSize, !copy(from: bundled, to: fileURL) {
                NSLog("[WorldPack] extract failed — 将回落网络")
            }
            if let h = try? FileHandle(forReadingFrom: fileURL) {
                newEntries = Self.readIndex(h)
                if newEntries != nil { newHandle = h }
            }
        } else {
            NSLog("[WorldPack] \(Self.fileName) 不在 bundle 内 — 将回落网络")
        }

        queue.sync {
            preparing = false
            if let h = newHandle, let e = newEntries {
                handle = h
                entries = e
                prepared = true
                NSLog("[WorldPack] ready version=\(Self.packVersion) entries=\(e.count) bytes=\(Self.expectedSize)")
            }
        }

        if newHandle != nil, let h = newHandle {
            verifyChecksum(h)     // 后台校验（不阻塞、失败只记日志）
        }
    }

    /// 后台准备 + 主线程回调（用于「先备好包再加载世界页」，保证首启也能命中本地包）
    func prepareAsync(_ done: @escaping (Bool) -> Void) {
        if isReady { done(true); return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.prepare()
            let ok = self.isReady
            DispatchQueue.main.async { done(ok) }
        }
    }

    var isReady: Bool { queue.sync { prepared } }
    var stats: (served: Int, missed: Int, ready: Bool) { queue.sync { (served, missed, prepared) } }

    /// 供 JS 层注入的条目清单（相对 `/v6/` 的路径）
    func entryNames() -> [String] { queue.sync { Array(entries.keys) } }

    // MARK: - 读取

    /// 读一个条目；不存在 / 未就绪 / 压缩方式不支持 → nil（调用方回落网络）
    func data(for path: String) -> Data? {
        let key = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return queue.sync {
            guard prepared, let e = entries[key], e.method == 0, let h = handle else {
                missed += 1
                return nil
            }
            do {
                try h.seek(toOffset: e.dataOffset)
                guard let d = try h.read(upToCount: Int(e.size)), d.count == Int(e.size) else {
                    missed += 1
                    return nil
                }
                served += 1
                return d
            } catch {
                missed += 1
                return nil
            }
        }
    }

    func contains(_ path: String) -> Bool {
        let key = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return queue.sync { entries[key] != nil }
    }

    /// 与安卓 `WorldPack.mime(path)` 完全一致的一张表
    static func mime(_ path: String) -> String {
        let p = path.lowercased()
        if p.hasSuffix(".glb") { return "model/gltf-binary" }
        if p.hasSuffix(".gltf") { return "model/gltf+json" }
        if p.hasSuffix(".webp") { return "image/webp" }
        if p.hasSuffix(".png") { return "image/png" }
        if p.hasSuffix(".jpg") || p.hasSuffix(".jpeg") { return "image/jpeg" }
        if p.hasSuffix(".ktx2") { return "image/ktx2" }
        if p.hasSuffix(".wasm") { return "application/wasm" }
        if p.hasSuffix(".json") { return "application/json" }
        if p.hasSuffix(".js") || p.hasSuffix(".mjs") { return "application/javascript" }
        if p.hasSuffix(".css") { return "text/css" }
        if p.hasSuffix(".bin") { return "application/octet-stream" }
        if p.hasSuffix(".mp3") { return "audio/mpeg" }
        return "application/octet-stream"
    }

    // MARK: - 内部工具

    private func fileSize(_ url: URL) -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let n = attrs[.size] as? NSNumber else { return nil }
        return n.int64Value
    }

    private func copy(from src: URL, to dst: URL) -> Bool {
        let tmp = dst.appendingPathExtension("part")
        try? FileManager.default.removeItem(at: tmp)
        do {
            try FileManager.default.copyItem(at: src, to: tmp)
        } catch {
            NSLog("[WorldPack] copy error: \(error)")
            try? FileManager.default.removeItem(at: tmp)
            return false
        }
        guard fileSize(tmp) == Self.expectedSize else {
            NSLog("[WorldPack] copied size mismatch — 丢弃")
            try? FileManager.default.removeItem(at: tmp)
            return false
        }
        try? FileManager.default.removeItem(at: dst)
        do {
            try FileManager.default.moveItem(at: tmp, to: dst)
            return true
        } catch {
            NSLog("[WorldPack] move error: \(error)")
            try? FileManager.default.removeItem(at: tmp)
            return false
        }
    }

    private func verifyChecksum(_ h: FileHandle) {
        DispatchQueue.global(qos: .utility).async {
            defer { try? h.close() }
            do {
                try h.seek(toOffset: 0)
                var hasher = SHA256()
                while let chunk = try h.read(upToCount: 1 << 20), !chunk.isEmpty {
                    hasher.update(data: chunk)
                }
                let hex = hasher.finalize().map { String(format: "%02x", $0) }.joined()
                if hex != Self.packSHA256 {
                    NSLog("[WorldPack] sha256 mismatch (拷贝受损) — 未命中条目仍会回落网络")
                } else {
                    NSLog("[WorldPack] sha256 ok")
                }
            } catch {
                NSLog("[WorldPack] sha256 check error: \(error)")
            }
        }
    }

    /// 解析中央目录；只读 11 KB 索引，数据按需 seek。返回 nil = 包不可用（→ 全局回落网络）
    private static func readIndex(_ h: FileHandle) -> [String: Entry]? {
        do {
            let fileLength = try h.seekToEnd()
            guard fileLength >= 22 else { return nil }
            let tailLength = min(fileLength, 66_000)
            try h.seek(toOffset: fileLength - tailLength)
            guard let tailData = try h.read(upToCount: Int(tailLength)) else { return nil }
            let tail = [UInt8](tailData)
            guard let eocd = lastSignature(0x0605_4b50, in: tail), eocd + 22 <= tail.count else { return nil }
            let cdSize = Int(u32(tail, eocd + 12))
            let cdOffset = UInt64(u32(tail, eocd + 16))
            guard cdSize > 0, cdOffset + UInt64(cdSize) <= fileLength else { return nil }

            try h.seek(toOffset: cdOffset)
            guard let cdData = try h.read(upToCount: cdSize), cdData.count == cdSize else { return nil }
            let cd = [UInt8](cdData)

            var out: [String: Entry] = [:]
            var p = 0
            while p + 46 <= cd.count, u32(cd, p) == 0x0201_4b50 {
                let method = u16(cd, p + 10)
                let compSize = u32(cd, p + 20)
                let nameLen = Int(u16(cd, p + 28))
                let extraLen = Int(u16(cd, p + 30))
                let commentLen = Int(u16(cd, p + 32))
                let localOffset = UInt64(u32(cd, p + 42))
                let nameStart = p + 46
                guard nameStart + nameLen <= cd.count else { break }
                let name = String(bytes: cd[nameStart..<(nameStart + nameLen)], encoding: .utf8) ?? ""

                // 数据起点 = local header 起点 + 30 + 局部名长/扩展字段长（不假设中央目录的 extra 与之相同）
                var dataOffset = localOffset + 30
                if let lhData = try? seekRead(h, offset: localOffset, count: 30) {
                    let lh = [UInt8](lhData)
                    if lh.count == 30, u32(lh, 0) == 0x0403_4b50 {
                        dataOffset = localOffset + 30 + UInt64(u16(lh, 26)) + UInt64(u16(lh, 28))
                    }
                }
                if !name.isEmpty, name.hasSuffix("/") == false {
                    out[name] = Entry(method: method, dataOffset: dataOffset, size: compSize)
                }
                p = nameStart + nameLen + extraLen + commentLen
            }
            return out.isEmpty ? nil : out
        } catch {
            return nil
        }
    }

    private static func seekRead(_ h: FileHandle, offset: UInt64, count: Int) throws -> Data? {
        try h.seek(toOffset: offset)
        return try h.read(upToCount: count)
    }

    private static func lastSignature(_ sig: UInt32, in bytes: [UInt8]) -> Int? {
        guard bytes.count >= 4 else { return nil }
        var i = bytes.count - 4
        while i >= 0 {
            if u32(bytes, i) == sig { return i }
            i -= 1
        }
        return nil
    }

    private static func u16(_ b: [UInt8], _ i: Int) -> UInt16 {
        UInt16(b[i]) | (UInt16(b[i + 1]) << 8)
    }

    private static func u32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) | (UInt32(b[i + 1]) << 8) | (UInt32(b[i + 2]) << 16) | (UInt32(b[i + 3]) << 24)
    }
}
