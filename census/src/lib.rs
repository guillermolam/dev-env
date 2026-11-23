#![deny(unsafe_code)]

use std::collections::HashSet;
use std::ffi::OsStr;
use std::path::{Path, PathBuf};

const WORKLOAD_CURRENT: u64 = 14;
const FILE_MAX_DEPTH: u32 = 8;
const REPO_MAX_DEPTH: u32 = 6;
const SKIP: &[&str] = &[
    ".git",
    "node_modules",
    ".cache",
    "Library",
    "target",
    "dist",
    "build",
    "venv",
    ".Trash",
    "OrbStack",
    ".ssh",
    ".gnupg",
    "Keychains",
];
const MEDIA_EXT: &[&str] = &[
    "aac", "aiff", "avi", "flac", "gif", "heic", "jpeg", "jpg", "m4a", "m4v", "mkv", "mov", "mp3",
    "mp4", "png", "tif", "tiff", "wav", "webp",
];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Row {
    pub name: &'static str,
    pub current: u64,
    pub operational: u64,
    pub left: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Board {
    pub rows: Vec<Row>,
    pub open_steps: Vec<&'static str>,
    pub files_capped: bool,
}

pub struct Input {
    pub home: PathBuf,
    pub repo: PathBuf,
    pub path_env: String,
    pub nix_prefix: PathBuf,
    pub service_dirs: Vec<PathBuf>,
    pub app_dirs: Vec<PathBuf>,
    pub file_dirs: Vec<PathBuf>,
    pub repo_scan_dirs: Vec<PathBuf>,
    pub config_dir: PathBuf,
    pub system_version: PathBuf,
    pub system_profile: PathBuf,
    pub crontab_text: String,
    pub launchd_list: String,
    pub restic_repository: String,
    pub restic_password_file: PathBuf,
    pub walk_cap: u64,
}

pub fn row(name: &'static str, current: u64, operational: u64) -> Row {
    let operational = operational.min(current);
    Row {
        name,
        current,
        operational,
        left: current - operational,
    }
}

pub fn render(board: &Board) -> String {
    let mut out = String::from("census\n");
    for row in &board.rows {
        out.push_str(&format!(
            "{} current={} operational={} left={}\n",
            row.name, row.current, row.operational, row.left
        ));
    }
    out.push_str("workload_a_open=");
    if board.open_steps.is_empty() {
        out.push_str("none");
    } else {
        out.push_str(&board.open_steps.join(","));
    }
    out.push('\n');
    out.push_str("files_capped=");
    out.push(if board.files_capped { '1' } else { '0' });
    out.push('\n');
    out
}

pub fn census(input: &Input) -> Board {
    let nix = std::fs::canonicalize(&input.nix_prefix).ok();
    let nix = nix.as_deref();
    let (passed, open_steps) = workload(input);
    let (tools_current, tools_operational) = count_tools(&input.path_env, nix);
    let (services_current, services_operational) =
        count_services(&input.launchd_list, &input.service_dirs, nix);
    let (apps_current, apps_operational) = count_level(&input.app_dirs, nix, Level::App);
    let (files_current, media_current, files_capped) =
        count_files(&input.file_dirs, input.walk_cap);
    let (repos_current, repos_operational) = count_repos(input);
    let (config_current, config_operational) =
        count_level(std::slice::from_ref(&input.config_dir), nix, Level::Any);
    Board {
        rows: vec![
            row("workload_a", WORKLOAD_CURRENT, passed),
            row("tools", tools_current, tools_operational),
            row("services", services_current, services_operational),
            row("jobs", count_jobs(&input.crontab_text), 0),
            row("applications", apps_current, apps_operational),
            row("files", files_current, 0),
            row("media", media_current, 0),
            row("repositories", repos_current, repos_operational),
            row("configuration", config_current, config_operational),
        ],
        open_steps,
        files_capped,
    }
}

fn workload(input: &Input) -> (u64, Vec<&'static str>) {
    let checks: [(&str, bool); 14] = [
        ("A1", input.system_version.is_file()),
        ("A2", input.home.is_dir()),
        ("A3", step_a3(input)),
        ("A4", step_a4(input)),
        ("A4b", step_a4b(input)),
        ("A5", marker_file(&input.repo, "a5-ok")),
        ("A6", input.system_profile.exists()),
        ("A7", step_a7(input)),
        ("A8", step_a8(input)),
        ("A9", marker_exists(&input.repo, "a9-ok")),
        ("A10", marker_exists(&input.repo, "a10-ok")),
        ("A11", marker_exists(&input.repo, "a11-ok")),
        ("A12", marker_exists(&input.repo, "a12-ok")),
        ("A13", marker_exists(&input.repo, "a13-ok")),
    ];
    let mut open = Vec::new();
    let mut passed = 0u64;
    for (id, ok) in checks {
        if ok {
            passed += 1;
        } else {
            open.push(id);
        }
    }
    (passed, open)
}

fn step_a3(input: &Input) -> bool {
    input.nix_prefix.is_dir() || path_has_tool(&input.path_env, "nix")
}

fn step_a4(input: &Input) -> bool {
    input.repo.join("flake.nix").is_file() && input.repo.join(".git").exists()
}

fn step_a4b(input: &Input) -> bool {
    let Ok(entries) = std::fs::read_dir(input.repo.join("receipts")) else {
        return false;
    };
    for entry in entries.flatten() {
        let name = entry.file_name();
        let Some(name) = name.to_str() else {
            continue;
        };
        if name.starts_with("a4b-ok") && entry.path().is_file() {
            return true;
        }
    }
    false
}

fn step_a7(input: &Input) -> bool {
    input
        .repo
        .join("operations")
        .join(".cache")
        .join("opa")
        .is_file()
        || path_has_tool(&input.path_env, "opa")
}

fn step_a8(input: &Input) -> bool {
    let repository = input.restic_repository.as_str();
    !repository.is_empty()
        && !repository.contains("local-restic")
        && input.restic_password_file.is_file()
}

fn marker_file(repo: &Path, name: &str) -> bool {
    repo.join("receipts").join(name).is_file()
}

fn marker_exists(repo: &Path, name: &str) -> bool {
    repo.join("receipts").join(name).exists()
}

fn count_jobs(text: &str) -> u64 {
    text.lines()
        .filter(|line| {
            let trimmed = line.trim();
            !trimmed.is_empty() && !trimmed.starts_with('#')
        })
        .count() as u64
}

fn path_dirs(path_env: &str) -> impl Iterator<Item = &Path> {
    path_env
        .split(':')
        .filter(|part| !part.is_empty())
        .map(Path::new)
}

fn path_has_tool(path_env: &str, name: &str) -> bool {
    path_dirs(path_env).any(|dir| {
        std::fs::symlink_metadata(dir.join(name))
            .map(|meta| is_tool(&meta))
            .unwrap_or(false)
    })
}

fn count_tools(path_env: &str, nix: Option<&Path>) -> (u64, u64) {
    let mut seen = HashSet::<PathBuf>::new();
    let mut current = 0u64;
    let mut operational = 0u64;
    for dir in path_dirs(path_env) {
        let Ok(entries) = std::fs::read_dir(dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            let Ok(meta) = std::fs::symlink_metadata(&path) else {
                continue;
            };
            if !is_tool(&meta) {
                continue;
            }
            let key = std::fs::canonicalize(&path).unwrap_or(path);
            if !seen.insert(key.clone()) {
                continue;
            }
            current += 1;
            if nix.is_some_and(|root| key.starts_with(root)) {
                operational += 1;
            }
        }
    }
    (current, operational)
}

fn count_services(list: &str, dirs: &[PathBuf], nix: Option<&Path>) -> (u64, u64) {
    let labels = launchd_labels(list);
    let operational = nix_loaded_services(dirs, nix, &labels);
    (labels.len() as u64, operational)
}

fn launchd_labels(text: &str) -> HashSet<String> {
    let mut labels = HashSet::new();
    for line in text.lines() {
        let mut fields = line.split_whitespace();
        if fields.next().is_none() || fields.next().is_none() {
            continue;
        }
        let Some(label) = fields.next() else {
            continue;
        };
        if fields.next().is_some() || label == "Label" {
            continue;
        }
        labels.insert(label.to_string());
    }
    labels
}

fn nix_loaded_services(dirs: &[PathBuf], nix: Option<&Path>, labels: &HashSet<String>) -> u64 {
    let mut seen = HashSet::<String>::new();
    let mut operational = 0u64;
    for dir in dirs {
        let Ok(entries) = std::fs::read_dir(dir) else {
            continue;
        };
        for entry in entries.flatten() {
            if !level_match(Level::Plist, &entry) {
                continue;
            }
            let Some(stem) = plist_stem(&entry.file_name()) else {
                continue;
            };
            if !labels.contains(&stem) || !in_nix(&entry.path(), nix) {
                continue;
            }
            if seen.insert(stem) {
                operational += 1;
            }
        }
    }
    operational
}

fn plist_stem(name: &OsStr) -> Option<String> {
    let text = name.to_str()?;
    let stem = text.strip_suffix(".plist")?;
    if stem.is_empty() {
        None
    } else {
        Some(stem.to_string())
    }
}

fn is_tool(meta: &std::fs::Metadata) -> bool {
    let kind = meta.file_type();
    if kind.is_symlink() {
        return true;
    }
    kind.is_file() && exec_bit(meta)
}

#[cfg(unix)]
fn exec_bit(meta: &std::fs::Metadata) -> bool {
    use std::os::unix::fs::PermissionsExt;
    meta.permissions().mode() & 0o111 != 0
}

#[cfg(not(unix))]
fn exec_bit(_meta: &std::fs::Metadata) -> bool {
    false
}

#[derive(Clone, Copy)]
enum Level {
    Any,
    App,
    Plist,
}

fn count_level(dirs: &[PathBuf], nix: Option<&Path>, kind: Level) -> (u64, u64) {
    let mut current = 0u64;
    let mut operational = 0u64;
    for dir in dirs {
        let Ok(entries) = std::fs::read_dir(dir) else {
            continue;
        };
        for entry in entries.flatten() {
            if !level_match(kind, &entry) {
                continue;
            }
            current += 1;
            if in_nix(&entry.path(), nix) {
                operational += 1;
            }
        }
    }
    (current, operational)
}

fn level_match(kind: Level, entry: &std::fs::DirEntry) -> bool {
    match kind {
        Level::Any => true,
        Level::App => name_ends(&entry.file_name(), ".app"),
        Level::Plist => name_ends(&entry.file_name(), ".plist") && is_file_or_link(&entry.path()),
    }
}

fn is_file_or_link(path: &Path) -> bool {
    match std::fs::symlink_metadata(path) {
        Ok(meta) => {
            let kind = meta.file_type();
            kind.is_file() || kind.is_symlink()
        }
        Err(_) => false,
    }
}

fn name_ends(name: &OsStr, suffix: &str) -> bool {
    name.to_str()
        .map(|text| text.ends_with(suffix))
        .unwrap_or(false)
}

fn in_nix(path: &Path, nix: Option<&Path>) -> bool {
    let Some(root) = nix else {
        return false;
    };
    std::fs::canonicalize(path)
        .map(|canon| canon.starts_with(root))
        .unwrap_or(false)
}

struct FileWalk {
    files: u64,
    media: u64,
    capped: bool,
}

fn count_files(dirs: &[PathBuf], cap: u64) -> (u64, u64, bool) {
    let mut state = FileWalk {
        files: 0,
        media: 0,
        capped: false,
    };
    for dir in dirs {
        if state.capped {
            break;
        }
        walk_files(dir, 0, cap, &mut state);
    }
    (state.files, state.media, state.capped)
}

fn walk_files(dir: &Path, dir_depth: u32, cap: u64, state: &mut FileWalk) {
    if state.capped || dir_depth >= FILE_MAX_DEPTH {
        return;
    }
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries {
        if state.capped {
            return;
        }
        let Ok(entry) = entry else {
            continue;
        };
        let path = entry.path();
        let Ok(meta) = std::fs::symlink_metadata(&path) else {
            continue;
        };
        let kind = meta.file_type();
        if kind.is_symlink() {
            continue;
        }
        if kind.is_dir() {
            if !skipped(&entry.file_name()) && dir_depth + 1 < FILE_MAX_DEPTH {
                walk_files(&path, dir_depth + 1, cap, state);
            }
            continue;
        }
        if kind.is_file() && !record_file(state, &path, cap) {
            return;
        }
    }
}

fn record_file(state: &mut FileWalk, path: &Path, cap: u64) -> bool {
    if state.files >= cap {
        state.capped = true;
        return false;
    }
    state.files += 1;
    if is_media(path) {
        state.media += 1;
    }
    if state.files >= cap {
        state.capped = true;
        return false;
    }
    true
}

fn is_media(path: &Path) -> bool {
    let Some(ext) = path.extension().and_then(|ext| ext.to_str()) else {
        return false;
    };
    let lower = ext.to_ascii_lowercase();
    MEDIA_EXT.iter().any(|item| *item == lower)
}

fn count_repos(input: &Input) -> (u64, u64) {
    let mut found = HashSet::<PathBuf>::new();
    for dir in &input.repo_scan_dirs {
        collect_repos(dir, 0, &mut found);
    }
    let current = found.len() as u64;
    let counted = found.contains(&canonical_key(&input.repo));
    let operational = u64::from(counted && has_git_child(&input.repo));
    (current, operational)
}

fn collect_repos(dir: &Path, depth: u32, found: &mut HashSet<PathBuf>) {
    if !dir.is_dir() {
        return;
    }
    if has_git_child(dir) {
        found.insert(canonical_key(dir));
        return;
    }
    if depth >= REPO_MAX_DEPTH {
        return;
    }
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        if skipped(&entry.file_name()) {
            continue;
        }
        let path = entry.path();
        if is_real_dir(&path) {
            collect_repos(&path, depth + 1, found);
        }
    }
}

