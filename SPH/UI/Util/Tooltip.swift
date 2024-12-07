//
//  Tooltip.swift
//  SPH
//
//  Created by Florian Plaswig on 07.12.24.
//

// Source: https://stackoverflow.com/questions/59129089/how-do-you-display-a-tooltip-hint-on-hover

import SwiftUI

@available(OSX 10.15, *)
public extension View {
    func tooltip(_ toolTip: String) -> some View {
        self.overlay(TooltipView(toolTip))
    }
}

@available(OSX 10.15, *)
private struct TooltipView: NSViewRepresentable {
    let toolTip: String

    init(_ toolTip: String) {
        self.toolTip = toolTip
    }

    func makeNSView(context: NSViewRepresentableContext<TooltipView>) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: NSViewRepresentableContext<TooltipView>) {
        nsView.toolTip = self.toolTip
    }
}
