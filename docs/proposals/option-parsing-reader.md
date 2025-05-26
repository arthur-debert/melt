# Option Parsig parameters in Melt

How command-line options can be integrated into
`lua.melt: focusing on translating flat option keys into a hierarchical structure. This is based on the behavior of the existing [`env.lua`](lua/melt/readers/env.lua:1)
reader and typical patterns in Lua command-line parsing libraries.

**Proposal for Command-Line Option Reader in `lua.melt`**

1.  **Input to the Reader:**

    - The command-line option reader function will accept a single Lua table as
      input.
    - This input table is expected to be the direct result produced by a
      command-line argument parsing library (e.g., Lapp, lua-argparse, cliargs,
      etc.) that the end-user's application employs. `lua.melt` itself will
      _not_ parse `argv` or the command-line string.

2.  **Key Transformation and Hierarchy:**

    - **Primary Separator:** The hyphen character (`-`) in an option key (from
      the input table) will be used as the delimiter to create hierarchical
      structures.
    - **Case Conversion:** All option keys, and the segments derived from
      splitting them, will be converted to lowercase. This ensures consistency
      and matches the behavior of the [`env.lua`](lua/melt/readers/env.lua:82)
      reader which also lowercases keys.
    - **Transformation Process:**
      - For each `key, value` pair in the input table:
        1.  Take the `key` (string).
        2.  Convert `key` to lowercase.
        3.  Split the lowercased `key` by the hyphen (`-`) character. For
            example, `"database-connection-timeout"` becomes
            `{"database", "connection", "timeout"}`.
        4.  Join these segments with a dot (`.`) to form a path string:
            `"database.connection.timeout"`.
        5.  Keys without hyphens (e.g., `"logfile"`, `"retry_attempts"`) will
            remain as top-level keys after lowercasing (e.g., `"logfile"`,
            `"retry_attempts"`).

3.  **Value Conversion:**

    - Values obtained from the input table (which are often strings by default
      from parsing libraries) should undergo type conversion.
    - This conversion logic should be similar to the
      [`convert_value`](lua/melt/readers/env.lua:24) function found in
      [`env.lua`](lua/melt/readers/env.lua:1):
      - Attempt to convert string values `"true"` and `"false"`
        (case-insensitively) to Lua booleans.
      - Attempt to convert string values that represent numbers (e.g., `"123"`,
        `"3.14"`) to Lua numbers.
      - If a value from the parsing library is already a non-string type (e.g.,
        a boolean or number directly provided by the parser), it should be used
        as-is. The existing [`convert_value`](lua/melt/readers/env.lua:25)
        function already handles this by returning non-string inputs directly.

4.  **Populating the Configuration Table:**
    - A helper function, analogous to
      [`set_nested_value(tbl, path_str, value)`](lua/melt/readers/env.lua:6)
      from [`env.lua`](lua/melt/readers/env.lua:1), will be used.
    - This function will take the target configuration table, the transformed
      path string (e.g., `"database.connection.timeout"`), and the (potentially
      type-converted) value to populate the configuration.

**Consistency with Existing Readers:**

- **`env.lua`:** Uses `__` as a separator in the environment variable name,
  converting to `.` and lowercasing. The proposed CLI reader uses `-` from the
  option key, converting to `.` and lowercasing. The core idea of a designated
  separator mapping to `.` and lowercasing is consistent.
- **`ini.lua`:** Relies on the `ini_config` library which handles INI sections
  as tables. This is inherently hierarchical. The CLI proposal achieves
  hierarchy through key naming conventions.

**Example:**

If a command-line parsing library provides the following table to `lua.melt`:

```lua
{
  ["Log-Level"] = "DEBUG",
  ["database-host"] = "db.example.com",
  ["DATABASE-PORT"] = "5432",
  ["enable-feature-x"] = "true",
  ["max_retries"] = "10",       -- underscore, not hyphen
  ["timeout"] = "30.5"
}
```

The `lua.melt` command-line reader would process this into the following
structure:

```lua
{
  log = {
    level = "DEBUG" -- Assuming "DEBUG" doesn't match boolean/number conversion
  },
  database = {
    host = "db.example.com",
    port = 5432          -- Converted to number
  },
  enable = {
    feature = {
      x = true           -- Converted to boolean
    }
  },
  max_retries = 10,      -- Lowercased, remains top-level, converted to number
  timeout = 30.5         -- Lowercased, remains top-level, converted to number
}
```

**Rationale for Hyphen as Separator:**

- Hyphens are a very common convention in command-line option names (e.g.,
  `--my-config-option`).
- The user's example (`--repository-name` to `repository.name`) directly
  suggests this.
- Using a single, common character like `-` makes it intuitive for users to
  structure their option names for hierarchical configuration.

This approach ensures that the mechanism is straightforward for users: if they
name their command-line options with hyphens where they intend hierarchy,
`lua.melt` will interpret it accordingly. Options without hyphens, or with other
separators like underscores, will be treated as single-level keys.
