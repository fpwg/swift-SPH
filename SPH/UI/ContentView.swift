// ContentView.swift
// SPH
//
// Created by Florian Plaswig on 06.12.24.

import SwiftUI

struct NumberTextField<T: Numeric & LosslessStringConvertible & CustomStringConvertible>: View {
    @Binding var number: T
    let formatter: NumberFormatter

    @State private var input: String = ""

    var body: some View {
        TextField("Enter a number", text: $input)
            .onChange(of: input) { _, _ in
                // Update input, but do not immediately convert to number.
                // Allow users to type freely (e.g., commas, decimal points)
            }
            .onSubmit {
                // Convert the input string to a Double when Enter is pressed
                if let value = T(input) {
                    number = value
                }
            }
            .onAppear {
                // Set initial value as input string on appear
                input = String(number)
            }
    }
}

struct ContentView: View {
    @StateObject private var simulation = Simulation(on: MTLCreateSystemDefaultDevice()!)
    @State private var showSettings = false

    private func inputField<T: Numeric & LosslessStringConvertible & CustomStringConvertible>(
        title: String,
        value: Binding<T>,
        systemImage: String
    ) -> some View {
        let formatter = NumberFormatter()
        formatter.maximumSignificantDigits = 5
        formatter.isPartialStringValidationEnabled = true
        formatter.decimalSeparator = "."
        formatter.allowsFloats = true

        return HStack {
            Image(systemName: systemImage)
                .frame(width: 20, alignment: .center)
            NumberTextField(number: value, formatter: formatter)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 80)
        }.tooltip(title)
    }

    var body: some View {
        VStack {
            VStack {
                HStack(alignment: .top) {
                    // Play/Pause icon button
                    Button(action: {
                        simulation.isRunning.toggle()
                        simulation.objectWillChange.send()
                    }) {
                        Image(systemName: simulation.isRunning ? "pause.fill" : "play.fill")
                    }
                    Button(action: {
                        // TODO: this is hacky, but it works for now
                        simulation.particleCount = simulation.particleCount
                        simulation.objectWillChange.send()
                    }) { Image(systemName: "backward.end.fill") }
                    Spacer()
                    Picker("Interaction", selection: $simulation.mousePushesParticles) {
                        HStack {
                            Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                            Text("Push")
                        }.tag(true)
                        HStack {
                            Image(systemName: "arrow.down.right.and.arrow.up.left.circle.fill")
                            Text("Drag")
                        }.tag(false)
                    }.pickerStyle(.radioGroup)
                    Spacer()
                    HStack {
                        Image(systemName: "stopwatch")
                        Text("\(simulation.currentDeltaTime > 0 ? Int(1 / simulation.currentDeltaTime) : 0) fps")
                            .frame(width: 60, alignment: .leading)
                    }
                }.padding(.bottom, 5)
                Divider()
                FlexibleGrid(itemWidth: 110, spacing: 10) {
                    inputField(title: "Particle count", value: $simulation.particleCount, systemImage: "chart.dots.scatter")
                    inputField(title: "Kernel radius", value: $simulation.kernelRadius, systemImage: "ruler")
                    inputField(title: "Stiffness", value: $simulation.stiffness, systemImage: "rectangle.compress.vertical")
                    inputField(title: "Gravity", value: $simulation.gravity, systemImage: "scalemass.fill")
                    inputField(title: "Gravity direction", value: $simulation.gravityDirection, systemImage: "arrow.down")
                    inputField(title: "Friction", value: $simulation.friction, systemImage: "tortoise.fill")
                    inputField(title: "Collision dampening", value: $simulation.wallCollisionDampening, systemImage: "square.dotted")
                    inputField(title: "XSPH", value: $simulation.xsph_strength, systemImage: "heat.waves")
                    inputField(title: "Brightness", value: $simulation.intensityMultiplierLog, systemImage: "circle.lefthalf.filled")
                    inputField(title: "Cohesion", value: $simulation.cohesion, systemImage: "link")
                    inputField(title: "Drag Radius", value: $simulation.dragRadius, systemImage: "hand.pinch")

                }.padding(.top.union(.horizontal), 5)
            }
            .padding(.top.union(.horizontal))
            .padding(.bottom, 5)
            .symbolRenderingMode(.hierarchical)

            // The main simulation view
            SimulationView(simulation: simulation)
                .frame(height: 600)
        }
    }
}

#Preview {
    ContentView()
}
