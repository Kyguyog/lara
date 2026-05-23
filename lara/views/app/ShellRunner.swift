//
//  ShellRunner.swift
//  lara
//

import Foundation

class ShellRunner {
    static func run(_ command: String, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let pipe = Pipe()
            var pid: pid_t = 0

            var spawnAttr = posix_spawnattr_t(bitPattern: 0)
            posix_spawnattr_init(&spawnAttr)

            var fileActions = posix_spawn_file_actions_t(bitPattern: 0)
            posix_spawn_file_actions_init(&fileActions)
            posix_spawn_file_actions_adddup2(&fileActions, pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
            posix_spawn_file_actions_adddup2(&fileActions, pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
            posix_spawn_file_actions_addclose(&fileActions, pipe.fileHandleForReading.fileDescriptor)

            var argv: [UnsafeMutablePointer<CChar>?] = [
                strdup("/bin/sh"),
                strdup("-c"),
                strdup(command),
                nil
            ]
            var envp: [UnsafeMutablePointer<CChar>?] = [
                strdup("PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"),
                strdup("HOME=/var/root"),
                strdup("TERM=xterm"),
                nil
            ]

            let result = argv.withUnsafeMutableBufferPointer { argvPtr in
                envp.withUnsafeMutableBufferPointer { envpPtr in
                    posix_spawn(&pid, "/bin/sh", &fileActions, &spawnAttr,
                                argvPtr.baseAddress, envpPtr.baseAddress)
                }
            }

            pipe.fileHandleForWriting.closeFile()

            let output: String
            if result == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                var raw = String(data: data, encoding: .utf8) ?? ""
                // trim trailing newline
                if raw.hasSuffix("\n") { raw.removeLast() }
                output = raw.isEmpty ? "(no output)" : raw
                waitpid(pid, nil, 0)
            } else {
                output = "spawn failed: errno \(result) (\(String(cString: strerror(result))))"
            }

            argv.compactMap { $0 }.forEach { free($0) }
            envp.compactMap { $0 }.forEach { free($0) }
            posix_spawn_file_actions_destroy(&fileActions)
            posix_spawnattr_destroy(&spawnAttr)

            DispatchQueue.main.async { completion(output) }
        }
    }
}
