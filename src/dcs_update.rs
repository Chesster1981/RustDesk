//! DCS Norway custom-client update check against GitHub Releases.
//! Stock RustDesk queries api.rustdesk.com; branded builds skip that path.

use hbb_common::{bail, get_version_number, log, ResultType};
use serde::Deserialize;

/// GitHub owner/repo that publishes DCS Windows installers.
pub const DCS_RELEASES_OWNER: &str = "Chesster1981";
pub const DCS_RELEASES_REPO: &str = "RustDesk";

const RELEASES_API: &str =
    "https://api.github.com/repos/Chesster1981/RustDesk/releases?per_page=10";

#[derive(Debug, Deserialize)]
struct GhRelease {
    tag_name: String,
    html_url: String,
    draft: bool,
    prerelease: bool,
    assets: Vec<GhAsset>,
}

#[derive(Debug, Deserialize)]
struct GhAsset {
    name: String,
}

/// Strip optional `dcs-` / `v` prefixes so `get_version_number` can parse.
pub fn normalize_release_version(tag: &str) -> String {
    let mut t = tag.trim();
    if let Some(rest) = t.strip_prefix("dcs-") {
        t = rest;
    }
    if let Some(rest) = t.strip_prefix('v') {
        t = rest;
    }
    t.to_string()
}

fn is_dcs_client_asset(name: &str, tag: &str) -> bool {
    let n = name.to_ascii_lowercase();
    let tag = tag.to_ascii_lowercase();
    let branded = n.starts_with("dcs-norway-rdc-");
    let stock = n.starts_with(&format!("rustdesk-{tag}-"))
        || n.starts_with(&format!("rustdesk-{tag}."));
    if !(branded || stock) {
        return false;
    }
    n.ends_with(".exe")
        || n.ends_with(".apk")
        || n.ends_with(".deb")
        || n.ends_with(".dmg")
        || n.ends_with(".rpm")
        || n.ends_with(".appimage")
}

fn release_has_client_asset(rel: &GhRelease) -> bool {
    let tag = rel.tag_name.as_str();
    rel.assets.iter().any(|a| is_dcs_client_asset(&a.name, tag))
}

/// Pick the newest published release that has a DCS client installer asset.
pub fn pick_latest_windows_release(releases: &[GhRelease]) -> Option<&GhRelease> {
    releases
        .iter()
        .find(|r| !r.draft && release_has_client_asset(r))
}

/// Query GitHub Releases and return the release page URL when a newer build exists.
pub async fn check_dcs_github_update(current_version: &str) -> ResultType<Option<String>> {
    let client = reqwest::Client::builder()
        .user_agent(format!(
            "DCS-Norway-RD-updater/{}",
            current_version.trim()
        ))
        .timeout(std::time::Duration::from_secs(30))
        .build()?;

    let resp = client
        .get(RELEASES_API)
        .header("Accept", "application/vnd.github+json")
        .send()
        .await?;
    if !resp.status().is_success() {
        bail!("GitHub releases HTTP {}", resp.status());
    }
    let releases: Vec<GhRelease> = resp.json().await?;
    let Some(latest) = pick_latest_windows_release(&releases) else {
        log::debug!("No DCS client release asset found on GitHub");
        return Ok(None);
    };

    let remote = normalize_release_version(&latest.tag_name);
    let local = normalize_release_version(current_version);
    if get_version_number(&remote) > get_version_number(&local) {
        log::info!(
            "DCS update available: local={} remote={} url={}",
            local,
            remote,
            latest.html_url
        );
        Ok(Some(latest.html_url.clone()))
    } else {
        log::debug!(
            "DCS client up to date: local={} remote={}",
            local,
            remote
        );
        Ok(None)
    }
}

/// Whether a GitHub download URL is allowed for this branded client.
pub fn is_allowed_dcs_update_url(owner: &str, repo: &str) -> bool {
    owner.eq_ignore_ascii_case(DCS_RELEASES_OWNER) && repo.eq_ignore_ascii_case(DCS_RELEASES_REPO)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_strips_prefixes() {
        assert_eq!(normalize_release_version("1.4.10"), "1.4.10");
        assert_eq!(normalize_release_version("v1.4.10"), "1.4.10");
        assert_eq!(normalize_release_version("dcs-1.4.10"), "1.4.10");
        assert_eq!(normalize_release_version("dcs-v1.4.10"), "1.4.10");
        assert_eq!(normalize_release_version("1.4.9-2"), "1.4.9-2");
    }

    #[test]
    fn pick_skips_draft_and_missing_asset() {
        let releases = vec![
            GhRelease {
                tag_name: "1.4.11".into(),
                html_url: "https://github.com/Chesster1981/RustDesk/releases/tag/1.4.11".into(),
                draft: true,
                prerelease: false,
                assets: vec![GhAsset {
                    name: "rustdesk-1.4.11-x86_64.exe".into(),
                }],
            },
            GhRelease {
                tag_name: "1.4.10".into(),
                html_url: "https://github.com/Chesster1981/RustDesk/releases/tag/1.4.10".into(),
                draft: false,
                prerelease: true,
                assets: vec![GhAsset {
                    name: "rustdesk-1.4.10-x86_64.exe".into(),
                }],
            },
        ];
        let picked = pick_latest_windows_release(&releases).unwrap();
        assert_eq!(picked.tag_name, "1.4.10");
    }

    #[test]
    fn pick_accepts_linux_and_macos_assets() {
        let releases = vec![
            GhRelease {
                tag_name: "1.4.11".into(),
                html_url: "https://github.com/Chesster1981/RustDesk/releases/tag/1.4.11".into(),
                draft: false,
                prerelease: false,
                assets: vec![GhAsset {
                    name: "rustdesk-1.4.11-x86_64.deb".into(),
                }],
            },
        ];
        assert_eq!(
            pick_latest_windows_release(&releases).unwrap().tag_name,
            "1.4.11"
        );

        let dmg = vec![GhRelease {
            tag_name: "1.4.12".into(),
            html_url: "https://github.com/Chesster1981/RustDesk/releases/tag/1.4.12".into(),
            draft: false,
            prerelease: false,
            assets: vec![GhAsset {
                name: "DCS-Norway-RDC-1.4.12-aarch64.dmg".into(),
            }],
        }];
        assert_eq!(
            pick_latest_windows_release(&dmg).unwrap().tag_name,
            "1.4.12"
        );
    }

    #[test]
    fn allowlist_owner_repo() {
        assert!(is_allowed_dcs_update_url("Chesster1981", "RustDesk"));
        assert!(is_allowed_dcs_update_url("chesster1981", "rustdesk"));
        assert!(!is_allowed_dcs_update_url("rustdesk", "rustdesk"));
    }
}
