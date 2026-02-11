# Moodle 4.x LMS development: a senior architect's reference

Moodle 4.x introduced a fundamentally redesigned navigation system, a PSR-14 hooks API (from 4.4), expanded table/column name limits (from 4.3), and tighter alignment with modern PHP practices including mandatory type hints and namespaced classes. This guide synthesizes the official developer documentation from moodledev.io, the Moodle GitHub repository, and community sources into an actionable reference for enterprise plugin development. Every section pairs **recommended patterns** with explicit **anti-patterns**, linked to the rationale behind each convention.

---

## 1. Choosing between local and block plugin types

The most common architectural decision when extending Moodle is whether to build a `local` plugin or a `block` plugin. The official guidance at `moodledev.io/docs/apis/plugintypes/local` is clear: **use a standard plugin type first** (activity, block, auth, enrol), and reach for `local` only when nothing else fits.

### When to use a `local` plugin

Local plugins are system-level extensions with no required UI surface. They execute last during install and upgrade, and their `settings.php` loads last in the admin tree—making them ideal for extending any settings page. Core use cases include event observers communicating with external systems, custom web service definitions, scheduled/adhoc tasks, and navigation extensions. Local plugins are the **primary consumer of the Events API** since event subscriptions flow from core to plugins.

### When to use a `block` plugin

Block plugins exist to display contextual, user-facing content on dashboards, course pages, and site pages. They support per-instance configuration via `edit_form.php`, can be placed by users with `addinstance`/`myaddinstance` capabilities, and render inside Moodle 4.x's collapsible **blocks drawer** on the right side. If your feature requires a visible widget that users can add, reposition, or configure per page, a block is the correct choice.

### Decision matrix

|Criterion|`local` plugin|`block` plugin|
|---|---|---|
|Visible UI on pages|Optional|Required|
|Per-instance configuration|No|Yes (`edit_form.php`)|
|Event handling / observers|Primary use case|Not typical|
|Web service definitions|Ideal|Not typical|
|Background tasks (cron)|Ideal|Possible but uncommon|
|Sidebar/dashboard widget|Not directly|Native support|
|System-level extension|Ideal|Not suitable|

**GOOD — choosing correctly:**

```php
// System-level integration that syncs users to an external HR system:
// → local plugin (no UI needed, event-driven, web services)

// Dashboard widget showing a student's upcoming deadlines:
// → block plugin (user-facing, per-instance, page-placeable)
```

**BAD — common mistakes:**

```php
// Using a block plugin solely to run a cron task with no visible output
// → Should be a local plugin with a scheduled task

// Using a local plugin to display course-level content by hacking
// $PAGE output in lib.php callbacks
// → Should be a block plugin or activity module
```

---

## 2. Required plugin files and their specifications

Every Moodle 4.x plugin shares a common file structure defined at `moodledev.io/docs/apis/commonfiles`. Two files are universally mandatory: `version.php` and the language file.

### version.php — the plugin identity card

All fields documented at `moodledev.io/docs/apis/commonfiles/version.php`:

|Field|Required|Description|
|---|---|---|
|`$plugin->component`|**Yes**|Frankenstyle name (`local_myplugin`)|
|`$plugin->version`|**Yes**|`YYYYMMDDXX` integer, must always increase|
|`$plugin->requires`|Recommended|Minimum Moodle version (e.g., `2022112800.00` for 4.1)|
|`$plugin->supported`|Optional (3.9+)|Branch range `[401, 405]` inclusive|
|`$plugin->incompatible`|Optional (3.9+)|Earliest incompatible branch (e.g., `500`)|
|`$plugin->maturity`|Recommended|`MATURITY_ALPHA`, `_BETA`, `_RC`, or `_STABLE`|
|`$plugin->release`|Recommended|Human-readable version string|
|`$plugin->dependencies`|Optional|Array of Frankenstyle names → minimum versions|

**GOOD:**

