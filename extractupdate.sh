#!/bin/sh
if [ "$#" -le 1 ]; then
  echo "ERROR: Missing arguments. Filename to watch for, output path and whether to create a symlink to latest required.\n\nExample:\n./extractupdate.sh Hedge.app.zip ~/Desktop/output [~/Desktop/Hedge-latest.app]"
  exit 1
fi

filename="$1"
app_name=${filename%%.*}
output_dir="$2"
symlink_path="$3"

if [ ! -d "$output_dir" ]; then
  echo "ERROR: Destination folder doesn't exist. Create it first."
  exit 2
fi

latest_build=0
latest_path=

while read -d "" path; do

  # Check if the file still exists at the path
  # If not, it's probably deleted or moved
  zip_path=
  if [ -f "$path" ]; then
   
    # If the path ends with the filename, it's the file that we want
    if [[ "$path" == *$filename ]]; then

      zip_path="$path"

    fi

  elif [ -d "$path" ]; then

    # Check if the folder contains the file we want
    if [ -f "$path/$filename" ]; then

      zip_path="$path/$filename"

    fi
  fi

  if [ -z "$zip_path" ]; then
    # Skip if zip_path is null
    continue
  fi

  # Create temp directory in the output dir
  tmp_dir="$output_dir/tmp"

  /usr/bin/unzip -qou "$zip_path" -d "$tmp_dir"
  zip_success=$?

  if [ $zip_success -ne 0 ]; then
    echo "ERROR: Failed to extract the zip." 
    # Stop processing if zip wasn't extracted
    continue
  fi

  # Find the app
  app_path=$(/usr/bin/find "$tmp_dir" -name '*.app' | head -n 1)

  if [ -z "$app_path" ]; then
    echo "WARNING: No .app found in the zip file. Skipping."
    # Skip if app_path is null
    continue
  fi

  # Get app info
  plist="$app_path/Contents/Info.plist"
  build_version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $plist)
  build_number=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $plist)

  # Move to output folder with updated name
  output_app_path="$output_dir/${app_name}_${build_version}b${build_number}.app"

  # Save path to be able to update symlink to latest
  if (( $build_number >= $latest_build )); then
    latest_build=$build_number
    latest_path="$output_app_path"
  fi

  now=$(date +"%d-%m-%Y %H:%M:%S")

  if [ -d "$output_app_path" ]; then
    echo "$now: $output_app_path already exists"
    # Remove temporarily extracted app
    rm -r "$app_path"
    continue
  fi

  mv "$app_path" "$output_app_path"
  mv_success=$?

  if [ $mv_success -ne 0 ]; then
    echo "ERROR: Failed to move app to output folder."
    # Stop if the file wasn't moved
    continue
  fi

  echo "$now: $output_app_path"

  # Create symlink to latest
  if [ ! -z "$symlink_path" ] && [ ! -z "$latest_path" ]; then

    # Remove old symlink
    if [ -d "$symlink_path" ]; then
      rm "$symlink_path"
    fi

    ln -s "$latest_path" "$symlink_path"
    sym_success=$?

    if [ $sym_success -ne 0 ]; then
      echo "ERROR: Failed to create symlink to the last build."
    fi
  fi

done
