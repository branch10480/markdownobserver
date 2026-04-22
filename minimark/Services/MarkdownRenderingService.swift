import Foundation

struct RenderedMarkdown: Equatable, Sendable {
    let htmlDocument: String
    let changedRegions: [ChangedRegion]
    let renderedAt: Date
}

protocol MarkdownRendering {
    func render(
        markdown: String,
        changedRegions: [ChangedRegion],
        unsavedChangedRegions: [ChangedRegion],
        theme: ThemeDefinition,
        syntaxTheme: SyntaxThemeKind,
        baseFontSize: Double
    ) throws -> RenderedMarkdown
}

struct MarkdownRenderingService: MarkdownRendering {
    private let cssFactory: CSSFactory
    private let payloadEncoder: MarkdownRuntimePayloadEncoding
    private let runtimeAssetResolver: RuntimeAssetResolving
    private let userCSSLoader: UserCustomCSSLoading

    init(
        cssFactory: CSSFactory = CSSFactory(),
        payloadEncoder: MarkdownRuntimePayloadEncoding = JSONBase64MarkdownRuntimePayloadEncoder(),
        runtimeAssetResolver: RuntimeAssetResolving = BundledRuntimeAssetResolver(),
        userCSSLoader: UserCustomCSSLoading = BundledUserCustomCSSLoader()
    ) {
        self.cssFactory = cssFactory
        self.payloadEncoder = payloadEncoder
        self.runtimeAssetResolver = runtimeAssetResolver
        self.userCSSLoader = userCSSLoader
    }

    func render(
        markdown: String,
        changedRegions: [ChangedRegion],
        unsavedChangedRegions: [ChangedRegion],
        theme: ThemeDefinition,
        syntaxTheme: SyntaxThemeKind,
        baseFontSize: Double
    ) throws -> RenderedMarkdown {
        let runtimeAssets = try runtimeAssetResolver.requiredRuntimeAssets()
        let payloadBase64 = try payloadEncoder.makePayloadBase64(
            markdown: markdown,
            changedRegions: changedRegions,
            unsavedChangedRegions: unsavedChangedRegions
        )
        let themeCSS = cssFactory.makeCSS(theme: theme, syntaxTheme: syntaxTheme, baseFontSize: baseFontSize)
        let css = Self.merged(themeCSS: themeCSS, userCSS: userCSSLoader.loadUserCSS())
        let htmlDocument = cssFactory.makeHTMLDocument(
            css: css,
            payloadBase64: payloadBase64,
            runtimeAssets: runtimeAssets,
            themeJavaScript: theme.customJavaScript
        )

        return RenderedMarkdown(
            htmlDocument: htmlDocument,
            changedRegions: changedRegions,
            renderedAt: Date()
        )
    }

    private static func merged(themeCSS: String, userCSS: String?) -> String {
        guard let userCSS, !userCSS.isEmpty else {
            return themeCSS
        }
        return themeCSS + "\n\n/* === user.css (loaded from ~/Library/Application Support/MarkdownObserver/themes/) === */\n" + userCSS
    }
}