```php
<?php
defined('MOODLE_INTERNAL') || die();

$plugin->version      = 2024061700;
$plugin->requires     = 2022112800.00;        // Moodle 4.1
$plugin->supported    = [401, 405];           // 4.1 through 4.5
$plugin->incompatible = 500;                  // Not yet compatible with 5.0
$plugin->component    = 'local_myplugin';
$plugin->maturity     = MATURITY_STABLE;
$plugin->release      = '1.2.0';
$plugin->dependencies = [
    'mod_forum' => 2022112800,
];
```

**BAD:**

```php
<?php
// Missing defined('MOODLE_INTERNAL') guard
$plugin->version = 20240617;      // Wrong format — missing XX suffix
// Missing $plugin->component     // Install will fail validation
$plugin->requires = '4.1';        // Wrong type — must be integer version
```

### lib.php — keep it minimal

Moodle loads **every** `lib.php` for a given plugin type on many page requests. Place only the callbacks that core explicitly requires here; all business logic belongs in autoloaded classes under `classes/`. Key callbacks for local plugins include `local_pluginname_extend_navigation()`, `local_pluginname_extend_settings_navigation()`, and `local_pluginname_extend_navigation_course()`.

**From Moodle 4.4 onward**, the new **Hooks API** (`moodledev.io/docs/apis/core/hooks`) provides PSR-14 style event dispatching as a modern replacement for many lib.php callbacks. Register hooks in `db/hooks.php`:

```php
$callbacks = [
    [
        'hook' => \core\hook\navigation\primary_extend::class,
        'callback' => [\local_myplugin\hook_callbacks::class, 'extend_primary_nav'],
        'priority' => 500,
    ],
];
```

Both legacy callbacks and hook callbacks can coexist for multi-branch compatibility. When a hook callback is present for an event that also has a legacy callback, the legacy callback is automatically skipped.

### settings.php — admin settings integration

For most plugin types, Moodle pre-creates a `$settings` object (`admin_settingpage`). For **local plugins**, `$settings` is null—you must create your own page and register it with `$ADMIN->add()`.

**GOOD — local plugin settings pattern:**

```php
<?php
defined('MOODLE_INTERNAL') || die();

if ($hassiteconfig) {
    $settings = new admin_settingpage('local_myplugin',
        new lang_string('pluginname', 'local_myplugin'));
    $ADMIN->add('localplugins', $settings);

    $settings->add(new admin_setting_configtext(
        'local_myplugin/apiendpoint',
        new lang_string('apiendpoint', 'local_myplugin'),
        new lang_string('apiendpoint_desc', 'local_myplugin'),
        'https://api.example.com',
        PARAM_URL
    ));
}
```

**BAD:**

```php
<?php
// Missing $hassiteconfig check — security hole allowing non-admins to trigger
// Missing defined('MOODLE_INTERNAL') guard
// Using get_string() instead of new lang_string() — forces string loading on every page
$settings->add(new admin_setting_configtext(
    'apikey',                           // Missing component prefix — stored in wrong config table
    get_string('apikey', 'local_myplugin'),
    '', '', PARAM_RAW                   // PARAM_RAW when PARAM_TEXT would suffice
));
```

Use `new lang_string()` (a lazy-loading proxy) instead of `get_string()` in settings.php for performance, since the admin tree is constructed on every admin page load.

---

## 3. Mustache templates and the Moodle 4.x rendering pipeline

Moodle uses the Mustache template engine (`moodledev.io/docs/guides/templates`) for all HTML output. Templates live in `templates/`, are identified by Frankenstyle (`local_myplugin/items_page`), and can be rendered both server-side (PHP) and client-side (JavaScript). Themes can override any template by placing a copy at `theme/mytheme/templates/local_myplugin/items_page.mustache`.

### The three-layer rendering architecture

**Layer 1 — Renderable class** (implements `renderable` + `templatable`):

```php
namespace local_myplugin\output;

class items_page implements \renderable, \templatable {
    private array $items;

    public function __construct(array $items) {
        $this->items = $items;
    }

    public function export_for_template(\renderer_base $output): \stdClass {
        $data = new \stdClass();
        $data->hasitems = !empty($this->items);
        $data->items = array_values($this->items); // Re-index for Mustache
        return $data;
    }
}
```

**Layer 2 — Template file** (`templates/items_page.mustache`):

