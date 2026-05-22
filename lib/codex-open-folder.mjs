#!/usr/bin/env node

import { execFileSync, spawn } from "node:child_process";
import {
  existsSync,
  readFileSync,
  readdirSync,
  realpathSync,
  statSync,
} from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const DEFAULT_CODEX_HOME = join(homedir(), ".codex");

export function uniqueExistingPaths(paths) {
  const seen = new Set();
  const unique = [];

  for (const path of paths) {
    if (typeof path !== "string" || path.length === 0 || seen.has(path)) {
      continue;
    }

    seen.add(path);
    unique.push(path);
  }

  return unique;
}

export function quoteSqlString(value) {
  return `'${value.replaceAll("'", "''")}'`;
}

export function buildThreadLookupSql(paths) {
  const candidates = uniqueExistingPaths(paths);
  if (candidates.length === 0) {
    throw new Error("At least one folder path is required");
  }

  return `SELECT id FROM threads WHERE archived=0 AND cwd IN (${candidates
    .map(quoteSqlString)
    .join(",")}) ORDER BY updated_at_ms DESC, updated_at DESC LIMIT 1;`;
}

export function parseThreadId(output) {
  const value = output.trim();
  return value.length === 0 ? null : value.split(/\r?\n/, 1)[0];
}

export function decideLaunchAction({
  folder,
  isSavedProject = false,
  newFolderChoice = null,
  threadId,
}) {
  if (threadId != null && threadId.length > 0) {
    return {
      kind: "open-thread",
      url: `codex://threads/${threadId}`,
    };
  }

  if (isSavedProject || newFolderChoice === "open-project") {
    return {
      folder,
      kind: "open-project",
    };
  }

  if (newFolderChoice === "open-codex") {
    return {
      kind: "open-codex",
    };
  }

  if (newFolderChoice === "cancel") {
    return {
      kind: "cancel",
    };
  }

  return {
    folder,
    kind: "ask-open-project",
  };
}

function executableCandidates(name) {
  const pathCandidates = (process.env.PATH ?? "")
    .split(":")
    .filter(Boolean)
    .map((path) => join(path, name));

  return uniqueExistingPaths([
    ...pathCandidates,
    `/opt/homebrew/bin/${name}`,
    `/usr/local/bin/${name}`,
    `/usr/bin/${name}`,
    `/bin/${name}`,
    `${homedir()}/.local/bin/${name}`,
    `${homedir()}/bin/${name}`,
  ]);
}

function isExecutable(path) {
  try {
    return existsSync(path) && statSync(path).isFile();
  } catch {
    return false;
  }
}

function findExecutable(name, extraCandidates = []) {
  for (const candidate of uniqueExistingPaths([
    ...extraCandidates,
    ...executableCandidates(name),
  ])) {
    if (isExecutable(candidate)) {
      return candidate;
    }
  }

  return null;
}

function nvmCodexCandidates() {
  const versionsRoot = join(homedir(), ".nvm", "versions", "node");
  try {
    return readdirSync(versionsRoot)
      .sort()
      .reverse()
      .map((version) => join(versionsRoot, version, "bin", "codex"));
  } catch {
    return [];
  }
}

function findCodexBin() {
  const envCandidate = process.env.CODEX_BIN;
  return findExecutable("codex", [
    ...(envCandidate == null ? [] : [envCandidate]),
    ...nvmCodexCandidates(),
  ]);
}

function findSqlite3Bin() {
  const envCandidate = process.env.SQLITE3_BIN;
  return findExecutable("sqlite3", envCandidate == null ? [] : [envCandidate]);
}

function codexHome() {
  return process.env.CODEX_HOME || DEFAULT_CODEX_HOME;
}

function stateDbPath() {
  return process.env.CODEX_STATE_DB || join(codexHome(), "state_5.sqlite");
}

function globalStatePath() {
  return process.env.CODEX_GLOBAL_STATE || join(codexHome(), ".codex-global-state.json");
}

function selectedFolderCandidates(input) {
  const absolute = resolve(input);
  const real = (() => {
    try {
      return realpathSync(absolute);
    } catch {
      return absolute;
    }
  })();

  return uniqueExistingPaths([absolute, real]);
}

function ensureFolder(input) {
  const absolute = resolve(input);
  if (!existsSync(absolute)) {
    throw new Error(`Path does not exist: ${absolute}`);
  }

  if (!statSync(absolute).isDirectory()) {
    throw new Error(`Open in Codex expects a folder, not a file: ${absolute}`);
  }

  return absolute;
}

