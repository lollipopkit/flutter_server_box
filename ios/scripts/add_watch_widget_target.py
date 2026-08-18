#!/usr/bin/env python3
"""One-shot edit of Runner.xcodeproj to wire up the watch targets.

Xcode is the usual author of `project.pbxproj`, and it is not available in the
environment this repo is developed in, so the edits are scripted instead of
hand-typed: every insertion is anchored on an exact existing line and the
script refuses to run twice.

What it does:
  - raises WATCHOS_DEPLOYMENT_TARGET to 9.0 (SwiftUI Charts)
  - gives WatchApp and StatusWidgetExtension an entitlements file (App Group)
  - adds WatchShared.swift / MonitorClient.swift to WatchApp, and drops
    Utils.swift from it (its `Status`/`helpUrl` now come from WatchShared)
  - creates the WatchWidgetExtension target, which never existed: the sources
    under ios/WatchWidget were not referenced by the project at all
  - embeds that extension into the watch app

Run from the repo root:  python3 ios/scripts/add_watch_widget_target.py
"""

import re
import sys
from pathlib import Path

PBX = Path("ios/Runner.xcodeproj/project.pbxproj")

# Ids are 24 uppercase hex chars. This prefix is not used by Xcode's generator
# (which derives ids from a timestamp), so these cannot collide.
def oid(n: int) -> str:
    return f"FA7C40{n:018d}"


REF_WATCH_SHARED = oid(1)
REF_MONITOR_CLIENT = oid(2)
REF_WATCH_APP_ENT = oid(3)
REF_WIDGET_SRC = oid(4)
REF_WIDGET_BUNDLE = oid(5)
REF_WIDGET_ENT = oid(6)
REF_WIDGET_APPEX = oid(7)
REF_STATUS_ENT = oid(8)
REF_WIDGET_PLIST = oid(9)

GROUP_WATCH_WIDGET = oid(10)

BF_APP_SHARED = oid(11)
BF_APP_MONITOR = oid(12)
BF_WIDGET_SRC = oid(13)
BF_WIDGET_BUNDLE = oid(14)
BF_WIDGET_SHARED = oid(15)
BF_WIDGET_STORE = oid(16)
BF_EMBED_APPEX = oid(17)

PHASE_SOURCES = oid(20)
PHASE_FRAMEWORKS = oid(21)
PHASE_RESOURCES = oid(22)
PHASE_EMBED = oid(23)

TARGET = oid(30)
CFG_LIST = oid(31)
CFG_DEBUG = oid(32)
CFG_RELEASE = oid(33)
CFG_PROFILE = oid(34)
DEPENDENCY = oid(35)
PROXY = oid(36)

# Existing ids this script anchors on.
WATCH_APP_TARGET = "E39515C62AB5AD62003602C1"
WATCH_APP_GROUP = "E39515C82AB5AD62003602C1"
WATCH_APP_SOURCES = "E39515C32AB5AD62003602C1"
WATCH_APP_STORE_REF = "E39515DC2AB5AE9E003602C1"
UTILS_IN_WATCH_APP = "E3AE8AEC2AB601DB000A6459"
PRODUCTS_GROUP = "97C146EF1CF9000F007C117D"
IOS_GROUP = "97C146E51CF9000F007C117D"
STATUS_WIDGET_GROUP = "E33A3E3D2A626DCE009744AB"
PROJECT_OBJ = "97C146E61CF9000F007C117D"


