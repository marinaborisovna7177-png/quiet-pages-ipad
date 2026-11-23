from pathlib import Path
import hashlib
root=Path(__file__).parent
sources=['QuietPagesApp.swift','NotebookData.swift','NotebookUI.swift','NotebookEditor.swift','TextStudio.swift','InkCanvas.swift','Export.swift']

def ident(s):return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def objid(prefix,name):return ident(prefix+name)
PBXROOT=objid('root','project'); FILEGROUP=objid('group','root'); SRCCG=objid('group','sources'); ASSETSG=objid('group','resources'); PRODUCTG=objid('group','products')
TARGET=objid('target','QuietPages'); SRCB=objid('buildphase','sources'); RESB=objid('buildphase','resources'); FRAMEB=objid('buildphase','frameworks'); PROJLIST=objid('cfglist','project'); TARGETLIST=objid('cfglist','target')
PRODUCT=objid('product','QuietPages.app'); ASSET=objid('file','Assets.xcassets')
CONFPRD=objid('conf','ProjectRelease');CONFPDD=objid('conf','ProjectDebug');CONFTD=objid('conf','TargetDebug');CONFTR=objid('conf','TargetRelease')
content=[]
def add(s):content.append(s)
add('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {')
add('/* Begin PBXBuildFile section */')
for s in sources:
  add(f'\t\t{objid("build",s)} /* {s} in Sources */ = {{isa = PBXBuildFile; fileRef = {objid("file",s)} /* {s} */; }};')
add(f'\t\t{objid("build","assets")} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ASSET} /* Assets.xcassets */; }};')
add('/* End PBXBuildFile section */')
add('/* Begin PBXFileReference section */')
for s in sources:
  add(f'\t\t{objid("file",s)} /* {s} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {s}; sourceTree = "<group>"; }};')
