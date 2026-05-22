#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import {
  chmodSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { homedir, platform } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const installHome = process.env.OPEN_IN_CODEX_INSTALL_HOME || homedir();
const dryRun = process.argv.includes("--dry-run");
const noRefresh = process.argv.includes("--no-refresh");

const helperSource = join(repoRoot, "lib", "codex-open-folder.mjs");
const helperTarget = join(installHome, ".codex", "bin", "codex-open-folder.mjs");
const workflowDir = join(installHome, "Library", "Services", "Open in Codex.workflow");
const workflowContentsDir = join(workflowDir, "Contents");
const workflowResourcesDir = join(workflowContentsDir, "Resources");
const infoPlistPath = join(workflowContentsDir, "Info.plist");
const documentPath = join(workflowContentsDir, "document.wflow");

function log(message) {
  process.stdout.write(`${message}\n`);
}

function ensureMacOS() {
  if (platform() !== "darwin") {
    throw new Error("This installer only creates a macOS Finder Quick Action.");
  }
}

function ensureFile(path) {
  if (!existsSync(path) || !statSync(path).isFile()) {
    throw new Error(`Required file not found: ${path}`);
  }
}

function escapeXml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function writeFile(path, contents) {
  if (dryRun) {
    log(`[dry-run] write ${path}`);
    return;
  }

  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, contents);
}

function copyFile(source, target) {
  if (dryRun) {
    log(`[dry-run] copy ${source} -> ${target}`);
    return;
  }

  mkdirSync(dirname(target), { recursive: true });
  copyFileSync(source, target);
}

function removePath(path) {
  if (dryRun) {
    log(`[dry-run] remove ${path}`);
    return;
  }

  rmSync(path, { force: true, recursive: true });
}

function workflowCommand() {
  return `#!/bin/zsh

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

helper="$HOME/.codex/bin/codex-open-folder.mjs"
node_bin="/Applications/Codex.app/Contents/Resources/node"

if [ ! -x "$node_bin" ]; then
  node_bin="$(command -v node 2>/dev/null)"
fi

if [ -z "$node_bin" ]; then
  /usr/bin/osascript -e "display dialog \\"Node.js was not found, and Codex.app's bundled Node runtime is unavailable.\\" buttons {\\"OK\\"} default button \\"OK\\" with icon caution"
  exit 1
fi

if [ ! -f "$helper" ]; then
  /usr/bin/osascript -e "display dialog \\"Codex Finder helper was not found at ~/.codex/bin/codex-open-folder.mjs\\" buttons {\\"OK\\"} default button \\"OK\\" with icon caution"
  exit 1
fi

"$node_bin" "$helper" "$@"
`;
}

