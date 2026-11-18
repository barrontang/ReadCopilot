import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - 封面加载
//
// 单文件 HTML 要求图片以 data: URI 内嵌。这里下载微信读书返回的封面，
// 缩到 480px 后重新编码为 JPEG；失败时返回 nil，由报告渲染带标注的占位图。
// 不猜测封面 URL，不使用 stock photo，不把远程地址留在最终文件里。

enum ReportCoverLoader {
    static func load(urlString: String) async -> ReportCover? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("ReadCopilot/0.2 (macOS; iOS)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  !data.isEmpty else {
                return nil
            }
            if let jpeg = downscaleJPEG(data, maxPixel: 480) {
                return ReportCover(data: jpeg, mimeType: "image/jpeg", source: "封面：微信读书 API")
            }
            if let mime = http.value(forHTTPHeaderField: "Content-Type"),
               mime.hasPrefix("image/"),
               data.count < 2_500_000 {
                return ReportCover(data: data, mimeType: mime, source: "封面：微信读书 API")
            }
            return nil
        } catch {
            return nil
        }
    }

    private static func downscaleJPEG(_ data: Data, maxPixel: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
