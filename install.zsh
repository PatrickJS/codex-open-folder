#!/bin/zsh

set -u

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

INSTALL_HOME="${OPEN_IN_CODEX_INSTALL_HOME:-$HOME}"
DRY_RUN=0
NO_REFRESH=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
      ;;
    --no-refresh)
      NO_REFRESH=1
      ;;
    *)
      print -r -- "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ "$(/usr/bin/uname)" != "Darwin" ]]; then
  print -r -- "This installer only creates a macOS Finder Quick Action." >&2
  exit 1
fi

SCRIPT_DIR="${0:A:h}"
HELPER_SOURCE="$SCRIPT_DIR/bin/codex-open-folder.zsh"
HELPER_TARGET="$INSTALL_HOME/.codex/bin/codex-open-folder.zsh"
OLD_NODE_HELPER="$INSTALL_HOME/.codex/bin/codex-open-folder.mjs"
WORKFLOW_DIR="$INSTALL_HOME/Library/Services/Open in Codex.workflow"
CONTENTS_DIR="$WORKFLOW_DIR/Contents"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
DOCUMENT_WFLOW="$CONTENTS_DIR/document.wflow"

run_or_echo() {
  if (( DRY_RUN )); then
    print -r -- "[dry-run] $*"
  else
    "$@"
  fi
}

write_file() {
  local file_path="$1"
  if (( DRY_RUN )); then
    print -r -- "[dry-run] write $file_path"
    return 0
  fi

  mkdir -p "${file_path:h}"
  cat > "$file_path"
}

if [[ ! -f "$HELPER_SOURCE" ]]; then
  print -r -- "Missing helper source: $HELPER_SOURCE" >&2
  exit 1
fi

run_or_echo mkdir -p "${HELPER_TARGET:h}"
run_or_echo cp "$HELPER_SOURCE" "$HELPER_TARGET"
run_or_echo chmod 755 "$HELPER_TARGET"

if [[ -f "$OLD_NODE_HELPER" ]]; then
  run_or_echo rm -f "$OLD_NODE_HELPER"
fi

if [[ -e "$WORKFLOW_DIR" ]]; then
  run_or_echo rm -rf "$WORKFLOW_DIR"
fi
run_or_echo mkdir -p "$RESOURCES_DIR"

write_file "$INFO_PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSBackgroundColorName</key>
			<string>background</string>
			<key>NSIconName</key>
			<string>workflowCustomImage</string>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>Open in Codex</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
			<key>NSRequiredContext</key>
			<dict>
				<key>NSApplicationIdentifier</key>
				<string>com.apple.finder</string>
			</dict>
			<key>NSSendFileTypes</key>
			<array>
				<string>public.folder</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
PLIST

write_file "$DOCUMENT_WFLOW" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>533</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<false/>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.path</string>
					</array>
				</dict>
				<key>AMActionVersion</key>
				<string>2.0.3</string>
				<key>AMApplication</key>
				<array>
					<string>Automator</string>
				</array>
				<key>AMParameterProperties</key>
				<dict>
					<key>COMMAND_STRING</key>
					<dict/>
					<key>CheckedForUserDefaultShell</key>
					<dict/>
					<key>inputMethod</key>
					<dict/>
					<key>shell</key>
					<dict/>
					<key>source</key>
					<dict/>
				</dict>
				<key>AMProvides</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string><![CDATA[#!/bin/zsh

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

helper="$HOME/.codex/bin/codex-open-folder.zsh"

if [ ! -f "$helper" ]; then
  /usr/bin/osascript -e "display dialog \"Codex Finder helper was not found at ~/.codex/bin/codex-open-folder.zsh\" buttons {\"OK\"} default button \"OK\" with icon caution"
  exit 1
fi

/bin/zsh "$helper" "$@"
]]></string>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>inputMethod</key>
					<integer>1</integer>
					<key>shell</key>
					<string>/bin/zsh</string>
					<key>source</key>
					<string></string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key>
				<false/>
				<key>CanShowWhenRun</key>
				<true/>
				<key>Category</key>
				<array>
					<string>AMCategoryUtilities</string>
				</array>
				<key>Class Name</key>
				<string>RunShellScriptAction</string>
				<key>InputUUID</key>
				<string>9876EC08-CA52-494A-9D34-F1BF3C4518F5</string>
				<key>Keywords</key>
				<array>
					<string>Shell</string>
					<string>Script</string>
					<string>Command</string>
					<string>Run</string>
					<string>Unix</string>
				</array>
				<key>OutputUUID</key>
				<string>6AE85C5F-6C8F-4990-9B0E-8ED2DAFC3D7D</string>
				<key>ShowWhenRun</key>
				<false/>
				<key>UUID</key>
				<string>543B2D5E-39D7-464B-951E-C39271C416BD</string>
				<key>UnlocalizedApplications</key>
				<array>
					<string>Automator</string>
				</array>
			</dict>
			<key>isViewVisible</key>
			<integer>1</integer>
			<key>location</key>
			<string>239.500000:238.000000</string>
			<key>nibPath</key>
			<string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/English.lproj/main.nib</string>
		</dict>
	</array>
	<key>connectors</key>
	<dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>applicationBundleIDsByPath</key>
		<dict/>
		<key>applicationPaths</key>
		<array/>
		<key>inputTypeIdentifier</key>
		<string>com.apple.Automator.fileSystemObject</string>
		<key>outputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>presentationMode</key>
		<integer>15</integer>
		<key>processesInput</key>
		<integer>0</integer>
		<key>serviceApplicationBundleID</key>
		<string>com.apple.finder</string>
		<key>serviceApplicationPath</key>
		<string>/System/Library/CoreServices/Finder.app</string>
		<key>serviceInputTypeIdentifier</key>
		<string>com.apple.Automator.fileSystemObject</string>
		<key>serviceOutputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>serviceProcessesInput</key>
		<integer>0</integer>
		<key>useAutomaticInputType</key>
		<integer>0</integer>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
PLIST

for icon in \
  "/Applications/Codex.app/Contents/Resources/icon.icns" \
  "/Applications/Codex.app/Contents/Resources/electron.icns"; do
  if [[ -f "$icon" ]]; then
    run_or_echo cp "$icon" "$RESOURCES_DIR/workflowCustomImage.icns"
    break
  fi
done

if (( ! DRY_RUN )); then
  /usr/bin/plutil -lint "$INFO_PLIST" || exit 1
  /usr/bin/plutil -lint "$DOCUMENT_WFLOW" || exit 1
fi

if (( ! DRY_RUN && ! NO_REFRESH )); then
  /usr/bin/touch "$INSTALL_HOME/Library/Services"
  /System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
  /System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
fi

print -r -- "Installed helper: $HELPER_TARGET"
print -r -- "Installed Finder Quick Action: $WORKFLOW_DIR"
print -r -- "Use Finder > right-click a folder > Quick Actions or Services > Open in Codex."