```mustache
{{!
    @template local_myplugin/items_page

    Renders the items listing page.

    Context variables required for this template:
    * hasitems bool - Whether items exist
    * items array - List of item objects with name and id

    Example context (json):
    { "hasitems": true, "items": [{"id": 1, "name": "Item One"}] }
}}
<div class="local_myplugin_items_page">
    {{#hasitems}}
    <ul>
        {{#items}}
        <li data-itemid="{{id}}">{{name}}</li>
        {{/items}}
    </ul>
    {{/hasitems}}
    {{^hasitems}}
    <p>{{#str}} noitems, local_myplugin {{/str}}</p>
    {{/hasitems}}
</div>
```

**Layer 3 — Page controller:**

```php
$output = $PAGE->get_renderer('local_myplugin');
echo $output->header();
$renderable = new \local_myplugin\output\items_page($items);
echo $output->render($renderable);
echo $output->footer();
```

### Moodle 4.x navigation and UI changes

Moodle 4.0 replaced the legacy navigation drawer with a **three-tier navigation** system. **Primary navigation** is a horizontal top bar (Dashboard, My Courses, Site Admin). **Secondary navigation** renders as context-sensitive tabs pulled automatically from existing `settings_navigation` and `navigation` nodes—plugins using standard navigation hooks get secondary nav items for free. **Tertiary navigation** provides back-button patterns where breadcrumbs are insufficient. The course page gained a **collapsible course index** in a left drawer and a **blocks drawer** on the right.

**BAD template practices to avoid:**

```mustache
{{! BAD: Testing array emptiness with index syntax — breaks in JS rendering }}
{{#items.0}}Has items{{/items.0}}

{{! GOOD: Use a boolean flag }}
{{#hasitems}}Has items{{/hasitems}}

{{! BAD: Raw HTML without format_text() processing }}
{{{usersubmittedhtml}}}

{{! GOOD: Process in PHP export_for_template, then output safely }}
{{#description}}{{{description}}}{{/description}}
```

---

## 4. Database operations with the global $DB object

The Data Manipulation Layer (DML) at `moodledev.io/docs/apis/core/dml` provides a database-agnostic CRUD interface through the global `$DB` object. Pass table names **without the prefix** to method calls; in raw SQL, wrap names in curly braces (`{user}`).

### Reading records

```php
// Single record with MUST_EXIST — throws dml_missing_record_exception if not found.
$user = $DB->get_record('user', ['id' => $userid], '*', MUST_EXIST);

// Multiple records with conditions, sorting, and pagination.
$users = $DB->get_records('user', ['deleted' => 0], 'lastname ASC', '*', 0, 100);

// Complex SQL with named placeholders.
$sql = "SELECT c.id, c.fullname, COUNT(ue.id) AS enrolcount
          FROM {course} c
          JOIN {enrol} e ON e.courseid = c.id
          JOIN {user_enrolments} ue ON ue.enrolid = e.id
         WHERE c.visible = :visible
      GROUP BY c.id, c.fullname
      ORDER BY enrolcount DESC";
$courses = $DB->get_records_sql($sql, ['visible' => 1], 0, 20);
```

**Strictness constants** control missing-record behavior: `MUST_EXIST` (throws exception), `IGNORE_MISSING` (returns `false`, default), and `IGNORE_MULTIPLE` (silently returns first—avoid).

For **large datasets**, use recordsets to avoid loading everything into memory:

```php
$rs = $DB->get_recordset('user', ['deleted' => 0]);
foreach ($rs as $user) {
    // Process one row at a time.
}
$rs->close(); // CRITICAL — failing to close leaks database resources.
```

**BAD — recordset mistakes:**

```php
$rs = $DB->get_recordset('user');
if (!empty($rs)) { }    // WRONG — recordset object is always truthy
if ($rs == true) { }     // WRONG
// Forgetting $rs->close() after the loop
```

### Writing records

```php
// Insert — returns new ID.
$record = new \stdClass();
$record->course = $courseid;
$record->name = 'New assignment';
$record->timemodified = time();
$newid = $DB->insert_record('assign', $record);

// Update — object MUST have an 'id' property.
$update = new \stdClass();
$update->id = $existingid;
$update->visible = 0;
$DB->update_record('course', $update);

// Quick single-field update.
$DB->set_field('user', 'confirmed', 1, ['id' => $userid]);

// Delete.
$DB->delete_records('user_preferences', ['userid' => $userid]);
$DB->delete_records_select('sessions', "timemodified < :cutoff", ['cutoff' => time() - 7200]);
```

