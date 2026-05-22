import assert from "node:assert/strict";
import test from "node:test";

import {
  buildThreadLookupSql,
  decideLaunchAction,
  parseThreadId,
  uniqueExistingPaths,
} from "../lib/codex-open-folder.mjs";

test("decideLaunchAction opens the latest exact folder thread when one exists", () => {
  assert.deepEqual(
    decideLaunchAction({
      folder: "/Users/patrickjs/code/example",
      threadId: "019e4e34-a595-7dd2-af09-1991f2f993dd",
    }),
    {
      kind: "open-thread",
      url: "codex://threads/019e4e34-a595-7dd2-af09-1991f2f993dd",
    },
  );
});

test("decideLaunchAction asks before opening a folder with no existing thread", () => {
  assert.deepEqual(
    decideLaunchAction({
      folder: "/Users/patrickjs/code/new-project",
      isSavedProject: false,
      threadId: null,
    }),
    {
      folder: "/Users/patrickjs/code/new-project",
      kind: "ask-open-project",
    },
  );
});

test("decideLaunchAction opens a saved project even when it has no exact thread", () => {
  assert.deepEqual(
    decideLaunchAction({
      folder: "/Users/patrickjs/code/existing-project",
      isSavedProject: true,
      threadId: null,
    }),
    {
      folder: "/Users/patrickjs/code/existing-project",
      kind: "open-project",
    },
  );
});

test("decideLaunchAction opens the project only after confirmation", () => {
  assert.deepEqual(
    decideLaunchAction({
      folder: "/Users/patrickjs/code/new-project",
      newFolderChoice: "open-project",
      threadId: null,
    }),
    {
      folder: "/Users/patrickjs/code/new-project",
      kind: "open-project",
    },
  );
});

test("decideLaunchAction can open Codex without creating a project", () => {
  assert.deepEqual(
    decideLaunchAction({
      folder: "/Users/patrickjs/code/new-project",
      newFolderChoice: "open-codex",
      threadId: null,
    }),
    {
      kind: "open-codex",
    },
  );
});

test("decideLaunchAction can cancel a new folder prompt", () => {
  assert.deepEqual(
    decideLaunchAction({
      folder: "/Users/patrickjs/code/new-project",
      newFolderChoice: "cancel",
      threadId: null,
    }),
    {
      kind: "cancel",
    },
  );
});

test("buildThreadLookupSql queries exact candidate cwd values newest first", () => {
  assert.equal(
    buildThreadLookupSql([
      "/tmp/project",
      "/tmp/project",
      "/tmp/project's child",
    ]),
    "SELECT id FROM threads WHERE archived=0 AND cwd IN ('/tmp/project','/tmp/project''s child') ORDER BY updated_at_ms DESC, updated_at DESC LIMIT 1;",
  );
});

test("parseThreadId returns only a non-empty sqlite result", () => {
  assert.equal(parseThreadId("  019e4e34-a595-7dd2-af09-1991f2f993dd\n"), "019e4e34-a595-7dd2-af09-1991f2f993dd");
  assert.equal(parseThreadId("\n"), null);
});

test("uniqueExistingPaths preserves order and removes duplicates", () => {
  assert.deepEqual(
    uniqueExistingPaths(["/tmp/a", "/tmp/a", "/tmp/b"]),
    ["/tmp/a", "/tmp/b"],
  );
});