function lookupLatestThreadId(folderCandidates) {
  const sqlite3Bin = findSqlite3Bin();
  const dbPath = stateDbPath();

  if (sqlite3Bin == null || !existsSync(dbPath)) {
    return null;
  }

  try {
    return parseThreadId(
      execFileSync(sqlite3Bin, [dbPath, buildThreadLookupSql(folderCandidates)], {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"],
      }),
    );
  } catch {
    return null;
  }
}

function readGlobalState() {
  const filePath = globalStatePath();
  try {
    return JSON.parse(readFileSync(filePath, "utf8"));
  } catch {
    return {};
  }
}

function isSavedProject(folderCandidates) {
  const roots = readGlobalState()["electron-saved-workspace-roots"];
  if (!Array.isArray(roots)) {
    return false;
  }

  return roots.some((root) => folderCandidates.includes(root));
}

function runOsascript(script, args = []) {
  return execFileSync("/usr/bin/osascript", ["-", ...args], {
    encoding: "utf8",
    input: script,
    stdio: ["pipe", "pipe", "ignore"],
  }).trim();
}

function showInfoDialog(message) {
  runOsascript(
    `on run argv
  display dialog (item 1 of argv) buttons {"OK"} default button "OK" with icon caution
end run
`,
    [message],
  );
}

function chooseNewFolderAction(folder) {
  let result;
  try {
    result = runOsascript(
      `on run argv
  set folderPath to item 1 of argv
  set promptText to "No existing Codex chat or saved project was found for:" & return & return & folderPath & return & return & "Open this folder in Codex as a project, or just open Codex?"
  return button returned of (display dialog promptText buttons {"Cancel", "Open Codex", "Open Project"} default button "Open Project" with icon note)
end run
`,
      [folder],
    );
  } catch {
    return "cancel";
  }

  if (result === "Open Project") {
    return "open-project";
  }

  if (result === "Open Codex") {
    return "open-codex";
  }

  return "cancel";
}

function openThread(url) {
  const child = spawn("/usr/bin/open", [url], {
    detached: true,
    stdio: "ignore",
  });
  child.unref();
}

function openProject(folder) {
  const codexBin = findCodexBin();
  if (codexBin == null) {
    showInfoDialog("Codex CLI was not found. Install it with: npm i -g @openai/codex");
    return 1;
  }

  const child = spawn(codexBin, ["app", folder], {
    detached: true,
    stdio: "ignore",
  });
  child.unref();
  return 0;
}

function openCodex() {
  const child = spawn("/usr/bin/open", ["-a", "Codex"], {
    detached: true,
    stdio: "ignore",
  });
  child.unref();
  return 0;
}

function handleFolder(input) {
  const folder = ensureFolder(input);
  const candidates = selectedFolderCandidates(folder);
  const threadId = lookupLatestThreadId(candidates);
  const action = decideLaunchAction({
    folder,
    isSavedProject: isSavedProject(candidates),
    threadId,
  });

  if (action.kind === "open-thread") {
    openThread(action.url);
    return 0;
  }

  if (action.kind === "open-project") {
    return openProject(action.folder);
  }

  if (action.kind === "open-codex") {
    return openCodex();
  }

  if (action.kind === "cancel") {
    return 0;
  }

  const confirmedAction = decideLaunchAction({
    folder: action.folder,
    isSavedProject: false,
    newFolderChoice: chooseNewFolderAction(action.folder),
    threadId: null,
  });

  if (confirmedAction.kind === "open-project") {
    return openProject(confirmedAction.folder);
  }

  if (confirmedAction.kind === "open-codex") {
    return openCodex();
  }

  return 0;
}

export async function runCli(argv = process.argv.slice(2)) {
  if (argv.length === 0) {
    showInfoDialog("Select a folder in Finder, then choose Open in Codex.");
    return 1;
  }

  let exitCode = 0;
  for (const input of argv) {
    try {
      exitCode = Math.max(exitCode, handleFolder(input));
    } catch (error) {
      showInfoDialog(error instanceof Error ? error.message : String(error));
      exitCode = 1;
    }
  }

  return exitCode;
}

const invokedPath = process.argv[1] == null ? null : pathToFileURL(process.argv[1]).href;
if (invokedPath === import.meta.url) {
  process.exitCode = await runCli();
}
