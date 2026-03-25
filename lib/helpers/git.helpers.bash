#!/usr/bin/env bash

GAUDI_SCM_GIT_SHOW_DETAILS=${GAUDI_SCM_GIT_SHOW_DETAILS:=true}
GAUDI_SCM_GIT_SHOW_REMOTE_INFO=${GAUDI_SCM_GIT_SHOW_REMOTE_INFO:=auto}
GAUDI_SCM_GIT_IGNORE_UNTRACKED=${GAUDI_SCM_GIT_IGNORE_UNTRACKED:=false}
GAUDI_SCM_GIT_IGNORE_SUBMODULES=${GAUDI_SCM_GIT_IGNORE_SUBMODULES:=true}
GAUDI_SCM_GIT_SHOW_CURRENT_USER=${GAUDI_SCM_GIT_SHOW_CURRENT_USER:=false}
GAUDI_SCM_GIT_SHOW_COMMIT_SHA=${GAUDI_SCM_GIT_SHOW_COMMIT_SHA:=false}
GAUDI_SCM_GIT_GITSTATUS_RAN=${GAUDI_SCM_GIT_GITSTATUS_RAN:=false}

GAUDI_SCM_GIT='git'
GAUDI_SCM_GIT_CHAR=${GAUDI_SCM_GIT_CHAR:=git}
GAUDI_SCM_GIT_USER_CHAR=${GAUDI_SCM_GIT_USER_CHAR:=@}
GAUDI_SCM_GIT_AHEAD_CHAR=${GAUDI_SCM_GIT_AHEAD_CHAR:=^}
GAUDI_SCM_GIT_BEHIND_CHAR=${GAUDI_SCM_GIT_BEHIND_CHAR:=v}
GAUDI_SCM_THEME_TAG_PREFIX=${GAUDI_SCM_THEME_TAG_PREFIX:=tag:}
GAUDI_SCM_THEME_DETACHED_PREFIX=${GAUDI_SCM_THEME_DETACHED_PREFIX:=detached:}
GAUDI_SCM_GIT_UNTRACKED_CHAR=${GAUDI_SCM_GIT_UNTRACKED_CHAR:=?:}
GAUDI_SCM_GIT_CHANGED_CHAR=${GAUDI_SCM_GIT_CHANGED_CHAR:=!:}
GAUDI_SCM_GIT_STAGED_CHAR=${GAUDI_SCM_GIT_STAGED_CHAR:=+:}
GAUDI_SCM_GIT_CONFLICTED_CHAR=${GAUDI_SCM_GIT_CONFLICTED_CHAR:=x:}
GAUDI_SCM_GIT_STASH_CHAR=${GAUDI_SCM_GIT_STASH_CHAR:=*:}
GAUDI_SCM_GIT_SHA_CHAR=${GAUDI_SCM_GIT_SHA_CHAR:=#:}
GAUDI_SCM_GIT_GONE_CHAR=${GAUDI_SCM_GIT_GONE_CHAR:=gone}

# Normalize the previously shipped defaults when the theme is re-sourced in an
# already-running shell. This preserves intentional user overrides while
# replacing the old broken literal escape strings.
[[ "${GAUDI_SCM_GIT_CHAR}" == "\\ue727" ]] && GAUDI_SCM_GIT_CHAR="git"
[[ "${GAUDI_SCM_GIT_USER_CHAR}" == "\\uf7a3" ]] && GAUDI_SCM_GIT_USER_CHAR="@"
[[ "${GAUDI_SCM_GIT_UNTRACKED_CHAR}" == "\\uf070 " ]] && GAUDI_SCM_GIT_UNTRACKED_CHAR="?:"
[[ "${GAUDI_SCM_GIT_CHANGED_CHAR}" == "U:" ]] && GAUDI_SCM_GIT_CHANGED_CHAR="!:"
[[ "${GAUDI_SCM_GIT_STAGED_CHAR}" == "S:" ]] && GAUDI_SCM_GIT_STAGED_CHAR="+:"
[[ "${GAUDI_SCM_GIT_STASH_CHAR}" == "\\uf5e1" ]] && GAUDI_SCM_GIT_STASH_CHAR="*:"
[[ "${GAUDI_SCM_GIT_SHA_CHAR}" == "\\uf417" ]] && GAUDI_SCM_GIT_SHA_CHAR="#:"
[[ "${GAUDI_SCM_THEME_DETACHED_PREFIX}" == "⌿" ]] && GAUDI_SCM_THEME_DETACHED_PREFIX="detached:"

function _git-symbolic-ref() {
	git symbolic-ref -q HEAD 2> /dev/null
}

# When on a branch, this is often the same as _git-commit-description, but this can be different when two branches are pointing to the same commit. _git-branch is used to explicitly choose the checked-out branch.
function _git-branch() {
	if [[ "${GAUDI_SCM_GIT_GITSTATUS_RAN:-}" == "true" ]]; then
		if [[ -n "${VCS_STATUS_LOCAL_BRANCH:-}" ]]; then
			echo "${VCS_STATUS_LOCAL_BRANCH}"
		else
			return 1
		fi
	else
		git symbolic-ref -q --short HEAD 2> /dev/null || return 1
	fi
}

function _git-hide-status() {
	[[ "$(git config --get gaudi-bash.hide-status)" == "1" ]]
}

function _git-tag() {
	if [[ "${GAUDI_SCM_GIT_GITSTATUS_RAN:-}" == "true" ]]; then
		if [[ -n "${VCS_STATUS_TAG:-}" ]]; then
			echo "${VCS_STATUS_TAG}"
		fi
	else
		git describe --tags --exact-match 2> /dev/null
	fi
}

function _git-commit-description() {
	git describe --contains --all 2> /dev/null
}

function _git-short-sha() {
	if [[ "${GAUDI_SCM_GIT_GITSTATUS_RAN:-}" == "true" ]]; then
		echo "${VCS_STATUS_COMMIT:0:7}"
	else
		git rev-parse --short HEAD
	fi
}

# Try the checked-out branch first to avoid collision with branches pointing to the same ref.
function _git-friendly-ref() {
	if [[ "${GAUDI_SCM_GIT_GITSTATUS_RAN:-}" == "true" ]]; then
		_git-branch || _git-tag || _git-short-sha # there is no tag based describe output in gitstatus
	else
		_git-branch || _git-tag || _git-commit-description || _git-short-sha
	fi
}

function _git-num-remotes() {
	git remote | wc -l
}

function _git-upstream() {
	local ref
	ref="$(_git-symbolic-ref)" || return 1
	git for-each-ref --format="%(upstream:short)" "${ref}"
}

function _git-upstream-remote() {
	local upstream branch
	upstream="$(_git-upstream)" || return 1

	branch="$(_git-upstream-branch)" || return 1
	echo "${upstream%"/${branch}"}"
}

function _git-upstream-branch() {
	local ref
	ref="$(_git-symbolic-ref)" || return 1

	# git versions < 2.13.0 do not support "strip" for upstream format
	# regex replacement gives the wrong result for any remotes with slashes in the name, so only use when the strip format fails.
	git for-each-ref --format="%(upstream:strip=3)" "${ref}" 2> /dev/null || git for-each-ref --format="%(upstream)" "${ref}" | sed -e "s/.*\/.*\/.*\///"
}

function _git-upstream-behind-ahead() {
	local upstream=""

	upstream="$(_git-upstream)" || {
		printf '0\t0'
		return 0
	}
	[[ -n "$upstream" ]] || {
		printf '0\t0'
		return 0
	}

	git rev-list --left-right --count "${upstream}...HEAD" 2> /dev/null || printf '0\t0'
}

function _git-upstream-branch-gone() {
	[[ "$(git status -s -b | sed -e 's/.* //')" == "[gone]" ]]
}

function _git-status() {
	local -a git_status_flags=("--porcelain")

	if [[ "${GAUDI_SCM_GIT_IGNORE_UNTRACKED:-}" == "true" ]]; then
		git_status_flags+=("-uno")
	fi
	if [[ "${GAUDI_SCM_GIT_IGNORE_SUBMODULES:-}" == "true" ]]; then
		git_status_flags+=("--ignore-submodules=dirty")
	fi

	git status "${git_status_flags[@]}" 2> /dev/null
}

function _git-status-counts() {
	local num_untracked=0
	local num_changed=0
	local num_staged=0
	local num_conflicted=0
	local status_line=""
	local staged_status=""
	local changed_status=""

	while IFS= read -r status_line; do
		[[ -z "$status_line" ]] && continue

		case "$status_line" in
			'?? '*)
				num_untracked=$((num_untracked + 1))
				continue
				;;
			'DD '*|'AU '*|'UD '*|'UA '*|'DU '*|'AA '*|'UU '*)
				num_conflicted=$((num_conflicted + 1))
				continue
				;;
		esac

		staged_status="${status_line:0:1}"
		changed_status="${status_line:1:1}"

		[[ "$staged_status" != " " ]] && num_staged=$((num_staged + 1))
		[[ "$changed_status" != " " ]] && num_changed=$((num_changed + 1))
	done < <(_git-status)

	printf '%s\t%s\t%s\t%s' "$num_untracked" "$num_changed" "$num_staged" "$num_conflicted"
}

