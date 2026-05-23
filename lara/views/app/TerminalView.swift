//
//  TerminalView.swift
//  lara
//

import SwiftUI

struct TerminalView: View {
    @EnvironmentObject var mgr: laramgr

    @State private var input: String = ""
    @State private var lines: [String] = []
    @State private var running: Bool = false
    @State private var elevated: Bool = false

    private let bottomID = "termBottom"

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // output
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            if lines.isEmpty {
                                Text("ready.")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(size: 13, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            Color.clear.frame(height: 1).id(bottomID)
                        }
                        .padding(12)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity)
                    .frame(height: 380)
                    .background(Color(.quaternarySystemFill), in: .rect(cornerRadius: 22))
                    .onChange(of: lines.count) { _ in
                        withAnimation { proxy.scrollTo(bottomID) }
                    }
                }

                // input bar
                HStack(spacing: 8) {
                    Text(elevated ? "#" : "$")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(elevated ? .orange : .secondary)
                        .frame(width: 14)

                    TextField("enter command", text: $input)
                        .font(.system(size: 14, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.go)
                        .onSubmit { submit() }
                        .disabled(running || !mgr.sbxready)

                    if running {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button(action: submit) {
                            Image(systemName: "return")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || !mgr.sbxready)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))

                if !mgr.sbxready {
                    Text("Sandbox escape required. Initialize System first.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Terminal")
            .toolbar {
                Menu {
                    Button(role: .destructive) {
                        lines.removeAll()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    Button {
                        UIPasteboard.general.string = lines.joined(separator: "\n")
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label("Copy All", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            if mgr.sbxready && !elevated {
                elevate()
            }
        }
        .onChange(of: mgr.sbxready) { ready in
            if ready && !elevated {
                elevate()
            }
        }
    }

    private func elevate() {
        mgr.sbxelevate()
        elevated = true
        lines.append("(elevated to root)")
    }

    private func submit() {
        let cmd = input.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty, !running, mgr.sbxready else { return }
        lines.append((elevated ? "# " : "$ ") + cmd)
        input = ""
        running = true
        ShellRunner.run(cmd) { output in
            lines.append(output)
            running = false
        }
    }
}

#Preview {
    TerminalView()
        .environmentObject(laramgr())
}