add(f'\t\t{ASSET} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};')
add(f'\t\t{PRODUCT} /* QuietPages.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = QuietPages.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
add('/* End PBXFileReference section */')
add('/* Begin PBXFrameworksBuildPhase section */')
add(f'\t\t{FRAMEB} = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};')
add('/* End PBXFrameworksBuildPhase section */')
add('/* Begin PBXGroup section */')
add(f'\t\t{FILEGROUP} = {{isa = PBXGroup; children = ({SRCCG} /* Sources */, {ASSETSG} /* Resources */, {PRODUCTG} /* Products */); sourceTree = "<group>"; }};')
add(f'\t\t{SRCCG} /* Sources */ = {{isa = PBXGroup; children = (')
for s in sources:add(f'\t\t\t{objid("file",s)} /* {s} */,')
add('\t\t); path = Sources; sourceTree = "<group>"; };')
add(f'\t\t{ASSETSG} /* Resources */ = {{isa = PBXGroup; children = ({ASSET} /* Assets.xcassets */); path = Resources; sourceTree = "<group>"; }};')
add(f'\t\t{PRODUCTG} /* Products */ = {{isa = PBXGroup; children = ({PRODUCT} /* QuietPages.app */); name = Products; sourceTree = "<group>"; }};')
add('/* End PBXGroup section */')
add('/* Begin PBXNativeTarget section */')
add(f'''\t\t{TARGET} /* QuietPages */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {TARGETLIST};
\t\t\tbuildPhases = ({SRCB}, {FRAMEB}, {RESB});
\t\t\tbuildRules = ();
\t\t\tdependencies = ();
\t\t\tname = QuietPages;
\t\t\tproductName = QuietPages;
\t\t\tproductReference = {PRODUCT} /* QuietPages.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};''')
add('/* End PBXNativeTarget section */')
add('/* Begin PBXProject section */')
add(f'''\t\t{PBXROOT} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{ BuildIndependentTargetsInParallel = 1; LastUpgradeCheck = 1600; TargetAttributes = {{ {TARGET} = {{ CreatedOnToolsVersion = 16.0; LastSwiftMigration = 1600; }}; }}; }};
\t\t\tbuildConfigurationList = {PROJLIST};
\t\t\tcompatibilityVersion = "Xcode 15.0";
\t\t\tdevelopmentRegion = ru;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (ru, en, Base);
\t\t\tmainGroup = {FILEGROUP};
\t\t\tproductRefGroup = {PRODUCTG};
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = ({TARGET} /* QuietPages */);
\t\t}};''')
add('/* End PBXProject section */')
add('/* Begin PBXResourcesBuildPhase section */')
add(f'\t\t{RESB} = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({objid("build","assets")} /* Assets.xcassets in Resources */); runOnlyForDeploymentPostprocessing = 0; }};')
add('/* End PBXResourcesBuildPhase section */')
add('/* Begin PBXSourcesBuildPhase section */')
add(f'\t\t{SRCB} = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (')
for s in sources:add(f'\t\t\t{objid("build",s)} /* {s} in Sources */,')
add('\t\t); runOnlyForDeploymentPostprocessing = 0; };')
add('/* End PBXSourcesBuildPhase section */')
add('/* Begin XCBuildConfiguration section */')
for id_,name,settings in [
 (CONFPDD,'Debug','''ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES; DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_TESTABILITY = YES; GCC_OPTIMIZATION_LEVEL = 0; SDKROOT = iphoneos; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; SWIFT_OPTIMIZATION_LEVEL = "-Onone";'''),
 (CONFPRD,'Release','''ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; SDKROOT = iphoneos; SWIFT_COMPILATION_MODE = wholemodule; SWIFT_OPTIMIZATION_LEVEL = "-O";'''),
 (CONFTD,'Debug','''ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; DEVELOPMENT_ASSET_PATHS = ""; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Resources/Info.plist; IPHONEOS_DEPLOYMENT_TARGET = 17.0; MARKETING_VERSION = 3.0; PRODUCT_BUNDLE_IDENTIFIER = com.salipaper.quietpages; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; TARGETED_DEVICE_FAMILY = 2;'''),
 (CONFTR,'Release','''ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; DEVELOPMENT_ASSET_PATHS = ""; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Resources/Info.plist; IPHONEOS_DEPLOYMENT_TARGET = 17.0; MARKETING_VERSION = 3.0; PRODUCT_BUNDLE_IDENTIFIER = com.salipaper.quietpages; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; TARGETED_DEVICE_FAMILY = 2;''')]:
 add(f'\t\t{id_} /* {name} */ = {{isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {name}; }};')
add('/* End XCBuildConfiguration section */')
add('/* Begin XCConfigurationList section */')
add(f'\t\t{PROJLIST} = {{isa = XCConfigurationList; buildConfigurations = ({CONFPDD}, {CONFPRD}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};')
add(f'\t\t{TARGETLIST} = {{isa = XCConfigurationList; buildConfigurations = ({CONFTD}, {CONFTR}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};')
add('/* End XCConfigurationList section */')
add('};\n\trootObject = '+PBXROOT+';\n}')
(root/'QuietPages.xcodeproj'/'project.pbxproj').write_text('\n'.join(content))

info='''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>ru</string>
<key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
<key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>Тихие страницы</string>
<key>CFBundleDisplayName</key><string>Тихие страницы</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$(MARKETING_VERSION)</string>
<key>CFBundleVersion</key><string>$(CURRENT_PROJECT_VERSION)</string>
<key>LSRequiresIPhoneOS</key><true/>
<key>NSPhotoLibraryUsageDescription</key><string>Фотографии используются только для украшения страниц блокнота и остаются на устройстве.</string>
<key>UISupportedInterfaceOrientations~ipad</key><array><string>UIInterfaceOrientationPortrait</string><string>UIInterfaceOrientationLandscapeLeft</string><string>UIInterfaceOrientationLandscapeRight</string><string>UIInterfaceOrientationPortraitUpsideDown</string></array>
<key>UIRequiredDeviceCapabilities</key><array><string>arm64</string></array>
<key>UIRequiresFullScreen</key><true/>
<key>UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key><false/></dict>
</dict></plist>
'''
(root/'Resources'/'Info.plist').write_text(info)