_git-remote-info () {
	local upstream=""
	local remote_info=""
	local same_branch_name=""

	upstream="$(_git-upstream)"
	[[ -n "$upstream" ]] || return

	[[ "$(_git-branch)" == "$(_git-upstream-branch)" ]] && same_branch_name=true
	if { [[ "${GAUDI_SCM_GIT_SHOW_REMOTE_INFO}" = "auto" ]] && [[ "$(_git-num-remotes)" -ge 2 ]]; } ||
		[[ "${GAUDI_SCM_GIT_SHOW_REMOTE_INFO}" = "true" ]]; then
		if [[ "${same_branch_name}" != "true" ]]; then
			remote_info="$upstream"
		else
			remote_info="$(_git-upstream-remote)"
		fi
	elif [[ "${same_branch_name}" != "true" ]]; then
		remote_info="$(_git-upstream-branch)"
	fi

	[[ -n "${remote_info}" ]] && printf "%s" "${remote_info}"
}

function _git-stash-count() {
	git rev-parse --verify refs/stash > /dev/null 2>&1 || {
		echo 0
		return 0
	}

	git rev-list --walk-reflogs --count refs/stash 2> /dev/null || echo 0
}

function _git-operation() {
	local git_dir=""

	git_dir="$(git rev-parse --git-dir 2> /dev/null)" || return 1

	if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
		echo "rebase"
	elif [[ -f "$git_dir/MERGE_HEAD" ]]; then
		echo "merge"
	elif [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
		echo "cherry"
	elif [[ -f "$git_dir/REVERT_HEAD" ]]; then
		echo "revert"
	elif [[ -f "$git_dir/BISECT_LOG" ]]; then
		echo "bisect"
	else
		return 1
	fi
}

git_user_info () {
  local git_user_name=""
  local git_user_initials=""
  local word=""

  # support two or more initials, set by 'git pair' plugin
  GAUDI_SCM_CURRENT_USER="$(git config user.initials | sed 's% %+%')"

  if [[ -z "${GAUDI_SCM_CURRENT_USER}" ]]; then
    git_user_name="$(git config user.name | PERLIO=:utf8 perl -pe '$_=lc')"
    for word in $git_user_name; do
      git_user_initials+="${word:0:1}"
    done
    GAUDI_SCM_CURRENT_USER="$git_user_initials"
  fi

  [[ -n "${GAUDI_SCM_CURRENT_USER}" ]] && printf "%b" "$GAUDI_SCM_GIT_USER_CHAR $GAUDI_SCM_CURRENT_USER"
}

git_prompt_vars () {
	local commits_behind=0
	local commits_ahead=0
	local stash_count=0
	local num_untracked=0
	local num_changed=0
	local num_staged=0
	local num_conflicted=0
	local git_operation=""
	local working_tree_dirty=false

  # Make sure we do a fetch to get all the information needed form the upstream
  [[ $GAUDI_SCM_FETCH == true ]] && git fetch &> /dev/null;

  if _git-branch &> /dev/null; then
    GAUDI_SCM_BRANCH="$(_git-friendly-ref)"
    [[ -n "$(_git-remote-info)" ]] && GAUDI_SCM_BRANCH+=" → $(_git-remote-info)"
  else
  	local detached_prefix
		if _git-tag &> /dev/null; then
			detached_prefix="${GAUDI_SCM_THEME_TAG_PREFIX}"
		else
			detached_prefix="${GAUDI_SCM_THEME_DETACHED_PREFIX}"
		fi
		GAUDI_SCM_BRANCH="${detached_prefix}$(_git-friendly-ref)"
  fi

  IFS=$'\t' read -r commits_behind commits_ahead <<< "$(_git-upstream-behind-ahead)"
  [[ "${commits_ahead:-0}" -gt 0 ]] && GAUDI_SCM_BRANCH+=" ${GAUDI_SCM_GIT_AHEAD_CHAR}${commits_ahead}"
  [[ "${commits_behind:-0}" -gt 0 ]] && GAUDI_SCM_BRANCH+=" ${GAUDI_SCM_GIT_BEHIND_CHAR}${commits_behind}"
  _git-upstream-branch-gone && GAUDI_SCM_BRANCH+=" ${GAUDI_SCM_GIT_GONE_CHAR}"

  git_operation="$(_git-operation 2> /dev/null || true)"
  [[ -n "${git_operation}" ]] && GAUDI_SCM_BRANCH+=" ${git_operation}"

  stash_count="$(_git-stash-count)"
  [[ "${stash_count:-0}" -gt 0 ]] && GAUDI_SCM_BRANCH+=" ${GAUDI_SCM_GIT_STASH_CHAR}${stash_count}"

  GAUDI_SCM_STATE=${GIT_THEME_PROMPT_CLEAN:-$GAUDI_SCM_THEME_PROMPT_CLEAN}
  
  IFS=$'\t' read -r num_untracked num_changed num_staged num_conflicted < <(_git-status-counts)
  
  if [[ "${num_staged}" -gt 0 || "${num_changed}" -gt 0 || "${num_untracked}" -gt 0 || "${num_conflicted}" -gt 0 ]]; then
    working_tree_dirty=true

    if [[ "${GAUDI_SCM_GIT_SHOW_DETAILS}" = "true" ]]; then
      [[ "${num_staged}" -gt 0 ]] && GAUDI_SCM_BRANCH+=" ${GAUDI_SCM_GIT_STAGED_CHAR}${num_staged}"
      [[ "${num_changed}" -gt 0 ]] && GAUDI_SCM_BRANCH+=" ${GAUDI_SCM_GIT_CHANGED_CHAR}${num_changed}"
      [[ "${num_untracked}" -gt 0 ]] && GAUDI_SCM_BRANCH+=" ${GAUDI_SCM_GIT_UNTRACKED_CHAR}${num_untracked}"
      [[ "${num_conflicted}" -gt 0 ]] && GAUDI_SCM_BRANCH+=" ${GAUDI_SCM_GIT_CONFLICTED_CHAR}${num_conflicted}"
      GAUDI_SCM_STATE=""
    else
      GAUDI_SCM_STATE=${GIT_THEME_PROMPT_DIRTY:-$GAUDI_SCM_THEME_PROMPT_DIRTY}
    fi
  else
    GAUDI_SCM_STATE=${GIT_THEME_PROMPT_CLEAN:-$GAUDI_SCM_THEME_PROMPT_CLEAN}
  fi

  if [[ "${num_conflicted}" -gt 0 ]]; then
    GAUDI_SCM_DIRTY=4
  elif [[ "${working_tree_dirty}" == "true" ]]; then
    if [[ "${num_changed}" -gt 0 || "${num_untracked}" -gt 0 ]]; then
      GAUDI_SCM_DIRTY=2
    else
      GAUDI_SCM_DIRTY=3
    fi
  fi

  if [[ "${GAUDI_SCM_GIT_SHOW_COMMIT_SHA}" == true ]]; then
    GAUDI_SCM_BRANCH+=" ${GAUDI_SCM_GIT_SHA_CHAR}$(_git-short-sha)"
  fi
  [[ "${GAUDI_SCM_GIT_SHOW_CURRENT_USER}" == "true" ]] && GAUDI_SCM_BRANCH+="$(git_user_info)"
  
  GAUDI_SCM_CHANGE=$(_git-short-sha 2>/dev/null || echo "")
  
}

export GAUDI_SCM_STATE
export GAUDI_SCM_DIRTY
export GAUDI_SCM_CHANGE
export GAUDI_SCM_GIT
export GAUDI_SCM_GIT_CHAR
