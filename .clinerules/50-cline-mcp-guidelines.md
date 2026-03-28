# Cline MCP & Context Management Guidelines

## Context Budget Awareness
- **Always** be extremely mindful of the context window. The system prompt is already large due to many MCP servers.
- **Never** inline large command output directly. Always redirect to a temporary file first (`command > /tmp/output.log 2>&1`), then check size with `wc -c` or `du -h`.
- Only read back small, targeted slices using `head`, `tail`, or specific line ranges.
- Prefer reporting file paths + concise summaries over pasting raw bulk output.

## MCP Server Management
- Only enable the minimum number of MCP servers needed for the current task.
- Keep servers disabled by default unless actively required.
- Before using an MCP tool, verify the server is connected. If you see "No connection found" or "Not connected", do not retry blindly.
- When installing or configuring a new MCP server:
  - Always read the existing `cline_mcp_settings.json` first.
  - Do not overwrite other servers.
  - Set `"disabled": false` and provide a minimal `autoApprove` list.
  - Use the exact server name specified by the user (e.g. `github.com/modelcontextprotocol/servers/tree/main/src/filesystem`).

## Tool Usage Rules
- **execute_command**: Always use `requires_approval: false` for safe operations. For potentially dangerous commands, set to `true`.
- **read_file / replace_in_file**: Always fetch the latest version of a file immediately before editing to avoid formatting mismatches.
- **attempt_completion**: Only call this after you have explicitly verified the task is complete (e.g. by running tests, checking output, or using `browser_action` to confirm UI changes). Never call it prematurely.

## Error Mitigation
- If you see "Invalid API Response" or context errors, immediately reduce output size and use temporary files.
- For MCP connection errors, check the server status before retrying.
- For `replace_in_file` failures, ensure your SEARCH block matches the file exactly (use a fresh `read_file` first).

Follow these rules in every interaction to prevent context overflow and repeated tool failures.