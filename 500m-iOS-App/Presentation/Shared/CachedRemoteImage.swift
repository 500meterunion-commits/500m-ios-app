import SwiftUI
import UIKit

final class RemoteImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private static let memoryCache = NSCache<NSURL, UIImage>()
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 80 * 1024 * 1024,
            diskCapacity: 300 * 1024 * 1024,
            diskPath: "500m_remote_image_cache"
        )
        return URLSession(configuration: configuration)
    }()

    private var currentURL: URL?
    private var task: Task<Void, Never>?

    deinit {
        task?.cancel()
    }

    @MainActor
    func load(from url: URL?) {
        guard currentURL != url else { return }

        task?.cancel()
        currentURL = url

        guard let url else {
            image = nil
            return
        }

        let key = url as NSURL
        if let cached = Self.memoryCache.object(forKey: key) {
            image = cached
            return
        }

        if let cachedResponse = Self.session.configuration.urlCache?.cachedResponse(for: URLRequest(url: url)),
           let cachedImage = UIImage(data: cachedResponse.data) {
            Self.memoryCache.setObject(cachedImage, forKey: key)
            image = cachedImage
            return
        }

        image = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                let (data, response) = try await Self.session.data(for: request)
                guard !Task.isCancelled, let downloaded = UIImage(data: data) else { return }

                let cachedResponse = CachedURLResponse(response: response, data: data)
                Self.session.configuration.urlCache?.storeCachedResponse(cachedResponse, for: request)
                Self.memoryCache.setObject(downloaded, forKey: key)

                await MainActor.run {
                    if self.currentURL == url {
                        self.image = downloaded
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
            }
        }
    }
}

struct CachedRemoteImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @StateObject private var loader = RemoteImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await MainActor.run {
                loader.load(from: url)
            }
        }
    }
}