fn has_git_child(dir: &Path) -> bool {
    std::fs::symlink_metadata(dir.join(".git")).is_ok()
}

fn is_real_dir(path: &Path) -> bool {
    match std::fs::symlink_metadata(path) {
        Ok(meta) => meta.file_type().is_dir(),
        Err(_) => false,
    }
}

fn canonical_key(path: &Path) -> PathBuf {
    std::fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf())
}

fn skipped(name: &OsStr) -> bool {
    SKIP.iter().any(|skip| OsStr::new(skip) == name)
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::path::{Path, PathBuf};
    use std::sync::atomic::{AtomicU64, Ordering};

    use super::{census, render, row, Board, Input, Row};

    const ROWS: [&str; 9] = [
        "workload_a",
        "tools",
        "services",
        "jobs",
        "applications",
        "files",
        "media",
        "repositories",
        "configuration",
    ];

    #[test]
    fn empty_inputs_are_zero_and_all_steps_open() {
        let scratch = Scratch::new();
        let board = census(&base(scratch.path()));
        assert_eq!(render(&board), empty_board());
        assert!(!board.files_capped);
        assert_eq!(board.open_steps, open_all());
    }

    #[test]
    fn render_lists_every_row() {
        let board = Board {
            rows: ROWS.iter().copied().map(|name| row(name, 3, 1)).collect(),
            open_steps: Vec::new(),
            files_capped: true,
        };
        let mut expected = String::from("census\n");
        for name in ROWS {
            expected.push_str(&format!("{name} current=3 operational=1 left=2\n"));
        }
        expected.push_str("workload_a_open=none\nfiles_capped=1\n");
        let text = render(&board);
        assert_eq!(text, expected);
        assert!(text.starts_with("census\n"));
        for name in ROWS {
            assert!(text.contains(name), "{name}");
        }

        let open = Board {
            rows: ROWS.iter().copied().map(|name| row(name, 0, 0)).collect(),
            open_steps: vec!["A1", "A4b"],
            files_capped: false,
        };
        let text = render(&open);
        assert!(text.contains("workload_a_open=A1,A4b\n"));
        assert!(text.ends_with("files_capped=0\n"));
    }

    #[test]
    fn row_clamps_operational() {
        let high = row("tools", 4, 10);
        assert_eq!((high.current, high.operational, high.left), (4, 4, 0));
        let under = row("tools", 4, 1);
        assert_eq!((under.operational, under.left), (1, 3));
    }

    #[cfg(unix)]
    #[test]
    fn tools_count_executable_outside_nix() {
        let scratch = Scratch::new();
        let root = scratch.path();
        let bin = root.join("bin");
        fs::create_dir_all(&bin).unwrap();
        make_exec(&bin.join("tool"));
        fs::write(bin.join("note"), b"no").unwrap();
        let mut input = base(root);
        input.path_env = path_text(&bin);
        input.nix_prefix = root.join("nix");
        let board = census(&input);
        assert_row(&board, "tools", 1, 0);
    }

    #[cfg(unix)]
    #[test]
    fn tools_symlink_into_nix_is_operational() {
        let scratch = Scratch::new();
        let root = scratch.path();
        let nix = root.join("nix");
        let store_bin = nix.join("bin");
        fs::create_dir_all(&store_bin).unwrap();
        fs::write(store_bin.join("payload"), b"payload").unwrap();
        let link_dir = root.join("links");
        fs::create_dir_all(&link_dir).unwrap();
        std::os::unix::fs::symlink(store_bin.join("payload"), link_dir.join("tool")).unwrap();

        let mut input = base(root);
        input.nix_prefix = nix;
        input.path_env = path_text(&link_dir);
        let board = census(&input);
        assert_row(&board, "tools", 1, 1);
        assert!(!render(&board).contains("payload"));

        let first = root.join("first");
        fs::create_dir_all(&first).unwrap();
        make_exec(&first.join("tool"));
        input.path_env = format!("{}:{}", path_text(&first), path_text(&link_dir));
        let board = census(&input);
        assert_row(&board, "tools", 2, 1);
    }

    #[cfg(unix)]
    #[test]
    fn services_count_plist_files_and_nix_links() {
        let scratch = Scratch::new();
        let root = scratch.path();
        let nix = root.join("nix");
        fs::create_dir_all(&nix).unwrap();
        fs::write(nix.join("managed.plist"), b"<plist/>").unwrap();
        let svc = root.join("LaunchAgents");
        fs::create_dir_all(svc.join("nested")).unwrap();
        fs::write(svc.join("plain.plist"), b"<plist/>").unwrap();
        fs::write(svc.join("notes.txt"), b"x").unwrap();
        fs::create_dir(svc.join("dir.plist")).unwrap();
        fs::write(svc.join("nested").join("deep.plist"), b"<plist/>").unwrap();
        std::os::unix::fs::symlink(nix.join("managed.plist"), svc.join("nix.plist")).unwrap();
        let mut input = base(root);
        input.nix_prefix = nix;
        input.service_dirs = vec![svc];
        input.launchd_list = "PID\tStatus\tLabel\n-\t0\tplain\n-\t0\tnix\n-\t0\tother\n".to_string();
        let board = census(&input);
        assert_row(&board, "services", 3, 1);
        let text = render(&board);
        assert!(!text.contains("plain.plist"));
        assert!(!text.contains("managed.plist"));
    }

    #[test]
    fn jobs_count_uncommented_lines_only() {
        let scratch = Scratch::new();
        let mut input = base(scratch.path());
        input.crontab_text = "\n# c\n0 * * * * x\n".to_string();
        let board = census(&input);
        assert_row(&board, "jobs", 1, 0);
        let text = render(&board);
        assert!(!text.contains("0 * * * *"));
        assert!(!text.contains("# c"));
    }

    #[test]
    fn applications_count_app_entries() {
        let scratch = Scratch::new();
        let root = scratch.path();
        let apps = root.join("Applications");
        fs::create_dir_all(apps.join("Foo.app")).unwrap();
        fs::create_dir_all(apps.join("nested").join("Bar.app")).unwrap();
        fs::write(apps.join("readme.txt"), b"x").unwrap();
        let mut input = base(root);
        input.app_dirs = vec![apps];
        let board = census(&input);
        assert_row(&board, "applications", 1, 0);
        assert!(!render(&board).contains("Foo.app"));
    }

    #[test]
    fn files_and_media_share_one_walk() {
        let scratch = Scratch::new();
        let root = scratch.path();
        let docs = root.join("Documents");
        let hidden = docs.join("node_modules");
        fs::create_dir_all(&hidden).unwrap();
        fs::write(docs.join("pic.png"), b"png").unwrap();
        fs::write(docs.join("note.txt"), b"txt").unwrap();
        fs::write(hidden.join("hidden.png"), b"no").unwrap();
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(docs.join("pic.png"), docs.join("skip.png")).unwrap();
            let outside = root.join("outside");
            fs::create_dir_all(&outside).unwrap();
            fs::write(outside.join("movie.mp4"), b"m").unwrap();
            std::os::unix::fs::symlink(&outside, docs.join("linked")).unwrap();
        }
        let mut input = base(root);
        input.file_dirs = vec![docs];
        let board = census(&input);
        assert_row(&board, "files", 2, 0);
        assert_row(&board, "media", 1, 0);
        assert!(!board.files_capped);
    }

    #[test]
    fn files_skip_named_directories() {
        let scratch = Scratch::new();
        let root = scratch.path();
        let docs = root.join("Documents");
        fs::create_dir_all(&docs).unwrap();
        for name in [
            ".git",
            "node_modules",
            ".cache",
            "Library",
            "target",
            "dist",
            "build",
            "venv",
            ".Trash",
            "OrbStack",
            ".ssh",
            ".gnupg",
            "Keychains",
        ] {
            let dir = docs.join(name);
            fs::create_dir_all(&dir).unwrap();
            fs::write(dir.join("hidden.txt"), b"x").unwrap();
        }
        fs::write(docs.join("keep.txt"), b"k").unwrap();
        let mut input = base(root);
        input.file_dirs = vec![docs];
        let board = census(&input);
        assert_row(&board, "files", 1, 0);
        assert_row(&board, "media", 0, 0);
    }

    #[test]
    fn files_stop_at_depth_eight() {
        let scratch = Scratch::new();
        let root = scratch.path();
        let docs = root.join("Documents");
        fs::create_dir_all(&docs).unwrap();
        fs::write(docs.join("top.txt"), b"t").unwrap();
        let at_eight = nest(&docs, &["l1", "l2", "l3", "l4", "l5", "l6", "l7"]);
        fs::write(at_eight.join("yes.txt"), b"y").unwrap();
        let at_nine = nest(&docs, &["l1", "l2", "l3", "l4", "l5", "l6", "l7", "l8"]);
        fs::write(at_nine.join("no.txt"), b"n").unwrap();
        let mut input = base(root);
        input.file_dirs = vec![docs];
        let board = census(&input);
        assert_row(&board, "files", 2, 0);
        assert!(!board.files_capped);
    }

    #[test]
    fn walk_cap_sets_files_capped() {
        let scratch = Scratch::new();
        let root = scratch.path();
        let first = root.join("Desktop");
        let second = root.join("Documents");
        fs::create_dir_all(&first).unwrap();
        fs::create_dir_all(&second).unwrap();
        fs::write(first.join("a.txt"), b"a").unwrap();
        fs::write(first.join("b.txt"), b"b").unwrap();
        fs::write(second.join("c.txt"), b"c").unwrap();
        let mut input = base(root);
        input.file_dirs = vec![first, second];
        input.walk_cap = 1;
        let board = census(&input);
        assert!(board.files_capped);
        assert_row(&board, "files", 1, 0);

        let one = root.join("Music");
        fs::create_dir_all(&one).unwrap();
        fs::write(one.join("only.txt"), b"o").unwrap();
        input.file_dirs = vec![one];
        input.walk_cap = 1;
        let board = census(&input);
        assert!(board.files_capped);
        assert_row(&board, "files", 1, 0);
        input.walk_cap = 2;
        let board = census(&input);
        assert!(!board.files_capped);
        assert_row(&board, "files", 1, 0);
        input.file_dirs.clear();
        input.walk_cap = 1;
        let board = census(&input);
        assert!(!board.files_capped);
        assert_row(&board, "files", 0, 0);
    }

    #[test]
    fn repositories_count_git_dirs_once() {
        let scratch = Scratch::new();
        let root = scratch.path();
        let scan = root.join("scan");
        let repo = scan.join("proj");
        fs::create_dir_all(repo.join(".git")).unwrap();
        fs::create_dir_all(repo.join("nested").join(".git")).unwrap();
        let decoy = scan.join("not-a-repo");
        fs::create_dir_all(&decoy).unwrap();
        fs::write(decoy.join(".gitignore"), b"x").unwrap();
        let depth6 = nest(&scan, &["p", "q", "r", "s", "t", "u"]);
        fs::write(depth6.join(".git"), b"gitdir: x\n").unwrap();
        let depth7 = nest(&scan, &["a", "b", "c", "d", "e", "f", "g"]);
        fs::write(depth7.join(".git"), b"gitdir: y\n").unwrap();

        let mut input = base(root);
        input.repo = repo.clone();
        input.repo_scan_dirs = vec![scan, repo];
        let board = census(&input);
        assert_row(&board, "repositories", 2, 1);

        let elsewhere = root.join("elsewhere");
        fs::create_dir_all(&elsewhere).unwrap();
        input.repo_scan_dirs = vec![elsewhere];
        let board = census(&input);
        assert_row(&board, "repositories", 0, 0);
    }

    #[cfg(unix)]
    #[test]
    fn configuration_symlink_into_nix_is_operational() {
        let scratch = Scratch::new();
        let root = scratch.path();
        let nix = root.join("nix");
        fs::create_dir_all(&nix).unwrap();
        fs::write(nix.join("item"), b"x").unwrap();
        let cfg = root.join("config");
        fs::create_dir_all(&cfg).unwrap();
        fs::write(cfg.join("plain"), b"x").unwrap();
        std::os::unix::fs::symlink(nix.join("item"), cfg.join("linked")).unwrap();
        let mut input = base(root);
        input.nix_prefix = nix;
        input.config_dir = cfg;
        let board = census(&input);
        assert_row(&board, "configuration", 2, 1);
    }

    #[test]
    fn workload_predicates_do_not_leak() {
        let scratch = Scratch::new();
        let root = scratch.path();
        let mut input = base(root);
        let repo = root.join("repo");
        let receipts = repo.join("receipts");
        fs::create_dir_all(&receipts).unwrap();
        fs::write(receipts.join("baseline-approved-1.json"), b"{}\n").unwrap();
        fs::write(receipts.join("local-restore-1.json"), b"{}\n").unwrap();
        fs::write(receipts.join("checklist.md"), b"# list\n").unwrap();
        fs::create_dir(receipts.join("a4b-ok-directory")).unwrap();
        input.repo = repo.clone();
        assert_eq!(census(&input).open_steps, open_all());

        let nix = root.join("nix");
        fs::create_dir(&nix).unwrap();
        input.nix_prefix = nix;
        assert!(!is_open(&census(&input), "A3"));
        input.nix_prefix = root.join("absent-nix");
        assert!(is_open(&census(&input), "A3"));
        #[cfg(unix)]
        {
            let bin = root.join("bin");
            fs::create_dir_all(&bin).unwrap();
            fs::write(bin.join("nix"), b"no").unwrap();
            input.path_env = path_text(&bin);
            assert!(is_open(&census(&input), "A3"));
            make_exec(&bin.join("nix"));
            assert!(!is_open(&census(&input), "A3"));
            input.path_env.clear();
        }

        fs::write(repo.join("flake.nix"), b"{}\n").unwrap();
        assert!(is_open(&census(&input), "A4"));
        fs::remove_file(repo.join("flake.nix")).unwrap();
        fs::create_dir(repo.join(".git")).unwrap();
        assert!(is_open(&census(&input), "A4"));
        fs::write(repo.join("flake.nix"), b"{}\n").unwrap();
        assert!(!is_open(&census(&input), "A4"));

        assert!(is_open(&census(&input), "A4b"));
        fs::write(receipts.join("a4b-ok-marker"), b"ok").unwrap();
        assert!(!is_open(&census(&input), "A4b"));

        fs::create_dir(receipts.join("a5-ok")).unwrap();
        assert!(is_open(&census(&input), "A5"));
        fs::remove_dir(receipts.join("a5-ok")).unwrap();
        fs::write(receipts.join("a5-ok"), b"ok").unwrap();
        assert!(!is_open(&census(&input), "A5"));

        let pass = root.join("secret-password-file-token");
        let bad_repo = "r2:secret-repo-token/local-restic/bucket";
        fs::write(&pass, b"pw").unwrap();
        input.restic_password_file = pass;
        input.restic_repository = bad_repo.to_string();
        let board = census(&input);
        assert!(is_open(&board, "A8"));
        let text = render(&board);
        assert!(!text.contains(bad_repo));
        assert!(!text.contains("secret-password-file-token"));

        input.restic_repository = "r2:secret-repo-token/bucket".to_string();
        let board = census(&input);
        assert!(!is_open(&board, "A8"));
        let text = render(&board);
        assert!(!text.contains("r2:secret-repo-token/bucket"));
        assert!(!text.contains("secret-password-file-token"));

        input.restic_repository.clear();
        assert!(is_open(&census(&input), "A8"));
        input.restic_repository = "r2:secret-repo-token/bucket".to_string();
        input.restic_password_file = root.join("missing-password-file");
        assert!(is_open(&census(&input), "A8"));
    }

    #[test]
    fn workload_all_steps_pass() {
        let scratch = Scratch::new();
        let root = scratch.path();
        let mut input = base(root);
        let home = root.join("home");
        fs::create_dir_all(&home).unwrap();
        input.home = home;
        let version = root.join("SystemVersion.plist");
        fs::write(&version, b"<plist/>").unwrap();
        input.system_version = version;
        let nix = root.join("nix");
        fs::create_dir_all(&nix).unwrap();
        input.nix_prefix = nix;
        let repo = root.join("repo");
        fs::create_dir_all(repo.join(".git")).unwrap();
        fs::write(repo.join("flake.nix"), b"{}\n").unwrap();
        let receipts = repo.join("receipts");
        fs::create_dir_all(&receipts).unwrap();
        fs::write(receipts.join("a4b-ok-marker"), b"ok").unwrap();
        fs::write(receipts.join("a5-ok"), b"ok").unwrap();
        for name in ["a9-ok", "a10-ok", "a11-ok", "a12-ok", "a13-ok"] {
            fs::write(receipts.join(name), b"ok").unwrap();
        }
        let profile = root.join("system-profile");
        fs::create_dir_all(&profile).unwrap();
        input.system_profile = profile;
        let opa = repo.join("operations").join(".cache").join("opa");
        fs::create_dir_all(opa.parent().unwrap()).unwrap();
        fs::write(&opa, b"opa").unwrap();
        input.repo = repo;
        let pass = root.join("offsite-password-token");
        fs::write(&pass, b"pw").unwrap();
        input.restic_password_file = pass;
        input.restic_repository = "r2:offsite-restic-token".to_string();
        let board = census(&input);
        assert!(board.open_steps.is_empty(), "{:?}", board.open_steps);
        assert_row(&board, "workload_a", 14, 14);
        let text = render(&board);
        assert!(text.contains("workload_a_open=none\n"));
        assert!(!text.contains("offsite-restic-token"));
        assert!(!text.contains("offsite-password-token"));
        assert!(!board.files_capped);
    }

    fn empty_board() -> String {
        concat!(
            "census\n",
            "workload_a current=14 operational=0 left=14\n",
            "tools current=0 operational=0 left=0\n",
            "services current=0 operational=0 left=0\n",
            "jobs current=0 operational=0 left=0\n",
            "applications current=0 operational=0 left=0\n",
            "files current=0 operational=0 left=0\n",
            "media current=0 operational=0 left=0\n",
            "repositories current=0 operational=0 left=0\n",
            "configuration current=0 operational=0 left=0\n",
            "workload_a_open=A1,A2,A3,A4,A4b,A5,A6,A7,A8,A9,A10,A11,A12,A13\n",
            "files_capped=0\n",
        )
        .to_string()
    }

    fn open_all() -> Vec<&'static str> {
        vec![
            "A1", "A2", "A3", "A4", "A4b", "A5", "A6", "A7", "A8", "A9", "A10", "A11", "A12", "A13",
        ]
    }

    fn is_open(board: &Board, id: &str) -> bool {
        board.open_steps.contains(&id)
    }

    fn assert_row(board: &Board, name: &str, current: u64, operational: u64) {
        let row = find_row(board, name);
        assert_eq!(row.current, current, "{name} current");
        assert_eq!(row.operational, operational, "{name} operational");
        assert_eq!(row.left, current - operational, "{name} left");
    }

    fn find_row<'a>(board: &'a Board, name: &str) -> &'a Row {
        board
            .rows
            .iter()
            .find(|row| row.name == name)
            .unwrap_or_else(|| panic!("missing row {name}"))
    }

    fn base(root: &Path) -> Input {
        Input {
            home: root.join("missing-home"),
            repo: root.join("missing-repo"),
            path_env: String::new(),
            nix_prefix: root.join("missing-nix"),
            service_dirs: Vec::new(),
            app_dirs: Vec::new(),
            file_dirs: Vec::new(),
            repo_scan_dirs: Vec::new(),
            config_dir: root.join("missing-config"),
            system_version: root.join("missing-system-version"),
            system_profile: root.join("missing-system-profile"),
            crontab_text: String::new(),
            launchd_list: String::new(),
            restic_repository: String::new(),
            restic_password_file: root.join("missing-password-file"),
            walk_cap: 200_000,
        }
    }

    fn nest(root: &Path, parts: &[&str]) -> PathBuf {
        let mut path = root.to_path_buf();
        for part in parts {
            path.push(part);
        }
        fs::create_dir_all(&path).unwrap();
        path
    }

    fn path_text(path: &Path) -> String {
        path.to_str().unwrap().to_string()
    }

    #[cfg(unix)]
    fn make_exec(path: &Path) {
        use std::os::unix::fs::PermissionsExt;
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(path, b"#!/bin/sh\nexit 0\n").unwrap();
        let mut perms = fs::metadata(path).unwrap().permissions();
        perms.set_mode(0o755);
        fs::set_permissions(path, perms).unwrap();
    }

    struct Scratch(PathBuf);

    impl Scratch {
        fn new() -> Self {
            static SEQ: AtomicU64 = AtomicU64::new(0);
            let n = SEQ.fetch_add(1, Ordering::Relaxed);
            let tick = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|elapsed| elapsed.as_nanos())
                .unwrap_or(0);
            let path = std::env::temp_dir().join(format!(
                "mac-env-census-{}-{}-{}",
                std::process::id(),
                n,
                tick
            ));
            fs::create_dir_all(&path).unwrap();
            Self(path)
        }

        fn path(&self) -> &Path {
            &self.0
        }
    }

    impl Drop for Scratch {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }
}