function infoPlist() {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>NSServices</key>
\t<array>
\t\t<dict>
\t\t\t<key>NSBackgroundColorName</key>
\t\t\t<string>background</string>
\t\t\t<key>NSIconName</key>
\t\t\t<string>workflowCustomImage</string>
\t\t\t<key>NSMenuItem</key>
\t\t\t<dict>
\t\t\t\t<key>default</key>
\t\t\t\t<string>Open in Codex</string>
\t\t\t</dict>
\t\t\t<key>NSMessage</key>
\t\t\t<string>runWorkflowAsService</string>
\t\t\t<key>NSRequiredContext</key>
\t\t\t<dict>
\t\t\t\t<key>NSApplicationIdentifier</key>
\t\t\t\t<string>com.apple.finder</string>
\t\t\t</dict>
\t\t\t<key>NSSendFileTypes</key>
\t\t\t<array>
\t\t\t\t<string>public.folder</string>
\t\t\t</array>
\t\t</dict>
\t</array>
</dict>
</plist>
`;
}

function documentWorkflow() {
  const command = escapeXml(workflowCommand());

  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>AMApplicationBuild</key>
\t<string>533</string>
\t<key>AMApplicationVersion</key>
\t<string>2.10</string>
\t<key>AMDocumentVersion</key>
\t<string>2</string>
\t<key>actions</key>
\t<array>
\t\t<dict>
\t\t\t<key>action</key>
\t\t\t<dict>
\t\t\t\t<key>AMAccepts</key>
\t\t\t\t<dict>
\t\t\t\t\t<key>Container</key>
\t\t\t\t\t<string>List</string>
\t\t\t\t\t<key>Optional</key>
\t\t\t\t\t<false/>
\t\t\t\t\t<key>Types</key>
\t\t\t\t\t<array>
\t\t\t\t\t\t<string>com.apple.cocoa.path</string>
\t\t\t\t\t</array>
\t\t\t\t</dict>
\t\t\t\t<key>AMActionVersion</key>
\t\t\t\t<string>2.0.3</string>
\t\t\t\t<key>AMApplication</key>
\t\t\t\t<array>
\t\t\t\t\t<string>Automator</string>
\t\t\t\t</array>
\t\t\t\t<key>AMParameterProperties</key>
\t\t\t\t<dict>
\t\t\t\t\t<key>COMMAND_STRING</key>
\t\t\t\t\t<dict/>
\t\t\t\t\t<key>CheckedForUserDefaultShell</key>
\t\t\t\t\t<dict/>
\t\t\t\t\t<key>inputMethod</key>
\t\t\t\t\t<dict/>
\t\t\t\t\t<key>shell</key>
\t\t\t\t\t<dict/>
\t\t\t\t\t<key>source</key>
\t\t\t\t\t<dict/>
\t\t\t\t</dict>
\t\t\t\t<key>AMProvides</key>
\t\t\t\t<dict>
\t\t\t\t\t<key>Container</key>
\t\t\t\t\t<string>List</string>
\t\t\t\t\t<key>Types</key>
\t\t\t\t\t<array>
\t\t\t\t\t\t<string>com.apple.cocoa.string</string>
\t\t\t\t\t</array>
\t\t\t\t</dict>
\t\t\t\t<key>ActionBundlePath</key>
\t\t\t\t<string>/System/Library/Automator/Run Shell Script.action</string>
\t\t\t\t<key>ActionName</key>
\t\t\t\t<string>Run Shell Script</string>
\t\t\t\t<key>ActionParameters</key>
\t\t\t\t<dict>
\t\t\t\t\t<key>COMMAND_STRING</key>
\t\t\t\t\t<string>${command}</string>
\t\t\t\t\t<key>CheckedForUserDefaultShell</key>
\t\t\t\t\t<true/>
\t\t\t\t\t<key>inputMethod</key>
\t\t\t\t\t<integer>1</integer>
\t\t\t\t\t<key>shell</key>
\t\t\t\t\t<string>/bin/zsh</string>
\t\t\t\t\t<key>source</key>
\t\t\t\t\t<string></string>
\t\t\t\t</dict>
\t\t\t\t<key>BundleIdentifier</key>
\t\t\t\t<string>com.apple.RunShellScript</string>
\t\t\t\t<key>CFBundleVersion</key>
\t\t\t\t<string>2.0.3</string>
\t\t\t\t<key>CanShowSelectedItemsWhenRun</key>
\t\t\t\t<false/>
\t\t\t\t<key>CanShowWhenRun</key>
\t\t\t\t<true/>
\t\t\t\t<key>Category</key>
\t\t\t\t<array>
\t\t\t\t\t<string>AMCategoryUtilities</string>
\t\t\t\t</array>
\t\t\t\t<key>Class Name</key>
\t\t\t\t<string>RunShellScriptAction</string>
\t\t\t\t<key>InputUUID</key>
\t\t\t\t<string>9876EC08-CA52-494A-9D34-F1BF3C4518F5</string>
\t\t\t\t<key>Keywords</key>
\t\t\t\t<array>
\t\t\t\t\t<string>Shell</string>
\t\t\t\t\t<string>Script</string>
\t\t\t\t\t<string>Command</string>
\t\t\t\t\t<string>Run</string>
\t\t\t\t\t<string>Unix</string>
\t\t\t\t</array>
\t\t\t\t<key>OutputUUID</key>
\t\t\t\t<string>6AE85C5F-6C8F-4990-9B0E-8ED2DAFC3D7D</string>
\t\t\t\t<key>ShowWhenRun</key>
\t\t\t\t<false/>
\t\t\t\t<key>UUID</key>
\t\t\t\t<string>543B2D5E-39D7-464B-951E-C39271C416BD</string>
\t\t\t\t<key>UnlocalizedApplications</key>
\t\t\t\t<array>
\t\t\t\t\t<string>Automator</string>
\t\t\t\t</array>
\t\t\t</dict>
\t\t\t<key>isViewVisible</key>
\t\t\t<integer>1</integer>
\t\t\t<key>location</key>
\t\t\t<string>239.500000:238.000000</string>
\t\t\t<key>nibPath</key>
\t\t\t<string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/English.lproj/main.nib</string>
\t\t</dict>
\t</array>
\t<key>connectors</key>
\t<dict/>
\t<key>workflowMetaData</key>
\t<dict>
\t\t<key>applicationBundleIDsByPath</key>
\t\t<dict/>
\t\t<key>applicationPaths</key>
\t\t<array/>
\t\t<key>inputTypeIdentifier</key>
\t\t<string>com.apple.Automator.fileSystemObject</string>
\t\t<key>outputTypeIdentifier</key>
\t\t<string>com.apple.Automator.nothing</string>
\t\t<key>presentationMode</key>
\t\t<integer>15</integer>
\t\t<key>processesInput</key>
\t\t<integer>0</integer>
\t\t<key>serviceApplicationBundleID</key>
\t\t<string>com.apple.finder</string>
\t\t<key>serviceApplicationPath</key>
\t\t<string>/System/Library/CoreServices/Finder.app</string>
\t\t<key>serviceInputTypeIdentifier</key>
\t\t<string>com.apple.Automator.fileSystemObject</string>
\t\t<key>serviceOutputTypeIdentifier</key>
\t\t<string>com.apple.Automator.nothing</string>
\t\t<key>serviceProcessesInput</key>
\t\t<integer>0</integer>
\t\t<key>useAutomaticInputType</key>
\t\t<integer>0</integer>
\t\t<key>workflowTypeIdentifier</key>
\t\t<string>com.apple.Automator.servicesMenu</string>
\t</dict>
</dict>
</plist>
`;
}

