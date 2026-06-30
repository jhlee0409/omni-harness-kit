/**
 * Type helpers — avoids importing non-exported BunShell from the plugin SDK.
 * The `$` shell function is typed via PluginInput's own declaration.
 */

/** Minimal shell type matching what we use from BunShell. */
export interface Shell {
  (strings: TemplateStringsArray, ...expressions: unknown[]): ShellPromise;
}

export interface ShellPromise extends Promise<ShellOutput> {
  quiet(): this;
}

export interface ShellOutput {
  text(encoding?: BufferEncoding): string;
  readonly exitCode: number;
}