### Transactions for data consistency

```php
$transaction = $DB->start_delegated_transaction();
try {
    $DB->insert_record('local_myplugin_items', $item);
    $DB->insert_record('local_myplugin_log', $logentry);
    $transaction->allow_commit();
} catch (\Exception $e) {
    $transaction->rollback($e);
}
```

---

## 5. SQL injection prevention with concrete examples

Moodle supports two placeholder styles: **positional** (`?`) and **named** (`:paramname`). The official security policy at `moodledev.io/general/development/policies/security/sql-injection` mandates placeholders for all user-influenced values.

**SAFE — parameterized queries:**

```php
$name = required_param('name', PARAM_TEXT);

// Positional placeholders.
$users = $DB->get_records_sql(
    "SELECT * FROM {user} WHERE firstname = ? AND deleted = ?",
    [$name, 0]
);

// Named placeholders (required when query has >1 parameter per style guide).
$users = $DB->get_records_sql(
    "SELECT * FROM {user} WHERE firstname = :fname AND deleted = :del",
    ['fname' => $name, 'del' => 0]
);
```

**UNSAFE — injection vulnerabilities:**

```php
// BAD: String concatenation — classic SQL injection.
$id = $_GET['id'];
$DB->get_record_sql("SELECT * FROM {user} WHERE id = $id");

// BAD: Quoting does not help.
$name = $_POST['name'];
$DB->execute("UPDATE {user} SET firstname = '$name' WHERE id = $id");

// BAD: Reusing named parameter names — Moodle throws an error.
$sql = "WHERE firstname = :name OR lastname = :name"; // Duplicate :name!
```

### Safe IN clauses with get_in_or_equal()

Never build `IN (...)` clauses by imploding user IDs into a string. Use `$DB->get_in_or_equal()`:

```php
$courseids = [1, 2, 3, 4, 5];
[$insql, $inparams] = $DB->get_in_or_equal($courseids, SQL_PARAMS_NAMED, 'cid');
$params = array_merge($inparams, ['vis' => 1]);
$sql = "SELECT * FROM {course} WHERE id {$insql} AND visible = :vis";
$courses = $DB->get_records_sql($sql, $params);
```

**BAD:**

```php
$ids = implode(',', $userids);
$sql = "SELECT * FROM {user} WHERE id IN ($ids)"; // Injection if $userids is tainted!
```

### Safe LIKE queries with sql_like()

```php
$search = required_param('q', PARAM_TEXT);
$likesql = $DB->sql_like('fullname', ':search', false); // Case-insensitive
$params = ['search' => '%' . $DB->sql_like_escape($search) . '%'];
$courses = $DB->get_records_sql("SELECT * FROM {course} WHERE {$likesql}", $params);
```

Without `sql_like_escape()`, a user could inject `%` or `_` wildcards to manipulate query results.

---

## 6. Access API: capabilities, contexts, and authentication

The Access API (`moodledev.io/docs/apis/subsystems/access`) governs all authorization in Moodle through a hierarchy of **contexts** and **capabilities**.

### Defining capabilities in db/access.php

```php
$capabilities = [
    'local/myplugin:manage' => [
        'riskbitmask'  => RISK_SPAM | RISK_XSS,
        'captype'      => 'write',
        'contextlevel' => CONTEXT_COURSE,
        'archetypes'   => [
            'editingteacher' => CAP_ALLOW,
            'manager'        => CAP_ALLOW,
        ],
    ],
    'local/myplugin:view' => [
        'captype'      => 'read',
        'contextlevel' => CONTEXT_COURSE,
        'archetypes'   => [
            'student'        => CAP_ALLOW,
            'teacher'        => CAP_ALLOW,
            'editingteacher' => CAP_ALLOW,
            'manager'        => CAP_ALLOW,
        ],
    ],
];
```

