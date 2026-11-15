const { spawn } = require("node:child_process");

const child = spawn("powershell.exe", [
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", "tools\\ProcessNewCrabIcons.ps1",
], { stdio: ["pipe", "pipe", "pipe"] });

if (process.stdin.isTTY) process.stdin.setRawMode(true);
process.stdin.resume();
process.stdin.on("data", (chunk) => child.stdin.write(chunk));
process.stdin.on("end", () => child.stdin.end());
child.stdout.on("data", (chunk) => process.stdout.write(chunk));
child.stderr.on("data", (chunk) => process.stderr.write(chunk));
child.on("exit", (code) => process.exit(code || 0));
