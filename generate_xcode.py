#!/usr/bin/env python3
"""Generate a valid Xcode project for PiecesTask."""
import os, hashlib

def xid(s):
    return hashlib.sha256(s.encode()).hexdigest()[:24].upper()

# Collect sources with their relative paths
sources = []
for root, _, files in os.walk("PiecesTask"):
    for f in sorted(files):
        if f.endswith(".swift"):
            src = os.path.join(root, f)
            relpath = src  # e.g. PiecesTask/PiecesTaskApp.swift
            sources.append(relpath)

file_ids = {s: xid(f"f:{s}") for s in sources}
bf_ids = {s: xid(f"bf:{s}") for s in sources}

PID = xid("project")
MGID = xid("mainGroup")
PGID = xid("productsGroup")
BCLID = xid("buildConfigList")
BCDID = xid("debugConfig")
BCRID = xid("releaseConfig")
SBPID = xid("sourcesPhase")
RBPID = xid("resourcesPhase")
ASSETS = "PiecesTaskAssets.xcassets"
ASSET_FID = xid(f"f:{ASSETS}")
ASSET_BFID = xid(f"bf:{ASSETS}")
PRID = xid("productRef")
NTID = xid("nativeTarget")
PXPID = xid("PBXProject")

lines = []
def L(txt): lines.append(txt)

L("// !$*UTF8*$!")
L("{")
L("\tarchiveVersion = 1;")
L("\tclasses = {};")
L("\tobjectVersion = 56;")
L("\tobjects = {")

for src in sources:
    fid = file_ids[src]
    name = os.path.basename(src)
    path = src
    L(f"\t\t{fid} /* {name} */ = {{")
    L(f"\t\t\tisa = PBXFileReference;")
    L(f"\t\t\tlastKnownFileType = sourcecode.swift;")
    L(f"\t\t\tpath = \"{path}\";")
    L(f"\t\t\tsourceTree = SOURCE_ROOT;")
    L(f"\t\t}};")

# Asset catalog
L(f"\t\t{ASSET_FID} /* {ASSETS} */ = {{")
L(f"\t\t\tisa = PBXFileReference;")
L(f"\t\t\tlastKnownFileType = folder.assetcatalog;")
L(f"\t\t\tpath = \"{ASSETS}\";")
L(f"\t\t\tsourceTree = SOURCE_ROOT;")
L(f"\t\t}};")

# Product ref
L(f"\t\t{PRID} /* PiecesTask.app */ = {{")
L(f"\t\t\tisa = PBXFileReference;")
L(f"\t\t\texplicitFileType = wrapper.application;")
L(f"\t\t\tincludeInIndex = 0;")
L(f"\t\t\tpath = \"PiecesTask.app\";")
L(f"\t\t\tsourceTree = BUILT_PRODUCTS_DIR;")
L(f"\t\t}};")

# Main group
L(f"\t\t{MGID} = {{")
L(f"\t\t\tisa = PBXGroup;")
L(f"\t\t\tchildren = (")
# Products group
L(f"\t\t\t\t{PGID} /* Products */,")
L(f"\t\t\t\t{ASSET_FID} /* {ASSETS} */,")
# Each source file
for src in sources:
    fname = os.path.basename(src)
    L(f"\t\t\t\t{file_ids[src]} /* {fname} */,")
L(f"\t\t\t);")
L(f"\t\t\tsourceTree = SOURCE_ROOT;")
L(f"\t\t}};")

# Products group
L(f"\t\t{PGID} = {{")
L(f"\t\t\tisa = PBXGroup;")
L(f"\t\t\tchildren = (")
L(f"\t\t\t\t{PRID} /* PiecesTask.app */,")
L(f"\t\t\t);")
L(f"\t\t\tname = Products;")
L(f"\t\t\tsourceTree = SOURCE_ROOT;")
L(f"\t\t}};")

# Build files
for src in sources:
    L(f"\t\t{bf_ids[src]} /* {os.path.basename(src)} in Sources */ = {{")
    L(f"\t\t\tisa = PBXBuildFile;")
    L(f"\t\t\tfileRef = {file_ids[src]};")
    L(f"\t\t}};")

L(f"\t\t{ASSET_BFID} /* {ASSETS} in Resources */ = {{")
L(f"\t\t\tisa = PBXBuildFile;")
L(f"\t\t\tfileRef = {ASSET_FID};")
L(f"\t\t}};")

