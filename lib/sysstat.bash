#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::sysstat_cpu_load () {
  local load="" cores="1"

  load="$(uptime | awk -F'load averages?: |load average: ' '{ print $2 }' | awk -F'[, ]+' '{ print $1 }')" || return 1
  [[ -n "$load" ]] || return 1

  cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || printf "1")"
  [[ "$cores" =~ ^[0-9]+$ && "$cores" -gt 0 ]] || cores="1"

  awk -v load="$load" -v cores="$cores" 'BEGIN { printf "%.0f", (load / cores) * 100 }'
}

gaudi::sysstat_memory_free () {
  if [[ -r /proc/meminfo ]]; then
    awk '/MemAvailable:/ { printf "%.1f", $2 / 1024 / 1024; exit }' /proc/meminfo
    return
  fi

  gaudi::exists vm_stat || return 1

  local page_size="" free_pages="" inactive_pages="" speculative_pages=""
  page_size="$(pagesize 2>/dev/null || sysctl -n hw.pagesize 2>/dev/null || printf "4096")"
  free_pages="$(vm_stat | awk '/Pages free:/ { gsub("\\.", "", $3); print $3; exit }')"
  inactive_pages="$(vm_stat | awk '/Pages inactive:/ { gsub("\\.", "", $3); print $3; exit }')"
  speculative_pages="$(vm_stat | awk '/Pages speculative:/ { gsub("\\.", "", $3); print $3; exit }')"

  awk \
    -v page="$page_size" \
    -v free="${free_pages:-0}" \
    -v inactive="${inactive_pages:-0}" \
    -v speculative="${speculative_pages:-0}" \
    'BEGIN { printf "%.1f", ((free + inactive + speculative) * page) / 1024 / 1024 / 1024 }'
}

gaudi::sysstat_hdd_usage () {
  df -h "${PWD:-.}" 2>/dev/null | awk 'NR == 2 { print $5; exit }'
}

# shellcheck disable=SC2034
gaudi::collect_system_stats () {
  GAUDI_CPU_LOAD="$(gaudi::sysstat_cpu_load 2>/dev/null || true)"
  GAUDI_MEMORY_FREE="$(gaudi::sysstat_memory_free 2>/dev/null || true)"
  GAUDI_HDD_USAGE="$(gaudi::sysstat_hdd_usage 2>/dev/null || true)"
}
