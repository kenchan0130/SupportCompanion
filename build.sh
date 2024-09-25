#!/bin/bash
PROJECT_PATH="."
BUILD_PATH="./Build"
BUILD_LA_PATH="./LaunchAgent"
APP_SUPPORT_PATH="${BUILD_PATH}/payload/Library/Application Support/SupportCompanion"
PUBLISH_OUTPUT_DIRECTORY="${PROJECT_PATH}/bin/Release/net8.0-macos/SupportCompanion.app"
PUBLISH_OUTPUT_APP="${PROJECT_PATH}/bin/Release/net8.0-macos/SupportCompanion.app"
ICON_FILE="${PROJECT_PATH}/Assets/appicon.icns"
SUKIUI_LICENSE_FILE="${PROJECT_PATH}/SUKIUI_LICENSE"
AVALONIA_LICENSE_FILE="${PROJECT_PATH}/LICENSE"
UNINSTALL_SCRIPT="${PROJECT_PATH}/Assets/Uninstall.sh"
APP_SIGNING_IDENTITY="Developer ID Application: Mac Admins Open Source (T4SK8ZXCXG)"
INSTALLER_SIGNING_IDENTITY="Developer ID Installer: Mac Admins Open Source (T4SK8ZXCXG)"
XCODE_PATH="/Applications/Xcode_15.4.app"
XCODE_NOTARY_PATH="$XCODE_PATH/Contents/Developer/usr/bin/notarytool"
XCODE_STAPLER_PATH="$XCODE_PATH/Contents/Developer/usr/bin/stapler"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${PROJECT_PATH}/Info.plist")
PKG_PATH="${BUILD_PATH}/build"
APP_NAME="payload/Applications/Utilities/SupportCompanion.app"
ENTITLEMENTS="${PROJECT_PATH}/SupportCompanion.entitlements"
MP_SHA="71c57fcfdf43692adcd41fa7305be08f66bae3e5"
MP_BINDIR="/tmp/munki-pkg"
MP_ZIP="/tmp/munki-pkg.zip"
CURRENT_SC_MAIN_BUILD_VERSION=$VERSION
NEWSUBBUILD=$((80620 + $(git rev-parse HEAD~0 | xargs -I{} git rev-list --count {})))

# Ensure Xcode is set to run-time
sudo xcode-select -s "$XCODE_PATH"

# automate the build version bump
AUTOMATED_SC_BUILD="$CURRENT_SC_MAIN_BUILD_VERSION.$NEWSUBBUILD"

echo "$AUTOMATED_SC_BUILD" > "./build_info.txt"
echo "$CURRENT_SC_MAIN_BUILD_VERSION" > "./build_info_main.txt"

# is dotnet installed?
dotnet="$(dotnet --version)"

if [ -z "$dotnet" ]
then
  echo "dotnet is not installed"
  exit 1
fi

# Install dotnet workloads
dotnet workload restore

# Download specific version of munki-pkg
echo "Downloading munki-pkg tool from github..."
if [ -f "${MP_ZIP}" ]; then
    /usr/bin/sudo /bin/rm -rf ${MP_ZIP}
fi
/usr/bin/curl https://github.com/munki/munki-pkg/archive/${MP_SHA}.zip -L -o ${MP_ZIP}
if [ -d ${MP_BINDIR} ]; then
    /usr/bin/sudo /bin/rm -rf ${MP_BINDIR}
fi
/usr/bin/unzip ${MP_ZIP} -d ${MP_BINDIR}
DL_RESULT="$?"
if [ "${DL_RESULT}" != "0" ]; then
    echo "Error downloading munki-pkg tool: ${DL_RESULT}" 1>&2
    exit 1
fi

# Setup notary item
$XCODE_NOTARY_PATH store-credentials --apple-id "opensource@macadmins.io" --team-id "T4SK8ZXCXG" --password "$1" supportcompanion

if [ -d "$PUBLISH_OUTPUT_DIRECTORY" ]
then
  rm -rf "$PUBLISH_OUTPUT_DIRECTORY"
fi

if [ -d "$APP_SUPPORT_PATH/scripts" ]
then
  rm -rf "$APP_SUPPORT_PATH/scripts"
fi

if [ -d "$BUILD_PATH/$APP_NAME/" ]
then
  rm -rf "$BUILD_PATH/{$APP_NAME}/"
