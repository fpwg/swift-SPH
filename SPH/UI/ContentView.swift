//
//  ContentView.swift
//  SPH
//
//  Created by Florian Plaswig on 06.12.24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var simulation = Simulation(on: MTLCreateSystemDefaultDevice()!)

    var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.maximumSignificantDigits = 5
        return formatter
    }

    var body: some View {
        VStack {
            VStack {
                HStack {
                    // Play/Pause icon button
                    Button(action: {
                        simulation.isRunning.toggle()
                        simulation.objectWillChange.send()
                    }) {
                        Image(systemName: simulation.isRunning ? "pause.fill" : "play.fill")
                    }
                    Button("Reset") {
                        // TODO: this is hacky, but it works for now
                        simulation.particleCount = simulation.particleCount
                        simulation.objectWillChange.send()
                    }

                    Text("Particles")
                    TextField("Particle count", value: $simulation.particleCount, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)

                    Text("Kernel radius")
                    TextField("Kernel radius", value: $simulation.kernelRadius, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)

                    Text("Stiffness")
                    TextField("Stiffness", value: $simulation.stiffness, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
                HStack {
                    Text("Gravity")
                    TextField("Gravity", value: $simulation.gravity, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)

                    Text("Friction")
                    TextField("Friction", value: $simulation.friction, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)

                    Text("Coll. damp.")
                    TextField("Collision dampening", value: $simulation.wallCollisionDampening, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)

                    Text("XSPH")
                    TextField("XSPH", value: $simulation.xsph_strength, formatter: formatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
                Text("\(simulation.currentDeltaTime > 0 ? Int(1 / simulation.currentDeltaTime) : 0) tps")
            }.padding()
            SimulationView(simulation: simulation)
        }
    }
}

#Preview {
    ContentView()
}