def fail(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def replace_once(text: str, old: str, new: str, what: str) -> str:
    count = text.count(old)
    if count != 1:
        fail(f"expected exactly one occurrence of {what}, found {count}")
    return text.replace(old, new)


def main() -> None:
    if not PBX.exists():
        fail(f"{PBX} not found; run from the repo root")
    text = PBX.read_text()

    if TARGET in text:
        fail("already applied (WatchWidgetExtension target present)")

    # --- deployment target ------------------------------------------------
    before = text
    text = text.replace(
        "WATCHOS_DEPLOYMENT_TARGET = 7.0;", "WATCHOS_DEPLOYMENT_TARGET = 9.0;"
    )
    if before.count("WATCHOS_DEPLOYMENT_TARGET = 7.0;") != 3:
        fail("expected 3 watchOS deployment target settings")

    # --- entitlements on existing targets ---------------------------------
    # Anchored on a setting each config of the target carries and no other
    # target does, so the three configs are hit once each.
    text = text.replace(
        "PRODUCT_BUNDLE_IDENTIFIER = com.lollipopkit.toolbox.WatchEnd;",
        "CODE_SIGN_ENTITLEMENTS = WatchApp/WatchApp.entitlements;\n"
        "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.lollipopkit.toolbox.WatchEnd;",
    )
    text = text.replace(
        "PRODUCT_BUNDLE_IDENTIFIER = com.lollipopkit.toolbox.StatusWidget;",
        "CODE_SIGN_ENTITLEMENTS = StatusWidget/StatusWidget.entitlements;\n"
        "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.lollipopkit.toolbox.StatusWidget;",
    )

    # --- PBXBuildFile -----------------------------------------------------
    text = replace_once(
        text,
        f"\t\t{UTILS_IN_WATCH_APP} /* Utils.swift in Sources */ = {{isa = PBXBuildFile; fileRef = E3AE8AE92AB601DB000A6459 /* Utils.swift */; }};\n",
        "",
        "the WatchApp Utils.swift build file",
    )
    text = replace_once(
        text,
        "/* End PBXBuildFile section */",
        "\n".join(
            [
                f"\t\t{BF_APP_SHARED} /* WatchShared.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {REF_WATCH_SHARED} /* WatchShared.swift */; }};",
                f"\t\t{BF_APP_MONITOR} /* MonitorClient.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {REF_MONITOR_CLIENT} /* MonitorClient.swift */; }};",
                f"\t\t{BF_WIDGET_SRC} /* WatchStatusWidget.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {REF_WIDGET_SRC} /* WatchStatusWidget.swift */; }};",
                f"\t\t{BF_WIDGET_BUNDLE} /* WatchStatusWidgetBundle.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {REF_WIDGET_BUNDLE} /* WatchStatusWidgetBundle.swift */; }};",
                f"\t\t{BF_WIDGET_SHARED} /* WatchShared.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {REF_WATCH_SHARED} /* WatchShared.swift */; }};",
                f"\t\t{BF_WIDGET_STORE} /* Store.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {WATCH_APP_STORE_REF} /* Store.swift */; }};",
                f"\t\t{BF_EMBED_APPEX} /* WatchWidgetExtension.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {REF_WIDGET_APPEX} /* WatchWidgetExtension.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};",
                "/* End PBXBuildFile section */",
            ]
        ),
        "the PBXBuildFile section end",
    )

    # --- PBXContainerItemProxy -------------------------------------------
    text = replace_once(
        text,
        "/* End PBXContainerItemProxy section */",
        "\n".join(
            [
                f"\t\t{PROXY} /* PBXContainerItemProxy */ = {{",
                "\t\t\tisa = PBXContainerItemProxy;",
                f"\t\t\tcontainerPortal = {PROJECT_OBJ} /* Project object */;",
                "\t\t\tproxyType = 1;",
                f"\t\t\tremoteGlobalIDString = {TARGET};",
                "\t\t\tremoteInfo = WatchWidgetExtension;",
                "\t\t};",
                "/* End PBXContainerItemProxy section */",
            ]
        ),
        "the PBXContainerItemProxy section end",
    )

    # --- PBXCopyFilesBuildPhase (embed the appex into the watch app) ------
    text = replace_once(
        text,
        "/* End PBXCopyFilesBuildPhase section */",
        "\n".join(
            [
                f"\t\t{PHASE_EMBED} /* Embed Foundation Extensions */ = {{",
                "\t\t\tisa = PBXCopyFilesBuildPhase;",
                "\t\t\tbuildActionMask = 2147483647;",
                '\t\t\tdstPath = "";',
                "\t\t\tdstSubfolderSpec = 13;",
                "\t\t\tfiles = (",
                f"\t\t\t\t{BF_EMBED_APPEX} /* WatchWidgetExtension.appex in Embed Foundation Extensions */,",
                "\t\t\t);",
                '\t\t\tname = "Embed Foundation Extensions";',
                "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
                "\t\t};",
                "/* End PBXCopyFilesBuildPhase section */",
            ]
        ),
        "the PBXCopyFilesBuildPhase section end",
    )

    # --- PBXFileReference -------------------------------------------------
    text = replace_once(
        text,
        "/* End PBXFileReference section */",
        "\n".join(
            [
                f"\t\t{REF_WATCH_SHARED} /* WatchShared.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WatchShared.swift; sourceTree = \"<group>\"; }};",
                f"\t\t{REF_MONITOR_CLIENT} /* MonitorClient.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MonitorClient.swift; sourceTree = \"<group>\"; }};",
                f"\t\t{REF_WATCH_APP_ENT} /* WatchApp.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = WatchApp.entitlements; sourceTree = \"<group>\"; }};",
                f"\t\t{REF_WIDGET_SRC} /* WatchStatusWidget.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WatchStatusWidget.swift; sourceTree = \"<group>\"; }};",
                f"\t\t{REF_WIDGET_BUNDLE} /* WatchStatusWidgetBundle.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WatchStatusWidgetBundle.swift; sourceTree = \"<group>\"; }};",
                f"\t\t{REF_WIDGET_ENT} /* WatchWidget.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = WatchWidget.entitlements; sourceTree = \"<group>\"; }};",
                f"\t\t{REF_WIDGET_PLIST} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};",
                f"\t\t{REF_WIDGET_APPEX} /* WatchWidgetExtension.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = WatchWidgetExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; }};",
                f"\t\t{REF_STATUS_ENT} /* StatusWidget.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = StatusWidget.entitlements; sourceTree = \"<group>\"; }};",
                "/* End PBXFileReference section */",
            ]
        ),
        "the PBXFileReference section end",
    )

    # --- PBXFrameworksBuildPhase -----------------------------------------
    text = replace_once(
        text,
        "/* End PBXFrameworksBuildPhase section */",
        "\n".join(
            [
                f"\t\t{PHASE_FRAMEWORKS} /* Frameworks */ = {{",
                "\t\t\tisa = PBXFrameworksBuildPhase;",
                "\t\t\tbuildActionMask = 2147483647;",
                "\t\t\tfiles = (",
                "\t\t\t);",
                "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
                "\t\t};",
                "/* End PBXFrameworksBuildPhase section */",
            ]
        ),
        "the PBXFrameworksBuildPhase section end",
    )

    # --- groups -----------------------------------------------------------
    text = replace_once(
        text,
        f"\t\t\t\t{WATCH_APP_STORE_REF} /* Store.swift */,\n",
        f"\t\t\t\t{WATCH_APP_STORE_REF} /* Store.swift */,\n"
        f"\t\t\t\t{REF_WATCH_SHARED} /* WatchShared.swift */,\n"
        f"\t\t\t\t{REF_MONITOR_CLIENT} /* MonitorClient.swift */,\n"
        f"\t\t\t\t{REF_WATCH_APP_ENT} /* WatchApp.entitlements */,\n",
        "Store.swift in the WatchApp group",
    )
    text = replace_once(
        text,
        f"\t\t{WATCH_APP_GROUP} /* WatchApp */ = {{",
        "\n".join(
            [
                f"\t\t{GROUP_WATCH_WIDGET} /* WatchWidget */ = {{",
                "\t\t\tisa = PBXGroup;",
                "\t\t\tchildren = (",
                f"\t\t\t\t{REF_WIDGET_SRC} /* WatchStatusWidget.swift */,",
                f"\t\t\t\t{REF_WIDGET_BUNDLE} /* WatchStatusWidgetBundle.swift */,",
                f"\t\t\t\t{REF_WIDGET_PLIST} /* Info.plist */,",
                f"\t\t\t\t{REF_WIDGET_ENT} /* WatchWidget.entitlements */,",
                "\t\t\t);",
                "\t\t\tpath = WatchWidget;",
                '\t\t\tsourceTree = "<group>";',
                "\t\t};",
                f"\t\t{WATCH_APP_GROUP} /* WatchApp */ = {{",
            ]
        ),
        "the WatchApp group header",
    )
    text = replace_once(
        text,
        f"\t\t\t\t{WATCH_APP_GROUP} /* WatchApp */,\n",
        f"\t\t\t\t{WATCH_APP_GROUP} /* WatchApp */,\n"
        f"\t\t\t\t{GROUP_WATCH_WIDGET} /* WatchWidget */,\n",
        "the WatchApp group's place in the project tree",
    )
    text = replace_once(
        text,
        "\t\t\t\tE37C48ED2B9C30EE00E542D2 /* StatusWidget.intentdefinition */,\n",
        "\t\t\t\tE37C48ED2B9C30EE00E542D2 /* StatusWidget.intentdefinition */,\n"
        f"\t\t\t\t{REF_STATUS_ENT} /* StatusWidget.entitlements */,\n",
        "the StatusWidget group contents",
    )
    text = replace_once(
        text,
        "\t\t\t\tE39515C72AB5AD62003602C1 /* ServerBox.app */,\n",
        "\t\t\t\tE39515C72AB5AD62003602C1 /* ServerBox.app */,\n"
        f"\t\t\t\t{REF_WIDGET_APPEX} /* WatchWidgetExtension.appex */,\n",
        "the Products group",
    )

    # --- native target ----------------------------------------------------
    text = replace_once(
        text,
        "/* End PBXNativeTarget section */",
        "\n".join(
            [
                f"\t\t{TARGET} /* WatchWidgetExtension */ = {{",
                "\t\t\tisa = PBXNativeTarget;",
                f'\t\t\tbuildConfigurationList = {CFG_LIST} /* Build configuration list for PBXNativeTarget "WatchWidgetExtension" */;',
                "\t\t\tbuildPhases = (",
                f"\t\t\t\t{PHASE_SOURCES} /* Sources */,",
                f"\t\t\t\t{PHASE_FRAMEWORKS} /* Frameworks */,",
                f"\t\t\t\t{PHASE_RESOURCES} /* Resources */,",
                "\t\t\t);",
                "\t\t\tbuildRules = (",
                "\t\t\t);",
                "\t\t\tdependencies = (",
                "\t\t\t);",
                "\t\t\tname = WatchWidgetExtension;",
                "\t\t\tproductName = WatchWidgetExtension;",
                f"\t\t\tproductReference = {REF_WIDGET_APPEX} /* WatchWidgetExtension.appex */;",
                '\t\t\tproductType = "com.apple.product-type.app-extension";',
                "\t\t};",
                "/* End PBXNativeTarget section */",
            ]
        ),
        "the PBXNativeTarget section end",
    )

    # Embed phase + dependency on the watch app.
    text = replace_once(
        text,
        "\n".join(
            [
                "\t\t\tbuildPhases = (",
                f"\t\t\t\t{WATCH_APP_SOURCES} /* Sources */,",
                "\t\t\t\tE39515C42AB5AD62003602C1 /* Frameworks */,",
                "\t\t\t\tE39515C52AB5AD62003602C1 /* Resources */,",
                "\t\t\t);",
                "\t\t\tbuildRules = (",
                "\t\t\t);",
                "\t\t\tdependencies = (",
                "\t\t\t);",
            ]
        ),
        "\n".join(
            [
                "\t\t\tbuildPhases = (",
                f"\t\t\t\t{WATCH_APP_SOURCES} /* Sources */,",
                "\t\t\t\tE39515C42AB5AD62003602C1 /* Frameworks */,",
                "\t\t\t\tE39515C52AB5AD62003602C1 /* Resources */,",
                f"\t\t\t\t{PHASE_EMBED} /* Embed Foundation Extensions */,",
                "\t\t\t);",
                "\t\t\tbuildRules = (",
                "\t\t\t);",
                "\t\t\tdependencies = (",
                f"\t\t\t\t{DEPENDENCY} /* PBXTargetDependency */,",
                "\t\t\t);",
            ]
        ),
        "the WatchApp target's phases",
    )

    # --- project: target list and attributes ------------------------------
    text = replace_once(
        text,
        "\t\t\t\t\tE39515C62AB5AD62003602C1 = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 14.3.1;\n\t\t\t\t\t};\n",
        "\t\t\t\t\tE39515C62AB5AD62003602C1 = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 14.3.1;\n\t\t\t\t\t};\n"
        f"\t\t\t\t\t{TARGET} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n\t\t\t\t\t}};\n",
        "the WatchApp target attributes",
    )
    text = replace_once(
        text,
        f"\t\t\t\t{WATCH_APP_TARGET} /* WatchApp */,\n\t\t\t);\n\t\t}};\n/* End PBXProject section */",
        f"\t\t\t\t{WATCH_APP_TARGET} /* WatchApp */,\n"
        f"\t\t\t\t{TARGET} /* WatchWidgetExtension */,\n"
        "\t\t\t);\n\t\t};\n/* End PBXProject section */",
        "the project's target list",
    )

    # --- resources phase --------------------------------------------------
    text = replace_once(
        text,
        "/* End PBXResourcesBuildPhase section */",
        "\n".join(
            [
                f"\t\t{PHASE_RESOURCES} /* Resources */ = {{",
                "\t\t\tisa = PBXResourcesBuildPhase;",
                "\t\t\tbuildActionMask = 2147483647;",
                "\t\t\tfiles = (",
                "\t\t\t);",
                "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
                "\t\t};",
                "/* End PBXResourcesBuildPhase section */",
            ]
        ),
        "the PBXResourcesBuildPhase section end",
    )

    # --- sources phases ---------------------------------------------------
    text = replace_once(
        text,
        f"\t\t\t\t{UTILS_IN_WATCH_APP} /* Utils.swift in Sources */,\n",
        f"\t\t\t\t{BF_APP_SHARED} /* WatchShared.swift in Sources */,\n"
        f"\t\t\t\t{BF_APP_MONITOR} /* MonitorClient.swift in Sources */,\n",
        "Utils.swift in the WatchApp sources phase",
    )
    text = replace_once(
        text,
        "/* End PBXSourcesBuildPhase section */",
        "\n".join(
            [
                f"\t\t{PHASE_SOURCES} /* Sources */ = {{",
                "\t\t\tisa = PBXSourcesBuildPhase;",
                "\t\t\tbuildActionMask = 2147483647;",
                "\t\t\tfiles = (",
                f"\t\t\t\t{BF_WIDGET_SRC} /* WatchStatusWidget.swift in Sources */,",
                f"\t\t\t\t{BF_WIDGET_BUNDLE} /* WatchStatusWidgetBundle.swift in Sources */,",
                f"\t\t\t\t{BF_WIDGET_SHARED} /* WatchShared.swift in Sources */,",
                f"\t\t\t\t{BF_WIDGET_STORE} /* Store.swift in Sources */,",
                "\t\t\t);",
                "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
                "\t\t};",
                "/* End PBXSourcesBuildPhase section */",
            ]
        ),
        "the PBXSourcesBuildPhase section end",
    )

    # --- target dependency ------------------------------------------------
    text = replace_once(
        text,
        "/* End PBXTargetDependency section */",
        "\n".join(
            [
                f"\t\t{DEPENDENCY} /* PBXTargetDependency */ = {{",
                "\t\t\tisa = PBXTargetDependency;",
                f"\t\t\ttarget = {TARGET} /* WatchWidgetExtension */;",
                f"\t\t\ttargetProxy = {PROXY} /* PBXContainerItemProxy */;",
                "\t\t};",
                "/* End PBXTargetDependency section */",
            ]
        ),
        "the PBXTargetDependency section end",
    )

    # --- build configurations --------------------------------------------
    def config(oid_: str, name: str, extra: list[str]) -> list[str]:
        return (
            [
                f"\t\t{oid_} /* {name} */ = {{",
                "\t\t\tisa = XCBuildConfiguration;",
                "\t\t\tbuildSettings = {",
                "\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;",
                "\t\t\t\tASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground;",
                "\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;",
                '\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";',
                "\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;",
                "\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;",
                "\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;",
                "\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;",
                "\t\t\t\tCODE_SIGN_ENTITLEMENTS = WatchWidget/WatchWidget.entitlements;",
                "\t\t\t\tCODE_SIGN_STYLE = Automatic;",
                "\t\t\t\tCURRENT_PROJECT_VERSION = 1466;",
                "\t\t\t\tDEVELOPMENT_TEAM = BA88US33G6;",
                "\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;",
                "\t\t\t\tGENERATE_INFOPLIST_FILE = YES;",
                "\t\t\t\tINFOPLIST_FILE = WatchWidget/Info.plist;",
                "\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = ServerBox;",
                '\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";',
                "\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (",
                '\t\t\t\t\t"$(inherited)",',
                '\t\t\t\t\t"@executable_path/Frameworks",',
                '\t\t\t\t\t"@executable_path/../../Frameworks",',
                "\t\t\t\t);",
                "\t\t\t\tMARKETING_VERSION = 1.0.1466;",
                "\t\t\t\tMTL_FAST_MATH = YES;",
                "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.lollipopkit.toolbox.WatchEnd.WatchWidget;",
                '\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";',
                "\t\t\t\tSDKROOT = watchos;",
                "\t\t\t\tSKIP_INSTALL = YES;",
                '\t\t\t\tSUPPORTED_PLATFORMS = "watchsimulator watchos";',
                "\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;",
                "\t\t\t\tSWIFT_VERSION = 5.0;",
                "\t\t\t\tTARGETED_DEVICE_FAMILY = 4;",
                "\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 9.0;",
            ]
            + extra
            + [
                "\t\t\t};",
                f"\t\t\tname = {name};",
                "\t\t};",
            ]
        )

    debug_extra = [
        "\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;",
        "\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;",
        '\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";',
    ]
    text = replace_once(
        text,
        "/* End XCBuildConfiguration section */",
        "\n".join(
            config(CFG_DEBUG, "Debug", debug_extra)
            + config(CFG_RELEASE, "Release", [])
            + config(CFG_PROFILE, "Profile", [])
            + ["/* End XCBuildConfiguration section */"]
        ),
        "the XCBuildConfiguration section end",
    )

    text = replace_once(
        text,
        "/* End XCConfigurationList section */",
        "\n".join(
            [
                f'\t\t{CFG_LIST} /* Build configuration list for PBXNativeTarget "WatchWidgetExtension" */ = {{',
                "\t\t\tisa = XCConfigurationList;",
                "\t\t\tbuildConfigurations = (",
                f"\t\t\t\t{CFG_DEBUG} /* Debug */,",
                f"\t\t\t\t{CFG_RELEASE} /* Release */,",
                f"\t\t\t\t{CFG_PROFILE} /* Profile */,",
                "\t\t\t);",
                "\t\t\tdefaultConfigurationIsVisible = 0;",
                "\t\t\tdefaultConfigurationName = Release;",
                "\t\t};",
                "/* End XCConfigurationList section */",
            ]
        ),
        "the XCConfigurationList section end",
    )

    if UTILS_IN_WATCH_APP in text:
        fail("Utils.swift is still referenced by the WatchApp target")

    PBX.write_text(text)
    print("ok: project.pbxproj updated")


if __name__ == "__main__":
    main()