fi

dotnet publish --configuration Release -p:UseAppHost=true

# Create the Applications directory and utilities directory
mkdir -p "${BUILD_PATH}/payload/Applications/Utilities"

# Create resources directory
mkdir -p "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources"

rm -f "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/suki_photo.ico"
cp "$ICON_FILE" "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/"
cp "$UNINSTALL_SCRIPT" "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/"
cp "$SUKIUI_LICENSE_FILE" "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/"
cp "$AVALONIA_LICENSE_FILE" "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/"
chmod +x "$PUBLISH_OUTPUT_DIRECTORY/Contents/Resources/Uninstall.sh"
cp -a "${PROJECT_PATH}/Assets/scripts" "${BUILD_PATH}/payload/Library/Application Support/SupportCompanion/"

# set the plist version to AUTOMATED_SC_BUILD
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $AUTOMATED_SC_BUILD" "${PUBLISH_OUTPUT_APP}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $AUTOMATED_SC_BUILD" "${PUBLISH_OUTPUT_APP}/Contents/Info.plist"

# mv each script file to remove the extension
SCRIPT_FILES="$(ls "${APP_SUPPORT_PATH}/scripts/")"
for SCRIPT_FILE in $SCRIPT_FILES
do
    FILE_WITHOUT_EXT=$(basename "$SCRIPT_FILE" .py)
    mv "$APP_SUPPORT_PATH/scripts/$SCRIPT_FILE" "$APP_SUPPORT_PATH/scripts/$FILE_WITHOUT_EXT"
    chmod +x "$APP_SUPPORT_PATH/scripts/$FILE_WITHOUT_EXT"
done

cp -a "$PUBLISH_OUTPUT_APP" "${BUILD_PATH}/payload/Applications/Utilities/"

# Sign the Support Companion app
# /usr/bin/codesign --sign "${APP_SIGNING_IDENTITY}" --timestamp --deep --force --options=runtime --entitlements "$ENTITLEMENTS" --preserve-metadata=identifier,entitlements,flags,runtime "${BUILD_PATH}/${APP_NAME}"
# Recursively sign everything in /Contents/MonoBundle
find "${BUILD_PATH}/${APP_NAME}/Contents/MonoBundle" -type f -perm -u=x -exec /usr/bin/codesign --sign "${APP_SIGNING_IDENTITY}" --timestamp --preserve-metadata=identifier,entitlements,flags,runtime -f {} \;
find "${BUILD_PATH}/${APP_NAME}/Contents/MonoBundle" -type f -name "*dylib" -exec /usr/bin/codesign --sign "${APP_SIGNING_IDENTITY}" --timestamp --preserve-metadata=identifier,entitlements,flags,runtime -f {} \;
# Recursively sign everything in /Contents/Resources
find "${BUILD_PATH}/${APP_NAME}/Contents/Resources" -type f -perm -u=x -exec /usr/bin/codesign --sign "${APP_SIGNING_IDENTITY}" --timestamp --preserve-metadata=identifier,entitlements,flags,runtime -f {} \;
# Avalonia docs signing style
find "$BUILD_PATH/$APP_NAME/Contents/MacOS/"|while read fname; do
    if [[ -f $fname ]]; then
        echo "[INFO] Signing $fname"
        codesign --force --timestamp --options=runtime --entitlements "$ENTITLEMENTS" --sign "$APP_SIGNING_IDENTITY" "$fname"
    fi
done

codesign --force --timestamp --options=runtime --entitlements "$ENTITLEMENTS" --sign "$APP_SIGNING_IDENTITY" "$BUILD_PATH/$APP_NAME"

# Create the json file for signed munkipkg Support Companion pkg
/bin/cat << SIGNED_JSONFILE > "$BUILD_PATH/build-info.json"
{
  "ownership": "recommended",
  "suppress_bundle_relocation": true,
  "identifier": "com.almenscorner.supportcompanion",
  "postinstall_action": "none",
  "distribution_style": true,
  "version": "$AUTOMATED_SC_BUILD",
  "name": "SupportCompanion-$AUTOMATED_SC_BUILD.pkg",
  "install_location": "/",
  "signing_info": {
    "identity": "$INSTALLER_SIGNING_IDENTITY",
    "timestamp": true
  }
}
SIGNED_JSONFILE

