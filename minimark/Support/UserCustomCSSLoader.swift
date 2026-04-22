import Foundation
import os

protocol UserCustomCSSLoading: Sendable {
    func loadUserCSS() -> String?
    var userCSSDirectoryURL: URL? { get }
}

struct BundledUserCustomCSSLoader: UserCustomCSSLoading {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "minimark",
        category: "UserCustomCSSLoader"
    )

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var userCSSDirectoryURL: URL? {
        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return appSupport
            .appendingPathComponent("MarkdownObserver", isDirectory: true)
            .appendingPathComponent("themes", isDirectory: true)
    }

    func loadUserCSS() -> String? {
        guard let directoryURL = userCSSDirectoryURL else {
            return nil
        }

        ensureDirectoryScaffolding(at: directoryURL)

        let cssURL = directoryURL.appendingPathComponent("user.css")
        guard fileManager.fileExists(atPath: cssURL.path) else {
            return nil
        }

        do {
            let contents = try String(contentsOf: cssURL, encoding: .utf8)
            let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : contents
        } catch {
            Self.logger.error(
                "Failed to read user.css: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func ensureDirectoryScaffolding(at directoryURL: URL) {
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true
                )
            } catch {
                Self.logger.error(
                    "Failed to create themes directory: \(error.localizedDescription, privacy: .public)"
                )
                return
            }
        }

        let readmeURL = directoryURL.appendingPathComponent("README.md")
        if !fileManager.fileExists(atPath: readmeURL.path) {
            try? Self.defaultReadmeContents.write(to: readmeURL, atomically: true, encoding: .utf8)
        }

        let exampleURL = directoryURL.appendingPathComponent("user.css.example")
        if !fileManager.fileExists(atPath: exampleURL.path) {
            try? Self.defaultExampleCSS.write(to: exampleURL, atomically: true, encoding: .utf8)
        }
    }

    private static let defaultReadmeContents = """
    # MarkdownObserver — User Themes

    Drop a file named `user.css` in this directory to override any CSS rule
    in the active reader theme. The file is re-read every time the preview
    re-renders (for example when the source markdown is saved).

    ## Available CSS custom properties

    All themes expose these variables on `:root`:

    - `--reader-bg`, `--reader-fg`, `--reader-fg-secondary`
    - `--reader-code-bg`, `--reader-border`, `--reader-link`
    - `--reader-changed-bg`, `--reader-changed-added`,
      `--reader-changed-edited`, `--reader-changed-deleted`
    - `--reader-font-size`
    - `--reader-h1`, `--reader-h2`, `--reader-h3` (optional, some themes only)

    See `user.css.example` for a starter file you can rename to `user.css`.
    """

    private static let defaultExampleCSS = """
    /* Example user stylesheet.
       Rename or copy this file to user.css to activate it.
       Rules here override whichever built-in theme is currently active. */

    :root {
      /* Slightly larger comfortable reading width. */
      --reader-content-max-width: 780px;
    }

    .markdown-body {
      max-width: var(--reader-content-max-width);
      margin: 0 auto;
    }

    /* Make fenced code blocks stand out a bit more. */
    .markdown-body pre {
      border: 1px solid var(--reader-border);
      border-radius: 8px;
      padding: 14px 16px;
    }

    /* Tighter inline code background. */
    .markdown-body :not(pre) > code {
      padding: 2px 6px;
      border-radius: 4px;
      background: var(--reader-code-bg);
    }

    /* Example: bump heading weight. */
    .markdown-body h1,
    .markdown-body h2,
    .markdown-body h3 {
      font-weight: 700;
      letter-spacing: -0.01em;
    }
    """
}
