//
//  ExpertPaywallView.swift
//  RestIQ
//
//  Shown when a user taps the locked Expert card.
//  Phase 1: brief animated preview of what Expert looks like.
//  Phase 2: paywall with price, feature list, purchase + restore buttons.
//

import SwiftUI

@available(iOS 18.0, *)
struct ExpertPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // PurchaseManager is not ObservableObject — use @State to trigger re-renders on action
    @State private var isPurchasing = false
    @State private var purchaseError: String? = nil
    @State private var showPaywall = false
    @State private var previewPulse = false

    var body: some View {
        ZStack {
            background

            if showPaywall {
                paywallContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                previewContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showPaywall)
        .onAppear {
            // Auto-advance to paywall after preview
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation { showPaywall = true }
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            AppTheme.backgroundGradient(colorScheme)
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(AppTheme.backgroundMaterialOpacity(colorScheme))
                .blendMode(.overlay)
        }
        .blur(radius: 45)
        .ignoresSafeArea()
    }

    // MARK: - Preview Phase

    private var previewContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Expert")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.titleGradient(colorScheme))

            Text("9×9 grid · Maximum challenge")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Blurred fake grid to tease the puzzle
            fakeGridPreview
                .scaleEffect(previewPulse ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: previewPulse)
                .onAppear { previewPulse = true }

            Text("Loading Expert…")
                .font(.footnote)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var fakeGridPreview: some View {
        let cols = 9
        let cellSize: CGFloat = 34

        return VStack(spacing: 1) {
            ForEach(0..<cols, id: \.self) { r in
                HStack(spacing: 1) {
                    ForEach(0..<cols, id: \.self) { c in
                        let colorIndex = (r + c) % 3
                        RoundedRectangle(cornerRadius: 2)
                            .fill(previewCellColor(colorIndex))
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
        .blur(radius: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    private func previewCellColor(_ index: Int) -> Color {
        let colors: [Color] = [
            Color(.displayP3, red: 205/255, green: 190/255, blue: 245/255).opacity(0.6),
            Color(.displayP3, red: 245/255, green: 195/255, blue: 215/255).opacity(0.6),
            Color(.displayP3, red: 191/255, green: 224/255, blue: 187/255).opacity(0.6),
        ]
        return colors[index]
    }

    // MARK: - Paywall Phase

    private var paywallContent: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.liquidInk(colorScheme))

                        Text("Unlock Expert")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.titleGradient(colorScheme))

                        Text("One-time purchase · No subscription")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)

                    // Feature list
                    VStack(alignment: .leading, spacing: 14) {
                        paywallFeatureRow(icon: "grid", text: "9×9 Expert puzzle, refreshed daily")
                        paywallFeatureRow(icon: "trophy.fill", text: "Bonus puzzle after 7-day streak")
                        paywallFeatureRow(icon: "icloud.fill", text: "Progress synced across your devices")
                        paywallFeatureRow(icon: "arrow.clockwise", text: "Lifetime access · buy once")
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                    // Purchase button
                    VStack(spacing: 12) {
                        Button {
                            Haptics.medium()
                            Task {
                                isPurchasing = true
                                purchaseError = nil
                                await PurchaseManager.shared.purchaseExpert()
                                isPurchasing = false
                                purchaseError = PurchaseManager.shared.purchaseError
                            }
                        } label: {
                            HStack {
                                if isPurchasing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Unlock for \(PurchaseManager.shared.expertPriceFormatted)")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: colorScheme == .light
                                            ? [AppTheme.Palette.roseLightA, AppTheme.Palette.roseLightB]
                                            : [AppTheme.Palette.purpleA, AppTheme.Palette.purpleB],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(isPurchasing)

                        Button {
                            Haptics.soft()
                            Task {
                                isPurchasing = true
                                await PurchaseManager.shared.restorePurchases()
                                isPurchasing = false
                                purchaseError = PurchaseManager.shared.purchaseError
                            }
                        } label: {
                            Text("Restore Purchase")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .underline()
                        }
                        .buttonStyle(.plain)
                        .disabled(isPurchasing)
                    }

                    // Error message
                    if let error = purchaseError {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Text("Payment charged to your Apple ID account at confirmation. No subscription.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func paywallFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.liquidInk(colorScheme))
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

#Preview {
    ExpertPaywallView()
}