# Create the signed pkg
python3 "${MP_BINDIR}/munki-pkg-${MP_SHA}/munkipkg" "$BUILD_PATH"
PKG_RESULT="$?"
if [ "${PKG_RESULT}" != "0" ]; then
  echo "Could not sign package: ${PKG_RESULT}" 1>&2
else
  # Notarize Support Companion package
  $XCODE_NOTARY_PATH submit "$PKG_PATH/SupportCompanion-$AUTOMATED_SC_BUILD.pkg" --keychain-profile "supportcompanion" --wait
  $XCODE_STAPLER_PATH staple "$PKG_PATH/SupportCompanion-$AUTOMATED_SC_BUILD.pkg"
fi

# Create the json file for signed munkipkg Support Companion LaunchAgent pkg
LAUNCHAGENT_VERSION="1.0.1"
/bin/cat << SIGNED_JSONFILE > "$BUILD_LA_PATH/build-info.json"
{
  "ownership": "recommended",
  "suppress_bundle_relocation": true,
  "identifier": "com.almenscorner.supportcompanion.LaunchAgent",
  "postinstall_action": "none",
  "distribution_style": true,
  "version": "$LAUNCHAGENT_VERSION",
  "name": "SupportCompanion_LaunchAgent-$LAUNCHAGENT_VERSION.pkg",
  "install_location": "/Library/LaunchAgents",
  "signing_info": {
    "identity": "$INSTALLER_SIGNING_IDENTITY",
    "timestamp": true
  }
}
SIGNED_JSONFILE

# Create the signed pkg
python3 "${MP_BINDIR}/munki-pkg-${MP_SHA}/munkipkg" "$BUILD_LA_PATH"
PKG_RESULT="$?"
if [ "${PKG_RESULT}" != "0" ]; then
  echo "Could not sign package: ${PKG_RESULT}" 1>&2
else
  mv "$BUILD_LA_PATH/build/SupportCompanion_LaunchAgent-$LAUNCHAGENT_VERSION.pkg" "$BUILD_PATH/build/SupportCompanion_LaunchAgent-$LAUNCHAGENT_VERSION.pkg"
  # Notarize Support Companion LaunchAgent package
  $XCODE_NOTARY_PATH submit "$PKG_PATH/SupportCompanion_LaunchAgent-$LAUNCHAGENT_VERSION.pkg" --keychain-profile "supportcompanion" --wait
  $XCODE_STAPLER_PATH staple "$PKG_PATH/SupportCompanion_LaunchAgent-$LAUNCHAGENT_VERSION.pkg"
fi

# Create the json file for signed munkipkg Support Companion suite pkg
mkdir "$BUILD_PATH/payload/Library/LaunchAgents"
cp "$BUILD_LA_PATH/payload/com.almenscorner.supportcompanion.agent.plist" "$BUILD_PATH/payload/Library/LaunchAgents/com.almenscorner.supportcompanion.agent.plist"

/bin/cat << SIGNED_JSONFILE > "$BUILD_PATH/build-info.json"
{
  "ownership": "recommended",
  "suppress_bundle_relocation": true,
  "identifier": "com.almenscorner.supportcompanion.suite",
  "postinstall_action": "none",
  "distribution_style": true,
  "version": "$AUTOMATED_SC_BUILD",
  "name": "SupportCompanion_Suite-$AUTOMATED_SC_BUILD.pkg",
  "install_location": "/",
  "signing_info": {
    "identity": "$INSTALLER_SIGNING_IDENTITY",
    "timestamp": true
  }
}
SIGNED_JSONFILE

python3 "${MP_BINDIR}/munki-pkg-${MP_SHA}/munkipkg" "$BUILD_PATH"
PKG_RESULT="$?"
if [ "${PKG_RESULT}" != "0" ]; then
  echo "Could not sign package: ${PKG_RESULT}" 1>&2
else
  # Notarize Support Companion Suite package
  $XCODE_NOTARY_PATH submit "$PKG_PATH/SupportCompanion_Suite-$AUTOMATED_SC_BUILD.pkg" --keychain-profile "supportcompanion" --wait
  $XCODE_STAPLER_PATH staple "$PKG_PATH/SupportCompanion_Suite-$AUTOMATED_SC_BUILD.pkg"
fi