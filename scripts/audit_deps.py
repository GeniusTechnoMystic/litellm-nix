#!/usr/bin/env python3
import tomllib
import subprocess
import re
import sys

def get_upstream_deps():
    """Fetches the upstream pyproject.toml directly from Git memory and parses Poetry deps."""
    try:
        up_str = subprocess.check_output(["git", "show", "upstream/main:pyproject.toml"], text=True)
        data = tomllib.loads(up_str)
        return data.get("tool", {}).get("poetry", {}).get("dependencies", {})
    except Exception as e:
        print(f"❌ Error fetching upstream TOML from Git: {e}")
        sys.exit(1)

def get_local_deps():
    """Parses our local PEP-621 pyproject.toml, combining base and optional dependencies."""
    try:
        with open("pyproject.toml", "rb") as f:
            data = tomllib.load(f)
        
        # Combine standard dependencies and all optional extra groups
        deps = data.get("project", {}).get("dependencies", [])
        extras = data.get("project", {}).get("optional-dependencies", {})
        for extra_list in extras.values():
            deps.extend(extra_list)
            
        # Extract just the package name for mapping (e.g., 'fastapi>=0.100' -> 'fastapi')
        return {re.split(r"[><=~^\[]", d)[0].lower(): d for d in deps}
    except Exception as e:
        print(f"❌ Error reading local TOML: {e}")
        sys.exit(1)

def main():
    up_deps = get_upstream_deps()
    local_deps = get_local_deps()

    print("\n🔍 AUDITING DEPENDENCIES (Upstream Poetry vs Local PEP-621)\n")
    
    missing = []
    mismatch = []

    for pkg, up_val in up_deps.items():
        if pkg.lower() == "python": 
            continue
            
        # Poetry allows dicts like: uvicorn = {version = "^1.2.3", optional = true}
        up_ver = up_val.get("version", "") if isinstance(up_val, dict) else str(up_val)
        
        if pkg.lower() not in local_deps:
            missing.append(f"  ❌ {pkg} (Upstream wants {up_ver})")
        else:
            loc_ver = local_deps[pkg.lower()]
            # Strip symbols to check if the core version numbers roughly match
            clean_up = re.sub(r"[^0-9.]", "", up_ver)
            if clean_up and clean_up not in loc_ver:
                mismatch.append(f"  ⚠️  {pkg.ljust(20)} | Upstream: {up_ver.ljust(15)} | Local: {loc_ver}")

    if missing:
        print("--- MISSING LOCALLY (Added by BerriAI recently) ---")
        for m in missing: print(m)
        print()

    if mismatch:
        print("--- VERSION MISMATCHES (Requires Review) ---")
        for m in mismatch: print(m)
        print()

    if not missing and not mismatch:
        print("✅ Success: All upstream dependencies are perfectly mirrored locally!")

if __name__ == "__main__":
    main()