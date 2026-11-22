#![deny(unsafe_code)]

use std::path::{Path, PathBuf};
use std::process::ExitCode;

use mac_env_census::{census, render, Input};

const USAGE: &str = "\
usage: mac-env-census [--home DIR] [--repo DIR] [--board FILE] [--path STRING] \
[--crontab-file FILE] [--nix-prefix DIR]\n";

struct Opts {
    home: Option<PathBuf>,
    repo: Option<PathBuf>,
    board: Option<PathBuf>,
    path: Option<String>,
    crontab_file: Option<PathBuf>,
    nix_prefix: Option<PathBuf>,
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(()) => {
            eprint!("{USAGE}");
            ExitCode::from(2)
        }
    }
}

fn run() -> Result<(), ()> {
    let args = cli_args()?;
    let opts = parse_args(&args)?;
    let text = render(&census(&input_from(&opts)));
    emit(&text);
    if let Some(path) = opts.board.as_deref() {
        write_board(path, &text);
    }
    Ok(())
}

fn cli_args() -> Result<Vec<String>, ()> {
    let mut args = Vec::new();
    for arg in std::env::args_os() {
        let Some(text) = arg.to_str() else {
            return Err(());
        };
        args.push(text.to_string());
    }
    Ok(args)
}

fn parse_args(args: &[String]) -> Result<Opts, ()> {
    let mut opts = Opts {
        home: None,
        repo: None,
        board: None,
        path: None,
        crontab_file: None,
        nix_prefix: None,
    };
    let mut index = 1usize;
    while index < args.len() {
        let name = args[index].as_str();
        match name {
            "--home" => opts.home = Some(PathBuf::from(next_value(args, &mut index)?)),
            "--repo" => opts.repo = Some(PathBuf::from(next_value(args, &mut index)?)),
            "--board" => opts.board = Some(PathBuf::from(next_value(args, &mut index)?)),
            "--path" => opts.path = Some(next_value(args, &mut index)?),
            "--crontab-file" => {
                opts.crontab_file = Some(PathBuf::from(next_value(args, &mut index)?));
            }
            "--nix-prefix" => {
                opts.nix_prefix = Some(PathBuf::from(next_value(args, &mut index)?));
            }
            _ => return Err(()),
        }
        index += 1;
    }
    Ok(opts)
}

fn next_value(args: &[String], index: &mut usize) -> Result<String, ()> {
    *index += 1;
    args.get(*index).cloned().ok_or(())
}

fn input_from(opts: &Opts) -> Input {
    let home = opts.home.clone().unwrap_or_else(default_home);
    let repo = opts.repo.clone().unwrap_or_else(default_repo);
    let path_env = opts.path.clone().unwrap_or_else(default_path);
    let nix_prefix = opts
        .nix_prefix
        .clone()
        .unwrap_or_else(|| PathBuf::from("/nix/store"));
    Input {
        service_dirs: keep_dirs([
            home.join("Library/LaunchAgents"),
            home.join("Library/LaunchDaemons"),
            PathBuf::from("/Library/LaunchAgents"),
            PathBuf::from("/Library/LaunchDaemons"),
        ]),
        app_dirs: vec![
            PathBuf::from("/Applications"),
            home.join("Applications"),
            PathBuf::from("/System/Applications"),
        ],
        file_dirs: [
            "Desktop",
            "Documents",
            "Downloads",
            "Pictures",
            "Movies",
            "Music",
        ]
        .into_iter()
        .map(|name| home.join(name))
        .collect(),
        repo_scan_dirs: vec![
            home.join("Git"),
            home.join("Documents"),
            home.join(".local"),
            repo.clone(),
        ],
        config_dir: home.join(".config"),
        system_version: PathBuf::from("/System/Library/CoreServices/SystemVersion.plist"),
        system_profile: PathBuf::from("/nix/var/nix/profiles/system"),
        crontab_text: load_crontab(opts.crontab_file.as_deref()),
        restic_repository: std::env::var("MAC_ENV_RESTIC_REPOSITORY").unwrap_or_default(),
        restic_password_file: std::env::var_os("MAC_ENV_RESTIC_PASSWORD_FILE")
            .map(PathBuf::from)
            .unwrap_or_default(),
        walk_cap: 200_000,
        home,
        repo,
        path_env,
        nix_prefix,
    }
}

fn default_home() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .filter(|path| !path.as_os_str().is_empty())
        .unwrap_or_else(|| PathBuf::from("/Users"))
}

fn default_repo() -> PathBuf {
    std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
}

fn default_path() -> String {
    std::env::var("PATH").unwrap_or_default()
}

fn keep_dirs(paths: [PathBuf; 4]) -> Vec<PathBuf> {
    paths.into_iter().filter(|path| path.is_dir()).collect()
}

fn load_crontab(path: Option<&Path>) -> String {
    if let Some(path) = path {
        return read_text(path);
    }
    let output = std::process::Command::new("crontab")
        .arg("-l")
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::null())
        .output();
    match output {
        Ok(output) if output.status.success() => {
            String::from_utf8_lossy(&output.stdout).into_owned()
        }
        _ => String::new(),
    }
}

fn read_text(path: &Path) -> String {
    match std::fs::read(path) {
        Ok(bytes) => String::from_utf8_lossy(&bytes).into_owned(),
        Err(_) => String::new(),
    }
}

fn emit(text: &str) {
    use std::io::Write;
    let mut out = std::io::stdout().lock();
    let _ = out.write_all(text.as_bytes());
    let _ = out.flush();
}

fn write_board(path: &Path, text: &str) {
    if let Some(parent) = path.parent() {
        if !parent.as_os_str().is_empty() && std::fs::create_dir_all(parent).is_err() {
            eprintln!("board write failed");
            return;
        }
    }
    if std::fs::write(path, text).is_err() {
        eprintln!("board write failed");
    }
}