# Native target
L(f"\t\t{NTID} = {{")
L(f"\t\t\tisa = PBXNativeTarget;")
L(f"\t\t\tbuildConfigurationList = {BCLID};")
L(f"\t\t\tbuildPhases = (")
L(f"\t\t\t\t{SBPID},")
L(f"\t\t\t\t{RBPID},")
L(f"\t\t\t);")
L(f"\t\t\tbuildRules = (")
L(f"\t\t\t);")
L(f"\t\t\tdependencies = (")
L(f"\t\t\t);")
L(f"\t\t\tname = \"PiecesTask\";")
L(f"\t\t\tproductName = \"PiecesTask\";")
L(f"\t\t\tproductReference = {PRID};")
L(f"\t\t\tproductType = \"com.apple.product-type.application\";")
L(f"\t\t}};")

# Sources build phase
L(f"\t\t{SBPID} = {{")
L(f"\t\t\tisa = PBXSourcesBuildPhase;")
L(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
L(f"\t\t\tfiles = (")
for src in sources:
    L(f"\t\t\t\t{bf_ids[src]},")
L(f"\t\t\t);")
L(f"\t\t}};")

# Resources build phase
L(f"\t\t{RBPID} = {{")
L(f"\t\t\tisa = PBXResourcesBuildPhase;")
L(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
L(f"\t\t\tfiles = (")
L(f"\t\t\t\t{ASSET_BFID},")
L(f"\t\t\t);")
L(f"\t\t}};")

# Build config list
L(f"\t\t{BCLID} = {{")
L(f"\t\t\tisa = XCConfigurationList;")
L(f"\t\t\tbuildConfigurations = (")
L(f"\t\t\t\t{BCDID} /* Debug */,")
L(f"\t\t\t\t{BCRID} /* Release */,")
L(f"\t\t\t);")
L(f"\t\t\tdefaultConfigurationIsVisible = 0;")
L(f"\t\t\tdefaultConfigurationName = Release;")
L(f"\t\t}};")

# Build configs
for cid, cname in [(BCDID, "Debug"), (BCRID, "Release")]:
    L(f"\t\t{cid} /* {cname} */ = {{")
    L(f"\t\t\tisa = XCBuildConfiguration;")
    L(f"\t\t\tbuildSettings = {{")
    L(f"\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    if cname == "Release":
        L(f"\t\t\t\tCODE_SIGN_ENTITLEMENTS = \"PiecesTask/PiecesTask.entitlements\";")
        L(f"\t\t\t\tCODE_SIGN_IDENTITY = \"Developer ID Application\";")
        L(f"\t\t\t\tCODE_SIGN_STYLE = Manual;")
        L(f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        L(f"\t\t\t\tDEVELOPMENT_TEAM = P5RB3W3D58;")
        L(f"\t\t\t\tENABLE_HARDENED_RUNTIME = YES;")
    else:
        L(f"\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    L(f"\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
    L(f"\t\t\t\tENABLE_PREVIEWS = YES;")
    L(f"\t\t\t\tINFOPLIST_FILE = \"PiecesTask/Info.plist\";")
    L(f"\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    L(f"\t\t\t\t\t\"$(inherited)\",")
    L(f"\t\t\t\t\t\"@executable_path/../Frameworks\",")
    L(f"\t\t\t\t);")
    if cname == "Release":
        L(f"\t\t\t\tMARKETING_VERSION = 1.0.0;")
    L(f"\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;")
    L(f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = app.piecestask;")
    L(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    L(f"\t\t\t\tSWIFT_VERSION = 6.0;")
    L(f"\t\t\t}};")
    L(f"\t\t\tname = {cname};")
    L(f"\t\t}};")

# Project
L(f"\t\t{PXPID} = {{")
L(f"\t\t\tisa = PBXProject;")
L(f"\t\t\tattributes = {{ BuildIndependentTargetsInParallel = 1; }};")
L(f"\t\t\tbuildConfigurationList = {BCLID};")
L(f"\t\t\tcompatibilityVersion = \"Xcode 15.0\";")
L(f"\t\t\tdevelopmentRegion = en;")
L(f"\t\t\thasScannedForEncodings = 0;")
L(f"\t\t\tknownRegions = (en, Base);")
L(f"\t\t\tmainGroup = {MGID};")
L(f"\t\t\tproductRefGroup = {PGID};")
L(f"\t\t\tprojectDirPath = \"\";")
L(f"\t\t\tprojectRoot = \"\";")
L(f"\t\t\ttargets = ({NTID},);")
L(f"\t\t}};")

L("\t};")
L(f"\trootObject = {PXPID} /* Project object */;")
L("}")

os.makedirs("PiecesTask.xcodeproj", exist_ok=True)
with open("PiecesTask.xcodeproj/project.pbxproj", "w") as f:
    f.write("\n".join(lines))

print(f"Generated Xcode project with {len(sources)} source files")
for s in sources:
    print(f"  - {s}")
