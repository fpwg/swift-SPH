//
//  FlexibleGrid.swift
//  SPH
//
//  Created by Florian Plaswig on 07.12.24.
//

import SwiftUI

struct FlexibleGrid<Content: View>: View {
    let itemWidth: CGFloat // Fixed width for each item
    let spacing: CGFloat // Spacing between items
    let content: () -> Content // Closure that builds the views

    init(itemWidth: CGFloat, spacing: CGFloat = 10, @ViewBuilder content: @escaping () -> Content) {
        self.itemWidth = itemWidth
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            // Calculate how many items can fit per row based on the available width
            let columns = Int(geometry.size.width / (itemWidth + spacing))

            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: .init(.fixed(itemWidth)), count: max(columns, 1)),
                    spacing: spacing
                ) {
                    content()
                }
                .padding()
            }
        }
    }
}