function installIcon() {
  const iconCandidates = [
    "/Applications/Codex.app/Contents/Resources/icon.icns",
    "/Applications/Codex.app/Contents/Resources/electron.icns",
  ];
  const iconSource = iconCandidates.find((path) => existsSync(path));
  if (iconSource == null) {
    log("Codex app icon was not found; installing workflow without a custom icon.");
    return;
  }

  copyFile(iconSource, join(workflowResourcesDir, "workflowCustomImage.icns"));
}

function lintPlist(path) {
  if (dryRun || !existsSync("/usr/bin/plutil")) {
    return;
  }

  execFileSync("/usr/bin/plutil", ["-lint", path], { stdio: "inherit" });
}

function refreshServices() {
  if (dryRun || noRefresh) {
    return;
  }

  try {
    execFileSync("/usr/bin/touch", [join(installHome, "Library", "Services")], {
      stdio: "ignore",
    });
    execFileSync("/System/Library/CoreServices/pbs", ["-flush"], { stdio: "ignore" });
    execFileSync("/System/Library/CoreServices/pbs", ["-update"], { stdio: "ignore" });
  } catch {
    log("Installed workflow, but macOS Services refresh did not complete. Log out/in if it does not appear.");
  }
}

function main() {
  ensureMacOS();
  ensureFile(helperSource);

  copyFile(helperSource, helperTarget);
  if (!dryRun) {
    chmodSync(helperTarget, 0o755);
  }

  removePath(workflowDir);
  if (dryRun) {
    log(`[dry-run] create ${workflowResourcesDir}`);
  } else {
    mkdirSync(workflowResourcesDir, { recursive: true });
  }
  writeFile(infoPlistPath, infoPlist());
  writeFile(documentPath, documentWorkflow());
  installIcon();

  lintPlist(infoPlistPath);
  lintPlist(documentPath);
  refreshServices();

  log(`Installed helper: ${helperTarget}`);
  log(`Installed Finder Quick Action: ${workflowDir}`);
  log("Use Finder > right-click a folder > Quick Actions or Services > Open in Codex.");
}

main();
