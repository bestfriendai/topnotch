import CoreGraphics
import Foundation

enum DeckPagingLogic {
    private static let swipeThresholdRatio: CGFloat = 0.16
    private static let interiorResistance: CGFloat = 0.9
    private static let edgeResistance: CGFloat = 0.32

    static func sanitizedIndex(storedIndex: Int, cardCount: Int) -> Int {
        guard cardCount > 0 else { return 0 }
        return min(max(storedIndex, 0), cardCount - 1)
    }

    static func resistedOffset(translationWidth: CGFloat, currentIndex: Int, cardCount: Int) -> CGFloat {
        let lastIndex = max(cardCount - 1, 0)
        let isLeadingEdge = currentIndex == 0 && translationWidth > 0
        let isTrailingEdge = currentIndex == lastIndex && translationWidth < 0

        if isLeadingEdge || isTrailingEdge {
            return translationWidth * edgeResistance
        }

        return translationWidth * interiorResistance
    }

    static func targetIndex(
        currentIndex: Int,
        cardCount: Int,
        translationWidth: CGFloat,
        predictedEndTranslationWidth: CGFloat,
        pageWidth: CGFloat
    ) -> Int {
        let safeIndex = sanitizedIndex(storedIndex: currentIndex, cardCount: cardCount)
        guard cardCount > 0 else { return safeIndex }

        let threshold = pageWidth * swipeThresholdRatio
        let effectiveTranslation: CGFloat

        if abs(predictedEndTranslationWidth) > abs(translationWidth) {
            effectiveTranslation = predictedEndTranslationWidth
        } else {
            effectiveTranslation = translationWidth
        }

        if effectiveTranslation <= -threshold {
            return sanitizedIndex(storedIndex: safeIndex + 1, cardCount: cardCount)
        }

        if effectiveTranslation >= threshold {
            return sanitizedIndex(storedIndex: safeIndex - 1, cardCount: cardCount)
        }

        return safeIndex
    }
}