Every capability name requires a matching language string (`$string['myplugin:manage'] = 'Manage plugin content';`), and **any change to `db/access.php` requires a version bump** in `version.php`.

Risk bitmask constants signal what damage a capability enables: **RISK_SPAM** (user-visible content), **RISK_PERSONAL** (access to others' PII), **RISK_XSS** (unfiltered HTML input), **RISK_CONFIG** (site configuration changes), and **RISK_DATALOSS** (irreversible data destruction).

### Context hierarchy and instantiation

Contexts follow a strict parent-child tree: `CONTEXT_SYSTEM (10)` → `CONTEXT_COURSECAT (40)` → `CONTEXT_COURSE (50)` → `CONTEXT_MODULE (70)` → `CONTEXT_BLOCK (80)`, with `CONTEXT_USER (30)` branching from system. Capabilities propagate downward—a permission granted at course level applies to all modules within that course.

```php
$systemctx = \context_system::instance();
$coursectx = \context_course::instance($course->id);
$modulectx = \context_module::instance($cm->id);
```

**BAD:**

```php
// Passing a course ID to context_module — needs $cm->id, not $course->id.
$ctx = \context_module::instance($course->id); // WRONG

// Checking a module-level capability against system context.
require_capability('mod/myplugin:submit', \context_system::instance()); // Wrong context
```

### The require_login / require_capability pattern

Every Moodle page script must call `require_login()` early, passing the course and course module when applicable. This verifies authentication, enrollment, module visibility, and availability restrictions. Follow it with `require_capability()` for the specific action.

**GOOD — complete module page setup:**

```php
require_once(__DIR__ . '/../../config.php');

$id = required_param('id', PARAM_INT);
[$course, $cm] = get_course_and_cm_from_cmid($id, 'myplugin');

$PAGE->set_url(new \moodle_url('/mod/myplugin/view.php', ['id' => $id]));
require_login($course, true, $cm);

$context = \context_module::instance($cm->id);
require_capability('mod/myplugin:view', $context);
```

**BAD:**

```php
// Missing require_login entirely — unauthenticated access.
$context = \context_module::instance($cm->id);
require_capability('mod/myplugin:view', $context);

// require_login() without course — does NOT verify enrollment.
require_login();

// Checking role IDs instead of capabilities — role IDs differ per installation.
if (user_has_role_assignment($USER->id, 3)) { /* fragile! */ }
```

Use `has_capability()` for conditional UI (showing/hiding buttons), and `require_capability()` as a hard gate before performing actions. `has_any_capability()` and `has_all_capabilities()` handle multi-capability checks.

---

## 7. Input validation and output escaping

### Input: never touch superglobals directly

All user input must pass through `required_param()`, `optional_param()`, or `clean_param()` with the most specific `PARAM_*` constant available. Group these calls at the top of every script for auditability.

|Constant|Use case|Example|
|---|---|---|
|`PARAM_INT`|Database IDs, pagination|`required_param('id', PARAM_INT)`|
|`PARAM_ALPHA`|Action strings|`optional_param('action', '', PARAM_ALPHA)`|
|`PARAM_TEXT`|Plain-text names (strips tags, keeps multilang)|`optional_param('name', '', PARAM_TEXT)`|
|`PARAM_RAW`|Rich HTML content (clean on **output**)|`optional_param('description', '', PARAM_RAW)`|
|`PARAM_URL`|External URLs|`optional_param('link', '', PARAM_URL)`|
|`PARAM_BOOL`|Toggles (normalizes to 0 or 1)|`optional_param('confirm', 0, PARAM_BOOL)`|
|`PARAM_LOCALURL`|Internal redirect targets|`optional_param('returnurl', '', PARAM_LOCALURL)`|

**BAD:**

```php
$id = $_GET['id'];                        // Direct superglobal access — NO validation
$name = $_POST['name'];                   // Unfiltered
$id = required_param('id', PARAM_RAW);    // Overly permissive — should be PARAM_INT
```

### Output: three functions for three contexts

- **`s($text)`** — HTML-entity escapes for attribute values and plain-text display.
- **`format_string($text, $striplinks, $options)`** — For short, single-line strings (activity names, headings). Applies multilang filter, strips HTML.
- **`format_text($text, $format, $options)`** — For rich content (forum posts, descriptions). Applies HTML cleaning, content filters, and format conversion. **Never set `noclean => true`** for user-submitted content.

**GOOD:**

```php
// Activity heading — short, filtered.
echo \html_writer::tag('h2', format_string($activity->name, true,
    ['context' => $modcontext]));

// Rich description — cleaned HTML.
echo format_text($activity->intro, $activity->introformat, [
    'noclean' => false,
    'context' => $modcontext,
]);

// Form field value — entity-escaped.
echo '<input type="text" name="title" value="' . s($title) . '" />';
```

**BAD:**

```php
echo $user->description;                    // XSS — raw user content
echo "<h1>$course->fullname</h1>";          // XSS — unescaped interpolation
echo format_text($post->message, FORMAT_HTML, ['noclean' => true]); // Disables cleaning!
```

### CSRF protection with sesskey

All state-changing operations require sesskey verification. The Moodle Forms API handles this automatically. For manual action links, include `sesskey()` in the URL and call `require_sesskey()` before processing:

```php
// Building the action URL.
$deleteurl = new \moodle_url('/local/myplugin/action.php', [
    'action'  => 'delete',
    'id'      => $item->id,
    'sesskey' => sesskey(),
]);

// Processing the action.
if ($action === 'delete') {
    require_sesskey();
    require_capability('local/myplugin:manage', $context);
    $DB->delete_records('local_myplugin_items', ['id' => $id]);
    redirect($returnurl);
}
```

**BAD:**

```php
// Destructive action without sesskey check.
$DB->delete_records('local_myplugin_items', ['id' => optional_param('delete', 0, PARAM_INT)]);
```

---

## 8. Frankenstyle naming and autoloading conventions

Frankenstyle (`moodledev.io/general/development/policies/codingstyle/frankenstyle`) is the universal naming scheme: **`{plugintype}_{pluginname}`**, always lowercase. It governs every identifier in the Moodle ecosystem.

|Entity|Pattern|Example|
|---|---|---|
|Component|`type_name`|`local_myplugin`|
|Namespaced class|`\type_name\subns\class`|`\local_myplugin\task\sync_data`|
|Legacy function|`type_name_verb_noun()`|`local_myplugin_get_items()`|
|DB table|`{type_name_table}`|`{local_myplugin_items}`|
|DB table (activity)|`{name_table}` (no `mod_`)|`{forum_posts}`|
|Capability|`type/name:cap`|`local/myplugin:manage`|
|Language file|`lang/en/type_name.php`|`lang/en/local_myplugin.php`|
|Language file (activity)|`lang/en/name.php`|`lang/en/forum.php`|
|Template|`type_name/template`|`local_myplugin/items_page`|
|JS module|`type_name/module`|`local_myplugin/manager`|
|Setting config key|`type_name` (plugin column)|`set_config('key', 'val', 'local_myplugin')`|

### Autoloading: classes/ directory to namespace mapping

Moodle's autoloader maps `\{component}\{path}\{classname}` to `{component_dir}/classes/{path}/{classname}.php`. One class per file. File name equals class name.

```
\local_myplugin\helper           → local/myplugin/classes/helper.php
\local_myplugin\event\item_created → local/myplugin/classes/event/item_created.php
\local_myplugin\task\sync_data    → local/myplugin/classes/task/sync_data.php
\local_myplugin\external\get_items → local/myplugin/classes/external/get_items.php
```

Standard subdirectories carry semantic meaning: `event/` for events, `task/` for scheduled and adhoc tasks, `external/` for web services, `form/` for form definitions, `output/` for renderables, `privacy/` for GDPR providers, and `local/` for plugin-internal utilities with no API contract.

**GOOD — proper namespace and class structure:**

```php
// File: local/myplugin/classes/task/sync_data.php
namespace local_myplugin\task;

class sync_data extends \core\task\scheduled_task {
    public function get_name(): string {
        return get_string('synctask', 'local_myplugin');
    }
    public function execute(): void {
        // Task logic.
    }
}
```

**BAD — deprecated non-namespaced style:**

```php
// DO NOT write new code like this.
class local_myplugin_task_sync_data extends \core\task\scheduled_task { }
```

---

## 9. Database schema management with XMLDB

Database tables are defined in `db/install.xml` (created via the XMLDB editor at Site Admin → Development → XMLDB editor) and modified through `db/upgrade.php`. Since **Moodle 4.3**, table names can be up to **53 characters** and column names up to **63 characters** (previously 28 and 30).

**GOOD — idempotent upgrade step:**

```php
function xmldb_local_myplugin_upgrade($oldversion): bool {
    global $DB;
    $dbman = $DB->get_manager();

    if ($oldversion < 2024060100) {
        $table = new \xmldb_table('local_myplugin_items');
        $field = new \xmldb_field('status', XMLDB_TYPE_CHAR, '20',
            null, XMLDB_NOTNULL, null, 'draft', 'timemodified');

        if (!$dbman->field_exists($table, $field)) {
            $dbman->add_field($table, $field);
        }

        upgrade_plugin_savepoint(true, 2024060100, 'local', 'myplugin');
    }

    return true;
}
```

**BAD:**

```php
// Missing existence check — crashes on re-run.
$dbman->add_field($table, $field);

// Using DDL outside of upgrade.php.
$DB->get_manager()->add_field($table, $field); // Never in normal page code!
```

---

## 10. PHP coding style essentials

Moodle follows **PSR-12** with Moodle-specific additions (documented at `moodledev.io/general/development/policies/codingstyle`). Enforce with the `local_codechecker` plugin.

- **Indentation**: 4 spaces, never tabs.
- **Braces**: Opening brace on the **same line** as the declaration.
- **Variables**: All lowercase, no underscores between words (`$courseid`, not `$course_id` or `$courseId`).
- **Functions**: Lowercase with underscores (`get_items()`, not `getItems()`).
- **Type hints and return types**: Required for all new code.
- **No closing `?>` tag**.
- **SQL in strings**: All keywords UPPERCASE, use double quotes for the SQL string, named params for queries with more than one parameter, `JOIN` not `INNER JOIN`, `<>` not `!=`, `AS` for column aliases only (never for table aliases).

**GOOD:**

```php
/**
 * Get active items for a course.
 *
 * @param int $courseid The course ID.
 * @param string|null $filter Optional status filter.
 * @return \stdClass[] Array of item records.
 */
public function get_items(int $courseid, ?string $filter = null): array {
    global $DB;
    $params = ['courseid' => $courseid, 'active' => 1];
    return $DB->get_records('local_myplugin_items', $params, 'timecreated DESC');
}
```

**BAD:**

```php
public function getItems($courseId) {           // camelCase, no type hints
    global $DB;
    return($DB->get_records('local_myplugin_items',  // Parenthesized return
        array('courseid' => $courseId)));              // array() instead of []
}
```

Every PHP file requires the GPL header, a `@package` tag with the Frankenstyle component name, `@copyright`, and `@license`. Non-entry-point files must include `defined('MOODLE_INTERNAL') || die();`.

---

## Conclusion

Building enterprise-grade Moodle 4.x plugins requires disciplined adherence to a well-defined architecture. **Choose plugin types based on their intended surface area**: local plugins for headless system extensions, block plugins for user-facing widgets. **Never concatenate user input into SQL**—use `$DB` method parameters and `get_in_or_equal()` exclusively. The **require_login → require_capability** two-step is non-negotiable on every page script, with `require_sesskey()` guarding every write operation.

The shift toward namespaced classes in `classes/`, the PSR-14 Hooks API in Moodle 4.4+, and mandatory type hints signals Moodle's convergence with modern PHP practices. For developers maintaining plugins across multiple Moodle branches, the dual-registration pattern (legacy callbacks alongside hook callbacks) provides a clean migration path. The expanded XMLDB limits in 4.3+ remove a longstanding constraint on table naming, but the Frankenstyle convention remains the organizing principle for every identifier in the system—from database columns to JavaScript module paths.

All documentation referenced in this guide is maintained at **moodledev.io** (primary developer docs), **docs.moodle.org/dev** (community wiki), and the **moodle/moodle** GitHub repository.